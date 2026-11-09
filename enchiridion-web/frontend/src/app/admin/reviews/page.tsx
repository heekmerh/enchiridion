'use client';

import { useState, useEffect, useCallback } from 'react';
import styles from './AdminReviews.module.css';
import { Review } from '@/app/api/reviews/route';
import { manageReviews } from '@/lib/reviews';
import { getAccessToken } from "@/lib/supabase";

export default function AdminReviewsPage() {
    const [reviews, setReviews] = useState<Review[]>([]);
    const [error, setError] = useState<string | null>(null);
    const [message, setMessage] = useState("");
    const [moderating, setModerating] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    const fetchAllReviewsForAdmin = useCallback(async () => {
        setIsLoading(true);
        setError(null);
        try {
            const data = await manageReviews('FETCH', { admin: true });
            setReviews(data);
        } catch (error) {
            setError("Reviews could not be loaded. Use Refresh Reviews to try again.");
        } finally {
            setIsLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchAllReviewsForAdmin();
    }, [fetchAllReviewsForAdmin]);

    const adminModerateReview = async (id: string, newStatus: 'approved' | 'rejected') => {
        setError(null);
        setMessage("");
        setModerating(id);
        try {
            const token = await getAccessToken();
            const res = await fetch('/api/reviews', {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({ id, status: newStatus }),
            });

            if (!res.ok) throw new Error("Moderation failed");
            if (res.ok) {
                setMessage(`Review by ${reviews.find(review => review.id === id)?.name ?? "reviewer"} ${newStatus}.`);
                requestAnimationFrame(() => document.getElementById(`moderation-${id}`)?.focus());
                // Update local state for immediate feedback (Live Sync)
                setReviews((prev) =>
                    prev.map((r) => (r.id === id ? { ...r, status: newStatus } : r))
                );
            }
        } catch (error) {
            setError("The review could not be updated. Please try again.");
        } finally {
            setModerating(null);
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

            {error && <p role="alert">{error}</p>}
            <p role="status">{isLoading ? "Loading reviews…" : message}</p>
            <section className={styles.section}>
                <div role="region" aria-label="Review moderation table" tabIndex={0} className={styles.tableWrapper}>
                    <table className={styles.table}>
                        <caption className="sr-only">Community reviews and moderation actions</caption>
                        <thead>
                            <tr>
                                <th scope="col">Date</th>
                                <th scope="col">Reviewer</th>
                                <th scope="col">Rating</th>
                                <th scope="col">Content</th>
                                <th scope="col">Status</th>
                                <th scope="col">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {reviews.length === 0 && !isLoading ? (
                                <tr>
                                    <td colSpan={6} className={styles.emptyRow}>No reviews found in the system.</td>
                                </tr>
                            ) : (
                                reviews.map((review) => (
                                    <tr key={review.id} id={`moderation-${review.id}`} tabIndex={-1}>
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
                                                        disabled={moderating !== null}
                                                        aria-label={`Approve review by ${review.name}`}
                                                        onClick={() => adminModerateReview(review.id, 'approved')}
                                                        className={styles.approveBtn}
                                                    >
                                                        Approve
                                                    </button>
                                                    <button
                                                        disabled={moderating !== null}
                                                        aria-label={`Reject review by ${review.name}`}
                                                        onClick={() => adminModerateReview(review.id, 'rejected')}
                                                        className={styles.rejectBtn}
                                                    >
                                                        Reject
                                                    </button>
                                                </div>
                                            ) : (
                                                <button
                                                    disabled={moderating !== null}
                                                        aria-label={`${review.status === "approved" ? "Reject" : "Approve"} review by ${review.name}`}
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
