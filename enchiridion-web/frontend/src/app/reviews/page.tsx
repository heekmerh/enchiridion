'use client';

import { useRef, useState } from 'react';
import ReviewForm from '@/components/ReviewForm';
import ReviewsFeed from '@/components/ReviewsFeed';
import styles from './ReviewsPage.module.css';

export default function ReviewsPage() {
    const [reviewVersion, setReviewVersion] = useState(0);
    const [isFormOpen, setIsFormOpen] = useState(false);

    const triggerRef = useRef<HTMLButtonElement>(null);
    const closeForm = () => {
        setIsFormOpen(false);
        requestAnimationFrame(() => triggerRef.current?.focus());
    };

    const handleReviewSubmitted = () => {
        closeForm();
        setReviewVersion(version => version + 1);
    };

    return (
        <div className={styles.main}>

            <section className={styles.hero}>
                <div className={styles.container}>
                    <h1>Reviews & Feedback</h1>
                    <p>Hear from the medical professionals using Enchiridion to transform clinical practice.</p>
                </div>
            </section>

            <section className={styles.formSection}>
                <div className={styles.container}>
                    <button ref={triggerRef}
                        onClick={() => setIsFormOpen(!isFormOpen)}
                        aria-expanded={isFormOpen}
                        aria-controls="review-form-panel"
                        className={styles.writeBtn}
                    >
                        {isFormOpen ? 'Close Form' : 'Write a Review'}
                    </button>

                    <div id="review-form-panel" hidden={!isFormOpen} className={`${styles.formDropdown} ${isFormOpen ? styles.formOpen : ""}`}>
                        <div className={styles.formWrapper}>
                            <ReviewForm key={reviewVersion}
                                onReviewSubmitted={handleReviewSubmitted}
                                onCancel={closeForm}
                            />
                        </div>
                    </div>
                </div>
            </section>

            <section className={styles.feedSection}>
                <div className={styles.container}>
                    <h2 className={styles.sectionTitle}>Community Feedback</h2>
                    <ReviewsFeed key={reviewVersion} />
                </div>
            </section>

        </div>
    );
}
