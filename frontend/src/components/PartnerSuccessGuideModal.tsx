"use client";

import { useDialog } from "@/hooks/useDialog";
import styles from "./PartnerSuccessGuideModal.module.css";

interface PartnerSuccessGuideModalProps {
    isOpen: boolean;
    onClose: () => void;
}

export default function PartnerSuccessGuideModal({ isOpen, onClose }: PartnerSuccessGuideModalProps) {
    const dialogRef = useDialog(isOpen, onClose);
    if (!isOpen) return null;

    return (
        <div className={styles.overlay} onClick={onClose}>
            <div ref={dialogRef} role="dialog" aria-modal="true" aria-label="Partner success guide" tabIndex={-1} className={styles.modal} onClick={(e) => e.stopPropagation()}>
                <button className={styles.closeBtn} onClick={onClose} aria-label="Close modal">
                    <i aria-hidden="true" className="fas fa-times"></i>
                </button>

                <div className={styles.header}>
                    <h2>Enchiridion Partner Success Guide</h2>
                    <p>Turn Your Medical Network into Rewards!</p>
                </div>

                <div className={styles.content} role="region" aria-label="Partner handbook" tabIndex={0}>
                    <div className={styles.section}>
                        <h3>1. Getting Started</h3>
                        <p><b>Your Unique Link:</b> Access your dashboard to find your custom referral link and code. This is your 'digital ID'—any app subscription or book purchase made with it is attributed to you.</p>
                        <p><b>Activate Your Account:</b> Submit one genuine review video of the Enchiridion app or a handbook. Your code and dashboard stay provisional until it's approved.</p>
                        <div className={styles.mathHighlight}>
                            The Math: You earn 20% commission on every app subscription and book purchase made through your link — for up to 6 months per referred user.
                        </div>
                    </div>

                    <div className={styles.section}>
                        <h3>2. How to Earn</h3>
                        <ul>
                            <li><b>App Subscriptions (20% commission):</b> Every payment a referred user makes on their app subscription earns you 20%, for up to 6 months from their signup date.</li>
                            <li><b>Book Sales (20% commission):</b> Every Enchiridion handbook purchased through your link earns you 20% commission.</li>
                            <li><b>Review Video Payouts:</b> Beyond commissions, your submitted review video can earn additional per-view payouts on social media — rates and terms are agreed separately with Enchiridion.</li>
                        </ul>
                    </div>

                    <div className={styles.section}>
                        <h3>3. Pro-Tips for Maximum Impact</h3>
                        <ul>
                            <li><b>Focus on Exams:</b> Mention that our app and books cover UKMLA, USMLE, and MCCQE. Targeting students during exam season is the fastest way to drive book sales.</li>
                            <li><b>Sell the Discount:</b> Remind your network that your code gets them ₦500 off their first app subscription and 10% off their first book order.</li>
                            <li><b>Climb the Rankings:</b> Check the 'Rewards' tab to see where you stand. Top partners gain visibility and prestige in the Enchiridion community.</li>
                            <li><b>Use the Share Buttons:</b> Don't manually copy-paste. Use the WhatsApp and Email buttons on your dashboard to send pre-formatted, professional messages.</li>
                        </ul>
                    </div>

                    <div className={styles.section}>
                        <h3>4. Payouts & Security</h3>
                        <ul>
                            <li>Ensure your bank details are correct in the 'Payout Settings' tab.</li>
                            <li>Payouts follow the schedule shown in your Partner Dashboard.</li>
                            <li>Referral codes are personal and non-transferable — don't post them on coupon or deal sites.</li>
                            <li><b>Note:</b> Self-referrals and fraudulent activity are monitored and will lead to commission reversal or account suspension.</li>
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
