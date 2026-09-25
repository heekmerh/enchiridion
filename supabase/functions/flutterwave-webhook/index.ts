// Supabase Edge Function (Deno). Deploy with:
//   supabase functions deploy flutterwave-webhook --no-verify-jwt
// and set its secrets with:
//   supabase secrets set FLUTTERWAVE_SECRET_KEY=<flutterwave secret key>
//   supabase secrets set FLUTTERWAVE_WEBHOOK_HASH=<the "secret hash" you set
//     in Flutterwave Dashboard -> Settings -> Webhooks>
//
// Renewals are charged by Flutterwave on its own schedule (payment plans),
// so nobody is signed in when they happen — unlike
// verify-flutterwave-payment, which the app calls with the buyer's session.
// That is why this endpoint runs without JWT verification and instead
// authenticates the CALLER by the secret hash, and identifies the PAYER by
// the transaction Flutterwave itself confirms.
//
// Nothing in the webhook body is trusted for money facts: every charge is
// re-fetched from Flutterwave's /verify endpoint with the SECRET key before
// any access is granted.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Keep in sync with verify-flutterwave-payment/index.ts and
// lib/config/pricing_config.dart.
const PLAN_PRICES: Record<string, { amount: number; accessDays: number }> = {
  book_monthly: { amount: 1000, accessDays: 30 },
  sub_monthly: { amount: 1000, accessDays: 30 },
  sub_yearly: { amount: 10000, accessDays: 365 },
};

const FLUTTERWAVE_SECRET_KEY = Deno.env.get("FLUTTERWAVE_SECRET_KEY") ?? "";
const FLUTTERWAVE_WEBHOOK_HASH = Deno.env.get("FLUTTERWAVE_WEBHOOK_HASH") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function hashMatches(received: string): boolean {
  if (!FLUTTERWAVE_WEBHOOK_HASH || received.length !== FLUTTERWAVE_WEBHOOK_HASH.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < received.length; i++) {
    diff |= received.charCodeAt(i) ^ FLUTTERWAVE_WEBHOOK_HASH.charCodeAt(i);
  }
  return diff === 0;
}

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function resolveUserId(
  metaUserId: unknown,
  subscriptionId: string | null,
  email: string | null,
): Promise<string | null> {
  if (typeof metaUserId === "string" && UUID_RE.test(metaUserId)) {
    return metaUserId;
  }
  if (subscriptionId) {
    const { data } = await admin
      .from("user_subscriptions")
      .select("user_id")
      .eq("flw_subscription_id", subscriptionId)
      .maybeSingle();
    if (data?.user_id) return data.user_id as string;
  }
  if (email) {
    const { data } = await admin.rpc("user_id_for_email", { p_email: email });
    if (typeof data === "string") return data;
  }
  return null;
}

async function handleRecurringCharge(data: Record<string, unknown>) {
  const transactionId = data.id;
  if (!transactionId) return json({ ignored: "no transaction id" }, 200);

  const verifyRes = await fetch(
    `https://api.flutterwave.com/v3/transactions/${transactionId}/verify`,
    { headers: { Authorization: `Bearer ${FLUTTERWAVE_SECRET_KEY}` } },
  );
  if (!verifyRes.ok) {
    // 5xx makes Flutterwave retry the webhook rather than dropping the charge.
    return json({ error: "Could not verify transaction" }, 502);
  }
  const verifyBody = await verifyRes.json();
  const tx = verifyBody?.data;
  if (!tx || verifyBody.status !== "success" || tx.status !== "successful") {
    return json({ granted: false, reason: "Transaction not successful" }, 200);
  }
  if (tx.currency !== "NGN") {
    return json({ granted: false, reason: "Unexpected currency" }, 200);
  }

  const meta = tx.meta ?? {};
  const email: string | null = tx.customer?.email ?? null;
  const subscriptionId = tx.payment_plan ? String(tx.payment_plan) : null;

  const userId = await resolveUserId(meta.user_id, subscriptionId, email);
  if (!userId) {
    // Nothing to grant to. Answer 200 so Flutterwave stops retrying — the
    // payment is recorded on their side and support can reconcile by email.
    return json({ granted: false, reason: "No matching account" }, 200);
  }

  let existingPlanId: string | undefined;
  let existingScope: string | undefined;
  if (subscriptionId) {
    const { data: existingSub } = await admin
      .from("user_subscriptions")
      .select("plan_id, scope")
      .eq("flw_subscription_id", subscriptionId)
      .maybeSingle();
    existingPlanId = existingSub?.plan_id ?? undefined;
    existingScope = existingSub?.scope ?? undefined;
  }

  const planId = (meta.plan_id as string | undefined) ?? existingPlanId;
  const scope = (meta.book_id as string | undefined) ?? existingScope ?? "*";
  const plan = planId ? PLAN_PRICES[planId] : undefined;
  if (!plan) return json({ granted: false, reason: "Unknown plan" }, 200);
  if (Number(tx.amount) < plan.amount) {
    return json({ granted: false, reason: "Amount does not match plan" }, 200);
  }

  // Anti-replay, shared with verify-flutterwave-payment: whichever of the two
  // sees a given transaction_id first grants it, the other is a no-op. That
  // matters for the FIRST charge of a subscription, which arrives both as a
  // webhook and as the client's own verify call.
  const { error: insertError } = await admin.from("processed_payments").insert({
    transaction_id: String(transactionId),
    user_id: userId,
    plan_id: planId,
    book_id: scope,
    amount: tx.amount,
    currency: tx.currency,
  });
  if (insertError) {
    return json({ granted: true, alreadyProcessed: true }, 200);
  }

  const { data: existingAccess } = await admin
    .from("user_book_access")
    .select("expires_at")
    .eq("user_id", userId)
    .eq("book_id", scope)
    .maybeSingle();

  const now = new Date();
  const currentExpiry = existingAccess?.expires_at
    ? new Date(existingAccess.expires_at)
    : null;
  const base = currentExpiry && currentExpiry > now ? currentExpiry : now;
  const expiresAt = new Date(base.getTime() + plan.accessDays * 86400000);

  const { error: grantError } = await admin.from("user_book_access").upsert(
    {
      user_id: userId,
      book_id: scope,
      access_type: scope === "*" ? "subscription" : "book",
      granted: true,
      expires_at: expiresAt.toISOString(),
    },
    { onConflict: "user_id,book_id" },
  );
  if (grantError) {
    return json({ error: "Could not grant access", detail: grantError.message }, 500);
  }

  await admin.from("user_subscriptions").upsert(
    {
      user_id: userId,
      scope,
      plan_id: planId,
      flw_plan_id: meta.flw_plan_id ? String(meta.flw_plan_id) : null,
      flw_subscription_id: subscriptionId,
      customer_email: email,
      status: "active",
      auto_renew: true,
      amount: tx.amount,
      currency: tx.currency,
      current_period_end: expiresAt.toISOString(),
      next_billing_at: expiresAt.toISOString(),
      last_payment_at: now.toISOString(),
      cancelled_at: null,
      updated_at: now.toISOString(),
    },
    { onConflict: "user_id,scope" },
  );

  return json({ granted: true, expiresAt: expiresAt.toISOString() }, 200);
}

async function handleSubscriptionCancelled(data: Record<string, unknown>) {
  const subscriptionId = data.id ? String(data.id) : null;
  const customer = data.customer;
  let email: string | null = null;
  if (typeof customer === "string") {
    email = customer;
  } else if (customer && typeof customer === "object") {
    const nested = (customer as Record<string, unknown>).email;
    if (typeof nested === "string") email = nested;
  }

  const patch = {
    status: "cancelled",
    auto_renew: false,
    cancelled_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  // Access is NOT revoked here: a cancelled subscription runs to the end of
  // the period already paid for, and user_book_access.expires_at is what
  // ends it.
  if (subscriptionId) {
    const { data: updated } = await admin
      .from("user_subscriptions")
      .update(patch)
      .eq("flw_subscription_id", subscriptionId)
      .select("user_id");
    if (updated && updated.length > 0) return json({ cancelled: true }, 200);
  }
  if (email) {
    await admin
      .from("user_subscriptions")
      .update(patch)
      .eq("customer_email", email);
  }
  return json({ cancelled: true }, 200);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  if (!hashMatches(req.headers.get("verif-hash") ?? "")) {
    return json({ error: "Invalid signature" }, 401);
  }

  try {
    const body = await req.json();
    const event = String(body?.event ?? "");
    const data = (body?.data ?? {}) as Record<string, unknown>;

    if (event === "charge.completed") {
      return await handleRecurringCharge(data);
    }
    if (event === "subscription.cancelled" || event === "subscription.deactivated") {
      return await handleSubscriptionCancelled(data);
    }
    return json({ ignored: event }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
