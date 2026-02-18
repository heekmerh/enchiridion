"use client";

import { useState } from "react";
import styles from "./Rewards.module.css";

export default function RewardsPage() {
    const [isTermsOpen, setIsTermsOpen] = useState(false);

    return (
        <div className={styles.rewardsPage}>
            <div className={styles.container}>
                <div className={styles.hero}>
                    <h1>Referral Rewards</h1>
                    <p>
                        Help clinicians discover the best medical resources and earn
                        recurring rewards for your impact.
                    </p>
                </div>

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
                                    <li>Referral links are cached in the user's browser. Activity is logged immediately upon the user's action.</li>
                                    <li>Self-referrals or fraudulent activity will result in the suspension of the partner account.</li>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
