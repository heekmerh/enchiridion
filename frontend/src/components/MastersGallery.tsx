import React, { useState, useEffect } from 'react';
import styles from './MastersGallery.module.css';

interface Master {
    username: string;
    soulsGuided: number;
    masteryDate: string;
    city: string;
    avatar: string;
}

const MasterCard: React.FC<{ master: Master }> = ({ master }) => {
    const formatDate = (dateString: string) => {
        if (!dateString) return 'Ancient Times';
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    };

    return (
        <div className={styles.masterCard}>
            <div className={styles.waxSeal}>
                <i className="fas fa-certificate"></i>
            </div>

            <div className={styles.avatarWrapper}>
                <img src={master.avatar} alt={master.username} className={styles.avatar} />
                <div className={styles.glowRing}></div>
            </div>

            <div className={styles.cardContent}>
                <h3 className={styles.username}>{master.username}</h3>
                <div className={styles.masterBadge}>
                    <i className="fas fa-crown"></i> ENCHIRIDION MASTER
                </div>

                <div className={styles.statsRow}>
                    <div className={styles.statItem}>
                        <label>Souls Guided</label>
                        <p>{master.soulsGuided}</p>
                    </div>
                    <div className={styles.statItem}>
                        <label>Location</label>
                        <p>{master.city}</p>
                    </div>
                </div>

                <div className={styles.masteryDate}>
                    Mastery attained: <span>{formatDate(master.masteryDate)}</span>
                </div>
            </div>
        </div>
    );
};

const MastersGallery: React.FC = () => {
    const [masters, setMasters] = useState<Master[]>([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('all');
    const [visibleCount, setVisibleCount] = useState(12);
    const [userCity, setUserCity] = useState<string | null>(null);

    useEffect(() => {
        const fetchMasters = async () => {
            try {
                const response = await fetch('/api/referral/masters');
                if (response.ok) {
                    const data = await response.json();
                    setMasters(data);
                }
            } catch (err) {
                console.error('Failed to fetch masters:', err);
            } finally {
                setLoading(false);
            }
        };

        const savedCity = localStorage.getItem('enchiridion_user_city');
        setUserCity(savedCity);
        fetchMasters();
    }, []);

    const filteredMasters = masters.filter(m => {
        if (filter === 'local' && userCity) {
            return m.city.toLowerCase().includes(userCity.toLowerCase());
        }
        return true;
    });

    const displayedMasters = filteredMasters.slice(0, visibleCount);

    if (loading) {
        return (
            <div className={styles.galleryLoading}>
                <div className={styles.spinner}></div>
                <p>Consulting the Records of Mastery...</p>
            </div>
        );
    }

    return (
        <section className={styles.pantheonSection}>
            <div className={styles.headerArea}>
                <h2 className={styles.cinematicTitle}>
                    The Enchiridion Legacy Wall
                    <span>Those Who Lead the Way</span>
                </h2>

                <div className={styles.filterBar}>
                    <button
                        className={`${styles.filterBtn} ${filter === 'all' ? styles.active : ''}`}
                        onClick={() => setFilter('all')}
                    >
                        All Masters
                    </button>
                    {userCity && (
                        <button
                            className={`${styles.filterBtn} ${filter === 'local' ? styles.active : ''}`}
                            onClick={() => setFilter('local')}
                        >
                            Masters from {userCity}
                        </button>
                    )}
                </div>
            </div>

            {displayedMasters.length > 0 ? (
                <div className={styles.mastersGrid}>
                    {displayedMasters.map((master, idx) => (
                        <MasterCard key={`${master.username}-${idx}`} master={master} />
                    ))}
                </div>
            ) : (
                <div className={styles.emptyPantheon}>
                    <i className="fas fa-hourglass-start"></i>
                    <p>The wall is waiting for the next legend from {userCity}.</p>
                </div>
            )}

            {visibleCount < filteredMasters.length && (
                <div className={styles.loadMoreArea}>
                    <button
                        className={styles.viewMoreBtn}
                        onClick={() => setVisibleCount(prev => prev + 12)}
                    >
                        View More Legends
                    </button>
                </div>
            )}

            <div className={styles.galleryFooter}>
                <p>Want your name here? Start your journey to Mastery today.</p>
                <button className={styles.ctaBtn} onClick={() => window.location.href = '/dashboard'}>
                    Begin My Legacy
                </button>
            </div>
        </section>
    );
};

export default MastersGallery;
