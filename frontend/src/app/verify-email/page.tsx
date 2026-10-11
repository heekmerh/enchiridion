"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import styles from "@/components/AuthCard.module.css";
import { authErrorMessage, authorizedFetch, currentSession, onSessionChange, supabase } from "@/lib/supabase";

export default function VerifyEmail() {
    const [email, setEmail] = useState("");
    const [code, setCode] = useState("");
    const [busy, setBusy] = useState(false);
    const [verified, setVerified] = useState(false);
    const [message, setMessage] = useState<string | null>(null);
    const [error, setError] = useState<string | null>(null);

    async function completeVerification() {
        setVerified(true);
        await authorizedFetch("/api/v1/communications/dispatch-mine", { method: "POST" }).catch(() => undefined);
    }

    useEffect(() => {
        currentSession().then(session => {
            setEmail(previous => previous || session?.user.email || localStorage.getItem("enchiridion_reg_email") || "");
            if (session?.user.email_confirmed_at) completeVerification();
        });
        return onSessionChange(session => {
            if (session?.user.email_confirmed_at) completeVerification();
        });
    }, []);

    async function verifyCode(event: React.FormEvent) {
        event.preventDefault();
        setBusy(true);
        setError(null);
        try {
            const { error: verifyError } = await supabase().auth.verifyOtp({ email: email.trim(), token: code.trim(), type: "signup" });
            if (verifyError) throw verifyError;
            await completeVerification();
        } catch (err) {
            setError(authErrorMessage(err, "That code is invalid or has expired."));
        } finally {
            setBusy(false);
        }
    }

    async function resend() {
        setBusy(true);
        setError(null);
        try {
            const { error: resendError } = await supabase().auth.resend({
                type: "signup", email: email.trim(), options: { emailRedirectTo: `${window.location.origin}/verify-email` },
            });
            if (resendError) throw resendError;
            setMessage("If this address still needs verification, a new email has been sent.");
        } catch (err) {
            setError(authErrorMessage(err, "Unable to send a new email. Please try again shortly."));
        } finally {
            setBusy(false);
        }
    }

    return (
        <div className={styles.page}>
            <div className={styles.container}>
                {verified ? (
                    <div className={styles.successCard}>
                        <i className="fas fa-check-circle"></i>
                        <h2>Your email is verified</h2>
                        <p>Your Enchiridion account is ready. Sign in with the same email and password on the website or in the app.</p>
                        <Link href="/dashboard" className={styles.backHome}>Continue to your account</Link>
                    </div>
                ) : (
                    <form className={styles.form} onSubmit={verifyCode}>
                        <div className={styles.header}>
                            <h2>Verify Your Email</h2>
                            <p>Enter the email address you registered with and the eight-digit code from your verification email.</p>
                        </div>
                        {error && <div className={styles.error}>{error}</div>}
                        {message && <div className={styles.message}>{message}</div>}
                        <div className={styles.field}>
                            <label htmlFor="verification-email">Email</label>
                            <div className={styles.inputGroup}>
                                <i className="fas fa-envelope"></i>
                                <input id="verification-email" type="email" required value={email}
                                    onChange={event => setEmail(event.target.value)} autoComplete="email" />
                            </div>
                        </div>
                        <div className={styles.field}>
                            <label htmlFor="verification-code">Verification code</label>
                            <div className={styles.inputGroup}>
                                <i className="fas fa-key"></i>
                                <input id="verification-code" inputMode="numeric" required value={code}
                                    onChange={event => setCode(event.target.value)} autoComplete="one-time-code" />
                            </div>
                        </div>
                        <button type="submit" className={styles.resetBtn} disabled={busy}>
                            {busy ? "Please wait..." : "Verify Email"}
                        </button>
                        <button type="button" className={styles.secondaryBtn} disabled={busy || !email} onClick={resend}>
                            Send a new verification email
                        </button>
                    </form>
                )}
            </div>
        </div>
    );
}
