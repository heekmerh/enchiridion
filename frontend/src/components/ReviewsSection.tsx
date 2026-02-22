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
    const [showForm, setShowForm] = useState(false);
    const carouselRef = useRef<HTMLDivElement>(null);
    const autoPlayRef = useRef<NodeJS.Timeout | null>(null);

    const fetchReviews = async () => {
        try {
            const data = await manageReviews('FETCH', { limit: 5 });
            setReviews(data);
        } catch (error) {
            console.error('Failed to fetch reviews:', error);
        } finally {
            setIsLoading(false);
        }
    };

    useEffect(() => {
        fetchReviews();
    }, []);

    // Auto-play logic
    useEffect(() => {
        if (reviews.length > 1) {
            startAutoPlay();
        }
        return () => stopAutoPlay();
    }, [reviews]);

    const startAutoPlay = () => {
        stopAutoPlay();
        autoPlayRef.current = setInterval(() => {
            if (carouselRef.current) {
                const { scrollLeft, scrollWidth, clientWidth } = carouselRef.current;
                const maxScroll = scrollWidth - clientWidth;

                if (scrollLeft >= maxScroll - 10) {
                    carouselRef.current.scrollTo({ left: 0, behavior: 'smooth' });
                } else {
                    carouselRef.current.scrollBy({ left: clientWidth, behavior: 'smooth' });
                }
            }
        }, 5000);
    };

    const stopAutoPlay = () => {
        if (autoPlayRef.current) {
            clearInterval(autoPlayRef.current);
        }
    };

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
                            ) : reviews.length === 0 ? (
                                <div className={styles.emptyState}>
                                    <p>No reviews yet. Be the first to share your experience!</p>
                                </div>
                            ) : (
                                <div className={styles.carouselContainer}
                                    onMouseEnter={stopAutoPlay}
                                    onMouseLeave={startAutoPlay}>
                                    <div className={styles.carousel} ref={carouselRef}>
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
