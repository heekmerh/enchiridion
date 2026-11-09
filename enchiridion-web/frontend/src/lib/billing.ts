export interface PlanPrice {
    amount: number;
    currency: string;
    display: string;
    period: string;
    tax_inclusive: boolean;
}

export interface Plan {
    id: string;
    name: string;
    description: string;
    interval: "month" | "year";
    price: PlanPrice;
    savings: { amount: number; display: string } | null;
    benefits: string[];
}

export interface PlanCatalogue {
    currency: string;
    plans: Plan[];
    price_notice: string;
    renewal_terms: { automatic: string; manual: string };
}

export interface Management {
    method: "website" | "google_play";
    url: string;
    instructions: string;
    can_cancel_here: boolean;
}

export interface Subscription {
    id: string;
    plan_id: string;
    plan_name: string | null;
    provider: "flutterwave" | "google_play";
    state: string;
    auto_renewing: boolean;
    current_period_end: string | null;
    access_expires_at: string | null;
    cancelled_at: string | null;
    message: string;
    management: Management;
}

export interface CurrentSubscription {
    subscription: Subscription | null;
    premium: boolean;
    entitlements: { feature: string; expires_at: string | null; source: string }[];
}

export interface CheckoutStatus {
    reference: string;
    status: "pending" | "paid" | "failed" | "abandoned";
    message: string;
    subscription: Subscription | null;
}

export function formatDate(value: string | null): string | null {
    if (!value) return null;
    return new Date(value).toLocaleDateString("en-NG", { day: "numeric", month: "long", year: "numeric" });
}

export async function errorDetail(response: Response, fallback: string): Promise<string> {
    try {
        const body = await response.json();
        if (typeof body.detail === "string") return body.detail;
        if (body.detail && typeof body.detail.message === "string") return body.detail.message;
    } catch {
        return fallback;
    }
    return fallback;
}
