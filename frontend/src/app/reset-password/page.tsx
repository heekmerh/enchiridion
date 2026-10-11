"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import styles from "@/components/AuthCard.module.css";
import { authErrorMessage, onSessionChange, supabase } from "@/lib/supabase";

const MINIMUM_PASSWORD_LENGTH = 8;

export default function ResetPasswordPage() {
    const router = useRouter();
    const [hasRecoverySession, setHasRecoverySession] = useState(false);
    const [email, setEmail] = useState("");
    const [code, setCode] = useState("");
    const [password, setPassword] = useState("");
    const [confirmPassword, setConfirmPassword] = useState("");
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState(false);

    useEffect(() => onSessionChange((_session, event) => {
        if (event === "PASSWORD_RECOVERY") setHasRecoverySession(true);
    }), []);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (password !== confirmPassword) {
            setError("Passwords do not match.");
            return;
        }
        if (password.length < MINIMUM_PASSWORD_LENGTH) {
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
            setTimeout(() => router.push("/dashboard"), 3000);
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
                    <div className={styles.successCard}>
                        <i className="fas fa-check-circle"></i>
                        <h2>Password Reset!</h2>
                        <p>Your password has been updated for the website and the app. Redirecting you to your account...</p>
                    </div>
                ) : (
                    <form className={styles.form} onSubmit={handleSubmit}>
                        <div className={styles.header}>
                            <h2>Set New Password</h2>
                            <p>{hasRecoverySession
                                ? "Choose a strong password for your Enchiridion account."
                                : "Enter the code from your reset email, then choose a new password."}</p>
                        </div>
                        {error && <div className={styles.error}>{error}</div>}
                        {!hasRecoverySession && (
                            <>
                                <div className={styles.field}>
                                    <label htmlFor="reset-email">Email</label>
                                    <div className={styles.inputGroup}>
                                        <i className="fas fa-envelope"></i>
                                        <input id="reset-email" type="email" required value={email}
                                            onChange={(e) => setEmail(e.target.value)} autoComplete="email" />
                                    </div>
                                </div>
                                <div className={styles.field}>
                                    <label htmlFor="reset-code">Reset code</label>
                                    <div className={styles.inputGroup}>
                                        <i className="fas fa-key"></i>
                                        <input id="reset-code" inputMode="numeric" required value={code}
                                            onChange={(e) => setCode(e.target.value)} autoComplete="one-time-code" />
                                    </div>
                                </div>
                            </>
                        )}
                        <div className={styles.field}>
                            <label htmlFor="new-password">New Password</label>
                            <div className={styles.inputGroup}>
                                <i className="fas fa-lock"></i>
                                <input id="new-password" type="password" value={password} required
                                    onChange={(e) => setPassword(e.target.value)} placeholder="minimum 8 characters"
                                    autoComplete="new-password" />
                            </div>
                        </div>
                        <div className={styles.field}>
                            <label htmlFor="confirm-password">Confirm New Password</label>
                            <div className={styles.inputGroup}>
                                <i className="fas fa-check-double"></i>
                                <input id="confirm-password" type="password" value={confirmPassword} required
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
