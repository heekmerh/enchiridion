"use client";

import { useState } from "react";
import { reviews } from "@/lib/data";
import styles from "./Reviews.module.css";

export default function Reviews() {
    const [activeIdx, setActiveIdx] = useState(0);

    const next = () => setActiveIdx((prev) => (prev + 1) % reviews.length);
    const prev = () => setActiveIdx((prev) => (prev - 1 + reviews.length) % reviews.length);

    return (
        <section id="reviews" className={styles.section}>
            <div className={styles.container}>
                <h2 className={`serif ${styles.sectionTitle}`}>Clinical Perspectives</h2>

                <div className={styles.carousel}>
                    <div className={styles.track}>
                        {reviews.map((review, i) => (
                            <div
                                key={review.id}
                                className={`${styles.slide} ${i === activeIdx ? styles.active : ""}`}
                            >
                                <blockquote className={styles.text}>{review.text}</blockquote>

                                <div className={styles.author}>
                                    <div className={styles.icon}>
                                        {review.gender === "female" ? "♀" : "♂"}
                                    </div>
                                    <div className={styles.info}>
                                        <p className={styles.name}>{review.name}</p>
                                        <p className={styles.meta}>MD &bull; Clinical Practitioner</p>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>

                    <div className={styles.controls}>
                        <button onClick={prev} className={styles.arrow} aria-label="Previous review">&larr;</button>
                        <div className={styles.dots}>
                            {reviews.map((_, i) => (
                                <button
                                    key={i}
                                    onClick={() => setActiveIdx(i)}
                                    className={`${styles.dot} ${i === activeIdx ? styles.activeDot : ""}`}
                                    aria-label={`Go to review ${i + 1}`}
                                />
                            ))}
                        </div>
                        <button onClick={next} className={styles.arrow} aria-label="Next review">&rarr;</button>
                    </div>
                </div>
            </div>
        </section>
    );
}
