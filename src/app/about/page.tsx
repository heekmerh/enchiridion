"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";
import { books } from "@/lib/data";
import styles from "./AboutPage.module.css";

export default function AboutPage() {
    const [currentImageIndex, setCurrentImageIndex] = useState(0);

    useEffect(() => {
        const interval = setInterval(() => {
            setCurrentImageIndex((prev) => (prev + 1) % books.length);
        }, 4000); // Rotate every 4 seconds

        return () => clearInterval(interval);
    }, []);

    return (
        <div className={styles.page}>
            {/* HERO SECTION */}
            <section className={styles.hero}>
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
            <section className={styles.ctaSection}>
                <div className={styles.ctaContent}>
                    <h2 className="serif">Ready to elevate your practice?</h2>
                    <div className={styles.ctaButtons}>
                        <Link href="/books/pediatrics" className={styles.primaryBtn}>Buy the Book</Link>
                        <button className={styles.secondaryBtn}>Download a Sample Chapter</button>
                        <button className={styles.secondaryBtn}>Join the Newsletter</button>
                    </div>
                </div>
            </section>
        </div>
    );
}
