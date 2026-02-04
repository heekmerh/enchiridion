"use client";

import { useState, use } from "react";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { books } from "@/lib/data";
import styles from "./BookPage.module.css";
import Accordion from "@/components/Accordion";

const states = [
    "Abia", "Adamawa", "Akwa Ibom", "Anambra", "Bauchi", "Bayelsa", "Benue", "Borno",
    "Cross River", "Delta", "Ebonyi", "Edo", "Ekiti", "Enugu", "Gombe", "Imo",
    "Jigawa", "Kaduna", "Kano", "Katsina", "Kebbi", "Kogi", "Kwara", "Lagos",
    "Nasarawa", "Niger", "Ogun", "Ondo", "Osun", "Oyo", "Plateau", "Rivers",
    "Sokoto", "Taraba", "Yobe", "Zamfara", "FCT (Abuja)"
];

export default function BookPage({ params }: { params: Promise<{ slug: string }> }) {
    const { slug } = use(params);
    const [showDistributors, setShowDistributors] = useState(false);
    const book = books.find((b) => b.slug === slug);

    if (!book) {
        notFound();
    }

    return (
        <div className={styles.page}>
            <section className={styles.hero}>
                <div className={styles.container}>
                    <div className={styles.coverImage}>
                        <Image
                            src={book.coverImage}
                            alt={book.title}
                            fill
                            style={{ objectFit: "cover" }}
                            priority
                        />
                    </div>
                    <div className={styles.heroInfo}>
                        <span className={`${styles.status} ${book.status === "Available" ? styles.available : styles.comingSoon}`}>
                            {book.status === "Available" ? "In Stock" : book.status}
                        </span>
                        <h1 className="fade-in">{book.title} Handbook</h1>
                        <p className={styles.description}>
                            The authoritative clinical reference for {book.specialty}.
                            Curated high-yield protocols, evidence-based management,
                            and seamless digital integration.
                        </p>

                        <div className={styles.actions}>
                            {book.status === "Available" ? (
                                <div className={styles.actionContainer}>
                                    <div className={styles.btnGroup}>
                                        <button
                                            className={styles.primaryBtn}
                                            onClick={() => setShowDistributors(!showDistributors)}
                                            aria-expanded={showDistributors}
                                        >
                                            Buy Edition — ₦10,000
                                        </button>
                                        <button className={styles.secondaryBtn}>Access Digital</button>
                                    </div>

                                    {showDistributors && (
                                        <div className={styles.distributorDropdown}>
                                            <div className={styles.dropdownHeader}>
                                                <h3>Select Your State (Nigeria)</h3>
                                            </div>
                                            <div className={styles.stateList}>
                                                {states.map((state) => (
                                                    <div key={state} className={styles.stateItem}>
                                                        <h4>{state}</h4>
                                                        <div className={styles.distributorDetails}>
                                                            <p><span>Distributor:</span> [Coming Soon]</p>
                                                            <p><span>Location:</span> [TBD]</p>
                                                            <p><span>Phone:</span> [N/A]</p>
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                            <div className={styles.becomeDistributorWrapper}>
                                                <Link
                                                    href="/refer#become-referral-partner"
                                                    className={styles.becomeDistributorBtn}
                                                    aria-label="Become a Distributor and create referral account"
                                                >
                                                    Become a Distributor
                                                </Link>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            ) : (
                                <button className={styles.secondaryBtn} disabled>Coming Soon</button>
                            )}
                        </div>
                    </div>
                </div>
            </section>

            <section className={styles.details}>
                <div className={styles.container}>
                    <div className={styles.accordionGroup}>
                        <Accordion title="Book Overview" defaultOpen>
                            <p>
                                The {book.title} is a meticulously curated resource designed for {book.specialty}
                                practitioners. It provides high-yield clinical data, evidence-based management
                                protocols, and authoritative guidance for complex clinical scenarios.
                            </p>
                        </Accordion>

                        <Accordion title="Format & Availability">
                            <p>Available in the following formats:</p>
                            <ul>
                                <li><strong>Print:</strong> Premium editorial binding, acid-free paper (₦10,000).</li>
                                <li><strong>Digital:</strong> Full integration within the Enchiridion mobile app.</li>
                            </ul>
                            <p style={{ marginTop: "1rem" }}>
                                Status: <strong style={{ color: "var(--accent-primary)" }}>{book.status}</strong>
                            </p>
                        </Accordion>

                        <Accordion title="Content Highlights">
                            <ul>
                                <li>Life-saving emergency management protocols.</li>
                                <li>Specialty-specific calculators and scoring systems.</li>
                                <li>Pediatric and adult dosing guidelines where applicable.</li>
                                <li>Interactive clinical pearl database via app.</li>
                            </ul>
                        </Accordion>

                        <Accordion title="Future Updates">
                            <p>
                                All digital editions receive lifetime updates. Any revisions to clinical guidelines
                                are automatically synced to your Enchiridion app.
                            </p>
                        </Accordion>
                    </div>
                </div>
            </section>
        </div>
    );
}
