'use client';

import { useState, useEffect, useRef } from 'react';
import styles from './ReviewsSection.module.css';
import ReviewForm from './ReviewForm';
import ReviewCard from './ReviewCard';
import { Review } from '@/app/api/reviews/route';
import { manageReviews } from '@/lib/reviews';

export default function ReviewsSection() {
    const [reviews, setReviews] = useState<Review[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [loadError, setLoadError] = useState(false);
    const [showForm, setShowForm] = useState(false);
    const carouselRef = useRef<HTMLDivElement>(null);

    const fetchReviews = async () => {
        try {
            const data = await manageReviews('FETCH', { limit: 5 });
            setReviews(data);
        } catch (error) {
            setLoadError(true);
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
        fetchReviews();
    };

    return (
        <section className={styles.section} id="user-reviews">
            <div className={styles.container}>
                <div className={styles.header}>
                    <h2>What Our Users Are Saying</h2>
                    <p>Verified feedback from medical professionals and students.</p>
                </div>

                {showForm ? (
                    <div className={styles.formContainer}>
                        <ReviewForm onReviewSubmitted={handleReviewSubmitted} onCancel={() => setShowForm(false)} />
                    </div>
                ) : (
                    <>
                        <div className={styles.contentArea}>
                            {isLoading ? (
                                <div className={styles.loading}>Loading reviews...</div>
                            ) : loadError ? (<p role="alert">Reviews are temporarily unavailable. Please try again later.</p>) : reviews.length === 0 ? (
                                <div className={styles.emptyState}>
                                    <p>No reviews yet. Be the first to share your experience!</p>
                                </div>
                            ) : (
                                <div className={styles.carouselContainer}>
                                    <div className={styles.carousel} ref={carouselRef} tabIndex={0} role="region" aria-label="User reviews">
                                        {reviews.map((review) => (
                                            <div key={review.id} className={styles.cardWrapper}>
                                                <ReviewCard review={review} />
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>

                        <div className={styles.footerActions}>
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
