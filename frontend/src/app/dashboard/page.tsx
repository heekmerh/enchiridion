"use client";

import { useState, useEffect, useRef } from "react";
import styles from "./Dashboard.module.css";
import { recordShare } from "@/lib/record";
import OnboardingChecklist from "@/components/OnboardingChecklist";
import ImpactLiveFeed from "@/components/ImpactLiveFeed";
import LegacyBadge from "@/components/LegacyBadge";
import Link from "next/link";
import GlobalToast from "@/components/GlobalToast";
import SocialShareCard from "@/components/SocialShareCard";

export default function PartnerDashboard() {
    const [copied, setCopied] = useState(false);
    const [partnerData, setPartnerData] = useState({
        username: "Partner", // Will be updated from localStorage
        refCode: "",
        stats: {
            friendsReferred: 0,
            pointsEarned: 0,
            accruedRevenue: 0,
            lifetimeEarnings: 0,
            totalReferrals: 0,
            pendingPoints: 0,
            networkSpreadCount: 0,
        },
        recentActivity: [] as any[],
        refereeProgress: [] as any[],
        payout: {
            accountName: "",
            accountNumber: "",
            bankName: "",
            isSaved: false,
        },
        legacy: {
            rank: 'Seeker' as 'Seeker' | 'Sage' | 'Master',
            soulsGuided: 0,
            masteryDate: null as string | null
        }
    });

    const [mounted, setMounted] = useState(false);
    const [milestoneFulfilled, setMilestoneFulfilled] = useState<{ [tier: number]: boolean }>({ 50: false, 100: false });
    const [userProgress, setUserProgress] = useState<any>(null);
    const [showCashbackPulse, setShowCashbackPulse] = useState(false);
    const [showRankUp, setShowRankUp] = useState<any>(null); // { title: string, body: string, btnText: string, icon: string }

    const prevRankRef = useRef<string | null>(null);

    useEffect(() => {
        // Load name and ref code from localStorage for immediate availability
        const savedName = localStorage.getItem("enchiridion_user_name");
        const savedRef = localStorage.getItem("enchiridion_user_ref");

        setPartnerData(prev => ({
            ...prev,
            username: savedName || prev.username,
            refCode: savedRef || prev.refCode
        }));

        setMounted(true);

        // Fetch actual stats from backend
        const fetchStats = async () => {
            const token = localStorage.getItem("enchiridion_token");
            if (!token) return;

            try {
                const response = await fetch("/api/referral/stats", {
                    headers: {
                        "Authorization": `Bearer ${token}`
                    }
                });
                if (response.ok) {
                    const stats = await response.json();
                    setPartnerData(prev => ({
                        ...prev,
                        refCode: stats.referralCode,
                        stats: {
                            ...prev.stats,
                            pointsEarned: stats.points,
                            accruedRevenue: stats.revenue,
                            lifetimeEarnings: stats.lifetimeEarnings || 0,
                            totalReferrals: stats.totalReferrals || 0,
                            pendingPoints: stats.pendingPoints || 0,
                            networkSpreadCount: stats.networkSpreadCount || 0,
                        },
                        recentActivity: stats.milestones || [],
                        refereeProgress: stats.refereeProgress || [],
                        payout: {
                            accountName: stats.accountName || "",
                            accountNumber: stats.accountNumber || "",
                            bankName: stats.bankName || "",
                            isSaved: !!(stats.accountName && stats.accountNumber && stats.bankName)
                        },
                        legacy: {
                            rank: stats.legacyRank || 'Seeker',
                            soulsGuided: stats.soulsGuided || 0,
                            masteryDate: stats.masteryDate || null
                        }
                    }));

                    // Persist ref code in case it changed or was missing
                    if (stats.referralCode) {
                        localStorage.setItem("enchiridion_user_ref", stats.referralCode);
                    }

                    // Pre-fill payout form if data exists
                    if (stats.accountName || stats.accountNumber || stats.bankName) {
                        setPayoutForm({
                            accountName: stats.accountName || "",
                            accountNumber: stats.accountNumber || "",
                            bankName: stats.bankName || "",
                        });
                    }
                    localStorage.setItem("enchiridion_user_city", stats.city || "");
                }

                // Also fetch user progress for the mastery card and animations
                const progressRes = await fetch("/api/referral/progress", {
                    headers: { "Authorization": `Bearer ${token}` }
                });
                if (progressRes.ok) {
                    const progress = await progressRes.json();
                    setUserProgress(progress);

                    // Trigger pulse if mastery just achieved (check localStorage or recent milestone)
                    const hasPulseShown = localStorage.getItem("enchiridion_mastery_pulse_shown");
                    if (progress.has_purchased_book && !hasPulseShown) {
                        setShowCashbackPulse(true);
                        localStorage.setItem("enchiridion_mastery_pulse_shown", "true");
                        // Reset pulse state after animation finished
                        setTimeout(() => setShowCashbackPulse(false), 5000);
                    }
                }
            } catch (err) {
                console.error("Failed to fetch dashboard stats:", err);
            }
        };

        fetchStats();
    }, []);

    // Detect Rank Up
    useEffect(() => {
        if (!partnerData.legacy.rank) return;

        const currentRank = partnerData.legacy.rank;
        const prevRank = prevRankRef.current;

        if (prevRank && prevRank !== currentRank) {
            // Rank Up event!
            if (currentRank === 'Master') {
                setShowRankUp({
                    title: "You Have Reached Mastery! 🏆",
                    body: "You have successfully guided 16 souls to the Enchiridion Blueprint. Your name has been added to the Legacy Wall as an Enchiridion Master.",
                    perk: "Your profile is now featured on the Rewards Page for the entire community to see.",
                    btnText: "View My Place on the Wall",
                    btnUrl: "/rewards#pantheon",
                    icon: "fa-crown"
                });
            } else if (currentRank === 'Sage') {
                setShowRankUp({
                    title: "You've Become an Enchiridion Sage! 📜",
                    body: "Your influence is growing. By guiding 6 souls, you've earned the Sage rank and the Silver insignia.",
                    perk: "You are now halfway to absolute Mastery.",
                    btnText: "Keep Leading the Way",
                    btnUrl: "#",
                    icon: "fa-scroll"
                });
            }
        }

        prevRankRef.current = currentRank;
    }, [partnerData.legacy.rank]);

    const applyMilestone = async (tier: number) => {
        const token = localStorage.getItem("enchiridion_token");
        if (!token || milestoneFulfilled[tier]) return;

        try {
            const response = await fetch("/api/referral/apply-milestone", {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${token}`,
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    refCode: partnerData.refCode,
                    tier: tier
                })
            });
            if (response.ok) {
                setMilestoneFulfilled(prev => ({ ...prev, [tier]: true }));
                // Update stats locally
                const result = await response.json();
                if (result.bonus) {
                    setPartnerData(prev => ({
                        ...prev,
                        stats: {
                            ...prev.stats,
                            accruedRevenue: result.new_total
                        }
                    }));
                }
            }
        } catch (err) {
            console.error(`Failed to apply milestone ${tier}:`, err);
        }
    };

    const [payoutForm, setPayoutForm] = useState({
        accountName: "",
        accountNumber: "",
        bankName: "",
    });

    const [showCelebration, setShowCelebration] = useState(false);
    const [celebrationTier, setCelebrationTier] = useState<number | null>(null);
    const [showRules, setShowRules] = useState(false);
    const prevReferralsRef = useRef(0);
    const revenueCardRef = useRef<HTMLDivElement>(null);
    const lifetimeCardRef = useRef<HTMLDivElement>(null);

    const referralLink = mounted ? `${window.location.origin}/refer?ref=${partnerData.refCode}` : `https://enchiridion.ng/refer?ref=${partnerData.refCode}`;
    const whatsappMessage = `Hey! I’ve been using these Concise Medical Handbooks from Enchiridion—they are incredibly practical for students and clinicians. Users, referral partners and distributors are eligible for incredible rewards and discounts! Plus, check out the official Book—it’s a game-changer for anyone in the medical space!\n\nJoin here: ${referralLink}`;
    const whatsappUrl = `https://wa.me/?text=${encodeURIComponent(whatsappMessage)}`;

    const handleCopy = async () => {
        try {
            await navigator.clipboard.writeText(referralLink);
            setCopied(true);
            const currentRef = partnerData.refCode || localStorage.getItem("enchiridion_user_ref");
            if (currentRef) {
                recordShare(currentRef, "Clipboard Copy");
            }
        } catch (err) {
            // Fallback for older mobile browsers
            const textArea = document.createElement("textarea");
            textArea.value = referralLink;
            document.body.appendChild(textArea);
            textArea.select();
            try {
                document.execCommand("copy");
                setCopied(true);
                const currentRef = partnerData.refCode || localStorage.getItem("enchiridion_user_ref");
                if (currentRef) {
                    recordShare(currentRef, "Clipboard Copy (Fallback)");
                }
            } catch (copyErr) {
                console.error("Fallback copy failed", copyErr);
            }
            document.body.removeChild(textArea);
        }
        setTimeout(() => setCopied(false), 2000);
    };

    const handleSocialShare = (platform: string, url: string) => {
        const currentRef = partnerData.refCode || localStorage.getItem("enchiridion_user_ref");

        if (currentRef) {
            recordShare(currentRef, platform);
        } else {
            console.warn("Cannot track share: Referral code missing");
            alert("Your referral code is still loading. Please wait a moment or try logging out and back in if this persists.");
        }
        window.open(url, '_blank');
    };

    const handleLogout = () => {
        localStorage.removeItem("enchiridion_token");
        localStorage.removeItem("enchiridion_user_name");
        localStorage.removeItem("enchiridion_user_ref");
        localStorage.removeItem("enchiridion_ref");
        localStorage.removeItem("enchiridion_user_city");
        localStorage.removeItem("enchiridion_mastery_pulse_shown");
        window.location.href = "/";
    };

    const handleCloseRankUp = () => setShowRankUp(null);

    const handlePayoutSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        const token = localStorage.getItem("enchiridion_token");
        if (!token) return;

        try {
            const response = await fetch("/api/referral/update-payout", {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${token}`,
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    refCode: partnerData.refCode,
                    ...payoutForm
                })
            });

            if (response.ok) {
                setPartnerData({
                    ...partnerData,
                    payout: {
                        ...payoutForm,
                        isSaved: true,
                    },
                });
                alert("Payout details saved successfully!");
            } else {
                const error = await response.json();
                alert(`Failed to save: ${error.detail || "Unknown error"}`);
            }
        } catch (err) {
            console.error("Failed to save payout:", err);
            alert("Connection error. Please try again.");
        }
    };

    useEffect(() => {
        const currentRefs = partnerData.stats.totalReferrals;
        const prevRefs = prevReferralsRef.current;

        if (currentRefs >= 100 && prevRefs < 100) {
            setCelebrationTier(100);
            setShowCelebration(true);
            applyMilestone(100);
            setTimeout(() => setShowCelebration(false), 8000);
        } else if (currentRefs >= 50 && prevRefs < 50) {
            setCelebrationTier(50);
            setShowCelebration(true);
            applyMilestone(50);
            setTimeout(() => setShowCelebration(false), 5000);
        }

        prevReferralsRef.current = currentRefs;
    }, [partnerData.stats.totalReferrals]);

    const scrollToRevenue = () => {
        setShowCelebration(false);
        revenueCardRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    };

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

    const totalRefs = partnerData.stats.totalReferrals;
    const progressPercent = Math.min((totalRefs / 100) * 100, 100);

    let milestoneStatus = "Next Goal: Power Partner (50)";
    if (totalRefs >= 100) {
        milestoneStatus = "Elite Ambassador Status Unlocked! 🏆";
    } else if (totalRefs >= 50) {
        milestoneStatus = "Power Partner Achieved! Next Goal: Elite Ambassador (100)";
    }

    return (
        <div className={styles.dashboard}>
            <div className={styles.container}>
                <div className={styles.welcomeSection}>
                    <div className={styles.nameBadgeRow}>
                        <h1>Welcome, {partnerData.username}</h1>
                        <LegacyBadge rank={partnerData.legacy.rank} />
                        <button className={styles.logoutBtn} onClick={handleLogout} title="Log out">
                            <i className="fas fa-sign-out-alt"></i> Logout
                        </button>
                    </div>
                    <p>
                        Track your impact and manage your rewards.
                        <Link href="/rewards#pantheon" className={styles.legacyWallLink}>
                            View the Legacy Wall <i className="fas fa-external-link-alt"></i>
                        </Link>
                    </p>
                </div>

                {userProgress?.has_purchased_book && (
                    <div className={styles.masteryUnlockingCard}>
                        <div className={styles.masteryContent}>
                            <div className={styles.masteryHeader}>
                                <h2>Enchiridion Mastery Unlocked! 🏆</h2>
                            </div>
                            <p className={styles.masteryBody}>
                                You just earned <b>1.0 Point</b> for your commitment. Your blueprint is ready.
                                Use your mastery to help others and maximize your earnings.
                            </p>
                            <div className={styles.masteryStats}>
                                <div className={styles.masteryStatItem}>
                                    <label>Current Wallet Balance</label>
                                    <p>{partnerData.stats.pointsEarned.toFixed(2)} Points (approx. ₦{partnerData.stats.accruedRevenue.toLocaleString()})</p>
                                </div>
                            </div>
                            <div className={styles.masteryCTA}>
                                <button className={styles.referralBtn} onClick={handleCopy}>
                                    {copied ? "Link Copied!" : "Copy My Referral Link"} <i className="fas fa-copy"></i>
                                </button>
                                <p style={{ margin: 0, color: '#94a3b8', fontSize: '0.9rem' }}>
                                    <b>Next Goal:</b> Refer your first friend to earn <b>5.0 Points</b>
                                </p>
                            </div>
                        </div>
                    </div>
                )}

                <OnboardingChecklist />

                {/* Stats Grid */}
                <div className={styles.statsGrid}>
                    <div className={`${styles.statCard} ${styles.glassCard}`}>
                        <div className={styles.statIcon}><i className="fas fa-users"></i></div>
                        <div className={styles.statValue}>{partnerData.stats.totalReferrals}</div>
                        <div className={styles.statLabel}>Total Referrals</div>
                        {partnerData.stats.totalReferrals === 0 && (
                            <p className={styles.emptyStateHint}>Start sharing your link to earn your first bonus!</p>
                        )}
                    </div>
                    <div className={`${styles.statCard} ${styles.glassCard}`}>
                        <div className={styles.statIcon}><i className="fas fa-star"></i></div>
                        <div className={styles.statValue}>
                            {partnerData.stats.pointsEarned.toFixed(1)}
                            <i
                                className={`fas fa-info-circle ${styles.infoIcon}`}
                                onClick={() => setShowRules(true)}
                                title="How points work"
                            ></i>
                        </div>
                        <div className={styles.statLabel}>Points Earned</div>
                    </div>
                    <div className={`${styles.statCard} ${styles.glassCard}`}>
                        <div className={styles.statIcon}><i className="fas fa-hourglass-half"></i></div>
                        <div className={styles.statValue}>{partnerData.stats.pendingPoints.toFixed(1)}</div>
                        <div className={styles.statLabel}>Pending Points</div>
                    </div>
                    <div className={`${styles.statCard} ${styles.glassCard} ${showCashbackPulse ? styles.walletPulse : ""}`} ref={revenueCardRef}>
                        {showCashbackPulse && <div className={styles.cashbackChip}>+1.0 Cash-back Awarded</div>}
                        <div className={styles.statIcon}><i className="fas fa-naira-sign"></i></div>
                        <div className={styles.statValue}>₦{partnerData.stats.accruedRevenue.toLocaleString()}</div>
                        <div className={styles.statLabel}>Accrued Balance</div>
                    </div>
                    <div
                        className={`${styles.statCard} ${styles.glassCard} ${totalRefs >= 100 ? styles.elitePulse : ''}`}
                        ref={lifetimeCardRef}
                    >
                        <div className={styles.statIcon}><i className="fas fa-history"></i></div>
                        <div className={styles.statValue}>₦{(partnerData.stats.lifetimeEarnings || 0).toLocaleString()}</div>
                        <div className={styles.statLabel}>Lifetime Earnings</div>
                    </div>
                </div>

                {/* Share Section */}
                <div className={styles.card}>
                    <h3>Share Your Link</h3>
                    <div className={styles.shareBox}>
                        <p className={styles.shareLabel}>Copy & Paste or Click & Share</p>
                        <div className={styles.linkGroup}>
                            <div className={styles.linkInput}>{referralLink}</div>
                            <button className={styles.copyBtn} onClick={handleCopy}>
                                {copied ? "Copied!" : "Copy"} <i className="fas fa-copy"></i>
                            </button>
                        </div>

                        <div className={styles.socialSharing}>
                            <span>Share via:</span>
                            <div className={styles.socialIcons}>
                                <button
                                    onClick={() => handleSocialShare('whatsapp', whatsappUrl)}
                                    className={`${styles.socialBtn} ${styles.whatsapp}`}
                                >
                                    <i className="fab fa-whatsapp"></i>
                                </button>
                                <button
                                    onClick={() => handleSocialShare('twitter', `https://twitter.com/intent/tweet?text=${encodeURIComponent("Check out Enchiridion! " + referralLink)}`)}
                                    className={`${styles.socialBtn} ${styles.twitter}`}
                                >
                                    <i className="fab fa-x-twitter"></i>
                                </button>
                                <button
                                    onClick={() => handleSocialShare('facebook', `https://facebook.com/sharer/sharer.php?u=${encodeURIComponent(referralLink)}`)}
                                    className={`${styles.socialBtn} ${styles.facebook}`}
                                >
                                    <i className="fab fa-facebook-f"></i>
                                </button>
                            </div>
                        </div>
                    </div>

                    <div className={styles.milestones}>
                        <div className={styles.milestoneTiers}>
                            <p className={styles.milestoneStatusLabel}>{milestoneStatus}</p>
                            <div className={styles.milestoneBarContainer}>
                                <div className={styles.milestoneProgress} style={{ width: `${progressPercent}%` }}></div>
                                <div className={`${styles.milestoneMarker} ${totalRefs >= 50 ? styles.reached : ''}`} style={{ left: '50%' }}>
                                    <div className={styles.markerLabel}>50: ₦2,000</div>
                                </div>
                                <div className={`${styles.milestoneMarker} ${totalRefs >= 100 ? styles.reached : ''}`} style={{ left: '100%' }}>
                                    <div className={styles.markerLabel}>100: ₦5,000</div>
                                </div>
                            </div>
                            <p className={styles.progressDetail}>Road to Power Partner: {totalRefs}/100 Referrals</p>
                        </div>
                    </div>

                    <div className={styles.milestoneSections}>
                        <div className={styles.milestoneTableCard}>
                            <h3>Milestone Tracker</h3>
                            <div className={styles.refereeList}>
                                {partnerData.refereeProgress.map((ref: any) => (
                                    <div key={ref.email} className={styles.refereeRow}>
                                        <div className={styles.refereeHeader}>
                                            <span>{ref.email}</span>
                                            <button
                                                className={styles.nudgeBtn}
                                                onClick={() => window.open(`https://wa.me/?text=${encodeURIComponent(`Hey! I saw you joined Enchiridion! If you grab the book, we both get closer to our goals! ${referralLink}`)}`, '_blank')}
                                            >
                                                <i className="fab fa-whatsapp"></i> Nudge
                                            </button>
                                        </div>
                                        <div className={styles.miniMilestones}>
                                            {ref.is_pending ? (
                                                <div className={`${styles.miniBadge} ${styles.pendingPulse}`}>Pending Verification</div>
                                            ) : (
                                                <>
                                                    <div className={`${styles.miniBadge} ${ref.milestones.includes('partner') ? styles.active : ''}`}>Registered</div>
                                                    <div className={`${styles.miniBadge} ${ref.milestones.includes('distributor') ? styles.active : ''}`}>Distributor</div>
                                                    <div className={`${styles.miniBadge} ${ref.milestones.includes('book_purchase') ? styles.active : ''}`}>Bought Book</div>
                                                </>
                                            )}
                                        </div>
                                    </div>
                                ))}
                                {partnerData.refereeProgress.length === 0 && (
                                    <p style={{ color: '#94a3b8', fontSize: '0.9rem' }}>No active milestones yet. Share your link to start tracking!</p>
                                )}
                            </div>
                        </div>

                        <div className={styles.milestoneTableCard}>
                            <h3>Network Tree (Tier-2)</h3>
                            <div className={styles.networkTree}>
                                <div className={styles.treeItem}>
                                    Network Spread: <b>{partnerData.stats.networkSpreadCount}</b> rewards earned.
                                </div>
                                <p style={{ color: '#64748b', fontSize: '0.85rem', marginTop: '12px' }}>
                                    You earn 0.1 points every time a friend of your friend joins the network!
                                </p>
                            </div>
                        </div>
                    </div>

                    <div className={styles.card}>
                        <h3>Recent Activity</h3>
                        <div className={styles.activityFeed}>
                            {partnerData.recentActivity.length > 0 ? (
                                partnerData.recentActivity.slice().reverse().map((act: any, idx: number) => (
                                    <div key={idx} className={styles.activityItem}>
                                        <div className={styles.activityDate}>
                                            {new Date(act.timestamp).toLocaleDateString()}
                                        </div>
                                        <div className={styles.activityMain}>
                                            <p><b>{act.referee}</b> completed <b>{act.type.replace('_', ' ')}</b></p>
                                        </div>
                                        <div className={styles.activityPoints}>
                                            +{act.points.toFixed(1)} Pts
                                        </div>
                                    </div>
                                ))
                            ) : (
                                <p className={styles.emptyActivity}>No activity recorded yet.</p>
                            )}
                        </div>
                    </div>

                </div>

                {/* Payout Settings */}
                <div className={styles.card}>
                    <h3>Payout Settings</h3>
                    {partnerData.payout.isSaved ? (
                        <div className={styles.savedInfo}>
                            <div className={styles.infoDetails}>
                                <div className={styles.infoItem}>
                                    <label>Account Name</label>
                                    <p>{partnerData.payout.accountName}</p>
                                </div>
                                <div className={styles.infoItem}>
                                    <label>Account Number</label>
                                    <p>{partnerData.payout.accountNumber}</p>
                                </div>
                                <div className={styles.infoItem}>
                                    <label>Bank Name</label>
                                    <p>{partnerData.payout.bankName}</p>
                                </div>
                            </div>
                            <button
                                className={styles.changeBtn}
                                onClick={() => setPartnerData({ ...partnerData, payout: { ...partnerData.payout, isSaved: false } })}
                            >
                                Change Account
                            </button>
                        </div>
                    ) : (
                        <form className={styles.payoutForm} onSubmit={handlePayoutSubmit}>
                            <div className={`${styles.field} ${styles.fieldFull}`}>
                                <label>Account Name</label>
                                <input
                                    type="text"
                                    value={payoutForm.accountName}
                                    onChange={(e) => setPayoutForm({ ...payoutForm, accountName: e.target.value })}
                                    placeholder="Full name as it appears on account"
                                    required
                                />
                            </div>
                            <div className={styles.field}>
                                <label>Account Number</label>
                                <input
                                    type="text"
                                    value={payoutForm.accountNumber}
                                    onChange={(e) => setPayoutForm({ ...payoutForm, accountNumber: e.target.value })}
                                    placeholder="10-digit account number"
                                    pattern="[0-9]{10}"
                                    required
                                />
                            </div>
                            <div className={styles.field}>
                                <label>Bank Name</label>
                                <input
                                    type="text"
                                    value={payoutForm.bankName}
                                    onChange={(e) => setPayoutForm({ ...payoutForm, bankName: e.target.value })}
                                    placeholder="Enter Bank Name"
                                    required
                                />
                            </div>
                            <button type="submit" className={styles.saveBtn}>Save Payout Details</button>
                        </form>
                    )}
                </div>
            </div>

            {/* Celebration Popup */}
            {showCelebration && (
                <div className={`${styles.celebrationOverlay} ${celebrationTier === 100 ? styles.eliteOverlay : ''}`}>
                    {renderConfetti(celebrationTier === 100 ? 150 : 50)}
                    <div className={`${styles.celebrationCard} ${celebrationTier === 100 ? styles.eliteCard : ''}`}>
                        <div className={styles.trophyIcon}>
                            <i className={`fas ${celebrationTier === 100 ? 'fa-crown' : 'fa-trophy'}`}></i>
                        </div>
                        <h2>{celebrationTier === 100 ? 'Elite Ambassador Status! 👑' : 'Power Partner Reached! 🎉'}</h2>
                        <p>
                            {celebrationTier === 100
                                ? "Incredible work! You've reached 100 referrals. A ₦5,000 Elite Bonus has been added to your account."
                                : "Congratulations! You've reached 50 referrals and unlocked the ₦2,000 Power Partner bonus."
                            }
                        </p>

                        <button className={styles.viewRevenueBtn} onClick={scrollToRevenue}>
                            {celebrationTier === 100 ? 'Claim My Elite Status' : 'View My Rewards'}
                        </button>
                    </div>
                </div>
            )}

            {/* Referral Rules Modal */}
            {showRules && (
                <div className={styles.rulesOverlay} onClick={() => setShowRules(false)}>
                    <div className={styles.rulesCard} onClick={(e) => e.stopPropagation()}>
                        <h2>
                            Referral Rules & Milestones
                            <button className={styles.closeButton} onClick={() => setShowRules(false)}>&times;</button>
                        </h2>

                        <div className={styles.ruleSection}>
                            <h3>How it Works</h3>
                            <p>Points are earned for <b>Verified Actions</b> taken by your friends, not just for sharing links. 1 Point = ₦100.</p>
                        </div>

                        <div className={styles.ruleSection}>
                            <h3>Earning Milestones</h3>
                            <ul>
                                <li><b>Partner Registration (+0.1 Pts):</b> Awarded when your friend joins and verifies their account.</li>
                                <li><b>Distributor Registration (+0.1 Pts):</b> Awarded when your friend registers as a Distributor.</li>
                                <li><b>Network Spread (+0.1 Pts):</b> Awarded when your friend (Tier 1) successfully refers someone else (Tier 2).</li>
                                <li><b>Book Purchase (+5.0 Pts):</b> The big one! Awarded when your friend purchases an official Antigravity book.</li>
                            </ul>
                        </div>

                        <div className={styles.ruleSection}>
                            <h3>Guidelines</h3>
                            <ul>
                                <li>Minimum withdrawal threshold: ₦500.</li>
                                <li>Self-referrals are prohibited and will result in point reversal.</li>
                                <li>Referees must verify their email for you to receive points.</li>
                            </ul>
                        </div>

                        <button className={styles.learnMoreBtn} onClick={() => setShowRules(false)}>Got it!</button>
                    </div>
                </div>
            )}

            <ImpactLiveFeed />
            <GlobalToast />

            {/* Rank Up Celebration Popup */}
            {showRankUp && (
                <div className={styles.celebrationOverlay} onClick={handleCloseRankUp}>
                    <div className={styles.celebrationCard} onClick={(e) => e.stopPropagation()}>
                        <div className={styles.trophyIcon}>
                            <i className={`fas ${showRankUp.icon}`}></i>
                        </div>
                        <h2>{showRankUp.title}</h2>

                        <div className={styles.celebrationBody}>
                            <p>{showRankUp.body}</p>

                            {/* Shareable Achievement Card */}
                            <div style={{ margin: '30px 0' }}>
                                <SocialShareCard
                                    username={partnerData.username}
                                    rank={partnerData.legacy.rank === 'Master' ? 'Master' : 'Sage'}
                                    soulsGuided={partnerData.legacy.soulsGuided}
                                    referralCode={partnerData.refCode}
                                />
                            </div>

                            <div className={styles.perkBadge}>
                                <strong>New Perk:</strong> {showRankUp.perk}
                            </div>
                        </div>

                        <button
                            className={styles.payoutBtn}
                            onClick={() => {
                                if (showRankUp.btnText === "View My Place on the Wall") {
                                    window.location.href = showRankUp.btnUrl;
                                } else {
                                    handleCloseRankUp();
                                }
                            }}
                        >
                            {showRankUp.btnText}
                        </button>

                        <button className={styles.closeCelebrationBtn} onClick={handleCloseRankUp}>
                            <i className="fas fa-times"></i>
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
