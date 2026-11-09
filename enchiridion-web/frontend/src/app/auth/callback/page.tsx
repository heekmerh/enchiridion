"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import styles from "@/components/AuthCard.module.css";
import { authorizedFetch, currentSession, PENDING_MARKETING_KEY, supabase, TERMS_VERSION } from "@/lib/supabase";

function safeNextPath(next: string | null): string {
    return next && next.startsWith("/") && !next.startsWith("//") ? next : "/dashboard";
}

function providerError(): string | null {
    const params = new URLSearchParams(window.location.hash.slice(1) || window.location.search);
    return params.get("error_description");
}

async function completeSignIn() {
    await supabase().rpc("accept_terms", { p_version: TERMS_VERSION });
    const refCode = localStorage.getItem("enchiridion_ref");
    if (refCode) {
        await authorizedFetch("/api/referral/claim-referrer", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ refCode }),
        });
    }
    if (localStorage.getItem(PENDING_MARKETING_KEY) === "true") {
        await authorizedFetch("/api/v1/communications/preferences", {
            method: "PUT",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ marketing_opt_in: true }),
        });
    }
    localStorage.removeItem(PENDING_MARKETING_KEY);
    const profile = await authorizedFetch("/api/users/me");
    if (profile.ok) {
        const user = await profile.json();
        localStorage.setItem("enchiridion_user_name", user.name);
        if (user.referral_code) localStorage.setItem("enchiridion_user_ref", user.referral_code);
    }
}

function Callback() {
    const router = useRouter();
    const next = safeNextPath(useSearchParams().get("next"));
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const failure = providerError();
        currentSession().then(async session => {
            if (!session) {
                setError(failure || "Google sign-in did not complete. Please try again.");
                return;
            }
            await completeSignIn().catch(() => undefined);
            router.replace(next);
        });
    }, [next, router]);

    if (error) {
        return (
            <div className={styles.errorCard} role="alert">
                <i aria-hidden="true" className="fas fa-exclamation-triangle"></i>
                <h1>Sign-in failed</h1>
                <p>{error}</p>
                <Link href="/#login" className={styles.backHome}>Try again</Link>
            </div>
        );
    }
    return (
        <div className={styles.successCard} role="status">
            <i aria-hidden="true" className="fas fa-spinner"></i>
            <h1>Signing you in…</h1>
        </div>
    );
}

export default function AuthCallbackPage() {
    return (
        <div className={styles.page}>
            <div className={styles.container}>
                <Suspense fallback={null}>
                    <Callback />
                </Suspense>
            </div>
        </div>
    );
}
