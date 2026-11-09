"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import styles from "@/components/AuthCard.module.css";

function Unsubscribe() {
    const token = useSearchParams().get("token");
    const [state, setState] = useState<"working" | "done" | "failed">("working");
    const [message, setMessage] = useState("");

    useEffect(() => {
        if (!token) return;
        fetch("/api/v1/communications/unsubscribe", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ token }),
        })
            .then(async response => {
                const body = await response.json().catch(() => ({}));
                setState(response.ok ? "done" : "failed");
                setMessage(response.ok ? body.message : body.detail || "This unsubscribe link is not valid.");
            })
            .catch(() => {
                setState("failed");
                setMessage("We couldn't process this request. Please try again.");
            });
    }, [token]);

    if (!token) {
        return (
            <div className={styles.errorCard} role="status">
                <i aria-hidden="true" className="fas fa-exclamation-triangle"></i>
                <h1>Something went wrong</h1>
                <p>This unsubscribe link is incomplete.</p>
                <Link href="/" className={styles.backHome}>Back to Enchiridion</Link>
            </div>
        );
    }

    return (
        <div className={state === "failed" ? styles.errorCard : styles.successCard} role="status">
            <i aria-hidden="true" className={`fas ${state === "failed" ? "fa-exclamation-triangle" : state === "done" ? "fa-check-circle" : "fa-spinner"}`}></i>
            <h1>{state === "done" ? "You're unsubscribed" : state === "failed" ? "Something went wrong" : "Updating your preferences"}</h1>
            <p>{message}</p>
            <Link href="/" className={styles.backHome}>Back to Enchiridion</Link>
        </div>
    );
}

export default function UnsubscribePage() {
    return (
        <div className={styles.page}>
            <div className={styles.container}>
                <Suspense fallback={null}>
                    <Unsubscribe />
                </Suspense>
            </div>
        </div>
    );
}
