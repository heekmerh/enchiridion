"use client";

import styles from "./PartnerSuccessGuideModal.module.css";

interface PartnerSuccessGuideModalProps {
    isOpen: boolean;
    onClose: () => void;
}

export default function PartnerSuccessGuideModal({ isOpen, onClose }: PartnerSuccessGuideModalProps) {
    if (!isOpen) return null;

    return (
        <div className={styles.overlay} onClick={onClose}>
            <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
                <button className={styles.closeBtn} onClick={onClose} aria-label="Close modal">
                    <i className="fas fa-times"></i>
                </button>

                <div className={styles.header}>
                    <h2>Enchiridion Partner Success Guide</h2>
                    <p>Turn Your Medical Network into Rewards!</p>
                </div>

                <div className={styles.content}>
                    <div className={styles.section}>
                        <h3>1. Getting Started</h3>
                        <p><b>Your Unique Link:</b> Access your dashboard to find your custom referral link. This link is your 'digital ID'—whenever someone clicks it, our system tracks them for 30 days.</p>
                        <div className={styles.mathHighlight}>
                            The Math: Every 1 Point = ₦100. Your goal is to reach the ₦5,000 payout threshold.
                        </div>
                    </div>

                    <div className={styles.section}>
                        <h3>2. How to Earn Fast</h3>
                        <ul>
                            <li><b>The 'Quick Tap' (0.1 Points / ₦10):</b> Share your link in medical study groups or on your WhatsApp status. You earn every time a unique colleague simply browses our site.</li>
                            <li><b>Building a Network (0.1 Points / ₦10):</b> Encourage others to join the Partner Network. When they register as a partner through your link, you get rewarded instantly.</li>
                            <li><b>The Big Win (5.0 Points / ₦500):</b> When a referred colleague purchases an Enchiridion book, you earn a high-value commission.</li>
                        </ul>
                    </div>

                    <div className={styles.section}>
                        <h3>3. Pro-Tips for Maximum Impact</h3>
                        <ul>
                            <li><b>Focus on Exams:</b> Mention that our app and books cover UKMLA, USMLE, and MCCQE. Targeting students during exam season is the fastest way to drive book sales.</li>
                            <li><b>Climb the Leaderboard:</b> Check the 'Rewards' tab to see where you stand. Top rankers don't just get points; they gain prestige in the Enchiridion community.</li>
                            <li><b>Use the Share Buttons:</b> Don't manually copy-paste. Use the WhatsApp and Email buttons on your dashboard to send pre-formatted, professional messages.</li>
                        </ul>
                    </div>

                    <div className={styles.section}>
                        <h3>4. Payouts & Security</h3>
                        <ul>
                            <li>Ensure your bank details are correct in the 'Payout Settings' tab.</li>
                            <li>Payouts are processed at the end of the month once you hit the minimum milestone.</li>
                            <li><b>Note:</b> Self-referrals and fraudulent clicks are monitored and will lead to account suspension.</li>
                        </ul>
                    </div>
                </div>

                <div className={styles.footer}>
                    <p>"Helping you achieve your medical dreams while growing together."</p>
                </div>
            </div>
        </div>
    );
}
