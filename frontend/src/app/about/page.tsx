"use client";
import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import Image from "next/image";
import { books } from "@/lib/data";
import styles from "./AboutPage.module.css";
import { logActivity } from "@/lib/record";
import EmailGateModal from "@/components/EmailGateModal";

export default function AboutPage() {
    const [currentImageIndex, setCurrentImageIndex] = useState(0);
    const [isPreviewLoading, setIsPreviewLoading] = useState(true);
    const [showGlow, setShowGlow] = useState(false);
    const [showFloatingButton, setShowFloatingButton] = useState(false);
    const [showEmailGate, setShowEmailGate] = useState(false);
    const [isUnlocked, setIsUnlocked] = useState(false);
    const previewRef = useRef<HTMLDivElement>(null);
    useEffect(() => {
        // Initial check for unlock status (Cookie or LocalStorage)
        const isCookieUnlocked = typeof document !== 'undefined' && document.cookie.includes("ench_sample_access=true");
        const isLSUnlocked = typeof localStorage !== 'undefined' && localStorage.getItem("ench_sample_access_v2") === "true";

        // Hybrid logic: If cookie exists, rely on it. 
        // If user cleared cookies but LS remains, respect the "Reset" and relock everything.
        if (isLSUnlocked && !isCookieUnlocked) {
            localStorage.removeItem("ench_sample_access_v2");
            setIsUnlocked(false);
        } else {
            setIsUnlocked(isCookieUnlocked || isLSUnlocked);
        }

        const interval = setInterval(() => {
            setCurrentImageIndex((prev) => (prev + 1) % books.length);
        }, 4000); // Rotate every 4 seconds

        return () => clearInterval(interval);
    }, []);

    useEffect(() => {
        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.isIntersecting) {
                    setShowGlow(true);
                    // Reset glow after animation
                    setTimeout(() => setShowGlow(false), 2000);
                }
            },
            { threshold: 0.5 }
        );

        if (previewRef.current) {
            observer.observe(previewRef.current);
        }

        const buttonObserver = new IntersectionObserver(
            ([entry]) => {
                // Show button when we've reached the bottom of the preview or scrolled past it
                if (!entry.isIntersecting && entry.boundingClientRect.top < 0) {
                    setShowFloatingButton(true);
                } else {
                    setShowFloatingButton(false);
                }
            },
            { threshold: 0 }
        );

        if (previewRef.current) {
            buttonObserver.observe(previewRef.current);
        }

        return () => {
            observer.disconnect();
            buttonObserver.disconnect();
        };
    }, []);

    const handleViewSample = () => {
        if (isUnlocked) {
            // Scroll directly to preview
            previewRef.current?.scrollIntoView({ behavior: "smooth" });
            // Log tracking event
            const refCode = localStorage.getItem("enchiridion_ref") || "organic";
            logActivity("Sample View", refCode);
        } else {
            // Open the email gate modal
            setShowEmailGate(true);
        }
    };

    const handleGateSuccess = () => {
        setShowEmailGate(false);
        setIsUnlocked(true);
        // Add a slight delay to allow modal to close before scrolling
        setTimeout(() => {
            previewRef.current?.scrollIntoView({ behavior: "smooth" });
        }, 300);
    };

    return (
        <div className={styles.page}>
            <section className={styles.hero}>
                {/* ... existing hero content ... */}
                <div className={styles.heroContent}>
                    <p className="eyebrow fade-in">Enchiridion Medical Reference</p>
                    <h1 className="fade-in">About Enchiridion</h1>
                    <p className={styles.heroSubtitle}>
                        A practical bedside guide for clinicians, students, and healthcare workers—clear, concise, and built for real-world care.
                    </p>
                </div>
                <div className={styles.heroImage}>
                    {books.map((book, index) => (
                        <div
                            key={book.id}
                            className={`${styles.bookCoverWrapper} ${index === currentImageIndex ? styles.active : styles.inactive}`}
                        >
                            <Image
                                src={book.coverImage}
                                alt={`${book.title} Cover`}
                                width={400}
                                height={560}
                                className={styles.bookCover}
                                priority={index === 0}
                            />
                        </div>
                    ))}
                </div>
            </section>

            {/* OVERVIEW SECTION */}
            <section className={`${styles.section} ${styles.gradientBg}`} id="overview">
                <div className={styles.container}>
                    <h2 className="serif">What Enchiridion Is</h2>
                    <div className={styles.content}>
                        <p>
                            <strong>Enchiridion</strong> is a concise, clinically focused medical guidebook designed to support healthcare professionals and students in everyday practice. Rooted in clarity, practicality, and relevance, it distills essential clinical knowledge into an accessible, easy-to-navigate format.
                        </p>
                        <p>
                            The book is written for <strong>medical students, house officers, NYSC doctors, general practitioners, and frontline healthcare workers</strong>, particularly those working in busy, resource-constrained settings. Rather than overwhelming the reader with theory, Enchiridion prioritizes <em>what you need to know, when you need to know it</em>.
                        </p>
                    </div>
                </div>
            </section>

            {/* WHY IT MATTERS SECTION */}
            <section className={`${styles.section} ${styles.altBg}`} id="why-it-matters">
                <div className={styles.container}>
                    <h2 className="serif">Why Enchiridion Matters</h2>
                    <div className={styles.content}>
                        <p>
                            Modern medical textbooks are often bulky, overly theoretical, and difficult to use at the bedside. <strong>Enchiridion exists to bridge that gap.</strong>
                        </p>
                        <p>It was created to:</p>
                        <ul className={styles.list}>
                            <li>Support <strong>quick clinical decision-making</strong></li>
                            <li>Reinforce <strong>core concepts</strong> without unnecessary complexity</li>
                            <li>Serve as a reliable companion during <strong>ward rounds, clinics, call duty, and exam preparation</strong></li>
                        </ul>
                        <p>
                            What sets Enchiridion apart is its <strong>practical orientation</strong>. It focuses on:
                        </p>
                        <ul className={styles.list}>
                            <li>Real patient presentations</li>
                            <li>Step-by-step approaches to diagnosis and management</li>
                            <li>Clear clinical reasoning rather than rote memorization</li>
                        </ul>
                        <p className={styles.highlight}>In short, it is a <em>tool</em>, not just a textbook.</p>
                    </div>
                </div>
            </section>

            {/* BACKSTORY SECTION */}
            <section className={`${styles.section} ${styles.gradientBg}`} id="backstory">
                <div className={styles.container}>
                    <h2 className="serif">The Story Behind Enchiridion</h2>
                    <div className={styles.content}>
                        <p>
                            Enchiridion was born out of everyday clinical experience—long ward rounds, emergency calls, examination preparation, and the recurring need for a <strong>simple, dependable reference</strong> that could be consulted quickly.
                        </p>
                        <p>
                            The idea emerged from observing a consistent problem: clinicians and students often knew <em>where</em> to look for information, but not <em>how fast</em> they needed it.
                        </p>
                        <p>
                            Inspired by classical &ldquo;handbook&rdquo; traditions and shaped by modern clinical realities, Enchiridion was designed to be <strong>portable in thought</strong>, structured in logic, and grounded in real practice.
                        </p>
                        <p>
                            The motivation behind the book is simple: to make good clinical knowledge <strong>accessible, practical, and usable</strong>.
                        </p>
                    </div>
                </div>
            </section>

            {/* WHAT'S INSIDE SECTION */}
            <section className={`${styles.section} ${styles.altBg}`} id="contents">
                <div className={styles.container}>
                    <h2 className="serif">What&rsquo;s Inside</h2>
                    <div className={styles.content}>
                        <p>
                            Enchiridion is organized into <strong>clear, topic-based sections</strong>, each designed for rapid understanding and application. While the structure may evolve, readers can expect coverage of:
                        </p>
                        <div className={styles.grid}>
                            <div className={styles.gridItem}>
                                <h3>Clinical Coverage</h3>
                                <ul className={styles.list}>
                                    <li>Common medical conditions</li>
                                    <li>Clinical presentations and differential diagnoses</li>
                                    <li>Step-by-step approaches to history taking and examination</li>
                                </ul>
                            </div>
                            <div className={styles.gridItem}>
                                <h3>Practical Tools</h3>
                                <ul className={styles.list}>
                                    <li>Investigations and interpretations</li>
                                    <li>Evidence-based management principles</li>
                                    <li>Complications, red flags, and exam-relevant points</li>
                                </ul>
                            </div>
                        </div>
                        <p>
                            The writing style is <strong>direct, structured, and clinically oriented</strong>, making it suitable for both learning and quick revision.
                        </p>
                    </div>
                </div>
            </section>

            {/* AUTHORS SECTION */}
            <section className={`${styles.section} ${styles.gradientBg}`} id="author">
                <div className={styles.container}>
                    <h2 className="serif">About the Authors</h2>
                    <div className={styles.content}>
                        <p>
                            The authors of Enchiridion are <strong>medical doctors with hands-on clinical experience</strong>, actively involved in patient care, teaching, and mentoring young clinicians.
                        </p>
                        <p>With experience spanning:</p>
                        <ul className={styles.list}>
                            <li>Frontline clinical practice</li>
                            <li>Medical education and examination preparation</li>
                            <li>Healthcare delivery in real-world settings</li>
                        </ul>
                        <div className={styles.visionBox}>
                            <h3>Author&rsquo;s Vision</h3>
                            <p>
                                To simplify medical knowledge without diluting its accuracy—and to empower clinicians to practice with confidence, clarity, and compassion.
                            </p>
                        </div>
                    </div>
                </div>
            </section>

            {/* READER VALUE SECTION */}
            <section className={`${styles.section} ${styles.readerValue}`}>
                <div className={styles.container}>
                    <h2 className="serif">What You Gain</h2>
                    <div className={styles.grid}>
                        <div className={styles.valueCard}>
                            <h4>Confidence</h4>
                            <p>Approach patients more systematically and confidently.</p>
                        </div>
                        <div className={styles.valueCard}>
                            <h4>Decision Making</h4>
                            <p>Improve clinical reasoning and decision-making.</p>
                        </div>
                        <div className={styles.valueCard}>
                            <h4>Efficiency</h4>
                            <p>Save time during busy clinical duties.</p>
                        </div>
                        <div className={styles.valueCard}>
                            <h4>Success</h4>
                            <p>Strengthen understanding for exams and assessments.</p>
                        </div>
                    </div>
                </div>
            </section>

            {/* CALL TO ACTION */}
            <section className={styles.ctaSection} id="sample-viewer">
                <div className={styles.container}>
                    <div className={styles.ctaContent}>
                        <h2 className="serif">Ready to elevate your practice?</h2>
                        <div className={styles.ctaButtons}>
                            <Link href="/books/pediatrics" className={styles.primaryBtn}>Buy the Book</Link>
                            <button className={styles.secondaryBtn} onClick={handleViewSample}>
                                View a Sample Chapter
                            </button>
                            <button
                                className={styles.secondaryBtn}
                                onClick={() => window.dispatchEvent(new CustomEvent("open-newsletter"))}
                            >
                                Join the Newsletter
                            </button>
                        </div>

                        {/* Guided Scroll indicator */}
                        <div className={styles.scrollIndicator}>
                            <p>{isUnlocked ? "Read a Preview Below" : "Unlock Preview Below"}</p>
                            <div className={styles.arrowDown}>
                                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M7 13l5 5 5-5M7 6l5 5 5-5" />
                                </svg>
                            </div>
                        </div>
                    </div>

                    {/* EMBEDDED PREVIEW */}
                    <div className={styles.previewSection} ref={previewRef}>
                        <div className={styles.previewHeader}>
                            <h3>Sample Chapter Preview</h3>
                            {isUnlocked && (
                                <a
                                    href="https://drive.google.com/file/d/1yOU0ZlIXfYPCfOfZjKaZuIYatm2f60IG/view?usp=sharing"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className={styles.fullscreenLink}
                                >
                                    <span>View Fullscreen</span>
                                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3" />
                                    </svg>
                                </a>
                            )}
                        </div>

                        {!isUnlocked ? (
                            <div className={styles.lockedPreview}>
                                <div className={styles.blurContent}>
                                    {/* Mock content for blur effect */}
                                    <div style={{ height: '600px', background: 'white', padding: '40px' }}>
                                        <div style={{ height: '40px', background: '#eee', width: '60%', marginBottom: '20px' }}></div>
                                        <div style={{ height: '20px', background: '#f5f5f5', width: '90%', marginBottom: '10px' }}></div>
                                        <div style={{ height: '20px', background: '#f5f5f5', width: '85%', marginBottom: '10px' }}></div>
                                        <div style={{ height: '20px', background: '#f5f5f5', width: '95%', marginBottom: '30px' }}></div>
                                        <div style={{ height: '300px', background: '#fcfcfc', border: '1px solid #eee' }}></div>
                                    </div>
                                </div>
                                <div className={styles.unlockOverlay}>
                                    <div className={styles.unlockIcon}>
                                        <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                                            <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                                            <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                                        </svg>
                                    </div>
                                    <h4>Sample Content Locked</h4>
                                    <p>Please enter your email to unlock the full sample chapter and start reading today.</p>
                                    <button className={styles.unlockBtn} onClick={() => setShowEmailGate(true)}>
                                        Unlock Sample Now
                                    </button>
                                </div>
                            </div>
                        ) : (
                            <div className={`${styles.iframeContainer} ${showGlow ? styles.iframeGlow : ""}`}>
                                {isPreviewLoading && (
                                    <div className={styles.loadingOverlay}>
                                        <div className={styles.spinner}></div>
                                        <p>Loading Preview...</p>
                                    </div>
                                )}
                                <iframe
                                    src="https://drive.google.com/file/d/1yOU0ZlIXfYPCfOfZjKaZuIYatm2f60IG/preview"
                                    className={styles.previewIframe}
                                    allow="autoplay"
                                    onLoad={() => setIsPreviewLoading(false)}
                                    title="Enchiridion Sample Chapter Preview"
                                ></iframe>
                            </div>
                        )}
                    </div>
                </div>
            </section>

            {/* Floating Conversion Trigger */}
            <Link
                href="/books/pediatrics"
                className={`${styles.floatingBuyButton} ${showFloatingButton ? styles.visible : ""}`}
            >
                Buy the Full Book
            </Link>



            {/* Email Gate Modal */}
            {showEmailGate && (
                <EmailGateModal
                    onSuccess={handleGateSuccess}
                    onClose={() => setShowEmailGate(false)}
                />
            )}
        </div>
    );
}
