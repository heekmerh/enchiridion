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
                            <li>Ed-In-Chief: Dr. Hikma Atanda, Dr Ibraheem Olaniyan</li>
                            <li>Lead Developer: Mr Asor Ahura</li>
                        </ul>
                    </div>

                    <div className={styles.section}>
                        <h4>Inquiries</h4>
                        <ul>
                            <li><Link href="mailto:enchiridion.med@gmail.com">enchiridion.med@gmail.com</Link></li>
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
                        <a href="#" target="_blank" rel="noopener noreferrer" aria-label="Facebook" className={`${styles.socialLink} ${styles.facebook}`}>
                            <i className="fab fa-facebook-f"></i>
                        </a>
                        <a href="#" target="_blank" rel="noopener noreferrer" aria-label="Instagram" className={`${styles.socialLink} ${styles.instagram}`}>
                            <i className="fab fa-instagram"></i>
                        </a>
                        <a href="#" target="_blank" rel="noopener noreferrer" aria-label="X (Twitter)" className={`${styles.socialLink} ${styles.xTwitter}`}>
                            <i className="fab fa-x-twitter"></i>
                        </a>
                        <a href="https://www.linkedin.com/company/enchiridion-md" target="_blank" rel="noopener noreferrer" aria-label="LinkedIn" className={`${styles.socialLink} ${styles.linkedin}`}>
                            <i className="fab fa-linkedin-in"></i>
                        </a>
                        <a href="#" target="_blank" rel="noopener noreferrer" aria-label="WhatsApp" className={`${styles.socialLink} ${styles.whatsapp}`}>
                            <i className="fab fa-whatsapp"></i>
                        </a>
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
