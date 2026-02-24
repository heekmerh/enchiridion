import React from 'react';
import styles from './LegacyBadge.module.css';

interface LegacyBadgeProps {
    rank: 'Seeker' | 'Sage' | 'Master';
    showLabel?: boolean;
}

const LegacyBadge: React.FC<LegacyBadgeProps> = ({ rank, showLabel = true }) => {
    const getRankDetails = () => {
        switch (rank) {
            case 'Master':
                return {
                    icon: 'fa-crown',
                    color: '#D4AF37',
                    className: styles.master,
                    label: 'Enchiridion Master'
                };
            case 'Sage':
                return {
                    icon: 'fa-scroll',
                    color: '#94a3b8',
                    className: styles.sage,
                    label: 'Enchiridion Sage'
                };
            default:
                return {
                    icon: 'fa-seedling',
                    color: '#cd7f32',
                    className: styles.seeker,
                    label: 'Enchiridion Seeker'
                };
        }
    };

    const details = getRankDetails();

    return (
        <div className={`${styles.badgeContainer} ${details.className}`} title={details.label}>
            <div className={styles.iconWrapper}>
                <i className={`fas ${details.icon}`}></i>
                {rank === 'Master' && (
                    <div className={styles.verificationCheck}>
                        <i className="fas fa-check-circle"></i>
                    </div>
                )}
            </div>
            {showLabel && <span className={styles.rankLabel}>{details.label}</span>}
        </div>
    );
};

export default LegacyBadge;
