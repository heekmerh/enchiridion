import type { Page } from "@playwright/test";

export const review = {
    id: "review-1", name: "Dr Example Reader", jobTitle: "Medical Officer",
    organization: "Example Teaching Hospital", rating: 4,
    text: "This reference is useful for everyday clinical learning and supports our team's discussions.",
    status: "pending", createdAt: "2026-10-01T12:00:00Z",
};
export const stats = {
    referralCode: "EXAMPLE", points: 10, revenue: 1000, lifetimeEarnings: 3000,
    totalReferrals: 3, pendingPoints: 1, networkSpreadCount: 2,
    legacyRank: "Sage", soulsGuided: 3, milestones: [],
    refereeProgress: [{ milestones: ["partner"], is_pending: false, name: "Example Colleague", email: "colleague@example.test", is_verified: true, is_partner: true, is_distributor: false, has_purchased_book: false }],
};
export const subscription = {
    premium: true, subscription: {
        plan_id: "monthly", plan_name: "Monthly Premium", state: "ACTIVE", provider: "flutterwave",
        message: "Premium is active.", auto_renewing: true, access_expires_at: "2026-12-01T00:00:00Z",
        management: { method: "website", can_cancel_here: true, instructions: "Manage renewals here." },
    },
};

/** Synthetic browser session and intercepted API responses; never use production credentials. */
export async function fixtures(page: Page, signedIn = false) {
    await page.addInitScript(({ signedIn }) => {
        localStorage.setItem("enchiridion_user_name", "Example Partner");
        localStorage.setItem("enchiridion_user_ref", "EXAMPLE");
        localStorage.setItem("userEmail", "reader@example.test");
        if (!signedIn) return;
        const token = `${btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }))}.${btoa(JSON.stringify({ sub: "example", exp: 4102444800, role: "authenticated" }))}.fixture`;
        localStorage.setItem("sb-a11y-auth-token", JSON.stringify({
            access_token: token, refresh_token: "fixture", expires_at: 4102444800,
            expires_in: 3600, token_type: "bearer",
            user: { id: "example", email: "reader@example.test", email_confirmed_at: "2026-01-01T00:00:00Z", app_metadata: {}, user_metadata: {} },
        }));
    }, { signedIn });
    await page.route("**/api/**", async route => {
        const path = new URL(route.request().url()).pathname;
        let body: unknown = [];
        if (path === "/api/reviews") body = route.request().method() === "GET" ? [review] : { success: true };
        if (path === "/api/users/me") body = { name: "Example Partner", email: "reader@example.test", is_superuser: true, referral_code: "EXAMPLE" };
        if (path.endsWith("/stats")) body = stats;
        if (path.endsWith("/progress")) body = { email: "reader@example.test", is_verified: true, is_partner: true, is_distributor: false, has_purchased_book: false };
        if (path.endsWith("/leaderboard")) body = [{ rank: 1, name: "Example Partner", email: "reader@example.test", points: 10, revenue: 1000, lifetimeEarnings: 3000, impact: "Sage" }];
        if (path.endsWith("/audit-verify")) body = { results: [{ row: 1, username: "reader@example.test", points: 10, revenue: 1000, lifetime_earnings: 3000, payout_status: "PENDING", math_ok: false, refCode: "EXAMPLE" }] };
        if (path.endsWith("/shipping-rates")) body = [{ name: "Lagos", cost: 2000, isHub: true }];
        if (path.endsWith("/checkout-config")) body = { bookPrice: 10000 };
        if (path.endsWith("/subscription/plans")) body = {
            currency: "NGN", price_notice: "Prices include applicable taxes.",
            renewal_terms: { automatic: "Renews until cancelled.", manual: "Does not renew automatically." },
            plans: ["month", "year"].map(interval => ({ id: interval, name: interval === "month" ? "Monthly" : "Annual", interval,
                description: "Premium medical reference access", price: { amount: 1000, display: "₦1,000", period: interval, currency: "NGN", tax_inclusive: true }, savings: null, benefits: ["Offline access"] })),
        };
        if (path.endsWith("/subscription/current")) body = subscription;
        if (path.endsWith("/communications/preferences")) body = { marketing_opt_in: false };
        if (path.includes("/flutterwave/checkout/")) body = { status: "paid", message: "Payment confirmed.", subscription: subscription.subscription };
        if (path.endsWith("/confirm")) body = { status: "paid", message: "Payment confirmed." };
        if (path.endsWith("/unsubscribe")) body = { message: "You are unsubscribed." };
        await route.fulfill({ json: body });
    });
    await page.route("https://a11y.supabase.co/**", route => route.fulfill({ status: 400, json: { message: "Example authentication error. Please try again." } }));
    await page.route("https://checkout.flutterwave.com/**", route => route.fulfill({ contentType: "text/javascript", body: "" }));
}
