"use client";

import { useState } from "react";
import Image from "next/image";
import styles from "./ReferralPage.module.css";
import Accordion from "@/components/Accordion";

export default function ReferralPage() {
    const [activeAccordion, setActiveAccordion] = useState<number | null>(null);
    const [isRegistered, setIsRegistered] = useState(false);
    const [referralCode, setReferralCode] = useState("");
    const [copied, setCopied] = useState(false);
    const [formData, setFormData] = useState({
        fullName: "",
        email: "",
        country: "",
        state: "",
        profession: "",
        password: "",
        confirmPassword: "",
        phone: "",
        institution: ""
    });
    const [formErrors, setFormErrors] = useState<Record<string, string>>({});

    const toggleAccordion = (index: number) => {
        setActiveAccordion(activeAccordion === index ? null : index);
    };

    const generateReferralCode = (name: string) => {
        const prefix = "ENCH";
        const suffix = Math.random().toString(36).substring(2, 6).toUpperCase();
        const initials = name.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2) || "RE";
        return `${prefix}-${initials}-${suffix}`;
    };

    const scrollToRegistration = () => {
        const element = document.getElementById("become-referral-partner");
        if (element) {
            element.scrollIntoView({ behavior: "smooth" });
        }
    };

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
        const { name, value } = e.target;
        setFormData(prev => ({ ...prev, [name]: value }));
        if (formErrors[name]) {
            setFormErrors(prev => ({ ...prev, [name]: "" }));
        }
    };

    const validateForm = () => {
        const errors: Record<string, string> = {};
        if (!formData.fullName.trim()) errors.fullName = "Full name is required";
        if (!formData.email.trim()) errors.email = "Email is required";
        else if (!/\S+@\S+\.\S+/.test(formData.email)) errors.email = "Invalid email format";
        if (!formData.country.trim()) errors.country = "Country is required";
        if (!formData.phone.trim()) errors.phone = "Phone number is required";
        if (!formData.profession) errors.profession = "Please select a profession";
        if (!formData.password) errors.password = "Password is required";
        else if (formData.password.length < 6) errors.password = "Password must be at least 6 characters";
        if (formData.password !== formData.confirmPassword) errors.confirmPassword = "Passwords do not match";
        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (validateForm()) {
            const code = generateReferralCode(formData.fullName);
            setReferralCode(code);
            setIsRegistered(true);
        }
    };

    const copyToClipboard = (text: string) => {
        navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
    };

    const stats = [
        { num: "12+", label: "Specialties in Development" },
        { num: "50k+", label: "Active Readers" },
        { num: "200+", label: "Institutions Reached" },
        { num: "1k+", label: "Contributor Network" },
    ];

    const benefits = [
        {
            title: "Income and Flexibility",
            text: "With Enchiridion you are your own boss, work with knowledge, manage your own time and earn extra income."
        },
        {
            title: "Share Knowledge, Earn Rewards",
            text: "Refer colleagues, students, and institutions to Enchiridion books and the companion app while earning referral bonuses, discounts, or commissions. Earn upto 20% profit on orders."
        },
        {
            title: "Be Part of the Enchiridion Ecosystem",
            text: "Join a trusted network of contributors, reviewers, and advocates shaping modern medical education."
        }
    ];

    const faqs = [
        { q: "Who can become a Referral Partner?", a: "Everyone. Whether you are a student, resident, consultant, or educator, you can join our mission." },
        { q: "What can I refer?", a: "Printed books, digital editions, app access, and future specialty releases across our entire library." },
        { q: "How are rewards calculated?", a: "Rewards are based on verified referrals and engagement, transparently tracked within your partner portal." },
        { q: "Is this an affiliate scheme?", a: "No. It is a structured referral and advocacy program aligned with Enchiridion's educational mission." }
    ];


    return (
        <div className={styles.page}>
            {/* 0. PAGE GOAL BANNER */}
            <div className={styles.goalBanner}>
                <div className={styles.goalContent}>
                    <blockquote>
                        The goal of the Enchiridion Referral Page is to convert readers, medical students, clinicians, and educators
                        into Enchiridion Referral Partners, enabling them to share trusted medical knowledge and earn impactful rewards.
                    </blockquote>
                </div>
            </div>

            {/* 1. HERO SECTION */}
            <section className={styles.hero}>
                <div className={styles.heroContent}>
                    <p className="eyebrow">Enchiridion Referral Program</p>
                    <h1 className="serif">THIS COULD BE YOU</h1>
                    <p className={styles.heroSubtitle}>Share trusted medical knowledge. Earn rewards. Build impact.</p>
                    <button className={styles.primaryBtn} onClick={scrollToRegistration}>Become a Referral Partner</button>
                </div>
                <div className={styles.heroImage}>
                    <div className={styles.visualContent}>
                        <h3 className="serif">Enchiridion Advocacy</h3>
                        <p>Turning medical knowledge into shared value</p>
                        <div style={{ marginTop: '20px', fontSize: '3rem' }}>📚</div>
                    </div>
                </div>
            </section>

            {/* BENEFIT OVERVIEW */}
            <section className={styles.benefitGrid}>
                {benefits.map((b, i) => (
                    <div key={i} className={styles.benefitItem}>
                        <span>0{i + 1}</span>
                        <h4>{b.title}</h4>
                        <p>{b.text}</p>
                    </div>
                ))}
            </section>

            {/* 2. HOW IT WORKS */}
            <section className={styles.howItWorks}>
                <div className={styles.sectionHeader}>
                    <h2 className="serif">How the Enchiridion Referral Program Works</h2>
                </div>
                <div className={styles.flowContainer}>
                    {[
                        { title: "Share Enchiridion", text: "Use your unique referral link or code to share Enchiridion books and app access." },
                        { title: "Readers Engage", text: "Your referrals purchase books, preorders, or unlock app content." },
                        { title: "You Earn Benefits", text: "Receive commissions, book discounts, early access, or exclusive content." }
                    ].map((step, i) => (
                        <div key={i} className={styles.flowItem}>
                            <div className={styles.flowNum}>{i + 1}</div>
                            <h4>{step.title}</h4>
                            <p>{step.text}</p>
                        </div>
                    ))}
                </div>
            </section>

            {/* 3. THEMED BLOCKS */}
            <section className={styles.themedBlocks}>
                <div className={styles.block}>
                    <div className={styles.blockContent}>
                        <h3 className="serif">KNOWLEDGE & IMPACT</h3>
                        <p>With Enchiridion, you don't just refer products — you help improve how medical knowledge is accessed, structured, and applied.</p>
                    </div>
                    <div className={styles.blockImage}>
                        <div style={{ fontSize: '4rem' }}>📖</div>
                    </div>
                </div>
                <div className={styles.block}>
                    <div className={styles.blockContent}>
                        <h3 className="serif">FLEXIBLE & DIGITAL</h3>
                        <p>Share books and app access online, at your own pace, with no inventory, logistics, or fixed schedule.</p>
                    </div>
                    <div className={styles.blockImage}>
                        <div style={{ fontSize: '4rem' }}>📱</div>
                    </div>
                </div>
                <div className={styles.block}>
                    <div className={styles.blockContent}>
                        <h3 className="serif">A GROWING MEDICAL COMMUNITY</h3>
                        <p>Join students, doctors, educators, and institutions building a shared ecosystem of trusted learning resources.</p>
                    </div>
                    <div className={styles.blockImage}>
                        <div style={{ fontSize: '4rem' }}>⭐</div>
                    </div>
                </div>
            </section>

            {/* 4. CREDIBILITY GRID - Oriflame Style */}
            <section className={styles.credibilitySection}>
                <div className={styles.credibilityGrid}>
                    {/* Row 1 */}
                    <div className={styles.imageTile}>
                        <div className={styles.imagePlaceholder}>
                            <span>🩺</span>
                            <p>Doctor with Tablet</p>
                        </div>
                    </div>
                    <div className={`${styles.statTile} ${styles.statBlue}`}>
                        <span className={styles.bigNum}>10,000+</span>
                        <p>Clinical Topics Covered</p>
                    </div>
                    <div className={`${styles.statTile} ${styles.statTeal}`}>
                        <span className={styles.bigNum}>50+</span>
                        <p>Medical Specialties</p>
                    </div>

                    {/* Row 2 */}
                    <div className={`${styles.statTile} ${styles.statPurple}`}>
                        <span className={styles.bigNum}>100K+</span>
                        <p>Healthcare Professionals Reached</p>
                    </div>
                    <div className={styles.imageTile}>
                        <div className={styles.imagePlaceholder}>
                            <span>👩‍⚕️</span>
                            <p>Medical Students</p>
                        </div>
                    </div>
                    <div className={`${styles.statTile} ${styles.statOrange}`}>
                        <span className={styles.bigNum}>24/7</span>
                        <p>Digital Access Anywhere</p>
                    </div>
                </div>
            </section>

            {/* 5. TESTIMONIALS */}
            <section className={styles.testimonials}>
                <h2 className="serif">REAL USERS. REAL IMPACT.</h2>
                <p>Why they share Enchiridion</p>
                <div className={styles.testimonialGrid}>
                    <div className={styles.testimonialCard}>
                        <blockquote>"Enchiridion made it easier to revise and explain concepts to juniors. Sharing it felt natural — the referral rewards were a bonus."</blockquote>
                        <p>— A., Medical Officer</p>
                    </div>
                    <div className={styles.testimonialCard}>
                        <blockquote>"The ability to refer my study group and earn credits for my next specialty book has been a game changer for my clinical years."</blockquote>
                        <p>— S., Medical Student</p>
                    </div>
                </div>
            </section>

            {/* 6. WELCOME PROGRAM */}
            <section className={styles.introBlock} style={{ backgroundColor: '#fff', border: 'none' }}>
                <div className={styles.containerSmall}>
                    <h2 className="serif" style={{ color: '#000000', fontWeight: 800 }}>Referral Partner Welcome Program</h2>
                    <ul style={{ listStyle: 'none', padding: 0, marginTop: '40px', textAlign: 'left' }}>
                        {[
                            "Free enrollment into the Enchiridion Referral Program",
                            "Starter referral rewards on your first successful referrals",
                            "Early access to new book releases and app features",
                            "Higher rewards during your first referral cycle"
                        ].map((item, i) => (
                            <li key={i} style={{ marginBottom: '15px', display: 'flex', gap: '15px', alignItems: 'center', fontSize: '1.2rem', color: '#000000', fontWeight: 700 }}>
                                <span style={{ color: '#000000', fontWeight: 800 }}>✓</span> {item}
                            </li>
                        ))}
                    </ul>
                </div>
            </section>

            {/* 7. APP INTEGRATION */}
            <section className={styles.faqAppSection}>
                <div className={styles.appBox}>
                    <div>
                        <div className={styles.appIcon}>E</div>
                    </div>
                    <div>
                        <p className="eyebrow" style={{ color: '#000000', fontWeight: 700 }}>The Digital Companion</p>
                        <h2 className="serif">The Enchiridion App</h2>
                        <ul style={{ listStyle: 'none', padding: 0, color: '#000000', fontWeight: 700 }}>
                            <li>• Read and reference on the go</li>
                            <li>• Search across specialties</li>
                            <li>• Updates synced with new editions</li>
                        </ul>
                    </div>
                </div>
            </section>

            {/* 9. BECOME A REFERRAL PARTNER - REGISTRATION SECTION */}
            <section id="become-referral-partner" className={styles.registrationSection}>
                <div className={styles.registrationContainer}>
                    {/* Section Header */}
                    <div className={styles.registrationHeader}>
                        <h1 className="serif">Become an Enchiridion Referral Partner</h1>
                        <h2>Share trusted medical knowledge. Earn rewards. Build impact.</h2>
                        <p>Join the Enchiridion ecosystem by referring doctors, students, and institutions to our books and app. Get a unique referral code, track your impact, and earn exclusive benefits.</p>
                    </div>

                    {/* How It Works - 3 Steps */}
                    <div className={styles.registrationSteps}>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>1</div>
                            <h4>Register</h4>
                            <p>Sign up as an Enchiridion Referral Partner in less than 2 minutes.</p>
                        </div>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>2</div>
                            <h4>Get Your Referral Code</h4>
                            <p>Instantly receive a unique referral code and shareable link.</p>
                        </div>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>3</div>
                            <h4>Earn & Track</h4>
                            <p>Earn rewards, discounts, and early access when people join through you.</p>
                        </div>
                    </div>

                    {/* Registration Form OR Success State */}
                    {!isRegistered ? (
                        <form className={styles.registrationForm} onSubmit={handleSubmit}>
                            <div className={styles.formGrid}>
                                <div className={styles.formGroup}>
                                    <label htmlFor="fullName">Full Name *</label>
                                    <input
                                        type="text"
                                        id="fullName"
                                        name="fullName"
                                        value={formData.fullName}
                                        onChange={handleInputChange}
                                        placeholder="Dr. Jane Smith"
                                        aria-required="true"
                                    />
                                    {formErrors.fullName && <span className={styles.error}>{formErrors.fullName}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="email">Email Address *</label>
                                    <input
                                        type="email"
                                        id="email"
                                        name="email"
                                        value={formData.email}
                                        onChange={handleInputChange}
                                        placeholder="jane@hospital.com"
                                        aria-required="true"
                                    />
                                    {formErrors.email && <span className={styles.error}>{formErrors.email}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="country">Country *</label>
                                    <input
                                        type="text"
                                        id="country"
                                        name="country"
                                        value={formData.country}
                                        onChange={handleInputChange}
                                        placeholder="Nigeria"
                                        aria-required="true"
                                    />
                                    {formErrors.country && <span className={styles.error}>{formErrors.country}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="state">State</label>
                                    <input
                                        type="text"
                                        id="state"
                                        name="state"
                                        value={formData.state}
                                        onChange={handleInputChange}
                                        placeholder="Lagos"
                                    />
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="profession">Profession *</label>
                                    <select
                                        id="profession"
                                        name="profession"
                                        value={formData.profession}
                                        onChange={handleInputChange}
                                        aria-required="true"
                                    >
                                        <option value="">Select your profession</option>
                                        <option value="doctor">Doctor</option>
                                        <option value="student">Medical Student</option>
                                        <option value="educator">Educator</option>
                                        <option value="institution">Institution Representative</option>
                                        <option value="other">Other</option>
                                    </select>
                                    {formErrors.profession && <span className={styles.error}>{formErrors.profession}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="phone">Phone Number *</label>
                                    <input
                                        type="tel"
                                        id="phone"
                                        name="phone"
                                        value={formData.phone}
                                        onChange={handleInputChange}
                                        placeholder="+234 800 000 0000"
                                        aria-required="true"
                                    />
                                    {formErrors.phone && <span className={styles.error}>{formErrors.phone}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="password">Password *</label>
                                    <input
                                        type="password"
                                        id="password"
                                        name="password"
                                        value={formData.password}
                                        onChange={handleInputChange}
                                        placeholder="Min. 6 characters"
                                        aria-required="true"
                                    />
                                    {formErrors.password && <span className={styles.error}>{formErrors.password}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="confirmPassword">Confirm Password *</label>
                                    <input
                                        type="password"
                                        id="confirmPassword"
                                        name="confirmPassword"
                                        value={formData.confirmPassword}
                                        onChange={handleInputChange}
                                        placeholder="Confirm password"
                                        aria-required="true"
                                    />
                                    {formErrors.confirmPassword && <span className={styles.error}>{formErrors.confirmPassword}</span>}
                                </div>
                                <div className={styles.formGroup} style={{ gridColumn: '1 / -1' }}>
                                    <label htmlFor="institution">Institution (Optional)</label>
                                    <input
                                        type="text"
                                        id="institution"
                                        name="institution"
                                        value={formData.institution}
                                        onChange={handleInputChange}
                                        placeholder="University or Hospital Name"
                                    />
                                </div>
                            </div>
                            <button type="submit" className={styles.submitBtn}>Create My Referral Account</button>
                        </form>
                    ) : (
                        <div className={styles.successState}>
                            <div className={styles.successIcon}>✓</div>
                            <h3>Welcome to the Enchiridion Partner Network!</h3>
                            <p>Your referral account has been created successfully.</p>

                            <div className={styles.codeDisplay}>
                                <span className={styles.codeLabel}>Your Referral Code</span>
                                <span className={styles.codeValue}>{referralCode}</span>
                                <button
                                    className={styles.copyBtn}
                                    onClick={() => copyToClipboard(referralCode)}
                                >
                                    {copied ? "Copied!" : "Copy"}
                                </button>
                            </div>

                            <div className={styles.linkDisplay}>
                                <span className={styles.linkLabel}>Your Shareable Link</span>
                                <span className={styles.linkValue}>https://enchiridion.app/ref/{referralCode}</span>
                                <button
                                    className={styles.copyBtn}
                                    onClick={() => copyToClipboard(`https://enchiridion.app/ref/${referralCode}`)}
                                >
                                    Copy Link
                                </button>
                            </div>

                            <div className={styles.shareButtons}>
                                <a
                                    href={`https://wa.me/?text=Join%20Enchiridion%20using%20my%20referral%20code%3A%20${referralCode}%20%E2%80%94%20https%3A%2F%2Fenchiridion.app%2Fref%2F${referralCode}`}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className={styles.shareBtn}
                                >
                                    Share via WhatsApp
                                </a>
                                <a
                                    href={`mailto:?subject=Join%20Enchiridion&body=Join%20Enchiridion%20using%20my%20referral%20code%3A%20${referralCode}%20%E2%80%94%20https%3A%2F%2Fenchiridion.app%2Fref%2F${referralCode}`}
                                    className={styles.shareBtn}
                                >
                                    Share via Email
                                </a>
                            </div>
                        </div>
                    )}

                    {/* Why Become a Partner - Benefits */}
                    <div className={styles.partnerBenefits}>
                        <h3>Why Become a Referral Partner?</h3>
                        <ul>
                            <li>Earn discounts on Enchiridion books and app subscriptions</li>
                            <li>Early access to unreleased specialties</li>
                            <li>Recognition inside the Enchiridion ecosystem</li>
                            <li>Priority access to contributor and reviewer programs</li>
                        </ul>
                    </div>

                    {/* Trust Statement */}
                    <p className={styles.trustStatement}>
                        Enchiridion is a curated medical knowledge ecosystem built by clinicians, educators, and designers. Referral activity is monitored and pre-approved to maintain academic integrity.
                    </p>
                </div>
            </section>

            {/* 10. FAQ */}
            <section className={styles.faqAppSection} style={{ paddingTop: 0 }}>
                <div className={styles.accordionContainer}>
                    <h2 className="serif" style={{ textAlign: 'center', marginBottom: '40px', color: 'var(--color-red)' }}>Frequently Asked Questions</h2>
                    {faqs.map((f, i) => (
                        <Accordion
                            key={i}
                            title={f.q}
                            isOpen={activeAccordion === i}
                            onToggle={() => toggleAccordion(i)}
                        >
                            <p>{f.a}</p>
                        </Accordion>
                    ))}
                </div>
            </section>

            {/* PERSISTENT CTA */}
            <div className={styles.stickyCta}>
                <button className={styles.primaryBtn} onClick={scrollToRegistration}>Become a Referral Partner</button>
            </div>
        </div>
    );
}
