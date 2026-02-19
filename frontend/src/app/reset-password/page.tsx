"use client";

import { useState, Suspense } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import styles from "./ResetPassword.module.css";
import Link from "next/link";

function ResetPasswordForm() {
    const searchParams = useSearchParams();
    const router = useRouter();
    const token = searchParams.get("token");

    const [password, setPassword] = useState("");
    const [confirmPassword, setConfirmPassword] = useState("");
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (password !== confirmPassword) {
            setError("Passwords do not match.");
            return;
        }

        if (password.length < 8) {
            setError("Password must be at least 8 characters long.");
            return;
        }

        setIsLoading(true);
        setError(null);

        try {
            const response = await fetch("/api/reset-password", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ token, password }),
            });

            if (response.ok) {
                setSuccess(true);
                setTimeout(() => {
                    router.push("/");
                }, 3000);
            } else {
                const data = await response.json();
                setError(data.detail || "Failed to reset password. The link may have expired.");
            }
        } catch (err) {
            setError("Something went wrong. Please try again.");
        } finally {
            setIsLoading(false);
        }
    };

    if (!token) {
        return (
            <div className={styles.errorCard}>
                <i className="fas fa-exclamation-triangle"></i>
                <h2>Invalid Link</h2>
                <p>This password reset link is invalid or has expired.</p>
                <Link href="/" className={styles.backHome}>Back to Home</Link>
            </div>
        );
    }

    if (success) {
        return (
            <div className={styles.successCard}>
                <i className="fas fa-check-circle"></i>
                <h2>Password Reset!</h2>
                <p>Your password has been updated successfully. Redirecting you to login...</p>
            </div>
        );
    }

    return (
        <form className={styles.form} onSubmit={handleSubmit}>
            <div className={styles.header}>
                <h2>Set New Password</h2>
                <p>Choose a strong password for your Enchiridion account.</p>
            </div>

            {error && <div className={styles.error}>{error}</div>}

            <div className={styles.field}>
                <label htmlFor="new-password">New Password</label>
                <div className={styles.inputGroup}>
                    <i className="fas fa-lock"></i>
                    <input
                        id="new-password"
                        type="password"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        placeholder="minimum 8 characters"
                        required
                    />
                </div>
            </div>

            <div className={styles.field}>
                <label htmlFor="confirm-password">Confirm New Password</label>
                <div className={styles.inputGroup}>
                    <i className="fas fa-check-double"></i>
                    <input
                        id="confirm-password"
                        type="password"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        placeholder="Re-type password"
                        required
                    />
                </div>
            </div>

            <button type="submit" className={styles.resetBtn} disabled={isLoading}>
                {isLoading ? "Updating..." : "Update Password"}
            </button>
        </form>
    );
}

export default function ResetPasswordPage() {
    return (
        <div className={styles.page}>
            <div className={styles.container}>
                <Suspense fallback={<div>Loading...</div>}>
                    <ResetPasswordForm />
                </Suspense>
            </div>
        </div>
    );
}
