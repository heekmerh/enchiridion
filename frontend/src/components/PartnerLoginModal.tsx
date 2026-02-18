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
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
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

    return (
        <div className={styles.overlay} onClick={onClose}>
            <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
                <button className={styles.closeBtn} onClick={onClose} aria-label="Close modal">
                    <i className="fas fa-times"></i>
                </button>

                <div className={styles.header}>
                    <h2>Partner Login</h2>
                    <p>Access your referral dashboard and rewards.</p>
                </div>

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
            </div>
        </div>
    );
}
