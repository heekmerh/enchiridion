import BookCarousel from "@/components/BookCarousel";
import AppSection from "@/components/AppSection";
import Reviews from "@/components/Reviews";
import Link from "next/link";
import styles from "./page.module.css";

export default function Home() {
  return (
    <div className={styles.page}>
      {/* SECTION 1 — HERO */}
      <section className={styles.hero}>
        <div className={styles.heroContent}>
          <h1 className="fade-in">
            Concise Medical <br />
            <span className={styles.carouselContainer} aria-live="polite" aria-atomic="true">
              <span className={styles.rotatingText}>
                <span>Knowledge.</span>
                <span>Pediatrics.</span>
                <span>Surgery.</span>
                <span>O&G.</span>
                <span>Orthopaedics.</span>
                <span>Dermatology.</span>
                <span>Medicine.</span>
                <span>Psychiatry.</span>
                <span>Radiology.</span>
                <span>Ophthalmology.</span>
              </span>
            </span>
          </h1>
          <p className={styles.heroDescription}>
            Enchiridion is a curated collection of practical medical handbooks
            designed for students, clinicians, and educators. Anywhere. Anytime.
          </p>
          <div className={styles.heroActions}>
            <Link href="#books" className={styles.primaryBtn}>Explore the Books</Link>
            <Link href="#app" className={styles.secondaryBtn}>Download the App</Link>
          </div>
        </div>

        {/* Floating Medical Icons */}
        <div className={styles.floatingIcons}>
          <div className={styles.icon1}>
            <svg width="100" height="100" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="0.5"><path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"></path></svg>
          </div>
          <div className={styles.icon2}>
            <svg width="120" height="120" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" strokeOpacity="0.8" strokeWidth="0.5"><circle cx="50" cy="50" r="30" /><circle cx="50" cy="50" r="15" /><path d="M50 10 L50 90 M10 50 L90 50" /></g></svg>
          </div>
        </div>
      </section>

      {/* LAYERED WAVE TRANSITION */}
      <div className={styles.waveTransitionContainer}>
        <div className={`${styles.waveLayer} ${styles.layer1}`}></div>
        <div className={`${styles.waveLayer} ${styles.layer2}`}></div>
        <div className={`${styles.waveLayer} ${styles.layer3}`}></div>
      </div>

      {/* SECTION 2 — BOOK CAROUSEL */}
      <section id="books" className={styles.collectionSection}>
        <div className={styles.collectionHeader}>
          <h2 className="serif">The Collection</h2>
          <p>Treating books like premium editorial products. A curated hospital library at your fingertips.</p>
        </div>
        <BookCarousel />

        {/* Decorative heart icon from reference */}
        <div className={styles.floatingIcons}>
          <div className={styles.icon3}>
            <svg width="80" height="80" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="0.5"><path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"></path></svg>
          </div>
        </div>
      </section>

      {/* SECTION 3 — APP SECTION */}
      <AppSection />

      {/* SECTION 4 — REVIEWS */}
      <section id="reviews" style={{ backgroundColor: 'white', padding: '120px 0' }}>
        <div className={styles.sectionHeader}>
          <h2 className="serif">Clinical Trust</h2>
          <p>What the community says about Enchiridion.</p>
        </div>
        <Reviews />
      </section>

      {/* SECTION 5 — REFERRAL PROGRAM PREVIEW */}
      <section className={styles.referralSection}>
        <div className={styles.container}>
          <div className={styles.referralTeaser}>
            <div className={styles.referralContent}>
              <h2 className="serif">Refer. Earn. Educate.</h2>
              <p>
                Share Enchiridion with colleagues and earn rewards while
                advancing medical education across your institution.
              </p>
              <Link href="/refer" className={styles.referralLink}>
                View Referral Program →
              </Link>
            </div>
            <div className={styles.referralVisual}>
              <svg width="120" height="120" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="0.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
                <path d="M22 21v-2a4 4 0 0 0-3-3.87"></path>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
              </svg>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
