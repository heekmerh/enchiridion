"use client";

import { useState, useEffect } from "react";
import styles from "./NewsletterSignup.module.css";

export default function NewsletterSignup() {
    const [isOpen, setIsOpen] = useState(false);
    const [email, setEmail] = useState("");
    const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");

    const toggleDropdown = () => {
        setIsOpen(!isOpen);
    };

    useEffect(() => {
        const handleOpen = () => {
            setIsOpen(true);
            document.getElementById("newsletter-toggle")?.scrollIntoView({ behavior: "smooth" });
        };

        window.addEventListener("open-newsletter", handleOpen);

        // Also check if hash is #newsletter on mount
        if (window.location.hash === "#newsletter") {
            handleOpen();
        }

        return () => window.removeEventListener("open-newsletter", handleOpen);
    }, []);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!email) return;

        setStatus("loading");

        try {
            // Get referral code from localStorage if available
            const refCode = localStorage.getItem('referralCode') || "";

            const response = await fetch('/api/referral/subscribe-newsletter', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    email: email,
                    refCode: refCode,
                    timestamp: new Date().toISOString(),
                    details: {
                        url: window.location.href,
                        source: 'Newsletter Component'
                    }
                }),
            });

            if (response.ok) {
                setStatus("success");
                setEmail("");
            } else {
                setStatus("error");
            }
        } catch (error) {
            console.error('Newsletter signup error:', error);
            setStatus("error");
        }
    };

    return (
        <div className={styles.newsletterWrapper}>
            <button
                id="newsletter-toggle"
                className={styles.newsletterBtn}
                onClick={toggleDropdown}
                aria-expanded={isOpen}
            >
                Join the Newsletter
            </button>

            <div
                className={`${styles.newsletterDropdown} ${isOpen ? styles.open : ""}`}
                aria-hidden={!isOpen}
            >
                <div className={styles.dropdownContent}>
                    <h2>BE THE FIRST TO KNOW</h2>
                    <p className={styles.leadText}>The best of Enchiridion delivered straight to your inbox.</p>

                    <div className={styles.formSection}>
                        <h3>Sign up for Enchiridion emails</h3>
                        <p className={styles.description}>
                            Receive news on app updates, new book arrivals, exclusive rewards, and streak winner announcements.
                        </p>

                        {status === "success" ? (
                            <div className={styles.successMessage}>
                                <p>✓ Thank you for subscribing! Check your inbox soon.</p>
                                <button onClick={() => setStatus("idle")} className={styles.resetBtn}>Subscribe another email</button>
                            </div>
                        ) : status === "error" ? (
                            <div className={styles.errorMessage}>
                                <p>Something went wrong. Please try again later.</p>
                                <button onClick={() => setStatus("idle")} className={styles.resetBtn}>Retry</button>
                            </div>
                        ) : (
                            <form onSubmit={handleSubmit} className={styles.form}>
                                <div className={styles.inputGroup}>
                                    <input
                                        type="email"
                                        id="newsletter-email"
                                        placeholder="Email*"
                                        required
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        disabled={status === "loading"}
                                    />
                                    <button
                                        type="submit"
                                        id="newsletter-subscribe"
                                        className={styles.subscribeBtn}
                                        disabled={status === "loading"}
                                    >
                                        {status === "loading" ? "..." : <span>&#9993; Subscribe</span>}
                                    </button>
                                </div>
                                <p className={styles.terms}>
                                    *By entering your email, you agree to our Terms of Use and Privacy Policy, including receipt of emails and promotions. You can unsubscribe at any time.
                                </p>
                            </form>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
