'use client';

import { useState, useEffect } from 'react';
import styles from './AdminReviews.module.css';
import { Review } from '@/app/api/reviews/route';

export default function AdminReviewsPage() {
    const [reviews, setReviews] = useState<Review[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    // Fetch ALL reviews (admin mode)
    const fetchReviews = async () => {
        try {
            const res = await fetch('/api/reviews?admin=true');
            if (res.ok) {
                const data = await res.json();
                setReviews(data);
            }
        } catch (error) {
            console.error('Failed to fetch reviews:', error);
        } finally {
            setIsLoading(false);
        }
    };

    useEffect(() => {
        fetchReviews();
    }, []);

    const handleModerate = async (id: string, newStatus: 'approved' | 'rejected') => {
        try {
            const res = await fetch('/api/reviews', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id, status: newStatus }),
            });

            if (res.ok) {
                const updatedReview = await res.json();
                setReviews((prev) =>
                    prev.map((r) => (r.id === id ? { ...r, status: newStatus } : r))
                );
            }
        } catch (error) {
            console.error('Failed to update status:', error);
        }
    };

    const pendingReviews = reviews.filter((r) => r.status === 'pending');
    const moderatedReviews = reviews.filter((r) => r.status !== 'pending');

    return (
        <div className={styles.container}>
            <header className={styles.header}>
                <h1>Review Moderation Dashboard</h1>
                <p>Approve or reject user submitted testimonials.</p>
            </header>

            <section className={styles.section}>
                <h2>Pending Reviews ({pendingReviews.length})</h2>
                {isLoading ? (
                    <p>Loading...</p>
                ) : pendingReviews.length === 0 ? (
                    <div className={styles.empty}>No pending reviews. Good job! 🎉</div>
                ) : (
                    <div className={styles.list}>
                        {pendingReviews.map((review) => (
                            <div key={review.id} className={styles.card}>
                                <div className={styles.cardHeader}>
                                    <span className={styles.rating}>★ {review.rating}</span>
                                    <span className={styles.date}>{new Date(review.createdAt).toLocaleDateString()}</span>
                                </div>
                                <div className={styles.author}>
                                    <strong>{review.name}</strong> • {review.jobTitle}
                                </div>
                                <p className={styles.text}>"{review.text}"</p>
                                <div className={styles.actions}>
                                    <button onClick={() => handleModerate(review.id, 'rejected')} className={styles.rejectBtn}>
                                        Reject
                                    </button>
                                    <button onClick={() => handleModerate(review.id, 'approved')} className={styles.approveBtn}>
                                        Approve
                                    </button>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </section>

            <section className={styles.section}>
                <h2>Moderated History</h2>
                <div className={styles.tableWrapper}>
                    <table className={styles.table}>
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Rating</th>
                                <th>Status</th>
                                <th>Date</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {moderatedReviews.map((review) => (
                                <tr key={review.id}>
                                    <td>{review.name}</td>
                                    <td>{review.rating} ★</td>
                                    <td>
                                        <span className={review.status === 'approved' ? styles.badgeApproved : styles.badgeRejected}>
                                            {review.status}
                                        </span>
                                    </td>
                                    <td>{new Date(review.createdAt).toLocaleDateString()}</td>
                                    <td>
                                        <button
                                            onClick={() => handleModerate(review.id, review.status === 'approved' ? 'rejected' : 'approved')}
                                            className={styles.smallBtn}
                                        >
                                            {review.status === 'approved' ? 'Reject' : 'Approve'}
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </section>
        </div>
    );
}
