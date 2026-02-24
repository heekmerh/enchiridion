"use client";

import { useState, useEffect, useCallback } from "react";
import styles from "./OnboardingChecklist.module.css";

interface Impact {
    type: string;
    text: string;
    timestamp: string;
}

export default function ImpactLiveFeed() {
    const [impacts, setImpacts] = useState<Impact[]>([]);
    const [currentImpact, setCurrentImpact] = useState<Impact | null>(null);
    const [isExiting, setIsExiting] = useState(false);
    const [index, setIndex] = useState(0);

    const fetchImpacts = useCallback(async () => {
        try {
            const response = await fetch("/api/referral/recent-milestones");
            if (response.ok) {
                const data = await response.json();
                if (data && data.length > 0) {
                    setImpacts(data);
                }
            }
        } catch (err) {
            console.error("Failed to fetch live impacts:", err);
        }
    }, []);

    useEffect(() => {
        fetchImpacts();
        const interval = setInterval(fetchImpacts, 300000); // Fetch new data every 5 mins
        return () => clearInterval(interval);
    }, [fetchImpacts]);

    useEffect(() => {
        if (impacts.length === 0) return;

        const showNext = () => {
            // Start exit animation
            if (currentImpact) {
                setIsExiting(true);
                setTimeout(() => {
                    setIsExiting(false);
                    setCurrentImpact(impacts[index]);
                    setIndex((prev) => (prev + 1) % impacts.length);
                }, 500); // Match exit animation duration
            } else {
                setCurrentImpact(impacts[index]);
                setIndex((prev) => (prev + 1) % impacts.length);
            }
        };

        // Rotation logic: Show for 5s, hide/wait for 60-120s
        const displayDuration = 5000;
        const waitDuration = Math.random() * (120000 - 60000) + 60000;

        const timer = setTimeout(() => {
            showNext();
            // After showing, set another timeout to hide it
            setTimeout(() => {
                setIsExiting(true);
                setTimeout(() => {
                    setCurrentImpact(null);
                    setIsExiting(false);
                }, 500);
            }, displayDuration);
        }, waitDuration);

        return () => clearTimeout(timer);
    }, [impacts, index, currentImpact]);

    if (!currentImpact) return null;

    const getIcon = (type: string) => {
        switch (type) {
            case "purchase": return <i className="fas fa-book-medical" style={{ color: "#4169E1" }}></i>;
            case "distributor": return <i className="fas fa-rocket" style={{ color: "#f6ad55" }}></i>;
            case "partner": return <i className="fas fa-certificate" style={{ color: "#48bb78" }}></i>;
            case "registration": return <i className="fas fa-user-plus" style={{ color: "#63b3ed" }}></i>;
            default: return <i className="fas fa-bell"></i>;
        }
    };

    return (
        <div className={styles.liveFeedContainer}>
            <div className={`${styles.toast} ${isExiting ? styles.toastExit : ""}`}>
                <div className={styles.toastIcon}>
                    {getIcon(currentImpact.type)}
                </div>
                <div className={styles.toastText}>
                    {currentImpact.text}
                </div>
            </div>
        </div>
    );
}
