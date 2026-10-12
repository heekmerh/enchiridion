"use client";

import { useRef, useState, useEffect, type PointerEvent } from "react";
import Link from "next/link";
import Image from "next/image";
import { books } from "@/lib/data";
import styles from "./BookCarousel.module.css";

export default function BookCarousel() {
    const [detailsDismissed, setDetailsDismissed] = useState(false);
    const scrollRef = useRef<HTMLDivElement>(null);
    const lastHoverRef = useRef<{ x: number; y: number } | null>(null);
    const [canScrollLeft, setCanScrollLeft] = useState(false);
    const [canScrollRight, setCanScrollRight] = useState(true);



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

    const revealHoveredCard = (event: PointerEvent<HTMLDivElement>) => {
        if (event.pointerType !== "mouse") return;
        const previous = lastHoverRef.current;
        // Scrolling can move another card beneath a stationary pointer.
        // Reveal only once at that pointer position, rather than cascading to the end.
        if (previous && Math.hypot(event.clientX - previous.x, event.clientY - previous.y) < 4) return;
        lastHoverRef.current = { x: event.clientX, y: event.clientY };
        revealClippedCard(event.currentTarget);
    };

    useEffect(() => {
        checkScroll();
        window.addEventListener("resize", checkScroll);
        return () => window.removeEventListener("resize", checkScroll);
    }, []);

    function scroll(direction: "left" | "right") {
        if (scrollRef.current) {
            const firstCard = scrollRef.current.firstElementChild as HTMLElement | null;
            const gap = parseFloat(getComputedStyle(scrollRef.current).columnGap) || 0;
            const scrollAmount = (firstCard?.offsetWidth || 320) + gap;
            scrollRef.current.scrollBy({
                left: direction === "left" ? -scrollAmount : scrollAmount,
                behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth",
            });
        }
    }

    return (
        <section
            className={styles.carouselContainer}
            onKeyDown={event => { if (event.key === "Escape") setDetailsDismissed(true); }}
        >
            <div className={styles.carouselHeader}>
                <div className={styles.browseHint}>
                    <p className={styles.bookCount}>Browse all {books.length} handbooks</p>
                    <p id="book-carousel-help">Swipe or use the arrows to explore.</p>
                </div>
                <div className={styles.controls}>
                    <button
                        onClick={() => scroll("left")}
                        disabled={!canScrollLeft}
                        className={styles.navBtn}
                        aria-label="Previous books"
                        aria-controls="book-carousel"
                    >
                        &larr;
                    </button>
                    <button
                        onClick={() => scroll("right")}
                        disabled={!canScrollRight}
                        className={styles.navBtn}
                        aria-label="Next books"
                        aria-controls="book-carousel"
                    >
                        &rarr;
                    </button>
                </div>
            </div>

            <div className={styles.carouselTrack}>
                <div
                    className={styles.carousel}
                    id="book-carousel"
                    role="region" aria-label="Medical handbooks" aria-describedby="book-carousel-help"
                    ref={scrollRef}
                    onScroll={checkScroll}
                    onPointerLeave={() => { lastHoverRef.current = null; }}
                >
                    {books.map((book) => (
                        <div key={book.id} className={styles.cardWrapper}
                            onPointerLeave={() => setDetailsDismissed(false)}
                            onPointerEnter={revealHoveredCard}
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
                                            sizes="(max-width: 768px) 80vw, 320px"
                                            className={styles.image}
                                            style={{ objectFit: "cover" }}
                                        />
                                        <div className={styles.hoverOverlay} style={detailsDismissed ? { opacity: 0 } : undefined}>
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
