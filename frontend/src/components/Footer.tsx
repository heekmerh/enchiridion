import Link from "next/link";
import NewsletterSignup from "./NewsletterSignup";
import styles from "./Footer.module.css";

export default function Footer() {
    return (
        <footer className={styles.footer}>
            <div className={styles.container}>
                <div className={styles.grid}>
                    <div className={styles.brand}>
                        <Link href="/" className={styles.brandLink}><h2 className={styles.logo}>ENCHIRIDION</h2></Link>
                        <p className={styles.division}>A division of ultramedikx nigeria limited</p>
                        <p className={styles.tagline}>Definitive clinical references for the modern healthcare professional.</p>
                        <NewsletterSignup />
                    </div>

                    <div className={styles.section}>
                        <h3>Contact & community</h3>
                        <a className={styles.email} href="mailto:support@enchiridion.site">support@enchiridion.site</a>
                        <nav aria-label="Enchiridion social profiles" className={styles.socials}>
                            <a href="https://www.instagram.com/enchiridion.md/" target="_blank" rel="noopener noreferrer">Instagram</a>
                            <a href="https://www.tiktok.com/@enchiridion.md" target="_blank" rel="noopener noreferrer">TikTok</a>
                            <a href="https://www.linkedin.com/company/enchiridion-md" target="_blank" rel="noopener noreferrer">LinkedIn</a>
                        </nav>
                        <p className={styles.handle}>@enchiridion.md</p>
                    </div>

                    <div className={styles.section}>
                        <h3>Editorial credits</h3>
                        <dl className={styles.credits}>
                            <dt>Editors-in-chief</dt>
                            <dd>Dr. Hikma Atanda<br />Dr. Ibraheem Olaniyan</dd>
                            <dt>Lead developer</dt>
                            <dd>Mr. Asor Ahura</dd>
                        </dl>
                    </div>
                </div>

                <div className={styles.bottom}>
                    <div className={styles.legal}>
                        <nav aria-label="Legal information" className={styles.legalLinks}>
                            <Link href="/privacy">Privacy Policy</Link>
                            <Link href="/terms">Terms and Conditions</Link>
                        </nav>
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
