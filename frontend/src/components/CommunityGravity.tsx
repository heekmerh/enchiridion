"use client";

import styles from "./OnboardingChecklist.module.css";

export default function CommunityGravity() {
    return (
        <div className={styles.communityGravityCard}>
            <div className={styles.gravityIcon}>
                <i className="fas fa-users-rays"></i>
            </div>
            <div className={styles.gravityContent}>
                <h4>Community Gravity</h4>
                <p>
                    By completing your profiles, you help your referrer earn leadership bonuses.
                    Once you finish, <strong>you</strong> can invite others and earn those same bonuses yourself!
                </p>
            </div>
        </div>
    );
}
