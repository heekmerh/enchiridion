"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";
import { books } from "@/lib/data";
import styles from "./SampleCTA.module.css";

export default function SampleCTA() {
    const [currentImageIndex, setCurrentImageIndex] = useState(0);

    useEffect(() => {
        const interval = setInterval(() => {
            setCurrentImageIndex((prev) => (prev + 1) % books.length);
        }, 4000);
        return () => clearInterval(interval);
    }, []);

    return (
        <section className={styles.section}>
            <div className={styles.container}>
                <div className={styles.content}>
                    <h2 className={`${styles.title} serif`}>See Inside the Enchiridion</h2>
                    <p className={styles.subtext}>
                        Get a sneak peek at our expert medical exam preparation content.
                        Download our curated sample chapter today.
                    </p>
                    <Link href="/about#sample-viewer" className={styles.ctaButton}>
                        View a Sample Chapter
                    </Link>
                </div>
                <div className={styles.visual}>
                    <div className={styles.bookStack}>
                        {books.map((book, index) => (
                            <div
                                key={book.id}
                                className={`${styles.bookImageWrapper} ${index === currentImageIndex ? styles.active : styles.inactive
                                    }`}
                            >
                                <Image
                                    src={book.coverImage}
                                    alt={book.title}
                                    width={300}
                                    height={420}
                                    className={styles.bookImage}
                                    priority={index === 0}
                                />
                            </div>
                        ))}
                    </div>
                </div>
            </div>
        </section>
    );
}
