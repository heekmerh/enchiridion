"use client";

import { useState, useEffect, useRef } from "react";
import styles from "./Dashboard.module.css";

export default function PartnerDashboard() {
    const [copied, setCopied] = useState(false);
    const [partnerData, setPartnerData] = useState({
        username: "Dr. Adebayo",
        refCode: "ADEBAYO2026",
        stats: {
            friendsReferred: 0,
            pointsEarned: 0,
            accruedRevenue: 0,
        },
        payout: {
            accountName: "",
            accountNumber: "",
            bankName: "",
            isSaved: false,
        },
    });

    const [payoutForm, setPayoutForm] = useState({
        accountName: "",
        accountNumber: "",
        bankName: "",
    });

    const [showCelebration, setShowCelebration] = useState(false);
    const prevPointsRef = useRef(partnerData.stats.pointsEarned);
    const revenueCardRef = useRef<HTMLDivElement>(null);

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

    const handlePayoutSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        // INTEGRATION: Save to Google Sheets
        setPartnerData({
            ...partnerData,
            payout: {
                ...payoutForm,
                isSaved: true,
            },
        });
    };

    useEffect(() => {
        const currentPoints = partnerData.stats.pointsEarned;
        const prevPoints = prevPointsRef.current;

        // Milestone logic: trigger if we cross a multiple of 50
        const currentMilestone = Math.floor(currentPoints / 50);
        const prevMilestone = Math.floor(prevPoints / 50);

        if (currentMilestone > prevMilestone && currentMilestone > 0) {
            setShowCelebration(true);
            setTimeout(() => setShowCelebration(false), 5000);
        }

        prevPointsRef.current = currentPoints;
    }, [partnerData.stats.pointsEarned]);

    const scrollToRevenue = () => {
        setShowCelebration(false);
        revenueCardRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    };

    // Helper to generate confetti particles
    const renderConfetti = () => {
        const colors = ["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff"];
        return Array.from({ length: 50 }).map((_, i) => (
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
                        <div className={styles.statValue}>{partnerData.stats.friendsReferred}</div>
                        <div className={styles.statLabel}>Friends Referred</div>
                        {partnerData.stats.friendsReferred === 0 && (
                            <p className={styles.emptyStateHint}>Start sharing your link to earn your first ₦500!</p>
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
                        <div className={styles.statLabel}>Accrued Revenue</div>
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
                        <div className={styles.progressHeader}>
                            <span className={styles.statLabel}>Next Payout Milestone: ₦5,000</span>
                            <span className={styles.statLabel}>{Math.round((partnerData.stats.accruedRevenue / 5000) * 100)}%</span>
                        </div>
                        <div className={styles.progressBar}>
                            <div
                                className={styles.progressFill}
                                style={{ width: `${Math.min((partnerData.stats.accruedRevenue / 5000) * 100, 100)}%` }}
                            ></div>
                        </div>
                        <div className={styles.progressTarget}>Earn ₦{Math.max(5000 - partnerData.stats.accruedRevenue, 0).toLocaleString()} more to reach your next payout!</div>
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
                <div className={styles.celebrationOverlay}>
                    {renderConfetti()}
                    <div className={styles.celebrationCard}>
                        <div className={styles.trophyIcon}>
                            <i className="fas fa-trophy"></i>
                        </div>
                        <h2>Milestone Reached! 🎉</h2>
                        <p>
                            Congratulations! You've just earned enough points for a ₦5,000 payout.
                            Your hard work is paying off!
                        </p>
                        <button className={styles.viewRevenueBtn} onClick={scrollToRevenue}>
                            View My Revenue
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
