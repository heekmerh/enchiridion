import Link from 'next/link';
import { Review } from '@/app/api/reviews/route';
import styles from './ReviewCard.module.css';

interface ReviewCardProps {
    review: Review;
}

export default function ReviewCard({ review }: ReviewCardProps) {
    const { name, jobTitle, organization, rating, text } = review;

    // Truncate text for carousel view
    const displayText = text.length > 150 ? `${text.substring(0, 150)}...` : text;

    return (
        <div className={styles.card}>
            <div className={styles.rating} role="img" aria-label={`${rating} out of 5 stars`}>
                {Array.from({ length: 5 }).map((_, i) => (
                    <span aria-hidden="true" key={i} className={i < rating ? styles.starFilled : styles.starEmpty}>
                        ★
                    </span>
                ))}
            </div>
            <p className={styles.text}>"{displayText}"</p>
            <Link href="/reviews" className={styles.readMore} aria-label={`Read more of ${name}’s review`}>Read More</Link>

            <div className={styles.author}>
                <div className={styles.avatarPlaceholder}>{name.charAt(0)}</div>
                <div className={styles.details}>
                    <div className={styles.name}>{name}</div>
                    <div className={styles.job}>
                        {jobTitle}
                        {organization && <span className={styles.org}> at {organization}</span>}
                    </div>
                </div>
            </div>
        </div>
    );
}
