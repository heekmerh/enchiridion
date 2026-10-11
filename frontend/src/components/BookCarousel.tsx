"use client";

import { useRef, useState, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";
import { books } from "@/lib/data";
import styles from "./BookCarousel.module.css";

export default function BookCarousel() {
    const scrollRef = useRef<HTMLDivElement>(null);
    const [canScrollLeft, setCanScrollLeft] = useState(false);
    const [canScrollRight, setCanScrollRight] = useState(true);

    const [isPaused, setIsPaused] = useState(false);

    const checkScroll = () => {
        if (scrollRef.current) {
            const { scrollLeft, scrollWidth, clientWidth } = scrollRef.current;
            setCanScrollLeft(scrollLeft > 0);
            setCanScrollRight(scrollLeft < scrollWidth - clientWidth - 5);
        }
    };

    const revealClippedCard = (card: HTMLDivElement) => {
        const carousel = scrollRef.current;
        if (!carousel) return;
        const viewport = carousel.getBoundingClientRect();
        const bounds = card.getBoundingClientRect();
        const offset = bounds.left < viewport.left
            ? bounds.left - viewport.left
            : bounds.right > viewport.right ? bounds.right - viewport.right : 0;
        if (Math.abs(offset) < 1) return;
        carousel.scrollBy({
            left: offset,
            behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth",
        });
    };

    useEffect(() => {
        checkScroll();
        window.addEventListener("resize", checkScroll);
        return () => window.removeEventListener("resize", checkScroll);
    }, []);

    useEffect(() => {
        if (!isPaused) {
            const interval = setInterval(() => {
                if (scrollRef.current) {
                    const { scrollLeft, scrollWidth, clientWidth } = scrollRef.current;
                    if (scrollLeft >= scrollWidth - clientWidth - 5) {
                        scrollRef.current.scrollTo({ left: 0, behavior: "smooth" });
                    } else {
                        scroll("right");
                    }
                }
            }, 5000);
            return () => clearInterval(interval);
        }
    }, [isPaused]);

    function scroll(direction: "left" | "right") {
        if (scrollRef.current) {
            const scrollAmount = 400;
            scrollRef.current.scrollBy({
                left: direction === "left" ? -scrollAmount : scrollAmount,
                behavior: "smooth",
            });
        }
    }

    return (
        <section
            id="books"
            className={styles.carouselContainer}
            onMouseEnter={() => setIsPaused(true)}
            onMouseLeave={() => setIsPaused(false)}
        >
            <div className={styles.carouselHeader}>
                <h2 className="fade-in">Medical Handbooks</h2>
                <div className={styles.controls}>
                    <button
                        onClick={() => scroll("left")}
                        disabled={!canScrollLeft}
                        className={styles.navBtn}
                        aria-label="Previous"
                    >
                        &larr;
                    </button>
                    <button
                        onClick={() => scroll("right")}
                        disabled={!canScrollRight}
                        className={styles.navBtn}
                        aria-label="Next"
                    >
                        &rarr;
                    </button>
                </div>
            </div>

            <div className={styles.carouselTrack}>
                <div
                    className={styles.carousel}
                    ref={scrollRef}
                    onScroll={checkScroll}
                >
                    {books.map((book) => (
                        <div key={book.id} className={styles.cardWrapper}
                            onPointerEnter={event => {
                                if (event.pointerType === "mouse") revealClippedCard(event.currentTarget);
                            }}
                            onFocus={event => revealClippedCard(event.currentTarget)}
                        >
                            <Link
                                href={`/books/${book.slug}`}
                                className={styles.card}
                                title={book.title}
                            >
                                <div className={styles.bookImageWrapper}>
                                    <div className={styles.coverImage}>
                                        <Image
                                            src={book.coverImage}
                                            alt={book.title}
                                            fill
                                            className={styles.image}
                                            style={{ objectFit: "cover" }}
                                        />
                                        <div className={styles.hoverOverlay}>
                                            <p>{book.description}</p>
                                            <span className={styles.learnMore}>Read More →</span>
                                        </div>
                                    </div>
                                </div>
                                <div className={styles.info}>
                                    <p className={styles.category}>{book.specialty}</p>
                                    <h3 className={styles.bookTitle}>{book.title}</h3>
                                </div>
                            </Link>
                        </div>
                    ))}
                </div>
            </div>
        </section>
    );
}
