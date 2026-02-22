'use client';

import { useState } from 'react';
import styles from './ReviewForm.module.css';
import { manageReviews } from '@/lib/reviews';

interface ReviewFormProps {
    onReviewSubmitted: () => void;
    onCancel: () => void;
}

export default function ReviewForm({ onReviewSubmitted, onCancel }: ReviewFormProps) {
    const [formData, setFormData] = useState({
        name: '',
        jobTitle: '',
        organization: '',
        rating: 5,
        text: '',
    });

    const [status, setStatus] = useState<'idle' | 'submitting' | 'success' | 'error'>('idle');
    const [errorMessage, setErrorMessage] = useState('');

    const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
        const { name, value } = e.target;
        setFormData((prev) => ({ ...prev, [name]: name === 'rating' ? Number(value) : value }));
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setStatus('submitting');
        setErrorMessage('');

        // Basic client-side validation
        if (!formData.name || !formData.jobTitle || !formData.text) {
            setErrorMessage('Please fill in all required fields.');
            setStatus('error');
            return;
        }

        if (formData.text.length < 30) {
            setErrorMessage('Review must be at least 30 characters long.');
            setStatus('error');
            return;
        }

        try {
            await manageReviews('SUBMIT', formData);
            setStatus('success');
            // Reset form after a brief delay
            setTimeout(() => {
                onReviewSubmitted();
            }, 2000);
        } catch (error) {
            console.error('Submission error:', error);
            setErrorMessage(error instanceof Error ? error.message : 'An error occurred. Please try again.');
            setStatus('error');
        }
    };

    if (status === 'success') {
        return (
            <div className={styles.successMessage}>
                <div className={styles.successIcon}>✓</div>
                <h3>Review Submitted!</h3>
                <p>Thank you for your feedback. Your review is pending moderation and will appear shortly once approved.</p>
                <button onClick={onReviewSubmitted} className={styles.secondaryBtn}>
                    Close
                </button>
            </div>
        );
    }

    return (
        <form onSubmit={handleSubmit} className={styles.form}>
            <div className={styles.formHeader}>
                <h3>Write a Review</h3>
                <p>Share your experience with Enchiridion to help the community.</p>
            </div>

            {status === 'error' && <div className={styles.errorMessage}>{errorMessage}</div>}

            <div className={styles.inputGroup}>
                <label htmlFor="name">Full Name <span className={styles.required}>*</span></label>
                <input
                    type="text"
                    id="name"
                    name="name"
                    value={formData.name}
                    onChange={handleChange}
                    placeholder="Dr. Amina Yusuf"
                    required
                />
            </div>

            <div className={styles.row}>
                <div className={styles.inputGroup}>
                    <label htmlFor="jobTitle">Job Title / Profession <span className={styles.required}>*</span></label>
                    <input
                        type="text"
                        id="jobTitle"
                        name="jobTitle"
                        value={formData.jobTitle}
                        onChange={handleChange}
                        placeholder="Medical Officer"
                        required
                    />
                </div>

                <div className={styles.inputGroup}>
                    <label htmlFor="organization">Organization <span className={styles.optional}>(Optional)</span></label>
                    <input
                        type="text"
                        id="organization"
                        name="organization"
                        value={formData.organization}
                        onChange={handleChange}
                        placeholder="City Hospital"
                    />
                </div>
            </div>

            <div className={styles.inputGroup}>
                <label htmlFor="rating">Rating <span className={styles.required}>*</span></label>
                <div className={styles.starSelect}>
                    {[5, 4, 3, 2, 1].map((star) => (
                        <label key={star} className={styles.starLabel}>
                            <input
                                type="radio"
                                name="rating"
                                value={star}
                                checked={formData.rating === star}
                                onChange={handleChange}
                            />
                            <span className={styles.starIcon}>★</span>
                        </label>
                    ))}
                    <span className={styles.ratingValue}>{formData.rating} Stars</span>
                </div>
            </div>

            <div className={styles.inputGroup}>
                <label htmlFor="text">Your Review <span className={styles.required}>*</span></label>
                <textarea
                    id="text"
                    name="text"
                    value={formData.text}
                    onChange={handleChange}
                    placeholder="Write your experience with Enchiridion... (min 30 chars)"
                    rows={5}
                    minLength={30}
                    required
                />
                <div className={styles.charCount}>
                    {formData.text.length} / 30 chars minimum
                </div>
            </div>

            <div className={styles.actions}>
                <button type="button" onClick={onCancel} className={styles.secondaryBtn} disabled={status === 'submitting'}>
                    Cancel
                </button>
                <button type="submit" className={styles.primaryBtn} disabled={status === 'submitting'}>
                    {status === 'submitting' ? 'Submitting...' : 'Submit Review'}
                </button>
            </div>
        </form>
    );
}
