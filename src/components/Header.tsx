"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";
import styles from "./Header.module.css";

const menuItems = [
  { label: "Books", href: "#books" },
  { label: "App", href: "#app" },
  { label: "Referral Program", href: "/refer" },
  { label: "Reviews", href: "#user-reviews" },
  { label: "About", href: "/about" },
  { label: "Download", href: "/download" },
];

export default function Header() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [activeMenu, setActiveMenu] = useState<string | null>(null);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <header
      className={`${styles.header} ${isScrolled ? styles.scrolled : ""} ${activeMenu ? styles.menuOpen : ""}`}
      onMouseLeave={() => setActiveMenu(null)}
    >
      <div className={styles.container}>
        {/* Left Nav */}
        <div className={styles.navGroup}>
          {menuItems.slice(0, 3).map((item) => (
            <div
              key={item.label}
              className={styles.navItem}
              onMouseEnter={() => ["Books", "App", "Referral Program"].includes(item.label) ? setActiveMenu(item.label) : setActiveMenu(null)}
            >
              <Link href={item.href} className={styles.navLink}>{item.label}</Link>
            </div>
          ))}
        </div>

        {/* Center Logo */}
        <div className={styles.logoContainer}>
          <Link href="/" className={styles.logo}>
            <img
              src="/Gemini.png"
              alt="Enchiridion Logo"
              className={styles.logoIcon}
            />
            <span>ENCHIRIDION</span>
          </Link>
        </div>

        {/* Right Nav */}
        <div className={styles.navGroup}>
          {menuItems.slice(3).map((item) => (
            <div
              key={item.label}
              className={styles.navItem}
              onMouseEnter={() => ["Books", "App", "Referral Program"].includes(item.label) ? setActiveMenu(item.label) : setActiveMenu(null)}
            >
              <Link href={item.href} className={styles.navLink}>{item.label}</Link>
            </div>
          ))}
        </div>
      </div>

      {/* Mega Dropdown Layer */}
      <div className={`${styles.megaDropdown} ${activeMenu ? styles.active : ""}`}>
        <div className={styles.megaContainer}>
          {activeMenu === "Books" && (
            <div className={styles.megaContent}>
              <div className={styles.megaCol}>
                <h4>Clinical Books</h4>
                <p>Curated medical handbooks for every specialty.</p>
                <Link href="#books" className={styles.megaLink}>View All Books →</Link>
              </div>
              <div className={styles.megaCol}>
                <div className={styles.bookGrid}>
                  <Link href="/books/pediatrics" className={styles.miniBook}>
                    <img src="/ped cover.png" alt="Pediatrics Cover" className={styles.miniBookImg} />
                  </Link>
                  <Link href="/books/surgery" className={styles.miniBook}>
                    <img src="/3.png" alt="Surgery Cover" className={styles.miniBookImg} />
                  </Link>
                  <Link href="/books/internal-medicine" className={styles.miniBook}>
                    <img src="/2.png" alt="Medicine Cover" className={styles.miniBookImg} />
                  </Link>
                </div>
              </div>
            </div>
          )}
          {activeMenu === "App" && (
            <div className={styles.megaContent}>
              <div className={styles.megaCol}>
                <h4>Enchiridion App</h4>
                <p>Your library everywhere. Searchable, offline, and up-to-date.</p>
              </div>
              <div className={styles.megaCol}>
                <Link href="/download" className={styles.ctaButton}>Get the App</Link>
              </div>
            </div>
          )}
          {activeMenu === "Referral Program" && (
            <div className={styles.megaContent}>
              <div className={styles.megaCol}>
                <h4 style={{ color: 'var(--color-red)' }}>Referral & Partnership</h4>
                <p>Convert your medical expertise into shared impact. Join our advocacy network.</p>
                <Link href="/refer" className={styles.megaLink}>Become a Partner →</Link>
              </div>
              <div className={styles.megaCol}>
                <div className={styles.bookGrid}>
                  <Link href="/refer" className={styles.miniBook} style={{ background: 'none' }}>
                    <img src="/impact-illustration.jpg" alt="Impact" className={styles.miniBookImg} />
                    <div className={styles.miniBookLabel}>Impact</div>
                  </Link>
                  <Link href="/refer" className={styles.miniBook} style={{ background: 'none' }}>
                    <img src="/rewards-new.png" alt="Rewards" className={styles.miniBookImg} />
                    <div className={styles.miniBookLabel}>Rewards</div>
                  </Link>
                  <Link href="/refer" className={styles.miniBook} style={{ background: 'none' }}>
                    <img src="/mission-new.png" alt="Mission" className={styles.miniBookImg} />
                    <div className={styles.miniBookLabel}>Mission</div>
                  </Link>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
