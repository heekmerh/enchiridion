"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import styles from "./PartnerLoginModal.module.css";
import GoogleButton from "@/components/GoogleButton";
import { authErrorMessage, authorizedFetch, signInWithGoogle, supabase } from "@/lib/supabase";

interface PartnerLoginModalProps {
    isOpen: boolean;
    onClose: () => void;
    onLoginSuccess: () => void;
    redirectTo?: string;
}

export default function PartnerLoginModal({ isOpen, onClose, onLoginSuccess, redirectTo }: PartnerLoginModalProps) {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");
    const [view, setView] = useState<"login" | "forgot">("login");
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [message, setMessage] = useState<string | null>(null);

    const router = useRouter();

    useEffect(() => {
        if (isOpen) {
            const savedEmail = localStorage.getItem("enchiridion_reg_email");
            if (savedEmail) {
                setUsername(savedEmail);
            }
        }
    }, [isOpen]);

    if (!isOpen) return null;

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsLoading(true);
        setError(null);

        try {
            const { error: signInError } = await supabase().auth.signInWithPassword({ email: username.trim(), password });
            if (signInError) {
                setError(signInError.message === "Email not confirmed"
                    ? "Please verify your email address first. Check your inbox for the verification email."
                    : "Invalid email or password. Please try again.");
                return;
            }
            try {
                const userProfileResponse = await authorizedFetch("/api/users/me");
                if (userProfileResponse.ok) {
                    const userData = await userProfileResponse.json();
                    localStorage.setItem("enchiridion_user_name", userData.name);
                    if (userData.referral_code) {
                        localStorage.setItem("enchiridion_user_ref", userData.referral_code);
                    }
                }
            } catch (profileErr) {
                console.error("Failed to fetch user name:", profileErr);
            }
            onLoginSuccess();
            onClose();
            router.push(redirectTo || "/dashboard");
        } catch (err) {
            setError(authErrorMessage(err, "An unexpected error occurred. Please try again later."));
        } finally {
            setIsLoading(false);
        }
    };

    const handleGoogle = async () => {
        setError(null);
        try {
            await signInWithGoogle(redirectTo || "/dashboard");
        } catch (err) {
            setError(authErrorMessage(err, "Google sign-in could not be started."));
        }
    };

    const handleForgotSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsLoading(true);
        setError(null);
        setMessage(null);

        try {
            const { error: resetError } = await supabase().auth.resetPasswordForEmail(username.trim(), {
                redirectTo: `${window.location.origin}/reset-password`,
            });
            if (resetError) throw resetError;
            setMessage("If an account exists for this email, a reset link has been sent.");
        } catch (err) {
            setError(authErrorMessage(err, "Something went wrong. Please try again."));
        } finally {
            setIsLoading(false);
        }
    };


    return (
        <div className={styles.overlay} onClick={onClose}>
            <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
                <button className={styles.closeBtn} onClick={onClose} aria-label="Close modal">
                    <i className="fas fa-times"></i>
                </button>

                <div className={styles.header}>
                    <h2>{view === "login" ? "Sign In" : "Reset Password"}</h2>
                    <p>
                        {view === "login"
                            ? "One Enchiridion account for the website, the app and Premium."
                            : "Enter your registered email to receive a reset link."}
                    </p>
                </div>


                {view === "login" ? (
                    <form className={styles.form} onSubmit={handleSubmit}>
                        {error && <div className={styles.error}>{error}</div>}

                        <div className={styles.field}>
                            <label htmlFor="username">Email</label>
                            <div className={styles.inputGroup}>
                                <i className="fas fa-user"></i>
                                <input
                                    id="username"
                                    type="email"
                                    value={username}
                                    onChange={(e) => setUsername(e.target.value)}
                                    placeholder="Enter your email"
                                    required
                                    autoComplete="email"
                                />
                            </div>
                        </div>

                        <div className={styles.field}>
                            <label htmlFor="password">Password</label>
                            <div className={styles.inputGroup}>
                                <i className="fas fa-lock"></i>
                                <input
                                    id="password"
                                    type="password"
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    placeholder="Enter your password"
                                    required
                                    autoComplete="current-password"
                                />
                            </div>
                            <button
                                type="button"
                                className={styles.forgotLink}
                                onClick={() => { setView("forgot"); setError(null); }}
                            >
                                Forgot Password?
                            </button>
                        </div>

                        <button type="submit" className={styles.loginBtn} disabled={isLoading}>
                            {isLoading ? (
                                <>
                                    <i className={`fas fa-spinner ${styles.spinner}`}></i>
                                    Logging in...
                                </>
                            ) : (
                                "Sign In"
                            )}
                        </button>
                        <GoogleButton onClick={handleGoogle} disabled={isLoading}
                            note="By continuing with Google you agree to the Terms and Conditions and Privacy Policy." />
                    </form>
                ) : (
                    <form className={styles.form} onSubmit={handleForgotSubmit}>
                        {error && <div className={styles.error}>{error}</div>}
                        {message && <div className={styles.message}>{message}</div>}

                        {!message && (
                            <div className={styles.field}>
                                <label htmlFor="reset-email">Registered Email</label>
                                <div className={styles.inputGroup}>
                                    <i className="fas fa-envelope"></i>
                                    <input
                                        id="reset-email"
                                        type="email"
                                        value={username}
                                        onChange={(e) => setUsername(e.target.value)}
                                        placeholder="Enter your email"
                                        required
                                    />
                                </div>
                            </div>
                        )}

                        <button type="submit" className={styles.loginBtn} disabled={isLoading || !!message}>
                            {isLoading ? "Sending..." : message ? "Sent!" : "Send Reset Link"}
                        </button>

                        <button
                            type="button"
                            className={styles.backBtn}
                            onClick={() => { setView("login"); setError(null); setMessage(null); }}
                        >
                            Back to Login
                        </button>
                    </form>
                )}

            </div>
        </div>
    );
}
