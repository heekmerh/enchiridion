import { Review } from '@/app/api/reviews/route';
import styles from './ReviewCard.module.css';

interface ReviewCardProps {
    review: Review;
}

export default function ReviewCard({ review }: ReviewCardProps) {
    const { name, jobTitle, organization, rating, text } = review;

    return (
        <div className={styles.card}>
            <div className={styles.rating}>
                {Array.from({ length: 5 }).map((_, i) => (
                    <span key={i} className={i < rating ? styles.starFilled : styles.starEmpty}>
                        ★
                    </span>
                ))}
            </div>
            <p className={styles.text}>"{text}"</p>
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
