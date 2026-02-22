'use client';

import { useState } from 'react';
import styles from './EmailGateModal.module.css';
import { captureLeadAndGetSample } from '@/lib/tracking';

interface EmailGateModalProps {
    onSuccess: () => void;
    onClose: () => void;
}

export default function EmailGateModal({ onSuccess, onClose }: EmailGateModalProps) {
    const [email, setEmail] = useState('');
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [error, setError] = useState('');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');

        if (!email || !email.includes('@')) {
            setError('Please enter a valid medical or student email.');
            return;
        }

        setIsSubmitting(true);
        try {
            const refCode = localStorage.getItem('enchiridion_ref') || 'organic';
            const result = await captureLeadAndGetSample(email, refCode);

            if (result.success) {
                // Store flag to skip modal next time
                localStorage.setItem('ench_sample_access_v2', 'true');
                onSuccess();
            } else {
                console.error('EmailGateModal: captureLeadAndGetSample failed:', result.error);
                setError(result.error || 'Something went wrong. Please try again.');
            }
        } catch (err) {
            console.error('EmailGateModal: Unexpected error during submission:', err);
            setError('Failed to process. Please check your connection.');
        } finally {
            setIsSubmitting(false);
        }
    };

    return (
        <div className={styles.overlay} onClick={(e) => e.target === e.currentTarget && onClose()}>
            <div className={styles.modal}>
                <button className={styles.closeBtn} onClick={onClose} aria-label="Close">×</button>

                <div className={styles.header}>
                    <h2>Access Free Sample</h2>
                    <p>Enter your email to instantly view the first chapter of Enchiridion.</p>
                </div>

                <form className={styles.form} onSubmit={handleSubmit}>
                    {error && <div className={styles.errorMessage}>{error}</div>}

                    <div className={styles.inputGroup}>
                        <label htmlFor="gate-email">Professional or Student Email</label>
                        <input
                            type="email"
                            id="gate-email"
                            placeholder="doc@example.com"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            disabled={isSubmitting}
                            required
                        />
                    </div>

                    <button type="submit" className={styles.submitBtn} disabled={isSubmitting}>
                        {isSubmitting ? 'Processing...' : 'Access Now'}
                    </button>

                    <p className={styles.privacyNote}>
                        We respect your privacy. No spam, only medical excellence.
                    </p>
                </form>
            </div>
        </div>
    );
}
