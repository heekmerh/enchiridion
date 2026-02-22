'use client';

import { useState, useEffect } from 'react';
import styles from './ReviewsFeed.module.css';
import { Review } from '@/app/api/reviews/route';
import { manageReviews } from '@/lib/reviews';

export default function ReviewsFeed() {
    const [reviews, setReviews] = useState<Review[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [openId, setOpenId] = useState<string | null>(null);

    useEffect(() => {
        const fetchAll = async () => {
            try {
                const data = await manageReviews('FETCH');
                setReviews(data);
            } catch (error) {
                console.error('Failed to fetch reviews:', error);
            } finally {
                setIsLoading(false);
            }
        };
        fetchAll();
    }, []);

    const toggleAccordion = (id: string) => {
        setOpenId(openId === id ? null : id);
    };

    if (isLoading) return <div className={styles.loading}>Loading Community Feedback...</div>;

    if (reviews.length === 0) return <div className={styles.empty}>No feedback available yet.</div>;

    return (
        <div className={styles.feed}>
            {reviews.map((review) => (
                <div key={review.id} className={styles.row}>
                    <button
                        className={styles.header}
                        onClick={() => toggleAccordion(review.id)}
                        aria-expanded={openId === review.id}
                    >
                        <div className={styles.summary}>
                            <div className={styles.topLine}>
                                <span className={styles.reviewerName}>{review.name}</span>
                                <span className={styles.jobTitle}> • {review.jobTitle}</span>
                            </div>
                            <div className={styles.rating}>
                                {Array.from({ length: 5 }).map((_, i) => (
                                    <span key={i} className={i < review.rating ? styles.starFilled : styles.starEmpty}>
                                        ★
                                    </span>
                                ))}
                            </div>
                        </div>
                        <i className={`fas fa-chevron-down ${styles.chevron} ${openId === review.id ? styles.chevronOpen : ""}`}></i>
                    </button>

                    <div className={`${styles.contentWrapper} ${openId === review.id ? styles.contentOpen : ""}`}>
                        <div className={styles.content}>
                            {review.organization && (
                                <div className={styles.orgInfo}>
                                    <strong>Organization:</strong> {review.organization}
                                </div>
                            )}
                            <p className={styles.detailedText}>{review.text}</p>
                        </div>
                    </div>
                </div>
            ))}
        </div>
    );
}
