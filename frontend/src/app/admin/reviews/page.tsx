'use client';

import { useState, useEffect, useCallback } from 'react';
import styles from './AdminReviews.module.css';
import { Review } from '@/app/api/reviews/route';
import { manageReviews } from '@/lib/reviews';

export default function AdminReviewsPage() {
    const [reviews, setReviews] = useState<Review[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    const fetchAllReviewsForAdmin = useCallback(async () => {
        setIsLoading(true);
        try {
            const data = await manageReviews('FETCH', { admin: true });
            setReviews(data);
        } catch (error) {
            console.error('Failed to fetch reviews:', error);
        } finally {
            setIsLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchAllReviewsForAdmin();
    }, [fetchAllReviewsForAdmin]);

    const adminModerateReview = async (id: string, newStatus: 'approved' | 'rejected') => {
        const token = localStorage.getItem('enchiridion_token');
        try {
            const res = await fetch('/api/reviews', {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({ id, status: newStatus }),
            });

            if (res.ok) {
                // Update local state for immediate feedback (Live Sync)
                setReviews((prev) =>
                    prev.map((r) => (r.id === id ? { ...r, status: newStatus } : r))
                );
            }
        } catch (error) {
            console.error('Failed to moderate review:', error);
        }
    };

    const getStatusBadge = (status: string) => {
        switch (status) {
            case 'approved': return <span className={styles.badgeApproved}>APPROVED</span>;
            case 'rejected': return <span className={styles.badgeRejected}>REJECTED</span>;
            default: return <span className={styles.badgePending}>PENDING</span>;
        }
    };

    return (
        <div className={styles.container}>
            <header className={styles.header}>
                <div className={styles.headerTop}>
                    <h1>Review Moderation Dashboard</h1>
                    <button onClick={fetchAllReviewsForAdmin} className={styles.refreshBtn} disabled={isLoading}>
                        {isLoading ? 'Refreshing...' : 'Refresh Reviews'}
                    </button>
                </div>
                <p>Strict Validation Mode: Audit and moderate community testimonials.</p>
            </header>

            <section className={styles.section}>
                <div className={styles.tableWrapper}>
                    <table className={styles.table}>
                        <thead>
                            <tr>
                                <th>Date</th>
                                <th>Reviewer</th>
                                <th>Rating</th>
                                <th>Content</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {reviews.length === 0 && !isLoading ? (
                                <tr>
                                    <td colSpan={6} className={styles.emptyRow}>No reviews found in the system.</td>
                                </tr>
                            ) : (
                                reviews.map((review) => (
                                    <tr key={review.id}>
                                        <td className={styles.dateCol}>
                                            {new Date(review.createdAt).toLocaleDateString()}
                                        </td>
                                        <td className={styles.authorCol}>
                                            <strong>{review.name}</strong>
                                            <div className={styles.jobTitle}>{review.jobTitle}</div>
                                        </td>
                                        <td className={styles.ratingCol}>
                                            {review.rating} ★
                                        </td>
                                        <td className={styles.textCol}>
                                            <div className={styles.reviewSnippet} title={review.text}>
                                                "{review.text}"
                                            </div>
                                        </td>
                                        <td className={styles.statusCol}>
                                            {getStatusBadge(review.status)}
                                        </td>
                                        <td className={styles.actionsCol}>
                                            {review.status === 'pending' ? (
                                                <div className={styles.btnGroup}>
                                                    <button
                                                        onClick={() => adminModerateReview(review.id, 'approved')}
                                                        className={styles.approveBtn}
                                                    >
                                                        Approve
                                                    </button>
                                                    <button
                                                        onClick={() => adminModerateReview(review.id, 'rejected')}
                                                        className={styles.rejectBtn}
                                                    >
                                                        Reject
                                                    </button>
                                                </div>
                                            ) : (
                                                <button
                                                    onClick={() => adminModerateReview(review.id, review.status === 'approved' ? 'rejected' : 'approved')}
                                                    className={styles.undoBtn}
                                                >
                                                    {review.status === 'approved' ? 'Reject' : 'Approve'}
                                                </button>
                                            )}
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </section>
        </div>
    );
}
