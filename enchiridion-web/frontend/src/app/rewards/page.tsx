"use client";

import { useState, useEffect } from "react";
import styles from "./Rewards.module.css";
import Link from "next/link";
import NextImage from "next/image";
import ReferralLeaderboard from "@/components/ReferralLeaderboard";
import PartnerSuccessGuideModal from "@/components/PartnerSuccessGuideModal";
import GlobalToast from "@/components/GlobalToast";
import MastersGallery from "@/components/MastersGallery";


export default function RewardsPage() {
    const [isTermsOpen, setIsTermsOpen] = useState(false);
    const [isGuideOpen, setIsGuideOpen] = useState(false);
    const [isRedemptionOpen, setIsRedemptionOpen] = useState(false);
    const [timeLeft, setTimeLeft] = useState({ months: 0, days: 0 });


    useEffect(() => {
        const calculateTimeLeft = () => {
            const now = new Date();
            const target = new Date(2027, 11, 30); // Dec 30th, 2027

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

                {/* App Rankings Podium */}
                <h2 className={styles.podiumTitle}>Can You Top the Ranks?</h2>
                <section className={styles.leaderboardSection}>
                    <div className={styles.podiumImageContainer}>
                        <img
                            src="/rewards-podium.png"
                            alt="Grand Prizes Podium"
                            className={styles.podiumImage}
                        />
                    </div>

                    {/* Prize description grid - Glass cards */}
                    <div className={styles.prizeDescriptionGrid}>
                        {/* 1st Place - Gold */}
                        <div className={`${styles.prizeGlassCard} ${styles.goldTheme}`}>
                            <div className={styles.prizeIcon}>
                                <i aria-hidden="true" className="fas fa-coins"></i>
                            </div>
                            <h3 className="serif">The Grand Master</h3>
                            <p className={styles.prizeDesc}>
                                $100 Cash Prize. Direct bank transfer to your 'Payout Settings' account. Use your influence to take the top spot.
                            </p>
                        </div>

                        {/* 2nd Place - Silver */}
                        <div className={`${styles.prizeGlassCard} ${styles.silverTheme}`}>
                            <div className={styles.prizeIcon}>
                                <i aria-hidden="true" className="fas fa-stethoscope"></i>
                            </div>
                            <h3 className="serif">The Elite Champ</h3>
                            <p className={styles.prizeDesc}>
                                Medical Excellence Pack. 1-year premium Enchiridion App subscription plus essential medical equipment shipped to your door.
                            </p>
                        </div>

                        {/* 3rd Place - Bronze */}
                        <div className={`${styles.prizeGlassCard} ${styles.bronzeTheme}`}>
                            <div className={styles.prizeIcon}>
                                <i aria-hidden="true" className="fas fa-book-open"></i>
                            </div>
                            <h3 className="serif">The Rising Star</h3>
                            <p className={styles.prizeDesc}>
                                The Scholar’s Choice. Select any physical Enchiridion textbook from our catalog to add to your professional library.
                            </p>
                        </div>
                    </div>

                    <div className={styles.prizeCTAWrapper}>
                        <Link href="#referral-link-section" className={styles.prizeCTA}>
                            Download the App & Win
                            <i aria-hidden="true" className="fas fa-arrow-right"></i>
                        </Link>
                    </div>

                    {/* Prize Redemption Rules Accordion */}
                    <button
                        aria-expanded={isRedemptionOpen} aria-controls="prize-redemption-rules" className={styles.redemptionToggle}
                        onClick={() => setIsRedemptionOpen(!isRedemptionOpen)}
                    >
                        View Prize Redemption Rules
                        <i aria-hidden="true" className={`fas fa-chevron-down ${styles.redemptionChevron} ${isRedemptionOpen ? styles.redemptionChevronOpen : ""}`}></i>
                    </button>

                    <div id="prize-redemption-rules" hidden={!isRedemptionOpen} className={`${styles.redemptionWrapper} ${isRedemptionOpen ? styles.redemptionWrapperOpen : ""}`}>
                        <div className={styles.redemptionGrid}>
                            <div className={styles.redemptionItem}>
                                <h3>Eligibility</h3>
                                <p>Prizes are awarded to the top 3 ranked winners at the end of the competition period. Fraudulent activity will result in immediate disqualification.</p>
                            </div>
                            <div className={styles.redemptionItem}>
                                <h3>Cash Payouts</h3>
                                <p>The $100 Gold Prize will be converted to ₦ at the prevailing market rate and sent to the bank details provided by the winner.</p>
                            </div>
                            <div className={styles.redemptionItem}>
                                <h3>Physical Prizes</h3>
                                <p>Silver and Bronze physical prizes (Medical Equipment/Books) will be shipped within 14 business days of verification. Shipping is restricted to Nigeria.</p>
                            </div>
                            <div className={styles.redemptionItem}>
                                <h3>Sub-Verification</h3>
                                <p>App subscriptions for the Silver prize will be activated via the winner's registered email address.</p>
                            </div>
                        </div>
                    </div>
                </section>

                <div id="referral-link-section">
                    <ReferralLeaderboard />
                </div>

                {/* THE PANTHEON - LEGACY WALL */}
                <div id="pantheon">
                    <MastersGallery />
                </div>

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
                            <i aria-hidden="true" className="fas fa-rocket"></i>
                        </div>
                        <Link href="/#app" className={styles.referralBtn}>
                            <i aria-hidden="true" className="fas fa-cloud-download-alt" style={{ marginRight: '10px' }}></i>
                            Download App Now
                        </Link>
                        <p style={{ opacity: 0.9, fontWeight: 600 }}>
                            <i aria-hidden="true" className="fas fa-bullhorn" style={{ marginRight: '8px' }}></i>
                            Winners will be emailed directly when the contest ends.
                        </p>
                    </div>
                </header>

                {/* Educational Info */}
                <section className={styles.infoSection}>
                    <div style={{ fontSize: '4rem', marginBottom: '25px', color: '#14b8a6' }}>
                        <i aria-hidden="true" className="fas fa-user-graduate"></i>
                    </div>
                    <h2>Prepare for Your Licensing Exams</h2>
                    <p style={{ fontSize: '1.2rem', color: '#475569', maxWidth: '700px', margin: '0 auto 30px' }}>
                        Questions are curated from major clinical exams worldwide. Prepare for your licensing exams and primaries while competing for rewards.
                    </p>
                    <div className={styles.examTags}>
                        {['UKMLA', 'MCCQE', 'USMLE', 'NAC', 'AMC', 'NExT', 'PRES', 'MRCP', 'NZREX', 'MDCN'].map(tag => (
                            <span key={tag} className={styles.examTag}>{tag}</span>
                        ))}
                    </div>
                    <p style={{ color: '#312e81', fontWeight: 800, fontSize: '1.2rem' }}>
                        <i aria-hidden="true" className="fas fa-heart" style={{ color: '#ef4444', marginRight: '8px' }}></i>
                        "This is our way of giving back while helping you achieve your dreams."
                    </p>

                    <div style={{ marginTop: '50px', display: 'flex', flexDirection: 'column', gap: '20px', alignItems: 'center' }}>
                        <Link href="/refer" className={`${styles.referralBtn} ${styles.secondaryBtn}`}>
                            <i aria-hidden="true" className="fas fa-share-alt" style={{ marginRight: '10px' }}></i>
                            Tell Friends & Earn Referral Points
                        </Link>

                        <button
                            onClick={() => setIsGuideOpen(true)}
                            className={styles.guideCard}
                        >
                            <div className={styles.guideIcon}>
                                <i aria-hidden="true" className="fas fa-book-reader"></i>
                            </div>
                            <div className={styles.guideText}>
                                <h3>New to the program?</h3>
                                <p>View the Partner Success Guide & Handbook</p>
                            </div>
                            <i aria-hidden="true" className="fas fa-external-link-alt"></i>
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
                        aria-expanded={isTermsOpen} aria-controls="account-payout-rules" className={styles.accordionHeader}
                        onClick={() => setIsTermsOpen(!isTermsOpen)}
                    >
                        <h2>Account & Payout Rules</h2>
                        <i aria-hidden="true" className={`fas fa-chevron-down ${styles.chevron} ${isTermsOpen ? styles.chevronOpen : ""}`}></i>
                    </button>

                    <div id="account-payout-rules" hidden={!isTermsOpen} className={`${styles.accordionContent} ${isTermsOpen ? styles.contentOpen : ""}`}>
                        <div className={styles.termsList}>
                            <div className={styles.termsSection}>
                                <h3>1. Becoming a Referral Partner</h3>
                                <ul>
                                    <li>To activate your Referral Partner account, you must submit <b>one review video</b> of the Enchiridion app or an Enchiridion handbook. The video should be a genuine, first-person review of your experience using the product.</li>
                                    <li>Your referral code and dashboard access are provisional until this review video is submitted and approved. Enchiridion may request a reasonable resubmission if the video does not meet basic quality or authenticity standards.</li>
                                </ul>
                            </div>

                            <div className={styles.termsSection}>
                                <h3>2. Partner Earnings</h3>
                                <ul>
                                    <li>You earn <b>20% commission</b> on app subscription payments made by any user who subscribes using your referral code.</li>
                                    <li>You earn <b>20% commission</b> on book purchases made using your referral code.</li>
                                    <li>Commissions are calculated on amounts actually collected by Enchiridion, net of refunds, chargebacks, or failed payments.</li>
                                    <li>In addition to commissions, you are paid per view your submitted review video garners on your social media platforms (e.g. Instagram, TikTok). View-based pay rates, eligible platforms, and payout terms are not fixed and are determined by a separate agreement between you and Enchiridion.</li>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>

                <PartnerSuccessGuideModal
                    isOpen={isGuideOpen}
                    onClose={() => setIsGuideOpen(false)}
                />


                <GlobalToast />
            </div>
        </div>

    );
}
