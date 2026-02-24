"use client";

import styles from "./SocialShareCard.module.css";

interface ShareCardProps {
    username: string;
    rank: "Sage" | "Master";
    soulsGuided: number;
    referralCode: string;
}

export default function SocialShareCard({ username, rank, soulsGuided, referralCode }: ShareCardProps) {
    const isMaster = rank === "Master";

    const shareText = isMaster
        ? `I just achieved Enchiridion Mastery! 🏆 ${soulsGuided} souls guided. Join the mission using my code: ${referralCode}`
        : `I've reached the rank of Enchiridion Sage! 🥈 Helping lead the community. Use my code: ${referralCode}`;

    // Encoded for sharing
    const whatsappUrl = `https://wa.me/?text=${encodeURIComponent(shareText)}`;

    return (
        <div className={styles.cardContainer}>
            <div className={styles.logo}>ENCHIRIDION</div>

            <div className={styles.badgeWrapper}>
                <i className={`fas ${isMaster ? "fa-crown" : "fa-medal"} ${styles.badgeIcon}`}></i>
            </div>

            <h2 className={styles.rankTitle}>{rank}</h2>
            <p className={styles.userName}>{username}</p>

            <div className={styles.statsGrid}>
                <div className={styles.statItem}>
                    <span>Souls Guided</span>
                    <strong>{soulsGuided}</strong>
                </div>
                <div className={styles.statItem}>
                    <span>Ref Code</span>
                    <strong>{referralCode}</strong>
                </div>
            </div>

            <div className={styles.shareButtons}>
                <a href={whatsappUrl} target="_blank" rel="noopener noreferrer" className={`${styles.shareBtn} ${styles.whatsapp}`}>
                    <i className="fab fa-whatsapp"></i> Share on WhatsApp
                </a>
                <button className={`${styles.shareBtn} ${styles.instagram}`} onClick={() => alert("Screenshot this card to share on Instagram!")}>
                    <i className="fab fa-instagram"></i> Share on IG
                </button>
            </div>

            <div className={styles.footer}>
                Verified Partner Since 2024
            </div>
        </div>
    );
}
