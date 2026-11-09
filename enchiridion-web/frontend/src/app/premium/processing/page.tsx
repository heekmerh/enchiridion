"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import styles from "@/components/Premium.module.css";
import { authorizedFetch } from "@/lib/supabase";
import { useSession } from "@/lib/useSession";
import { formatDate, type CheckoutStatus } from "@/lib/billing";

const POLL_INTERVAL_MS = 4000;
const MAX_POLLS = 30;
const APP_INSTALL_URL = process.env.NEXT_PUBLIC_PLAY_STORE_URL || "/download";

function ProcessingStatus() {
    const params = useSearchParams();
    const reference = params.get("reference") || params.get("tx_ref") || "";
    const transactionId = Number(params.get("transaction_id")) || undefined;
    const { ready, signedIn } = useSession();
    const [status, setStatus] = useState<CheckoutStatus | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [timedOut, setTimedOut] = useState(false);

    useEffect(() => {
        if (!ready || !signedIn || !reference) return;
        let cancelled = false;
        let polls = 0;

        async function confirm() {
            const response = await authorizedFetch("/api/v1/payments/flutterwave/confirm", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ reference, transaction_id: transactionId }),
            });
            if (response.ok && !cancelled) setStatus(await response.json());
            return response.ok;
        }

        async function poll() {
            while (!cancelled && polls < MAX_POLLS) {
                polls += 1;
                const response = await authorizedFetch(`/api/v1/payments/flutterwave/checkout/${encodeURIComponent(reference)}`);
                if (!response.ok) {
                    setError("We couldn't find this checkout on your account.");
                    return;
                }
                const next: CheckoutStatus = await response.json();
                if (cancelled) return;
                setStatus(next);
                if (next.status !== "pending") return;
                await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL_MS));
            }
            if (!cancelled) setTimedOut(true);
        }

        confirm().catch(() => false).then(() => poll()).catch(() => setError("We couldn't check your payment status."));
        return () => { cancelled = true; };
    }, [ready, signedIn, reference, transactionId]);

    if (!reference) {
        return <div className={styles.panel}><h1>Payment status</h1><p>This page needs a checkout reference.</p>
            <Link href="/premium">Back to plans</Link></div>;
    }
    if (ready && !signedIn) {
        return <div className={styles.panel}><h1>Sign in to continue</h1>
            <p>Sign in with the account you used at checkout to see your payment status.</p>
            <Link href="/#login">Sign in</Link></div>;
    }

    const paid = status?.status === "paid";
    const failed = status?.status === "failed" || status?.status === "abandoned";
    const accessUntil = formatDate(status?.subscription?.access_expires_at ?? null);

    return (
        <div className={styles.panel} aria-live="polite">
            {paid ? (
                <>
                    <h1>Premium is active</h1>
                    <p>{status?.message}</p>
                    {accessUntil && <p>Your current paid period runs until <strong>{accessUntil}</strong>.</p>}
                    <p>Sign in to the Enchiridion app with this same account to use your Premium benefits there.</p>
                    <div className={styles.actions}>
                        <a className={styles.primaryBtn} href={APP_INSTALL_URL}>Open Enchiridion</a>
                        <Link className={styles.secondaryBtn} href="/account/subscription">Manage subscription</Link>
                    </div>
                </>
            ) : failed ? (
                <>
                    <h1>Payment not completed</h1>
                    <p>{status?.message}</p>
                    <Link className={styles.secondaryBtn} href="/premium">Try again</Link>
                </>
            ) : (
                <>
                    <div className={styles.spinner} aria-hidden="true"></div>
                    <h1>Confirming your payment</h1>
                    <p>{status?.message || "We're confirming your payment. Premium will activate once verification is complete."}</p>
                    {timedOut && <p>This is taking longer than usual. You can safely leave this page; Premium activates as soon as
                        Flutterwave confirms the payment, and you will receive an email.</p>}
                </>
            )}
            {error && <div className={styles.alert} role="alert">{error}</div>}
        </div>
    );
}

export default function ProcessingPage() {
    return (
        <div className={styles.page}>
            <Suspense fallback={<div className={styles.spinner} aria-hidden="true"></div>}>
                <ProcessingStatus />
            </Suspense>
        </div>
    );
}
