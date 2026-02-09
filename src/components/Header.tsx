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
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [expandedSubMenu, setExpandedSubMenu] = useState<string | null>(null);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const toggleMenu = () => {
    setIsMenuOpen(!isMenuOpen);
    if (isMenuOpen) {
      setExpandedSubMenu(null);
    }
  };

  const toggleSubMenu = (label: string) => {
    if (["Books", "App", "Referral Program"].includes(label)) {
      setExpandedSubMenu(expandedSubMenu === label ? null : label);
    } else {
      setIsMenuOpen(false);
      setExpandedSubMenu(null);
    }
  };

  return (
    <>
      <header
        className={`${styles.header} ${isScrolled ? styles.scrolled : ""} ${activeMenu ? styles.menuOpen : ""}`}
        onMouseLeave={() => setActiveMenu(null)}
      >
        <div className={styles.container}>
          {/* Desktop Nav - Left */}
          <div className={`${styles.navGroup} ${styles.desktopOnly}`}>
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

          {/* Logo - Both Mobile and Desktop */}
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

          {/* Desktop Nav - Right */}
          <div className={`${styles.navGroup} ${styles.desktopOnly}`}>
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

          {/* Hamburger Menu Icon */}
          <button className={styles.hamburger} onClick={toggleMenu} aria-label="Toggle menu">
            <i className={`fas ${isMenuOpen ? "fa-times" : "fa-bars"}`}></i>
          </button>
        </div>

        {/* Mega Dropdown Layer (Desktop Only) */}
        <div className={`${styles.megaDropdown} ${activeMenu ? styles.active : ""} ${styles.desktopOnly}`}>
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
                  <h4 style={{ color: "var(--color-red)" }}>Referral & Partnership</h4>
                  <p>Convert your medical expertise into shared impact. Join our advocacy network.</p>
                  <Link href="/refer" className={styles.megaLink}>Become a Partner →</Link>
                </div>
                <div className={styles.megaCol}>
                  <div className={styles.bookGrid}>
                    <Link href="/refer" className={styles.miniBook} style={{ background: "none" }}>
                      <img src="/impact-illustration.jpg" alt="Impact" className={styles.miniBookImg} />
                      <div className={styles.miniBookLabel}>Impact</div>
                    </Link>
                    <Link href="/refer" className={styles.miniBook} style={{ background: "none" }}>
                      <img src="/rewards-new.png" alt="Rewards" className={styles.miniBookImg} />
                      <div className={styles.miniBookLabel}>Rewards</div>
                    </Link>
                    <Link href="/refer" className={styles.miniBook} style={{ background: "none" }}>
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

      {/* Mobile Sidebar */}
      <div className={`${styles.sidebar} ${isMenuOpen ? styles.sidebarOpen : ""}`}>
        <button className={styles.closeBtn} onClick={() => setIsMenuOpen(false)}>
          <i className="fas fa-times"></i>
        </button>
        <div className={styles.sidebarLinks}>
          {menuItems.map((item) => {
            const hasSubMenu = ["Books", "App", "Referral Program"].includes(item.label);
            const isExpanded = expandedSubMenu === item.label;

            return (
              <div key={item.label} className={styles.sidebarItem}>
                <div
                  className={styles.sidebarLinkContainer}
                  onClick={() => toggleSubMenu(item.label)}
                >
                  <span className={styles.sidebarLink}>{item.label}</span>
                  {hasSubMenu && (
                    <i className={`fas fa-chevron-down ${styles.chevron} ${isExpanded ? styles.chevronRotated : ""}`}></i>
                  )}
                  {!hasSubMenu && (
                    <Link
                      href={item.href}
                      className={styles.sidebarLinkOverlay}
                      onClick={() => setIsMenuOpen(false)}
                    />
                  )}
                </div>

                {hasSubMenu && (
                  <div className={`${styles.mobileSubMenu} ${isExpanded ? styles.subMenuOpen : ""}`}>
                    {item.label === "Books" && (
                      <div className={styles.mobileSubContent}>
                        <Link href="#books" onClick={() => setIsMenuOpen(false)}>View All Books</Link>
                        <Link href="/books/pediatrics" onClick={() => setIsMenuOpen(false)}>Pediatrics</Link>
                        <Link href="/books/surgery" onClick={() => setIsMenuOpen(false)}>Surgery</Link>
                        <Link href="/books/internal-medicine" onClick={() => setIsMenuOpen(false)}>Internal Medicine</Link>
                      </div>
                    )}
                    {item.label === "App" && (
                      <div className={styles.mobileSubContent}>
                        <p>Your library everywhere. Searchable, offline, and up-to-date.</p>
                        <Link href="/download" className={styles.mobileCta} onClick={() => setIsMenuOpen(false)}>Get the App</Link>
                      </div>
                    )}
                    {item.label === "Referral Program" && (
                      <div className={styles.mobileSubContent}>
                        <Link href="/refer" onClick={() => setIsMenuOpen(false)}>Become a Partner</Link>
                        <Link href="/refer" onClick={() => setIsMenuOpen(false)}>Referral Rewards</Link>
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Sidebar Overlay */}
      {isMenuOpen && <div className={styles.overlay} onClick={() => setIsMenuOpen(false)} />}
    </>
  );
}
