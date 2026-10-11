"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import styles from "@/components/Premium.module.css";
import PartnerLoginModal from "@/components/PartnerLoginModal";
import { authorizedFetch } from "@/lib/supabase";
import { useSession } from "@/lib/useSession";
import { errorDetail, formatDate, type CurrentSubscription } from "@/lib/billing";

const PROVIDER_LABELS = { flutterwave: "Enchiridion website (Flutterwave)", google_play: "Google Play" };
const STATE_LABELS: Record<string, string> = {
    ACTIVE: "Active", GRACE_PERIOD: "Active — payment being retried", PAYMENT_FAILED: "Payment failed",
    PAUSED: "Paused", CANCELLED: "Cancelled — will not renew", EXPIRED: "Expired", REFUNDED: "Refunded",
};

export default function SubscriptionAccountPage() {
    const { ready, signedIn } = useSession();
    const [current, setCurrent] = useState<CurrentSubscription | null>(null);
    const [marketingOptIn, setMarketingOptIn] = useState<boolean | null>(null);
    const [busy, setBusy] = useState(false);
    const [message, setMessage] = useState<string | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [loginOpen, setLoginOpen] = useState(false);

    const load = useCallback(() => Promise.all([
        authorizedFetch("/api/v1/subscription/current").then(response => response.ok ? response.json() : null),
        authorizedFetch("/api/v1/communications/preferences").then(response => response.ok ? response.json() : null),
    ]).then(([subscription, preferences]) => {
        if (subscription) setCurrent(subscription);
        if (preferences) setMarketingOptIn(preferences.marketing_opt_in);
    }).catch(() => setError("Your subscription could not be loaded.")), []);

    useEffect(() => {
        if (signedIn) load();
    }, [signedIn, load]);

    async function cancel() {
        if (!window.confirm("Cancel future renewals? Premium stays available until the end of your current paid period.")) return;
        setBusy(true);
        setError(null);
        try {
            const response = await authorizedFetch("/api/v1/subscription/cancel", { method: "POST" });
            if (!response.ok) {
                setError(await errorDetail(response, "The subscription could not be cancelled. Please try again."));
                return;
            }
            setMessage((await response.json()).message);
            await load();
        } finally {
            setBusy(false);
        }
    }

    async function updateMarketing(optIn: boolean) {
        setMarketingOptIn(optIn);
        const response = await authorizedFetch("/api/v1/communications/preferences", {
            method: "PUT",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ marketing_opt_in: optIn }),
        });
        if (response.ok) setMarketingOptIn((await response.json()).marketing_opt_in);
        else setError("Your email preference could not be saved.");
    }

    if (ready && !signedIn) {
        return (
            <div className={styles.page}>
                <div className={styles.panel}>
                    <h1>Your subscription</h1>
                    <p>Sign in with your Enchiridion account to view or manage your subscription.</p>
                    <button className={styles.primaryBtn} onClick={() => setLoginOpen(true)}>Sign in</button>
                </div>
                <PartnerLoginModal isOpen={loginOpen} onClose={() => setLoginOpen(false)} onLoginSuccess={() => undefined}
                    redirectTo="/account/subscription" />
            </div>
        );
    }

    const subscription = current?.subscription;
    const accessUntil = formatDate(subscription?.access_expires_at ?? null);
    const manualAccess = !subscription && current?.premium;

    return (
        <div className={styles.page}>
            <div className={styles.panel}>
                <h1>Your subscription</h1>
                {message && <div className={styles.success} role="status">{message}</div>}
                {error && <div className={styles.alert} role="alert">{error}</div>}
                {!current && <div className={styles.spinner} aria-hidden="true"></div>}
                {current && !subscription && !manualAccess && (
                    <>
                        <p>You are using the Free account.</p>
                        <Link className={styles.primaryBtn} href="/premium">Explore Premium</Link>
                    </>
                )}
                {manualAccess && <p>Premium access has been granted to this account by Enchiridion.</p>}
                {subscription && (
                    <>
                        <p>{subscription.message}</p>
                        <dl className={styles.details}>
                            <dt>Plan</dt><dd>{subscription.plan_name ?? subscription.plan_id}</dd>
                            <dt>Status</dt><dd>{STATE_LABELS[subscription.state] ?? subscription.state}</dd>
                            <dt>Purchased through</dt><dd>{PROVIDER_LABELS[subscription.provider]}</dd>
                            {accessUntil && <><dt>{subscription.auto_renewing ? "Renews on" : "Access until"}</dt><dd>{accessUntil}</dd></>}
                        </dl>
                        <p>{subscription.management.instructions}</p>
                        <div className={styles.actions}>
                            {subscription.management.method === "google_play" && (
                                <a className={styles.secondaryBtn} href={subscription.management.url} target="_blank" rel="noreferrer">
                                    Open Google Play subscriptions
                                </a>
                            )}
                            {subscription.management.can_cancel_here && (
                                <button className={styles.secondaryBtn} onClick={cancel} disabled={busy}>
                                    {busy ? "Cancelling..." : "Cancel future renewals"}
                                </button>
                            )}
                            {!current?.premium && <Link className={styles.primaryBtn} href="/premium">Subscribe again</Link>}
                        </div>
                    </>
                )}
                {marketingOptIn !== null && (
                    <label className={styles.toggle}>
                        <input type="checkbox" checked={marketingOptIn} onChange={event => updateMarketing(event.target.checked)} />
                        <span>Email me Enchiridion offers. Account, security and billing emails are always sent.</span>
                    </label>
                )}
            </div>
        </div>
    );
}
