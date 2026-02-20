"use client";

import { useState, useEffect } from 'react';
import styles from './ReferralLeaderboard.module.css';

interface LeaderboardEntry {
    rank: number;
    name: string;
    points: number;
    revenue: number;
    lifetimeEarnings: number;
    impact: string;
    email: string;
}

export default function ReferralLeaderboard() {
    const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
    const [userEmail, setUserEmail] = useState<string | null>(null);
    const [userStats, setUserStats] = useState<{ points: number; revenue: number; lifetimeEarnings: number } | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    useEffect(() => {
        const fetchData = async () => {
            try {
                // Get user info from localStorage if available
                const storedEmail = localStorage.getItem('userEmail');
                const email = storedEmail?.toLowerCase().trim() || null;
                setUserEmail(email);

                const response = await fetch('/api/referral/leaderboard');
                if (response.ok) {
                    const data = await response.json();
                    setLeaderboard(data);

                    // If user is identifies, find their specific stats for the summary
                    if (email) {
                        const userEntry = data.find((e: LeaderboardEntry) => e.email.toLowerCase().trim() === email);
                        if (userEntry) {
                            setUserStats({
                                points: userEntry.points,
                                revenue: userEntry.revenue,
                                lifetimeEarnings: userEntry.lifetimeEarnings
                            });
                        }
                    }
                }
            } catch (error) {
                console.error('Failed to fetch leaderboard:', error);
            } finally {
                setIsLoading(false);
            }
        };

        fetchData();
    }, []);

    if (isLoading) {
        return (
            <div className={styles.loadingContainer}>
                <div className={styles.spinner}></div>
                <p>Calculating community impact...</p>
            </div>
        );
    }

    return (
        <section className={styles.leaderboardSection}>
            <header className={styles.header}>
                <h2 className={styles.title}>Top Referral Partners</h2>
                <p className={styles.subtitle}>Tracking the impact of our community.</p>
            </header>

            {userStats && (
                <div className={styles.userStatsBar}>
                    <div className={styles.statCard}>
                        <span className={styles.statLabel}>Your Accrued Points</span>
                        <span className={styles.statValue}>{(userStats?.points || 0).toLocaleString()} Pts</span>
                    </div>
                    <div className={`${styles.statCard} ${styles.incomeStat}`}>
                        <span className={styles.statLabel}>Your Accrued Income</span>
                        <span className={styles.statValue}>₦{(userStats?.revenue || 0).toLocaleString()}</span>
                    </div>
                    <div className={`${styles.statCard} ${styles.lifetimeStat}`}>
                        <span className={styles.statLabel}>Total Lifetime Earnings</span>
                        <span className={styles.statValue}>₦{(userStats?.lifetimeEarnings || 0).toLocaleString()}</span>
                    </div>
                </div>
            )}

            <div className={styles.tableWrapper}>
                <table className={styles.table}>
                    <thead>
                        <tr>
                            <th className={styles.rankCol}>Rank</th>
                            <th className={styles.partnerCol}>Partner</th>
                            <th className={styles.pointsCol}>Points</th>
                            <th className={styles.incomeCol}>Current Balance</th>
                            <th className={styles.lifetimeCol}>Lifetime Total</th>
                            <th className={styles.impactCol}>Impact</th>
                        </tr>
                    </thead>
                    <tbody>
                        {leaderboard.map((entry) => {
                            const isUser = userEmail && entry.email.toLowerCase().trim() === userEmail;

                            return (
                                <tr
                                    key={entry.rank}
                                    className={`${styles.row} ${isUser ? styles.userRow : ''}`}
                                >
                                    <td className={styles.rankCell}>
                                        <div className={styles.rankWrapper}>
                                            {entry.rank === 1 && <span className={styles.medal}>🥇</span>}
                                            {entry.rank === 2 && <span className={styles.medal}>🥈</span>}
                                            {entry.rank === 3 && <span className={styles.medal}>🥉</span>}
                                            <span className={styles.rankNumber}>{entry.rank}</span>
                                        </div>
                                    </td>
                                    <td className={styles.partnerCell}>
                                        <span className={styles.partnerName}>{entry.name}</span>
                                    </td>
                                    <td className={styles.pointsCell}>
                                        <span className={styles.pointsValue}>
                                            {(entry.points || 0).toLocaleString(undefined, { minimumFractionDigits: 1, maximumFractionDigits: 1 })} Pts
                                        </span>
                                    </td>
                                    <td className={styles.incomeCell}>
                                        <span className={styles.incomeValue}>
                                            ₦{(entry.revenue || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                                        </span>
                                    </td>
                                    <td className={styles.lifetimeCell}>
                                        <span className={styles.lifetimeValue}>
                                            ₦{(entry.lifetimeEarnings || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                                        </span>
                                    </td>
                                    <td className={styles.impactCell}>
                                        <span className={`${styles.impactBadge} ${styles[entry.impact.replace(' ', '')]}`}>
                                            {entry.impact}
                                        </span>
                                    </td>
                                </tr>
                            );
                        })}
                    </tbody>
                </table>
            </div>


            {leaderboard.length === 0 && !isLoading && (
                <div className={styles.emptyState}>
                    <i className="fas fa-users" style={{ fontSize: '2rem', marginBottom: '10px', opacity: 0.5 }}></i>
                    <p>No rankings yet. Start sharing to see your name here!</p>
                </div>
            )}
        </section>
    );
}
