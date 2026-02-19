"use client";

import { useState, useEffect } from "react";
import styles from "./Rewards.module.css";
import Link from "next/link";
import ReferralLeaderboard from "@/components/ReferralLeaderboard";
import PartnerSuccessGuideModal from "@/components/PartnerSuccessGuideModal";


export default function RewardsPage() {
    const [isTermsOpen, setIsTermsOpen] = useState(false);
    const [isGuideOpen, setIsGuideOpen] = useState(false);
    const [timeLeft, setTimeLeft] = useState({ months: 0, days: 0 });


    useEffect(() => {
        const calculateTimeLeft = () => {
            const now = new Date();
            const target = new Date(now.getFullYear(), 11, 30); // Dec 30th

            // If target has passed this year, set to next year
            if (now > target) {
                target.setFullYear(now.getFullYear() + 1);
            }

            const diff = target.getTime() - now.getTime();

            const months = Math.floor(diff / (1000 * 60 * 60 * 24 * 30.44));
            const days = Math.floor((diff % (1000 * 60 * 60 * 24 * 30.44)) / (1000 * 60 * 60 * 24));

            setTimeLeft({ months, days });
        };

        calculateTimeLeft();
        const timer = setInterval(calculateTimeLeft, 1000 * 60 * 60); // Update hourly
        return () => clearInterval(timer);
    }, []);

    return (
        <div className={styles.rewardsPage}>
            {/* Decorative Background Elements */}
            <div className={`${styles.blob} ${styles.blob1}`}></div>
            <div className={`${styles.blob} ${styles.blob2}`}></div>
            <div className={`${styles.blob} ${styles.blob3}`}></div>

            <div className={styles.container}>

                {/* Leaderboard Podium */}
                <section className={styles.leaderboardSection}>
                    <h2>Can You Top the Ranks?</h2>
                    <div className={styles.podium}>
                        {/* 2nd Place - SILVER */}
                        <div className={`${styles.podiumSpot} ${styles.secondSpot}`}>
                            <div className={styles.spotlight}></div>
                            <div className={styles.pentagonFrame}>
                                <div className={styles.pentagonInner}>
                                    <i className="fas fa-stethoscope"></i>
                                </div>
                                <div className={styles.rankBadge}>2</div>
                            </div>
                            <div className={styles.rankInfo}>
                                <span className={styles.rankTitle}>Silver</span>
                            </div>
                            <div className={styles.podiumPillar}></div>
                        </div>

                        {/* 1st Place - GOLD (Front) */}
                        <div className={`${styles.podiumSpot} ${styles.firstSpot}`}>
                            <div className={styles.spotlight}></div>
                            <div className={styles.pentagonFrame}>
                                <div className={styles.pentagonInner} style={{ color: '#fbbf24' }}>
                                    <i className="fas fa-money-bill-wave"></i>
                                </div>
                                <div className={styles.rankBadge}>1</div>
                            </div>
                            <div className={styles.rankInfo}>
                                <span className={styles.rankTitle}>Gold</span>
                            </div>
                            <div className={styles.podiumPillar}></div>
                        </div>

                        {/* 3rd Place - BRONZE */}
                        <div className={`${styles.podiumSpot} ${styles.thirdSpot}`}>
                            <div className={styles.spotlight}></div>
                            <div className={styles.pentagonFrame}>
                                <div className={styles.pentagonInner}>
                                    <i className="fas fa-book-medical"></i>
                                </div>
                                <div className={styles.rankBadge}>3</div>
                            </div>
                            <div className={styles.rankInfo}>
                                <span className={styles.rankTitle}>bronze</span>
                            </div>
                            <div className={styles.podiumPillar}></div>
                        </div>
                    </div>
                    <p style={{ fontSize: '1.2rem', color: '#64748b', fontWeight: 600 }}>
                        Current leading users are tracked via the app based on questions answered correctly. Climb the ranks today!
                    </p>
                    <div className={styles.podiumIllustration}>
                        <img src="/images/climb-ranks.png" alt="Climbing the ranks" className={styles.climbImage} />
                    </div>
                </section>

                {/* Referral Leaderboard Section */}
                <ReferralLeaderboard />

                {/* Prize Hero Section */}
                <header className={styles.prizeHero}>
                    <h1 className={styles.prizeWelcome}>Download the App, Climb the Ranks, and Win!</h1>

                    <div className={styles.countdownContainer}>
                        <div className={styles.countdownItem}>
                            <span className={styles.countNumber}>{timeLeft.months}</span>
                            <span className={styles.countLabel}>Months</span>
                        </div>
                        <div className={styles.countdownItem}>
                            <span className={styles.countNumber}>{timeLeft.days}</span>
                            <span className={styles.countLabel}>Days</span>
                        </div>
                    </div>

                    <div className={styles.actionRow}>
                        <div className={styles.downloadIcon}>
                            <i className="fas fa-rocket"></i>
                        </div>
                        <Link href="/download" className={styles.referralBtn}>
                            <i className="fas fa-cloud-download-alt" style={{ marginRight: '10px' }}></i>
                            Download App Now
                        </Link>
                        <p style={{ opacity: 0.9, fontWeight: 600 }}>
                            <i className="fas fa-bullhorn" style={{ marginRight: '8px' }}></i>
                            Winners will be emailed directly when the contest ends.
                        </p>
                    </div>
                </header>

                {/* Educational Info */}
                <section className={styles.infoSection}>
                    <div style={{ fontSize: '4rem', marginBottom: '25px', color: '#14b8a6' }}>
                        <i className="fas fa-user-graduate"></i>
                    </div>
                    <h3>Prepare for Your Licensing Exams</h3>
                    <p style={{ fontSize: '1.2rem', color: '#475569', maxWidth: '700px', margin: '0 auto 30px' }}>
                        Questions are curated from major clinical exams worldwide. Prepare for your licensing exams and primaries while competing for rewards.
                    </p>
                    <div className={styles.examTags}>
                        {['UKMLA', 'MCCQE', 'USMLE', 'NAC', 'AMC', 'NExT', 'PRES', 'MRCP', 'NZREX', 'MDCN'].map(tag => (
                            <span key={tag} className={styles.examTag}>{tag}</span>
                        ))}
                    </div>
                    <p style={{ color: '#312e81', fontWeight: 800, fontSize: '1.2rem' }}>
                        <i className="fas fa-heart" style={{ color: '#ef4444', marginRight: '8px' }}></i>
                        "This is our way of giving back while helping you achieve your dreams."
                    </p>

                    <div style={{ marginTop: '50px', display: 'flex', flexDirection: 'column', gap: '20px', alignItems: 'center' }}>
                        <Link href="/refer" className={`${styles.referralBtn} ${styles.secondaryBtn}`}>
                            <i className="fas fa-share-alt" style={{ marginRight: '10px' }}></i>
                            Tell Friends & Earn Referral Points
                        </Link>

                        <button
                            onClick={() => setIsGuideOpen(true)}
                            className={styles.guideCard}
                        >
                            <div className={styles.guideIcon}>
                                <i className="fas fa-book-reader"></i>
                            </div>
                            <div className={styles.guideText}>
                                <h4>New to the program?</h4>
                                <p>View the Partner Success Guide & Handbook</p>
                            </div>
                            <i className="fas fa-external-link-alt"></i>
                        </button>
                    </div>

                </section>

                {/* Legacy Content (Moved Below) */}
                <section className={styles.section}>
                    <h2>Why Join the Program?</h2>
                    <div className={styles.rulesGrid}>
                        <div className={styles.ruleItem}>
                            <h3>Professional Growth</h3>
                            <p>Position yourself as a thought leader in medical education and digital health advocacy.</p>
                        </div>
                        <div className={styles.ruleItem}>
                            <h3>Impactful Sharing</h3>
                            <p>Every referral helps a fellow clinician or student access reliable, quick-reference specialty books.</p>
                        </div>
                        <div className={styles.ruleItem}>
                            <h3>Lucrative Rewards</h3>
                            <p>Earn points for every visit, signup, and sale. Our points have direct Naira value for local partners.</p>
                        </div>
                    </div>
                </section>

                {/* Collapsible Terms Section */}
                <div className={styles.accordion}>
                    <button
                        className={styles.accordionHeader}
                        onClick={() => setIsTermsOpen(!isTermsOpen)}
                    >
                        <h2>Account & Payout Rules</h2>
                        <i className={`fas fa-chevron-down ${styles.chevron} ${isTermsOpen ? styles.chevronOpen : ""}`}></i>
                    </button>

                    <div className={`${styles.accordionContent} ${isTermsOpen ? styles.contentOpen : ""}`}>
                        <div className={styles.termsList}>
                            <div className={styles.termsSection}>
                                <h3>1. Earning Points</h3>
                                <ul>
                                    <li><b>Browsing:</b> Earn 0.1 points (₦10) for every unique visitor who browses the site via your link.</li>
                                    <li><b>Registration:</b> Earn 0.1 points (₦10) for every user who registers as a referral partner using your link.</li>
                                    <li><b>Book Sales:</b> Earn 5.0 points (₦500) for every book purchased by a user you referred.</li>
                                </ul>
                            </div>

                            <div className={styles.termsSection}>
                                <h3>2. Conversions & Payouts</h3>
                                <ul>
                                    <li>Points are pegged to book sales: 1 point is equivalent to 1% of a standard book sale (₦100).</li>
                                    <li>The current conversion rate is <b>1 Point = ₦100</b>.</li>
                                    <li>Payouts are processed to the bank account details provided in your "Payout Settings".</li>
                                </ul>
                            </div>

                            <div className={styles.termsSection}>
                                <h3>3. Tracking</h3>
                                <ul>
                                    <li>Activity is logged immediately upon the user's action.</li>
                                    <li>Self-referrals or fraudulent activity will result in the suspension of the partner account.</li>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>

                <PartnerSuccessGuideModal
                    isOpen={isGuideOpen}
                    onClose={() => setIsGuideOpen(false)}
                />
            </div>
        </div>

    );
}
