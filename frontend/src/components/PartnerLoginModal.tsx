"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import styles from "./PartnerLoginModal.module.css";

interface PartnerLoginModalProps {
    isOpen: boolean;
    onClose: () => void;
    onLoginSuccess: () => void;
}

export default function PartnerLoginModal({ isOpen, onClose, onLoginSuccess }: PartnerLoginModalProps) {
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
                // Optional: clear it so it doesn't pre-fill forever
                // localStorage.removeItem("enchiridion_reg_email");
            }
        }
    }, [isOpen]);

    if (!isOpen) return null;

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsLoading(true);
        setError(null);

        try {
            const formData = new FormData();
            formData.append("username", username);
            formData.append("password", password);

            const response = await fetch("/api/auth/login", {
                method: "POST",
                body: formData,
            });

            if (response.ok) {
                const data = await response.json();
                localStorage.setItem("enchiridion_token", data.access_token);

                // Fetch user profile to get the dynamic name
                try {
                    const userProfileResponse = await fetch("/api/users/me", {
                        headers: {
                            "Authorization": `Bearer ${data.access_token}`
                        }
                    });
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
                router.push("/dashboard");
            } else {
                const errorData = await response.json();
                setError(errorData.detail || "Invalid username or password. Please try again.");
            }
        } catch (err) {
            setError("An unexpected error occurred. Please try again later.");
        } finally {
            setIsLoading(false);
        }
    };

    const handleForgotSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsLoading(true);
        setError(null);
        setMessage(null);

        try {
            const response = await fetch("/api/forgot-password", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ email: username }),
            });

            // FastAPI-Users returns 202 for forgot password
            if (response.ok || response.status === 202) {
                setMessage("If an account exists for this email, a reset link has been sent.");
            } else {
                const data = await response.json();
                setError(data.detail || "Failed to send reset link.");
            }
        } catch (err) {
            setError("Something went wrong. Please try again.");
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
                    <h2>{view === "login" ? "Partner Login" : "Reset Password"}</h2>
                    <p>
                        {view === "login"
                            ? "Access your referral dashboard and rewards."
                            : "Enter your registered email to receive a reset link."}
                    </p>
                </div>


                {view === "login" ? (
                    <form className={styles.form} onSubmit={handleSubmit}>
                        {error && <div className={styles.error}>{error}</div>}

                        <div className={styles.field}>
                            <label htmlFor="username">Username</label>
                            <div className={styles.inputGroup}>
                                <i className="fas fa-user"></i>
                                <input
                                    id="username"
                                    type="text"
                                    value={username}
                                    onChange={(e) => setUsername(e.target.value)}
                                    placeholder="Enter your username"
                                    required
                                    autoComplete="username"
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
                                "Login to Dashboard"
                            )}
                        </button>
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
