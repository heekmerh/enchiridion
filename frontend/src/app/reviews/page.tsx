'use client';

import { useState } from 'react';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import ReviewForm from '@/components/ReviewForm';
import ReviewsFeed from '@/components/ReviewsFeed';
import styles from './ReviewsPage.module.css';

export default function ReviewsPage() {
    const [isFormOpen, setIsFormOpen] = useState(false);

    const handleReviewSubmitted = () => {
        setIsFormOpen(false);
        // Refresh page or broadcast event
        window.location.reload();
    };

    return (
        <main className={styles.main}>
            <Header />

            <section className={styles.hero}>
                <div className={styles.container}>
                    <h1>Reviews & Feedback</h1>
                    <p>Hear from the medical professionals using Enchiridion to transform clinical practice.</p>
                </div>
            </section>

            <section className={styles.formSection}>
                <div className={styles.container}>
                    <button
                        onClick={() => setIsFormOpen(!isFormOpen)}
                        className={styles.writeBtn}
                    >
                        {isFormOpen ? 'Close Form' : 'Write a Review'}
                    </button>

                    <div className={`${styles.formDropdown} ${isFormOpen ? styles.formOpen : ""}`}>
                        <div className={styles.formWrapper}>
                            <ReviewForm
                                onReviewSubmitted={handleReviewSubmitted}
                                onCancel={() => setIsFormOpen(false)}
                            />
                        </div>
                    </div>
                </div>
            </section>

            <section className={styles.feedSection}>
                <div className={styles.container}>
                    <h2 className={styles.sectionTitle}>Community Feedback</h2>
                    <ReviewsFeed />
                </div>
            </section>

            <Footer />
        </main>
    );
}
