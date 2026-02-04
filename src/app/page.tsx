import BookCarousel from "@/components/BookCarousel";
import AppSection from "@/components/AppSection";
import ReviewsSection from '@/components/ReviewsSection';
import Link from "next/link";
import styles from "./page.module.css";

export default function Home() {
  return (
    <div className={styles.page}>
      <div className={styles.mainWrapper}>
        <div className={styles.heartBackground}></div>
        {/* SECTION 1 — HERO */}
        <section className={styles.hero}>
          {/* Dynamic Red Aurora Overlay */}
          <div className={styles.redAurora}></div>

          {/* Atmospheric Glowing Orbs in Hero */}
          <div className={styles.smokeParticle} style={{ top: '15%', left: '10%', animationDelay: '0s' }}></div>
          <div className={styles.smokeParticle} style={{ top: '25%', right: '15%', animationDelay: '-5s' }}></div>
          <div className={styles.smokeParticle} style={{ top: '40%', left: '70%', animationDelay: '-12s' }}></div>
          <div className={styles.smokeParticle} style={{ bottom: '20%', left: '30%', animationDelay: '-3s' }}></div>

          <div className={styles.heroContent}>
            <div className={styles.heroCircleContainer} aria-label="Main call-to-action area">
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


        {/* SECTION 2 — BOOK CAROUSEL */}
        <section id="books" className={styles.collectionSection}>
          {/* Prominent Smoke Ribbon Flow */}
          <div className={styles.smokeRibbon}></div>

          {/* Ambient Blue/Red Accents */}
          <div className={styles.ambientGlow} style={{ top: '10%', left: '5%', animationDelay: '0s', background: 'radial-gradient(circle, rgba(60, 100, 255, 0.2) 0%, transparent 80%)' }}></div>
          <div className={styles.ambientGlow} style={{ top: '60%', right: '5%', animationDelay: '-6s', background: 'radial-gradient(circle, rgba(255, 60, 60, 0.2) 0%, transparent 80%)' }}></div>

          {/* Floating Smoke Particles (Glowing Orbs) - Increased Density */}
          <div className={styles.smokeParticle} style={{ bottom: '20%', left: '20%', animationDelay: '0s' }}></div>
          <div className={styles.smokeParticle} style={{ bottom: '40%', right: '25%', animationDelay: '-4s' }}></div>
          <div className={styles.smokeParticle} style={{ bottom: '10%', left: '50%', animationDelay: '-10s' }}></div>
          <div className={styles.smokeParticle} style={{ bottom: '70%', right: '15%', animationDelay: '-15s' }}></div>
          <div className={styles.smokeParticle} style={{ top: '15%', left: '80%', animationDelay: '-3s' }}></div>
          <div className={styles.smokeParticle} style={{ top: '30%', left: '10%', animationDelay: '-7s' }}></div>
          <div className={styles.smokeParticle} style={{ top: '50%', right: '40%', animationDelay: '-12s' }}></div>
          <div className={styles.smokeParticle} style={{ bottom: '5%', right: '5%', animationDelay: '-18s' }}></div>
          <div className={styles.smokeParticle} style={{ top: '40%', left: '45%', animationDelay: '-22s' }}></div>
          <div className={styles.smokeParticle} style={{ top: '65%', right: '60%', animationDelay: '-28s' }}></div>
          <div className={styles.smokeParticle} style={{ bottom: '30%', left: '15%', animationDelay: '-32s' }}></div>

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
      </div>

      {/* SECTION 3 — APP SECTION */}
      <AppSection />

      {/* SECTION 4 — REVIEWS */}
      <ReviewsSection />

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
              <img
                src="/Gemini_Generated_Image_aoqcigaoqcigaoqc.png"
                alt="Referral Program"
                className={styles.referralImage}
              />
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
