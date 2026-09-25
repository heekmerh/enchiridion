// Supabase Edge Function (Deno). Deploy with:
//   supabase functions deploy verify-flutterwave-payment
// and set its secret with:
//   supabase secrets set FLUTTERWAVE_SECRET_KEY=<your Flutterwave secret key>
//
// This is the ONLY place allowed to write public.user_book_access — see
// that table's own RLS note in scripts/sql/999_MASTER_init.sql. The
// client (lib/services/payment_service.dart) only ever launches a
// Flutterwave checkout and hands this function the resulting
// transaction_id; every fact this function acts on (whether the payment
// actually succeeded, how much was actually paid, in what currency) comes
// from calling Flutterwave's own /verify endpoint with the SECRET key,
// never from anything the client claims.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Server-side source of truth for pricing — the client's meta.plan_id is
// only a hint for which plan was intended, never trusted for the amount.
// Keep in sync with lib/config/pricing_config.dart.
const PLAN_PRICES: Record<string, { amount: number; accessDays: number }> = {
  book_monthly: { amount: 1000, accessDays: 30 },
  sub_monthly: { amount: 1000, accessDays: 30 },
  sub_yearly: { amount: 10000, accessDays: 365 },
};

const FLUTTERWAVE_SECRET_KEY = Deno.env.get("FLUTTERWAVE_SECRET_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "POST only" }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401);
    }

    const { transaction_id } = await req.json();
    if (!transaction_id) {
      return json({ error: "transaction_id is required" }, 400);
    }

    // Who is actually calling this, per their own verified session — never
    // the client-supplied meta.user_id, which is only cross-checked below.
    const callerClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData?.user) {
      return json({ error: "Not authenticated" }, 401);
    }
    const callerId = userData.user.id;

    const verifyRes = await fetch(
      `https://api.flutterwave.com/v3/transactions/${transaction_id}/verify`,
      { headers: { Authorization: `Bearer ${FLUTTERWAVE_SECRET_KEY}` } },
    );
    if (!verifyRes.ok) {
      return json({ error: "Could not verify transaction with Flutterwave" }, 502);
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
    const planId = meta.plan_id as string | undefined;
    const bookId = (meta.book_id as string | undefined) ?? "*";
    const metaUserId = meta.user_id as string | undefined;

    const plan = planId ? PLAN_PRICES[planId] : undefined;
    if (!plan) {
      return json({ granted: false, reason: "Unknown plan" }, 200);
    }
    // The amount Flutterwave says was actually paid must meet this plan's
    // real price — this is what stops a tampered meta.plan_id from getting
    // a cheap payment to unlock a pricier plan.
    if (Number(tx.amount) < plan.amount) {
      return json({ granted: false, reason: "Amount does not match plan" }, 200);
    }
    if (metaUserId && metaUserId !== callerId) {
      return json({ granted: false, reason: "User mismatch" }, 200);
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Anti-replay: transaction_id is the primary key, so a second call with
    // the same id fails here and never reaches the grant below.
    const { error: insertError } = await admin.from("processed_payments").insert({
      transaction_id: String(transaction_id),
      user_id: callerId,
      plan_id: planId,
      book_id: bookId,
      amount: tx.amount,
      currency: tx.currency,
    });
    if (insertError) {
      // Unique violation on transaction_id -> already processed by an
      // earlier call. That call already granted access; this one just
      // confirms it rather than erroring.
      return json({ granted: true, alreadyProcessed: true }, 200);
    }

    // Extend from whichever is later: now, or this book_id's current
    // expiry — fair to a renewal made before the previous window lapses,
    // and safe against replay since processed_payments already guarded
    // above (so this can't be reached twice for the same payment).
    const { data: existing } = await admin
      .from("user_book_access")
      .select("expires_at")
      .eq("user_id", callerId)
      .eq("book_id", bookId)
      .maybeSingle();

    const now = new Date();
    const currentExpiry = existing?.expires_at ? new Date(existing.expires_at) : null;
    const base = currentExpiry && currentExpiry > now ? currentExpiry : now;
    const expiresAt = new Date(base.getTime() + plan.accessDays * 24 * 60 * 60 * 1000);

    const { error: grantError } = await admin.from("user_book_access").upsert(
      {
        user_id: callerId,
        book_id: bookId,
        access_type: bookId === "*" ? "subscription" : "book",
        granted: true,
        expires_at: expiresAt.toISOString(),
      },
      { onConflict: "user_id,book_id" },
    );
    if (grantError) {
      return json({ error: "Could not grant access", detail: grantError.message }, 500);
    }

    return json({ granted: true }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
