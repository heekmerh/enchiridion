"use client";

import { useState, useEffect, useRef } from "react";
import styles from "./Dashboard.module.css";

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
        },
        payout: {
            accountName: "",
            accountNumber: "",
            bankName: "",
            isSaved: false,
        },
    });

    const [milestoneFulfilled, setMilestoneFulfilled] = useState<{ [tier: number]: boolean }>({ 50: false, 100: false });

    useEffect(() => {
        // Load name from localStorage
        const savedName = localStorage.getItem("enchiridion_user_name");
        if (savedName) {
            setPartnerData(prev => ({ ...prev, username: savedName }));
        }

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
                        },
                        payout: {
                            accountName: stats.accountName || "",
                            accountNumber: stats.accountNumber || "",
                            bankName: stats.bankName || "",
                            isSaved: !!(stats.accountName && stats.accountNumber && stats.bankName)
                        }
                    }));

                    // Pre-fill payout form if data exists
                    if (stats.accountName || stats.accountNumber || stats.bankName) {
                        setPayoutForm({
                            accountName: stats.accountName || "",
                            accountNumber: stats.accountNumber || "",
                            bankName: stats.bankName || "",
                        });
                    }
                }
            } catch (err) {
                console.error("Failed to fetch dashboard stats:", err);
            }
        };

        fetchStats();
    }, []);

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
    const prevReferralsRef = useRef(0);
    const revenueCardRef = useRef<HTMLDivElement>(null);
    const lifetimeCardRef = useRef<HTMLDivElement>(null);

    const referralLink = `https://enchiridion.ng/?ref=${partnerData.refCode}`;
    const whatsappMessage = `Hello! I’ve been using these Concise Medical Handbooks from Enchiridion—they are incredibly practical for students and clinicians. Users, referral partners and distributors are eligible for incredible rewards and discounts! You can browse the collection or download the app here: ${referralLink}`;
    const whatsappUrl = `https://wa.me/?text=${encodeURIComponent(whatsappMessage)}`;

    const handleCopy = async () => {
        try {
            await navigator.clipboard.writeText(referralLink);
            setCopied(true);
        } catch (err) {
            // Fallback for older mobile browsers
            const textArea = document.createElement("textarea");
            textArea.value = referralLink;
            document.body.appendChild(textArea);
            textArea.select();
            try {
                document.execCommand("copy");
                setCopied(true);
            } catch (copyErr) {
                console.error("Fallback copy failed", copyErr);
            }
            document.body.removeChild(textArea);
        }
        setTimeout(() => setCopied(false), 2000);
    };

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

        // Multi-tier Milestone logic
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

    // Helper to generate confetti particles
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

    // Calculate milestone progress
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
                    <h1>Welcome, {partnerData.username}</h1>
                    <p>Track your impact and manage your rewards.</p>
                </div>

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
                        <div className={styles.statValue}>{partnerData.stats.pointsEarned.toFixed(1)}</div>
                        <div className={styles.statLabel}>Points Earned</div>
                    </div>
                    <div className={`${styles.statCard} ${styles.glassCard}`} ref={revenueCardRef}>
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
                                <a href={whatsappUrl} target="_blank" rel="noopener noreferrer" className={`${styles.socialBtn} ${styles.whatsapp}`}>
                                    <i className="fab fa-whatsapp"></i>
                                </a>
                                <a href={`https://twitter.com/intent/tweet?text=${encodeURIComponent("Check out Enchiridion! " + referralLink)}`} target="_blank" rel="noopener noreferrer" className={`${styles.socialBtn} ${styles.twitter}`}>
                                    <i className="fab fa-x-twitter"></i>
                                </a>
                                <a href={`https://facebook.com/sharer/sharer.php?u=${encodeURIComponent(referralLink)}`} target="_blank" rel="noopener noreferrer" className={`${styles.socialBtn} ${styles.facebook}`}>
                                    <i className="fab fa-facebook-f"></i>
                                </a>
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
        </div>
    );
}
