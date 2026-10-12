"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import styles from "./OnboardingChecklist.module.css";
import CommunityGravity from "./CommunityGravity";
import { getAccessToken } from "@/lib/supabase";

interface UserProgress {
    email: string;
    is_verified: boolean;
    is_partner: boolean;
    is_distributor: boolean;
    has_purchased_book: boolean;
    last_updated: string;
}

export default function OnboardingChecklist() {
    const [progress, setProgress] = useState<UserProgress | null>(null);
    const [loading, setLoading] = useState(true);
    const [showConfetti, setShowConfetti] = useState(false);
    const prevMasteryRef = useRef(false);

    const fetchProgress = useCallback(async () => {
        setLoading(true);
        try {
            const token = await getAccessToken();
            if (!token) return;
            const response = await fetch("/api/referral/progress", { headers: { Authorization: `Bearer ${token}` } });
            if (response.ok) setProgress(await response.json());
        } catch (error) { console.error("Failed to fetch onboarding progress:", error); }
        finally { setLoading(false); }
    }, []);
    useEffect(() => { fetchProgress(); }, [fetchProgress]);

    if (!progress) return null;

    const steps = [
        {
            id: 'verify',
            title: 'Account Verified',
            completed: progress.is_verified,
            active: !progress.is_verified,
            locked: false,
            benefit: 'Step 1: Verify your email to unlock dashboard tracking & rewards.',
            actionLabel: 'Verify Email',
            actionUrl: '/verify-email'
        },
        {
            id: 'partner',
            title: 'Partner Status',
            completed: progress.is_partner,
            active: progress.is_verified && !progress.is_partner,
            locked: !progress.is_verified,
            benefit: 'Step 2: Become a Partner to unlock the Rewards Dashboard.',
            actionLabel: 'Become a Partner',
            actionUrl: '/refer'
        },
        {
            id: 'distributor',
            title: 'Distributor Status',
            completed: progress.is_distributor,
            active: progress.is_partner && !progress.is_distributor,
            locked: !progress.is_partner,
            benefit: 'Step 3: Become a Distributor to unlock the Marketplace.',
            actionLabel: 'Apply Now',
            actionUrl: '/books/pediatrics?tab=distributor'
        },
        {
            id: 'mastery',
            title: 'Enchiridion Mastery',
            completed: progress.has_purchased_book,
            active: progress.is_distributor && !progress.has_purchased_book,
            locked: !progress.is_distributor,
            benefit: 'Step 4: Own "The Book" to master the Enchiridion & maximize rewards.',
            actionLabel: 'Get The Book',
            actionUrl: '/books/pediatrics',
            reward: '+1.0 Points'
        }
    ];

    const completedCount = steps.filter(s => s.completed).length;
    const progressPercent = (completedCount / steps.length) * 100;

    const renderConfetti = (count = 50) => {
        const colors = ["#ff0000", "#00ff00", "#0000ff", "#fbbf24", "#4169E1", "#00ffff"];
        return Array.from({ length: count }).map((_, i) => (
            <div
                key={i}
                className={styles.confetti}
                style={{
                    left: `${Math.random() * 100}%`,
                    backgroundColor: colors[Math.floor(Math.random() * colors.length)],
                    animationDuration: `${Math.random() * 2 + 1}s`,
                    animationDelay: `${Math.random() * 2}s`,
                } as React.CSSProperties}
            />
        ));
    };

    return (
        <div className={styles.onboardingContainer}>
            {showConfetti && <div className={styles.confettiContainer}>{renderConfetti(100)}</div>}

            <div className={styles.onboardingCard}>
                <div className={styles.header}>
                    <h2>Enchiridion Onboarding</h2>
                    <button type="button" disabled={loading} onClick={fetchProgress}>Refresh progress</button>
                    <div className={styles.progressText}>{Math.round(progressPercent)}% Complete</div>
                </div>

                <div role="progressbar" aria-label="Onboarding completion" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(progressPercent)} className={styles.progressBarContainer}>
                    <div className={styles.progressBar} style={{ width: `${progressPercent}%` }}></div>
                </div>

                <div className={styles.stepsGrid}>
                    {steps.map((step) => (
                        <div
                            key={step.id}
                            className={`${styles.stepCard} ${step.completed ? styles.completed : ""} ${step.active ? styles.active : ""} ${step.locked ? styles.locked : ""}`}
                        >
                            <div className={styles.stepHeader}>
                                <div className={styles.titleGroup}>
                                    <h3>{step.title}</h3>
                                    {step.completed && (step as any).reward && (
                                        <span className={styles.rewardBadge}>{(step as any).reward}</span>
                                    )}
                                </div>
                                <div className={`${styles.statusIcon} ${step.completed ? styles.completed : step.active ? styles.active : styles.locked ? styles.locked : ""}`}>
                                    <span className="sr-only">{step.completed ? "Completed" : step.locked ? "Locked" : "Next step"}</span>
                                    {step.completed ? <i aria-hidden="true" className="fas fa-check"></i> : step.locked ? <i aria-hidden="true" className="fas fa-lock"></i> : <i aria-hidden="true" className="fas fa-arrow-right"></i>}
                                </div>
                            </div>

                            <p className={styles.benefitText}>{step.benefit}</p>

                            {(step.active || (step.id === 'mastery' && step.completed)) && (
                                <button
                                    className={`${styles.actionBtn} ${step.completed ? styles.completedAction : ""}`}
                                    onClick={() => window.location.href = step.actionUrl}
                                >
                                    {step.actionLabel}
                                </button>
                            )}

                            {step.id === 'mastery' && step.completed && (
                                <p className={styles.nudgeText}>
                                    You've been rewarded. Now, help others master the Enchiridion and earn <b>5.0 points</b> per referral!
                                </p>
                            )}
                        </div>
                    ))}
                </div>

                <CommunityGravity />
            </div>
        </div>
    );
}
