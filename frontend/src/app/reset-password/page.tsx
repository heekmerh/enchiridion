"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import styles from "@/components/AuthCard.module.css";
import { authErrorMessage, onSessionChange, supabase } from "@/lib/supabase";

const MINIMUM_PASSWORD_LENGTH = 8;

export default function ResetPasswordPage() {
    const [hasRecoverySession, setHasRecoverySession] = useState(false);
    const [email, setEmail] = useState("");
    const [code, setCode] = useState("");
    const [password, setPassword] = useState("");
    const [confirmPassword, setConfirmPassword] = useState("");
    const [isLoading, setIsLoading] = useState(false);
    const [passwordError, setPasswordError] = useState(false);
    const [confirmationError, setConfirmationError] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState(false);

    useEffect(() => onSessionChange((_session, event) => {
        if (event === "PASSWORD_RECOVERY") setHasRecoverySession(true);
    }), []);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setPasswordError(false);
        setConfirmationError(false);
        if (password !== confirmPassword) {
            setConfirmationError(true);
            setError("Passwords do not match.");
            document.getElementById("confirm-password")?.focus();
            return;
        }
        if (password.length < MINIMUM_PASSWORD_LENGTH) {
            setPasswordError(true);
            document.getElementById("new-password")?.focus();
            setError(`Password must be at least ${MINIMUM_PASSWORD_LENGTH} characters long.`);
            return;
        }
        setIsLoading(true);
        setError(null);
        try {
            const auth = supabase().auth;
            if (!hasRecoverySession) {
                const { error: verifyError } = await auth.verifyOtp({ email: email.trim(), token: code.trim(), type: "recovery" });
                if (verifyError) throw verifyError;
            }
            const { error: updateError } = await auth.updateUser({ password });
            if (updateError) throw updateError;
            setSuccess(true);

        } catch (err) {
            setError(authErrorMessage(err, "Failed to reset password. The link or code may have expired."));
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className={styles.page}>
            <div className={styles.container}>
                {success ? (
                    <div className={styles.successCard} role="status">
                        <i aria-hidden="true" className="fas fa-check-circle"></i>
                        <h1>Password Reset!</h1>
                        <Link href="/dashboard" className={styles.backHome}>Continue to your account</Link>
                        <p>Your password has been updated for the website and the app. You can now continue to your account.</p>
                    </div>
                ) : (
                    <form className={styles.form} onSubmit={handleSubmit}>
                        <div className={styles.header}>
                            <h1>Set New Password</h1>
                            <p>{hasRecoverySession
                                ? "Choose a strong password for your Enchiridion account."
                                : "Enter the code from your reset email, then choose a new password."}</p>
                        </div>
                        {error && <div id="reset-error" className={styles.error} role="alert">{error}</div>}
                        {!hasRecoverySession && (
                            <>
                                <div className={styles.field}>
                                    <label htmlFor="reset-email">Email</label>
                                    <div className={styles.inputGroup}>
                                        <i aria-hidden="true" className="fas fa-envelope"></i>
                                        <input id="reset-email" type="email" required value={email}
                                            onChange={(e) => setEmail(e.target.value)} autoComplete="email" />
                                    </div>
                                </div>
                                <div className={styles.field}>
                                    <label htmlFor="reset-code">Reset code</label>
                                    <div className={styles.inputGroup}>
                                        <i aria-hidden="true" className="fas fa-key"></i>
                                        <input id="reset-code" inputMode="numeric" required value={code}
                                            onChange={(e) => setCode(e.target.value)} autoComplete="one-time-code" />
                                    </div>
                                </div>
                            </>
                        )}
                        <div className={styles.field}>
                            <p id="password-hint">Use at least 8 characters. You can paste a password or use a password manager.</p>
                            <label htmlFor="new-password">New Password</label>
                            <div className={styles.inputGroup}>
                                <i aria-hidden="true" className="fas fa-lock"></i>
                                <input id="new-password" aria-invalid={passwordError} aria-describedby={passwordError ? "reset-error" : "password-hint"} type="password" value={password} required
                                    onChange={(e) => setPassword(e.target.value)} placeholder="minimum 8 characters"
                                    autoComplete="new-password" />
                            </div>
                        </div>
                        <div className={styles.field}>
                            <label htmlFor="confirm-password">Confirm New Password</label>
                            <div className={styles.inputGroup}>
                                <i aria-hidden="true" className="fas fa-check-double"></i>
                                <input id="confirm-password" aria-invalid={confirmationError} aria-describedby={confirmationError ? "reset-error" : undefined} type="password" value={confirmPassword} required
                                    onChange={(e) => setConfirmPassword(e.target.value)} placeholder="Re-type password"
                                    autoComplete="new-password" />
                            </div>
                        </div>
                        <button type="submit" className={styles.resetBtn} disabled={isLoading}>
                            {isLoading ? "Updating..." : "Update Password"}
                        </button>
                    </form>
                )}
            </div>
        </div>
    );
}
