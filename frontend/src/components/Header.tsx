"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { useDialog } from "@/hooks/useDialog";
import styles from "./Header.module.css";
import PartnerLoginModal from "./PartnerLoginModal";
import { currentSession, onSessionChange } from "@/lib/supabase";

const menuItems = [
  { label: "Books", href: "/#books" },
  { label: "App", href: "/#app" },
  { label: "Referral Program", href: "/refer" },
  { label: "Rewards", href: "/rewards" },
  { label: "Premium", href: "/premium" },
  { label: "Partner Login", href: "#login", modal: true },
  { label: "Reviews", href: "/reviews" },
  { label: "About", href: "/about" },
  { label: "Download", href: "/#app" },
];

export default function Header() {
  const [isScrolled, setIsScrolled] = useState(false);
  const menuTriggerRef = useRef<HTMLButtonElement | null>(null);
  const [activeMenu, setActiveMenu] = useState<string | null>(null);
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [expandedSubMenu, setExpandedSubMenu] = useState<string | null>(null);
  const sidebarRef = useDialog(isMenuOpen, () => setIsMenuOpen(false));
  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [isLoggedIn, setIsLoggedIn] = useState(false); // Temporary state for UI

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };

    const handleHashChange = () => {
      if (window.location.hash === "#login") {
        handleOpenLogin();
        // Clear hash without triggering scroll
        window.history.replaceState(null, "", window.location.pathname);
      }
    };

    currentSession().then(session => setIsLoggedIn(!!session));
    const stopListening = onSessionChange(session => setIsLoggedIn(!!session));

    window.addEventListener("scroll", handleScroll);
    window.addEventListener("hashchange", handleHashChange);

    // Check initial hash
    handleHashChange();

    return () => {
      window.removeEventListener("scroll", handleScroll);
      window.removeEventListener("hashchange", handleHashChange);
      stopListening();
    };
  }, []);

  const toggleMenu = () => {
    setIsMenuOpen(!isMenuOpen);
    if (isMenuOpen) {
      setExpandedSubMenu(null);
    }
  };

  const toggleSubMenu = (label: string) => {
    if (["Books", "App", "Partnership"].includes(label)) {
      setExpandedSubMenu(expandedSubMenu === label ? null : label);
    } else if (label === "Partner Login") {
      setIsLoginModalOpen(true);
      window.dispatchEvent(new CustomEvent("partner-login-modal-open"));
      setIsMenuOpen(false);
    } else {
      setIsMenuOpen(false);
      setExpandedSubMenu(null);
    }
  };

  function handleOpenLogin() {
    setIsLoginModalOpen(true);
    window.dispatchEvent(new CustomEvent("partner-login-modal-open"));
  }

  const handleCloseLogin = () => {
    setIsLoginModalOpen(false);
    window.dispatchEvent(new CustomEvent("partner-login-modal-close"));
  };

  return (
    <>
      <header
        className={`${styles.header} ${isScrolled ? styles.scrolled : ""} ${activeMenu ? styles.menuOpen : ""}`}
        onPointerLeave={event => {
          if (event.pointerType === "mouse" && !event.currentTarget.querySelector("#desktop-navigation-panel")?.contains(document.activeElement)) {
            setActiveMenu(null);
          }
        }}
        onKeyDown={event => { if (event.key === "Escape" && activeMenu) { setActiveMenu(null); menuTriggerRef.current?.focus(); } }}
        onBlur={event => { if (!event.currentTarget.contains(event.relatedTarget)) setActiveMenu(null); }}
        onClickCapture={event => {
          if (event.target instanceof Element && event.target.closest("a")) {
            setActiveMenu(null);
            setIsMenuOpen(false);
            setExpandedSubMenu(null);
          }
        }}
      >
        <div className={styles.container}>
          {/* Desktop Nav - Left */}
          <nav aria-label="Primary navigation" className={`${styles.navGroup} ${styles.desktopOnly}`}>
            {menuItems.slice(0, 4).map((item) => (
              <div
                key={item.label}
                className={styles.navItem}
                onPointerEnter={event => {
                  if (event.pointerType !== "mouse") return;
                  const trigger = event.currentTarget.querySelector<HTMLButtonElement>("button[aria-controls]");
                  if (trigger) {
                    menuTriggerRef.current = trigger;
                    setActiveMenu(item.label);
                  } else {
                    setActiveMenu(null);
                  }
                }}
              >
                {item.modal ? (
                  <button onClick={handleOpenLogin} className={styles.navLinkButton}>
                    {item.label}
                  </button>
                ) : (
                  <Link href={item.href} className={styles.navLink}>{item.label}</Link>
                )}
                {["Books", "App", "Referral Program"].includes(item.label) && (
                  <button type="button" className={styles.navDisclosure}
                    aria-label={`${activeMenu === item.label ? "Close" : "Open"} ${item.label} menu`}
                    aria-expanded={activeMenu === item.label} aria-controls="desktop-navigation-panel"
                    onClick={event => { menuTriggerRef.current = event.currentTarget; setActiveMenu(activeMenu === item.label ? null : item.label); }}>
                    <span aria-hidden="true">⌄</span>
                  </button>
                )}
              </div>
            ))}
          </nav>

          {/* Logo - Both Mobile and Desktop */}
          <div className={styles.logoContainer}>
            <Link href="/" className={styles.logo}>
              <img
                src="/Gemini.png"
                alt="Enchiridion Logo"
                className={styles.logoIcon}
              />
              <span className={styles.brandText}>
                <span>ENCHIRIDION</span>
                <small className={styles.division}>A division of ultramedikx nigeria limited</small>
              </span>
            </Link>
          </div>

          {/* Desktop Nav - Right */}
          <nav aria-label="Account and information" className={`${styles.navGroup} ${styles.desktopOnly}`}>
            {menuItems.slice(4).map((item) => {
              const isLoginItem = item.label === "Partner Login";
              if (isLoginItem && isLoggedIn) {
                return (
                  <div key="dashboard" className={styles.navItem}>
                    <Link href="/dashboard" className={styles.navLink}>Dashboard</Link>
                  </div>
                );
              }
              return (
                <div
                  key={item.label}
                  className={styles.navItem}
                >
                  {item.modal ? (
                    <button onClick={handleOpenLogin} className={styles.navLinkButton}>
                      {item.label}
                    </button>
                  ) : (
                    <Link href={item.href} className={styles.navLink}>{item.label}</Link>
                  )}
                </div>
              );
            })}
          </nav>

          {/* Hamburger Menu Icon */}
          <button className={styles.hamburger} onClick={toggleMenu} aria-label={isMenuOpen ? "Close navigation" : "Open navigation"} aria-expanded={isMenuOpen} aria-controls="mobile-navigation">
            <i aria-hidden="true" className={`fas ${isMenuOpen ? "fa-times" : "fa-bars"}`}></i>
          </button>
        </div>

        {/* Mega Dropdown Layer (Desktop Only) */}
        <div id="desktop-navigation-panel" role="region" aria-label={`${activeMenu || "Expanded"} navigation`} hidden={!activeMenu} className={`${styles.megaDropdown} ${activeMenu ? styles.active : ""} ${styles.desktopOnly}`}>
          <div className={styles.megaContainer}>
            {activeMenu === "Books" && (
              <div className={styles.megaContent}>
                <div className={styles.megaCol}>
                  <h4>Clinical Books</h4>
                  <p>Curated medical handbooks for every specialty.</p>
                  <Link href="/#books" className={styles.megaLink}>View All Books →</Link>
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
                  <Link href="/#app" className={styles.ctaButton}>Get the App</Link>
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
      <div id="mobile-navigation" ref={sidebarRef} role="dialog" aria-modal="true" aria-label="Navigation" tabIndex={-1} hidden={!isMenuOpen} className={`${styles.sidebar} ${isMenuOpen ? styles.sidebarOpen : ""}`}>
        <button className={styles.closeBtn} aria-label="Close navigation" onClick={() => setIsMenuOpen(false)}>
          <i aria-hidden="true" className="fas fa-times"></i>
        </button>
        <div className={styles.sidebarLinks}>
          {menuItems.map((item) => {
            // Group Partner-related items under "Partnership" in the mobile sidebar
            const partnerLabels = ["Referral Program", "Rewards", "Partner Login"];
            if (partnerLabels.includes(item.label) && item.label !== "Referral Program") return null;

            const isPartnershipGroup = item.label === "Referral Program";
            const displayLabel = isPartnershipGroup ? "Partnership" : item.label;
            const hasSubMenu = ["Books", "App"].includes(item.label) || isPartnershipGroup;
            const isExpanded = expandedSubMenu === (isPartnershipGroup ? "Partnership" : item.label);

            return (
              <div key={item.label} className={styles.sidebarItem}>
                {hasSubMenu ? (
                  <button type="button" className={styles.sidebarLinkContainer}
                    aria-expanded={isExpanded} aria-controls={`mobile-${item.label.replaceAll(" ", "-")}`}
                    onClick={() => toggleSubMenu(isPartnershipGroup ? "Partnership" : item.label)}>
                    <span className={styles.sidebarLink}>{displayLabel}</span>
                    <i aria-hidden="true" className={`fas fa-chevron-down ${styles.chevron} ${isExpanded ? styles.chevronRotated : ""}`} />
                  </button>
                ) : (
                  <Link href={item.href} className={styles.sidebarLinkContainer} onClick={() => setIsMenuOpen(false)}>
                    <span className={styles.sidebarLink}>{displayLabel}</span>
                  </Link>
                )}

                {hasSubMenu && (
                  <div id={`mobile-${item.label.replaceAll(" ", "-")}`} hidden={!isExpanded} className={`${styles.mobileSubMenu} ${isExpanded ? styles.subMenuOpen : ""}`}>
                    {item.label === "Books" && (
                      <div className={styles.mobileSubContent}>
                        <Link href="/#books" onClick={() => setIsMenuOpen(false)}>View All Books</Link>
                        <Link href="/books/pediatrics" onClick={() => setIsMenuOpen(false)}>Pediatrics</Link>
                        <Link href="/books/surgery" onClick={() => setIsMenuOpen(false)}>Surgery</Link>
                        <Link href="/books/internal-medicine" onClick={() => setIsMenuOpen(false)}>Internal Medicine</Link>
                      </div>
                    )}
                    {item.label === "App" && (
                      <div className={styles.mobileSubContent}>
                        <p>Your library everywhere. Searchable, offline, and up-to-date.</p>
                        <Link href="/#app" className={styles.mobileCta} onClick={() => setIsMenuOpen(false)}>Get the App</Link>
                      </div>
                    )}
                    {isPartnershipGroup && (
                      <div className={styles.mobileSubContent}>
                        <Link href="/refer" onClick={() => setIsMenuOpen(false)}>Referral Details</Link>
                        <Link href="/rewards" onClick={() => setIsMenuOpen(false)}>Rewards & Points</Link>
                        {isLoggedIn ? (
                          <Link href="/dashboard" className={styles.mobilePartnerBtn} style={{ textAlign: 'center' }} onClick={() => setIsMenuOpen(false)}>
                            Go to Dashboard
                          </Link>
                        ) : (
                          <button
                            className={styles.mobilePartnerBtn}
                            onClick={() => {
                              handleOpenLogin();
                              setIsMenuOpen(false);
                            }}
                          >
                            Partner Login
                          </button>
                        )}
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

      <PartnerLoginModal
        isOpen={isLoginModalOpen}
        onClose={handleCloseLogin}
        onLoginSuccess={() => setIsLoggedIn(true)}
      />
    </>
  );
}
