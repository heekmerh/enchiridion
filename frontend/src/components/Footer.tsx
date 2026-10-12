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
                        <p className={styles.division}>A division of ultramedikx nigeria limited</p>
                        <p className={styles.tagline}>Definitive clinical references for the modern healthcare professional.</p>
                    </div>

                    <div className={styles.section}>
                        <h4>Editorial Credits</h4>
                        <ul>
                            <li>Ed-In-Chief: Dr. Hikma Atanda, Dr Ibraheem Olaniyan</li>
                            <li>Lead Developer: Mr Asor Ahura</li>
                        </ul>
                    </div>

                    <div className={styles.section}>
                        <h4>Inquiries</h4>
                        <ul>
                            <li><Link href="mailto:support@enchiridion.site">support@enchiridion.site</Link></li>
                            <li>IG@enchiridion.md</li>
                            <li>tiktok@enchiridion.md</li>
                        </ul>
                    </div>

                    <div className={styles.section}>
                        <h4>Network</h4>
                        <div className={styles.socials}>
                            <Link href="https://www.linkedin.com/company/enchiridion-md" target="_blank" rel="noopener noreferrer">LinkedIn Professional</Link>
                        </div>
                    </div>
                </div>

                <div className={styles.socialSection}>
                    <h3 className={styles.socialTitle}>Connect with Us</h3>
                    <div className={styles.socialIcons}>
                        <a href="https://www.linkedin.com/company/enchiridion-md" target="_blank" rel="noopener noreferrer" aria-label="LinkedIn" className={`${styles.socialLink} ${styles.linkedin}`}>
                            <i className="fab fa-linkedin-in"></i>
                        </a>
                    </div>
                </div>

                <div className={styles.bottom}>
                    <div className={styles.legal}>
                        <Link href="/privacy">Privacy Policy</Link>
                        {" · "}
                        <Link href="/terms">Terms and Conditions</Link>
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
