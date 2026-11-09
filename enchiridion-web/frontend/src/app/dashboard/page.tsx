"use client";

import { useState, useEffect, useRef } from "react";
import { useDialog } from "@/hooks/useDialog";
import styles from "./Dashboard.module.css";
import { recordShare } from "@/lib/record";
import OnboardingChecklist from "@/components/OnboardingChecklist";
import ImpactLiveFeed from "@/components/ImpactLiveFeed";
import LegacyBadge from "@/components/LegacyBadge";
import Link from "next/link";
import GlobalToast from "@/components/GlobalToast";
import SocialShareCard from "@/components/SocialShareCard";
import { currentSession, getAccessToken, signOut } from "@/lib/supabase";

export default function PartnerDashboard() {
    const [copied, setCopied] = useState(false);
    const [partnerData, setPartnerData] = useState({
        username: "Partner", // Will be updated from localStorage
        refCode: "",
        stats: {
            friendsReferred: 0,
            accruedRevenue: 0,
            lifetimeEarnings: 0,
            totalReferrals: 0,
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
    const [accountEmail, setAccountEmail] = useState("");
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
            const session = await currentSession();
            setAccountEmail(session?.user.email ?? "");
            const meta = session?.user.user_metadata ?? {};
            const metaName = typeof meta.display_name === "string" && meta.display_name ? meta.display_name : (typeof meta.name === "string" ? meta.name.split(" ")[0] : "");
            const metaRef = typeof meta.referral_code === "string" ? meta.referral_code.toLowerCase() : "";
            if (metaName || metaRef) {
                setPartnerData(prev => ({
                    ...prev,
                    username: prev.username === "Partner" && metaName ? metaName : prev.username,
                    refCode: prev.refCode || metaRef,
                }));
            }

            const token = session?.access_token ?? await getAccessToken();
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
                        refCode: stats.referralCode || prev.refCode,
                        username: stats.name ? String(stats.name).split(" ")[0] : prev.username,
                        stats: {
                            ...prev.stats,
                            accruedRevenue: stats.revenue,
                            lifetimeEarnings: stats.lifetimeEarnings || 0,
                            totalReferrals: stats.totalReferrals || 0,
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
        const token = await getAccessToken();
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
    const rankRef = useDialog(!!showRankUp && !showCelebration, () => setShowRankUp(null));
    const celebrationRef = useDialog(showCelebration, () => setShowCelebration(false));
    const prevReferralsRef = useRef(0);
    const revenueCardRef = useRef<HTMLDivElement>(null);
    const lifetimeCardRef = useRef<HTMLDivElement>(null);

    const referralLink = mounted ? `${window.location.origin}/refer?ref=${partnerData.refCode}` : `https://enchiridion.site/refer?ref=${partnerData.refCode}`;
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

    const handleLogout = async () => {
        await signOut();
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
        const token = await getAccessToken();
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

        } else if (currentRefs >= 50 && prevRefs < 50) {
            setCelebrationTier(50);
            setShowCelebration(true);
            applyMilestone(50);

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

    // Projected recurring monthly commission (20% of the ₦1,500 hub delivery base, ₦300 per active referral/month).
    const milestoneTiers = [
        { referrals: 10, monthlyAmount: 3000, label: "10 Referrals" },
        { referrals: 50, monthlyAmount: 15000, label: "Power Partner (50)" },
        { referrals: 100, monthlyAmount: 30000, label: "Elite Ambassador (100)" },
    ];

    let milestoneStatus = `Next Goal: ${milestoneTiers[0].label} — ₦${milestoneTiers[0].monthlyAmount.toLocaleString()}/mo`;
    if (totalRefs >= 100) {
        milestoneStatus = "Elite Ambassador Status Unlocked! 🏆 ₦30,000/mo";
    } else if (totalRefs >= 50) {
        milestoneStatus = `Power Partner Achieved! Next Goal: ${milestoneTiers[2].label} — ₦${milestoneTiers[2].monthlyAmount.toLocaleString()}/mo`;
    } else if (totalRefs >= 10) {
        milestoneStatus = `10 Referrals Reached! Next Goal: ${milestoneTiers[1].label} — ₦${milestoneTiers[1].monthlyAmount.toLocaleString()}/mo`;
    }

    const nextTier = milestoneTiers.find((tier) => totalRefs < tier.referrals) || milestoneTiers[milestoneTiers.length - 1];
    const roadLabel = totalRefs >= 100 ? "Elite Ambassador (100)" : nextTier.label;
    const roadTarget = totalRefs >= 100 ? 100 : nextTier.referrals;

    return (
        <div className={styles.dashboard}>
            <div className={styles.heroBand}>
                <div className={styles.heroBandInner}>
                    <div className={styles.welcomeSection}>
                        <div className={styles.nameBadgeRow}>
                            <h1>Welcome, {partnerData.username}</h1>
                            <LegacyBadge rank={partnerData.legacy.rank} />
                            <button className={styles.logoutBtn} onClick={handleLogout} title="Log out">
                                <i aria-hidden="true" className="fas fa-sign-out-alt"></i> Logout
                            </button>
                        </div>
                            {accountEmail && <p>Signed in as <b>{accountEmail}</b></p>}
                        <p>
                            Track your impact and manage your rewards.
                            <Link href="/rewards#pantheon" className={styles.legacyWallLink}>
                                View the Legacy Wall <i aria-hidden="true" className="fas fa-external-link-alt"></i>
                            </Link>
                        </p>
                    </div>
                </div>
            </div>
            <div className={styles.container}>
                {userProgress?.has_purchased_book && (
                    <div className={styles.masteryUnlockingCard}>
                        <div className={styles.masteryContent}>
                            <div className={styles.masteryHeader}>
                                <h2>Enchiridion Mastery Unlocked! 🏆</h2>
                            </div>
                            <p className={styles.masteryBody}>
                                Your blueprint is ready. Use your mastery to help others and maximize your earnings.
                            </p>
                            <div className={styles.masteryStats}>
                                <div className={styles.masteryStatItem}>
                                    <label>Current Wallet Balance</label>
                                    <p>₦{partnerData.stats.accruedRevenue.toLocaleString()}</p>
                                </div>
                            </div>
                            <div className={styles.masteryCTA}>
                                <button className={styles.referralBtn} onClick={handleCopy}>
                                    {copied ? "Link Copied!" : "Copy My Referral Link"} <i aria-hidden="true" className="fas fa-copy"></i>
                                </button>
                                <p style={{ margin: 0, color: '#94a3b8', fontSize: '0.9rem' }}>
                                    <b>Next Goal:</b> Refer your first friend to start earning rewards.
                                </p>
                            </div>
                        </div>
                    </div>
                )}

                <OnboardingChecklist />

                {/* Stats Grid */}
                <div className={styles.statsGrid}>
                    <div className={`${styles.statCard} ${styles.glassCard} ${showCashbackPulse ? styles.walletPulse : ""}`} ref={revenueCardRef}>
                        {showCashbackPulse && <div className={styles.cashbackChip}>+1.0 Cash-back Awarded</div>}
                        <div className={styles.statIcon}><i aria-hidden="true" className="fas fa-naira-sign"></i></div>
                        <div className={styles.statValue}>₦{partnerData.stats.accruedRevenue.toLocaleString()}</div>
                        <div className={styles.statLabel}>Accrued Balance</div>
                    </div>
                    <div className={styles.statCard}>
                        <div className={styles.statIcon}><i aria-hidden="true" className="fas fa-users"></i></div>
                        <div className={styles.statValue}>{partnerData.stats.totalReferrals}</div>
                        <div className={styles.statLabel}>Total Referrals</div>
                        {partnerData.stats.totalReferrals === 0 && (
                            <p className={styles.emptyStateHint}>Start sharing your link to earn your first bonus!</p>
                        )}
                    </div>
                    <div
                        className={`${styles.statCard} ${totalRefs >= 100 ? styles.elitePulse : ''}`}
                        ref={lifetimeCardRef}
                    >
                        <div className={`${styles.statIcon} ${styles.statIconGold}`}><i aria-hidden="true" className="fas fa-history"></i></div>
                        <div className={styles.statValue}>₦{(partnerData.stats.lifetimeEarnings || 0).toLocaleString()}</div>
                        <div className={styles.statLabel}>Lifetime Earnings</div>
                    </div>
                </div>

                {/* Share Section */}
                <div className={styles.card}>
                    <h2>Share Your Link</h2>
                    <div className={styles.shareBox}>
                        <p className={styles.shareLabel}>Copy & Paste or Click & Share</p>
                        <div className={styles.linkGroup}>
                            <div className={styles.linkInput}>{partnerData.refCode ? referralLink : "Loading your referral link..."}</div>
                            <button className={styles.copyBtn} onClick={handleCopy}>
                                {copied ? "Copied!" : "Copy"} <i aria-hidden="true" className="fas fa-copy"></i>
                            </button>
                        </div>

                        <div className={styles.socialSharing}>
                            <span>Share via:</span>
                            <div className={styles.socialIcons}>
                                <button
                                    onClick={() => handleSocialShare('whatsapp', whatsappUrl)}
                                    aria-label="Share referral link on WhatsApp" className={`${styles.socialBtn} ${styles.whatsapp}`}
                                >
                                    <i aria-hidden="true" className="fab fa-whatsapp"></i>
                                </button>
                                <button
                                    onClick={() => handleSocialShare('twitter', `https://twitter.com/intent/tweet?text=${encodeURIComponent("Check out Enchiridion! " + referralLink)}`)}
                                    aria-label="Share referral link on X" className={`${styles.socialBtn} ${styles.twitter}`}
                                >
                                    <i aria-hidden="true" className="fab fa-x-twitter"></i>
                                </button>
                                <button
                                    onClick={() => handleSocialShare('facebook', `https://facebook.com/sharer/sharer.php?u=${encodeURIComponent(referralLink)}`)}
                                    aria-label="Share referral link on Facebook" className={`${styles.socialBtn} ${styles.facebook}`}
                                >
                                    <i aria-hidden="true" className="fab fa-facebook-f"></i>
                                </button>
                            </div>
                        </div>
                    </div>

                    <div className={styles.milestones}>
                        <div className={styles.milestoneTiers}>
                            <p className={styles.milestoneStatusLabel}>{milestoneStatus}</p>
                            <div className={styles.milestoneBarContainer}>
                                <div className={styles.milestoneProgress} style={{ width: `${progressPercent}%` }}></div>
                                {milestoneTiers.map((tier) => (
                                    <div
                                        key={tier.referrals}
                                        className={`${styles.milestoneMarker} ${totalRefs >= tier.referrals ? styles.reached : ''}`}
                                        style={{ left: `${tier.referrals}%` }}
                                    >
                                        <div className={styles.markerLabel}>{tier.referrals}: ₦{tier.monthlyAmount.toLocaleString()}/mo</div>
                                    </div>
                                ))}
                            </div>
                            <p className={styles.progressDetail}>Road to {roadLabel}: {totalRefs}/{roadTarget} Referrals</p>
                            <p className={styles.progressDetail} style={{ fontSize: '0.8rem', opacity: 0.75 }}>
                                Projected at ₦300/referral/month (20% commission on the ₦1,500 hub rate), assuming referrals stay active.
                            </p>
                        </div>
                    </div>

                    <div className={styles.milestoneSections}>
                        <div className={styles.milestoneTableCard}>
                            <h2>Milestone Tracker</h2>
                            <div className={styles.refereeList}>
                                {partnerData.refereeProgress.map((ref: any) => (
                                    <div key={ref.email} className={styles.refereeRow}>
                                        <div className={styles.refereeHeader}>
                                            <span>{ref.email}</span>
                                            <button
                                                className={styles.nudgeBtn}
                                                onClick={() => window.open(`https://wa.me/?text=${encodeURIComponent(`Hey! I saw you joined Enchiridion! If you grab the book, we both get closer to our goals! ${referralLink}`)}`, '_blank')}
                                            >
                                                <i aria-hidden="true" className="fab fa-whatsapp"></i> Nudge
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
                                    <p style={{ color: '#64748b', fontSize: '0.9rem' }}>No active milestones yet. Share your link to start tracking!</p>
                                )}
                            </div>
                        </div>
                    </div>

                    <div className={styles.card}>
                        <h2>Recent Activity</h2>
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
                    <h2>Payout Settings</h2>
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
                                <label htmlFor="payout-field-1">Account Name</label>
                                <input id="payout-field-1"
                                    type="text"
                                    value={payoutForm.accountName}
                                    onChange={(e) => setPayoutForm({ ...payoutForm, accountName: e.target.value })}
                                    placeholder="Full name as it appears on account"
                                    required
                                />
                            </div>
                            <div className={styles.field}>
                                <label htmlFor="payout-field-2">Account Number</label>
                                <input id="payout-field-2"
                                    type="text"
                                    value={payoutForm.accountNumber}
                                    onChange={(e) => setPayoutForm({ ...payoutForm, accountNumber: e.target.value })}
                                    placeholder="10-digit account number"
                                    pattern="[0-9]{10}"
                                    required
                                />
                            </div>
                            <div className={styles.field}>
                                <label htmlFor="payout-field-3">Bank Name</label>
                                <input id="payout-field-3"
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
                    <div ref={celebrationRef} role="dialog" aria-modal="true" aria-label="Referral milestone reached" tabIndex={-1} className={`${styles.celebrationCard} ${celebrationTier === 100 ? styles.eliteCard : ''}`}>
                        <div className={styles.trophyIcon}>
                            <i aria-hidden="true" className={`fas ${celebrationTier === 100 ? 'fa-crown' : 'fa-trophy'}`}></i>
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

            <ImpactLiveFeed />
            <GlobalToast />

            {/* Rank Up Celebration Popup */}
            {showRankUp && !showCelebration && (
                <div className={styles.celebrationOverlay} onClick={handleCloseRankUp}>
                    <div ref={rankRef} role="dialog" aria-modal="true" aria-label="Rank achievement" tabIndex={-1} className={styles.celebrationCard} onClick={(e) => e.stopPropagation()}>
                        <div className={styles.trophyIcon}>
                            <i aria-hidden="true" className={`fas ${showRankUp.icon}`}></i>
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

                        <button className={styles.closeCelebrationBtn} aria-label="Close achievement" onClick={handleCloseRankUp}>
                            <i aria-hidden="true" className="fas fa-times"></i>
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
