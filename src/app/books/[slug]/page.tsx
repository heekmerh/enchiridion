import Image from "next/image";
import { notFound } from "next/navigation";
import { books } from "@/lib/data";
import styles from "./BookPage.module.css";

import Accordion from "@/components/Accordion";

export async function generateStaticParams() {
    return books.map((book) => ({
        slug: book.slug,
    }));
}

export default async function BookPage({ params }: { params: { slug: string } }) {
    const { slug } = await params;
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
                                <>
                                    <button className={styles.primaryBtn}>Buy Edition — $49.99</button>
                                    <button className={styles.secondaryBtn}>Access Digital</button>
                                </>
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
                                <li><strong>Print:</strong> Premium editorial binding, acid-free paper ($49.99).</li>
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
