'use client';

import { useState, useEffect, useRef } from 'react';
import styles from './ReviewsSection.module.css';
import ReviewForm from './ReviewForm';
import ReviewCard from './ReviewCard';
import { Review } from '@/app/api/reviews/route';
import { manageReviews } from '@/lib/reviews';
import { useContinuousMotion } from '@/hooks/useContinuousMotion';

export default function ReviewsSection() {
    const [reviews, setReviews] = useState<Review[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [loadError, setLoadError] = useState(false);
    const [showForm, setShowForm] = useState(false);
    const carouselRef = useRef<HTMLDivElement>(null);
    const motionEnabled = useContinuousMotion();
    const [interacting, setInteracting] = useState(false);

    useEffect(() => {
        if (!motionEnabled || interacting || showForm || reviews.length < 2) return;
        const timer = window.setInterval(() => {
            const carousel = carouselRef.current;
            if (!carousel) return;
            if (carousel.scrollLeft >= carousel.scrollWidth - carousel.clientWidth - 10) {
                carousel.scrollTo({ left: 0, behavior: 'smooth' });
            } else {
                carousel.scrollBy({ left: carousel.clientWidth, behavior: 'smooth' });
            }
        }, 5000);
        return () => window.clearInterval(timer);
    }, [motionEnabled, interacting, showForm, reviews.length]);

    const triggerRef = useRef<HTMLButtonElement>(null);
    const closeForm = () => {
        setShowForm(false);
        requestAnimationFrame(() => triggerRef.current?.focus());
    };

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
        closeForm();
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
                        <ReviewForm onReviewSubmitted={handleReviewSubmitted} onCancel={closeForm} />
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
                                <div className={styles.carouselContainer}
                                    onPointerEnter={() => setInteracting(true)}
                                    onPointerLeave={event => setInteracting(event.currentTarget.contains(document.activeElement))}
                                    onFocus={() => setInteracting(true)}
                                    onBlur={event => { if (!event.currentTarget.contains(event.relatedTarget)) setInteracting(event.currentTarget.matches(':hover')); }}>
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
                            <button ref={triggerRef} onClick={() => setShowForm(true)} className={styles.writeReviewBtn}>
                                Write a Review
                            </button>
                        </div>
                    </>
                )}
            </div>
        </section>
    );
}
