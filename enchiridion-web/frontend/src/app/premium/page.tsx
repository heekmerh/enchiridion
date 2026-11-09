"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import styles from "@/components/Premium.module.css";
import PartnerLoginModal from "@/components/PartnerLoginModal";
import { authorizedFetch } from "@/lib/supabase";
import { useSession } from "@/lib/useSession";
import { errorDetail, type CurrentSubscription, type Plan, type PlanCatalogue } from "@/lib/billing";

const PLAN_COPY: Record<Plan["interval"], { title: string; cta: string; fallback: string }> = {
    month: { title: "Monthly", cta: "Subscribe Monthly", fallback: "Enjoy Premium access with flexible monthly billing." },
    year: { title: "Annual", cta: "Subscribe Annually", fallback: "" },
};

export default function PremiumPage() {
    const { session, ready, signedIn } = useSession();
    const [catalogue, setCatalogue] = useState<PlanCatalogue | null>(null);
    const [current, setCurrent] = useState<CurrentSubscription | null>(null);
    const [autoRenew, setAutoRenew] = useState(true);
    const [busyPlan, setBusyPlan] = useState<string | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [loginOpen, setLoginOpen] = useState(false);

    useEffect(() => {
        fetch("/api/v1/subscription/plans")
            .then(response => response.ok ? response.json() : Promise.reject())
            .then(setCatalogue)
            .catch(() => setError("Plans could not be loaded. Please refresh the page."));
    }, []);

    useEffect(() => {
        if (!signedIn) return;
        authorizedFetch("/api/v1/subscription/current")
            .then(response => response.ok ? response.json() : null)
            .then(setCurrent)
            .catch(() => setCurrent(null));
    }, [signedIn]);

    async function subscribe(plan: Plan) {
        setError(null);
        if (!signedIn) {
            setLoginOpen(true);
            return;
        }
        if (!session?.user.email_confirmed_at) {
            setError("Please verify your email address before subscribing.");
            return;
        }
        setBusyPlan(plan.id);
        try {
            const response = await authorizedFetch("/api/v1/payments/flutterwave/checkout", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ plan_id: plan.id, auto_renew: autoRenew }),
            });
            if (!response.ok) {
                setError(await errorDetail(response, "Checkout could not be started. Please try again."));
                return;
            }
            const checkout = await response.json();
            window.location.assign(checkout.checkout_url);
        } catch {
            setError("Checkout could not be started. Please check your connection and try again.");
        } finally {
            setBusyPlan(null);
        }
    }

    const alreadyPremium = signedIn && current?.premium === true;

    return (
        <div className={styles.page}>
            <section className={styles.intro}>
                <h1>Choose Your Premium Plan</h1>
                <p>Get more out of Enchiridion. Both plans include the same Premium features.</p>
            </section>

            {alreadyPremium && (
                <div className={styles.info} role="status">
                    Premium is already active on this account. Manage your existing subscription before starting another.{" "}
                    <Link href="/account/subscription">Manage subscription</Link>
                </div>
            )}
            {error && <div className={styles.alert} role="alert">{error}</div>}

            <label className={styles.renewalChoice}>
                <input type="checkbox" checked={autoRenew} onChange={event => setAutoRenew(event.target.checked)} />
                <span>
                    <strong>Renew automatically.</strong>{" "}
                    {autoRenew ? catalogue?.renewal_terms.automatic : catalogue?.renewal_terms.manual}
                    {!autoRenew && " Card, bank transfer and USSD are accepted."}
                </span>
            </label>

            <div className={styles.plans}>
                {(catalogue?.plans ?? []).map(plan => {
                    const copyForPlan = PLAN_COPY[plan.interval];
                    return (
                        <article key={plan.id} className={`${styles.card} ${plan.savings ? styles.featured : ""}`}>
                            {plan.savings && <span className={styles.badge}>Best value</span>}
                            <h2>{copyForPlan.title}</h2>
                            <div className={styles.price}>{plan.price.display}<span>/{plan.price.period}</span></div>
                            <p>{plan.interval === "month" ? copyForPlan.fallback : plan.description}</p>
                            <button className={styles.primaryBtn} disabled={!ready || alreadyPremium || busyPlan !== null}
                                onClick={() => subscribe(plan)}>
                                {busyPlan === plan.id ? "Opening secure checkout..." : copyForPlan.cta}
                            </button>
                        </article>
                    );
                })}
            </div>

            <div className={styles.notice}>
                <p><strong>{catalogue?.price_notice}</strong></p>
                <p>Payments are processed securely by Flutterwave. Subscriptions renew according to the terms shown before purchase.
                    Cancel future renewals from your account. See the <Link href="/terms">Terms and Conditions</Link>.</p>
                {!signedIn && (
                    <p>Already subscribed? <button className={styles.secondaryBtn} onClick={() => setLoginOpen(true)}>Sign in</button></p>
                )}
            </div>

            <PartnerLoginModal isOpen={loginOpen} onClose={() => setLoginOpen(false)} onLoginSuccess={() => undefined}
                redirectTo="/premium" />
        </div>
    );
}
