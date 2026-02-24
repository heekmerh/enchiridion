"use client";

import { useState, useEffect } from "react";
import styles from "./GlobalToast.module.css";

interface Broadcast {
    id: string;
    type: string;
    username: string;
    text: string;
    timestamp: string;
}

export default function GlobalToast() {
    const [broadcasts, setBroadcasts] = useState<Broadcast[]>([]);
    const [current, setCurrent] = useState<Broadcast | null>(null);
    const [isExiting, setIsExiting] = useState(false);
    const [shownIds, setShownIds] = useState<Set<string>>(new Set());

    useEffect(() => {
        const fetchBroadcasts = async () => {
            try {
                const response = await fetch("/api/referral/global-broadcasts");
                if (response.ok) {
                    const data: Broadcast[] = await response.json();
                    setBroadcasts(data);
                }
            } catch (err) {
                console.error("Failed to fetch global broadcasts:", err);
            }
        };

        fetchBroadcasts();
        const interval = setInterval(fetchBroadcasts, 15000); // Polling every 15s
        return () => clearInterval(interval);
    }, []);

    useEffect(() => {
        if (broadcasts.length === 0 || current) return;

        // Find first broadcast not yet shown
        const next = broadcasts.find(b => !shownIds.has(b.id));
        if (next) {
            setCurrent(next);
            setShownIds(prev => new Set(prev).add(next.id));

            // Auto-dismiss after 6s
            const timer = setTimeout(() => {
                setIsExiting(true);
                setTimeout(() => {
                    setCurrent(null);
                    setIsExiting(false);
                }, 500);
            }, 6000);

            return () => clearTimeout(timer);
        }
    }, [broadcasts, current, shownIds]);

    if (!current) return null;

    const isMaster = current.type === "master_rank";

    return (
        <div className={`${styles.globalToastContainer} ${isMaster ? styles.masterAlert : ""}`}>
            <div className={`${styles.toast} ${isExiting ? styles.toastExit : styles.toastEnter}`}>
                <div className={styles.toastIcon}>
                    <i className={`fas ${isMaster ? "fa-crown" : "fa-medal"}`} style={{ color: isMaster ? "#FFD700" : "#C0C0C0" }}></i>
                </div>
                <div className={styles.toastText}>
                    <strong>Community Alert:</strong> {current.text}
                </div>
                {isMaster && <div className={styles.confettiMini}></div>}
            </div>
        </div>
    );
}
