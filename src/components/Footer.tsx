import Link from "next/link";
import NewsletterSignup from "./NewsletterSignup";
import styles from "./Footer.module.css";

export default function Footer() {
    return (
        <footer className={styles.footer}>
            <div className={styles.container}>
                <NewsletterSignup />
                <div className={styles.grid}>
                    <div className={styles.brand}>
                        <h3 className={styles.logo}>ENCHIRIDION</h3>
                        <p className={styles.tagline}>Definitive clinical references for the modern healthcare professional.</p>
                    </div>

                    <div className={styles.section}>
                        <h4>Editorial Credits</h4>
                        <ul>
                            <li>Ed-In-Chief: Dr. Julian Vane</li>
                            <li>Lead Developer: Enchiridion Systems</li>
                            <li>Clinical Review: MedBoard Group</li>
                        </ul>
                    </div>

                    <div className={styles.section}>
                        <h4>Inquiries</h4>
                        <ul>
                            <li><Link href="mailto:editorial@enchiridion.med">editorial@enchiridion.med</Link></li>
                            <li><Link href="/institutional">Institutional Access</Link></li>
                        </ul>
                    </div>

                    <div className={styles.section}>
                        <h4>Network</h4>
                        <div className={styles.socials}>
                            <Link href="#">Journal Archive</Link>
                            <Link href="#">Clinician Portal</Link>
                            <Link href="#">LinkedIn Professional</Link>
                        </div>
                    </div>
                </div>

                <div className={styles.bottom}>
                    <div className={styles.legal}>
                        <p>&copy; {new Date().getFullYear()} Enchiridion. All rights reserved.</p>
                    </div>
                    <p className={styles.affiliations}>
                        Institutional affiliations are used for identification only.
                        Content is peer-reviewed and reference-grade.
                    </p>
                </div>
            </div>
        </footer>
    );
}
