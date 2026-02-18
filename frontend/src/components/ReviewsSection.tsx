'use client';

import { useState, useEffect } from 'react';
import styles from './ReviewsSection.module.css';
import ReviewForm from './ReviewForm';
import ReviewCard from './ReviewCard';
import { Review } from '@/app/api/reviews/route';

export default function ReviewsSection() {
    const [reviews, setReviews] = useState<Review[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [showForm, setShowForm] = useState(false);
    const [page, setPage] = useState(1);
    const reviewsPerPage = 6;

    const fetchReviews = async () => {
        try {
            const res = await fetch('/api/reviews'); // Fetches only approved reviews
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

    const handleReviewSubmitted = () => {
        setShowForm(false);
        // Optionally refresh reviews here, though pending ones won't show yet.
    };

    const displayedReviews = reviews.slice(0, page * reviewsPerPage);
    const hasMore = reviews.length > displayedReviews.length;

    return (
        <section className={styles.section} id="user-reviews">
            <div className={styles.container}>
                <div className={styles.header}>
                    <h2>What Our Users Are Saying</h2>
                    <p>Verified feedback from medical professionals and students.</p>
                </div>

                {showForm ? (
                    <ReviewForm onReviewSubmitted={handleReviewSubmitted} onCancel={() => setShowForm(false)} />
                ) : (
                    <>
                        {isLoading ? (
                            <div className={styles.loading}>Loading reviews...</div>
                        ) : reviews.length === 0 ? (
                            <div className={styles.emptyState}>
                                <p>No reviews yet. Be the first to share your experience!</p>
                            </div>
                        ) : (
                            <div className={styles.grid}>
                                {displayedReviews.map((review) => (
                                    <ReviewCard key={review.id} review={review} />
                                ))}
                            </div>
                        )}

                        <div className={styles.footerActions}>
                            {hasMore && (
                                <button onClick={() => setPage((p) => p + 1)} className={styles.loadMoreBtn}>
                                    Load More
                                </button>
                            )}
                            <button onClick={() => setShowForm(true)} className={styles.writeReviewBtn}>
                                Write a Review
                            </button>
                        </div>
                    </>
                )}
            </div>
        </section>
    );
}
