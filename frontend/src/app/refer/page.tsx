"use client";

import { useState, useEffect, useRef } from "react";
import Image from "next/image";
import Link from "next/link";
import styles from "./ReferralPage.module.css";
import Accordion from "@/components/Accordion";
import DistributorForm from "@/components/DistributorForm";
import GlobalToast from "@/components/GlobalToast";
import GoogleButton from "@/components/GoogleButton";
import { authErrorMessage, PENDING_MARKETING_KEY, signInWithGoogle, supabase, TERMS_VERSION } from "@/lib/supabase";

export default function ReferralPage() {
    const [activeAccordion, setActiveAccordion] = useState<number | null>(null);
    const [heroBtnOutOfView, setHeroBtnOutOfView] = useState(false);
    const [reachedWelcomeProgram, setReachedWelcomeProgram] = useState(false);
    const staticBtnRef = useRef<HTMLButtonElement>(null);
    const welcomeProgramRef = useRef<HTMLElement>(null);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const showFloatingBtn = heroBtnOutOfView && !reachedWelcomeProgram;

    useEffect(() => {
        const observer = new IntersectionObserver(
            ([entry]) => {
                // If the static button is NOT intersecting (out of view), show the floating button
                setHeroBtnOutOfView(!entry.isIntersecting);
            },
            { threshold: 0.1 }
        );

        if (staticBtnRef.current) {
            observer.observe(staticBtnRef.current);
        }

        return () => {
            if (staticBtnRef.current) {
                observer.unobserve(staticBtnRef.current);
            }
        };
    }, []);

    useEffect(() => {
        // Once the user scrolls to the Welcome Program section, the floating
        // "Become a Referral Partner" tab is redundant (registration is next) and stays hidden.
        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.isIntersecting) setReachedWelcomeProgram(true);
            },
            { threshold: 0.1 }
        );

        if (welcomeProgramRef.current) {
            observer.observe(welcomeProgramRef.current);
        }

        return () => {
            if (welcomeProgramRef.current) {
                observer.unobserve(welcomeProgramRef.current);
            }
        };
    }, []);

    useEffect(() => {
        const onOpen = () => setIsModalOpen(true);
        const onClose = () => setIsModalOpen(false);

        window.addEventListener("partner-login-modal-open", onOpen);
        window.addEventListener("partner-login-modal-close", onClose);

        return () => {
            window.removeEventListener("partner-login-modal-open", onOpen);
            window.removeEventListener("partner-login-modal-close", onClose);
        };
    }, []);
    const [isRegistered, setIsRegistered] = useState(false);
    const [termsAccepted, setTermsAccepted] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
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
        institution: "",
        acceptTerms: false,
        marketingOptIn: false
    });
    const [formErrors, setFormErrors] = useState<Record<string, string>>({});
    const [apiError, setApiError] = useState<string | null>(null);
    const [referrerName, setReferrerName] = useState<string | null>(null);

    const toggleAccordion = (index: number) => {
        setActiveAccordion(activeAccordion === index ? null : index);
    };

    const generateReferralCode = (name: string) => {
        const initials = name.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2) || "RE";
        const randomDigits = Math.floor(1000 + Math.random() * 9000); // 4 random digits
        return `${initials}${randomDigits}`;
    };

    const scrollToRegistration = () => {
        const element = document.getElementById("become-referral-partner");
        if (element) {
            element.scrollIntoView({ behavior: "smooth" });
        }
    };

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
        const { name, value } = e.target;
        const isCheckbox = e.target instanceof HTMLInputElement && e.target.type === "checkbox";
        setFormData(prev => ({ ...prev, [name]: isCheckbox ? (e.target as HTMLInputElement).checked : value }));
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
        if (!formData.acceptTerms) errors.acceptTerms = "Please accept the Terms and Privacy Policy";
        setFormErrors(errors);
        if (Object.keys(errors).length) requestAnimationFrame(() => document.getElementById("registration-errors")?.focus());
        return Object.keys(errors).length === 0;
    };

    useEffect(() => {
        const urlParams = new URLSearchParams(window.location.search);
        const ref = urlParams.get("ref") || localStorage.getItem("enchiridion_ref");

        if (ref) {
            fetch(`/api/referral/referrer-name?refCode=${ref}`)
                .then(res => res.json())
                .then(data => {
                    if (data.name) setReferrerName(data.name);
                })
                .catch(err => console.error("Failed to fetch referrer name:", err));
        }
    }, []);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setApiError(null);

        if (validateForm()) {
            setIsLoading(true);
            const code = generateReferralCode(formData.fullName);

            // Get referral code from storage if user was referred
            const referredBy = localStorage.getItem("enchiridion_ref") || "";

            try {
                const { error } = await supabase().auth.signUp({
                    email: formData.email.trim(),
                    password: formData.password,
                    options: {
                        emailRedirectTo: `${window.location.origin}/verify-email`,
                        data: {
                            name: formData.fullName.trim(),
                            display_name: formData.fullName.trim().split(" ")[0],
                            referral_code: code,
                            referred_by: referredBy,
                            country: formData.country,
                            state: formData.state,
                            profession: formData.profession,
                            phone: formData.phone,
                            institution: formData.institution,
                            signup_source: "web",
                            terms_version: TERMS_VERSION,
                            marketing_opt_in: formData.marketingOptIn ? "true" : "false",
                        },
                    },
                });
                if (error) throw error;
                localStorage.setItem("enchiridion_reg_email", formData.email);
                setReferralCode(code);
                setIsRegistered(true);
            } catch (err) {
                setApiError(authErrorMessage(err, "Registration failed. Email might already be in use."));
            } finally {
                setIsLoading(false);
            }
        }
    };

    const handleGoogleSignup = async () => {
        setApiError(null);
        if (!formData.acceptTerms) {
            setFormErrors(prev => ({ ...prev, acceptTerms: "Please accept the Terms and Privacy Policy" }));
            return;
        }
        localStorage.setItem(PENDING_MARKETING_KEY, formData.marketingOptIn ? "true" : "false");
        try {
            await signInWithGoogle("/dashboard");
        } catch (err) {
            setApiError(authErrorMessage(err, "Google sign-up could not be started."));
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

    const referralTerms = [
        {
            title: "1. Becoming a Referral Partner",
            body: [
                "To activate your Referral Partner account, you must submit one review video of the Enchiridion app or an Enchiridion handbook. The video should be a genuine, first-person review of your experience using the product.",
                "Your referral code and dashboard access are provisional until this review video is submitted and approved. Enchiridion may request a reasonable resubmission if the video does not meet basic quality or authenticity standards.",
            ],
        },
        {
            title: "2. Partner Earnings",
            body: [
                "You earn 20% commission on app subscription payments made by any user who subscribes using your referral code.",
                "You earn 20% commission on book purchases made using your referral code.",
                "Commission on a given referred user's purchases is payable for 6 months from the date that user first signs up with your referral code. Purchases made by that user after this 6-month window do not generate further commission.",
                "Commissions are calculated on amounts actually collected by Enchiridion, net of refunds, chargebacks, or failed payments.",
            ],
        },
        {
            title: "3. Referee Benefits",
            body: [
                "New users who enter your referral code receive ₦500 off their app subscription and a 10% discount on book purchases.",
                "Both discounts are one-time only: the ₦500 discount applies solely to the referee's first app subscription payment, and the 10% discount applies solely to their first book purchase. Subsequent payments and purchases are charged at full price.",
            ],
        },
        {
            title: "4. Review Video License",
            body: [
                "By submitting a review video, you grant the Enchiridion Network a worldwide, royalty-free, perpetual license to use, edit, reproduce, and distribute the video — in whole or in part — across its website, app, social media, and other marketing or promotional channels, with or without attribution.",
            ],
        },
        {
            title: "5. Eligibility & Conduct",
            body: [
                "Referral codes are personal, non-transferable, and intended for sharing within your genuine professional and academic network.",
                "You may not publicly post your referral code on coupon, deal, or cashback sites, or use paid advertising to promote it without written permission from Enchiridion.",
                "You may not use your own referral code to purchase books or subscriptions for yourself (\"self-referral\"); such purchases are not eligible for commission and may be reversed.",
                "Enchiridion reserves the right to withhold, claw back, or cancel commissions, and to suspend or terminate a Partner account, in cases of fraud, abuse, or violation of these Terms.",
            ],
        },
        {
            title: "6. General",
            body: [
                "Enchiridion may update these Terms, commission rates, or discount amounts at any time; continued participation in the program after a change constitutes acceptance of the updated Terms.",
                "You are responsible for any taxes applicable to the rewards or commissions you earn.",
                "These Referral Partner Terms are in addition to, and do not replace, the general Enchiridion Terms of Use and Privacy Policy.",
            ],
        },
    ];

    const handleAcceptReferralTerms = () => {
        if (!formData.acceptTerms) {
            setFormErrors(prev => ({ ...prev, acceptTerms: "Please check the box to agree to the Referral Partner Terms & Conditions." }));
            requestAnimationFrame(() => document.getElementById("referral-terms-error")?.focus());
            return;
        }
        setTermsAccepted(true);
    };

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
                    <p className="eyebrow" style={{ color: 'var(--color-orange)', fontWeight: 700 }}>Enchiridion Network</p>
                    <h1 className="serif" style={{ fontSize: 'clamp(2.5rem, 8vw, 4rem)', marginBottom: '16px' }}>
                        Your Journey to <br />Impact Starts Here.
                    </h1>
                    <p className={styles.heroSubtitle}>
                        {referrerName ? (
                            <>You’ve been invited by <strong>{referrerName}</strong> to join the Enchiridion Network.</>
                        ) : (
                            "Join the Enchiridion Network of medical professionals and educators."
                        )}
                    </p>
                    {(!isRegistered && !isModalOpen) && (
                        <button
                            ref={staticBtnRef}
                            className={`${styles.primaryBtn} ${styles.staticReferralCta}`}
                            onClick={scrollToRegistration}
                        >
                            Get Started Now
                        </button>
                    )}
                </div>
                <div className={styles.heroImage}>
                    <img
                        src="/Gemini_Generated_Image_5t78u25t78u25t78.png"
                        alt="Diverse group of healthcare professionals standing together, representing medical advocacy and knowledge sharing"
                        className={styles.advocacyImage}
                    />
                </div>
            </section>

            {/* WHY JOIN US? */}
            <section aria-label="Partner benefits" className={styles.benefitGrid}>
                <div className={styles.benefitItem}>
                    <span>01</span>
                    <h2>Become a Partner</h2>
                    <p>Help us scale and earn as you grow. Shared knowledge, shared rewards.</p>
                </div>
                <div className={styles.benefitItem}>
                    <span>02</span>
                    <h2>Become a Distributor</h2>
                    <p>Take control of your income and distribution. Higher tiers, higher impact.</p>
                </div>
                <div className={styles.benefitItem}>
                    <span>03</span>
                    <h2>Get the Book</h2>
                    <p>Unlock the full Enchiridion blueprint. 50% faster growth for you and your network.</p>
                </div>
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
                            <h3>{step.title}</h3>
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
                        <p>With Enchiridion, you don&apos;t just refer products — you help improve how medical knowledge is accessed, structured, and applied.</p>
                    </div>
                    <div className={styles.blockImage}>
                        <img
                            src="/Gemini_Generated_Image_mrv5itmrv5itmrv5.png"
                            alt="Medical knowledge and impact visual"
                            className={styles.impactImage}
                        />
                    </div>
                </div>
                <div className={styles.block}>
                    <div className={styles.blockContent}>
                        <h3 className="serif">FLEXIBLE & DIGITAL</h3>
                        <p>Share books and app access online, at your own pace, with no inventory, logistics, or fixed schedule.</p>
                    </div>
                    <div className={styles.blockImage}>
                        <img
                            src="/image (3) (1).png"
                            alt="Flexible and digital medical learning"
                            className={styles.digitalImage}
                        />
                    </div>
                </div>
                <div className={styles.block}>
                    <div className={styles.blockContent}>
                        <h3 className="serif">A GROWING MEDICAL COMMUNITY</h3>
                        <p>Join students, doctors, educators, and institutions building a shared ecosystem of trusted learning resources.</p>
                    </div>
                    <div className={styles.blockImage}>
                        <img
                            src="/Gemini_Generated_Image_gf85aagf85aagf85.png"
                            alt="Growing medical community"
                            className={styles.communityImage}
                        />
                    </div>
                </div>
            </section>

            {/* 4. CREDIBILITY GRID - Oriflame Style */}
            <section className={styles.credibilitySection}>
                <div className={styles.credibilityGrid}>
                    {/* Row 1 */}
                    <div className={styles.imageTile}>
                        <img
                            src="/doctor-with-tablet.png"
                            alt="Doctor using a tablet in a clinical setting"
                            className={styles.tileImage}
                        />
                    </div>
                    <div className={`${styles.statTile} ${styles.statBlue}`}>
                        <span className={styles.bigNum}>10,000+</span>
                        <p>Clinical Topics Covered</p>
                    </div>
                    <div className={styles.imageTile}>
                        <img
                            src="/specialties-visual.png"
                            alt="Visual representation of medical specialties"
                            className={styles.tileImage}
                        />
                        <div className={styles.tileLabel}>50+ Specialties</div>
                    </div>

                    {/* Row 2 */}
                    <div className={`${styles.statTile} ${styles.statPurple}`}>
                        <span className={styles.bigNum}>100K+</span>
                        <p>Healthcare Professionals Reached</p>
                    </div>
                    <div className={styles.imageTile}>
                        <img
                            src="/medical-students-visual.png"
                            alt="Medical students studying together"
                            className={styles.tileImage}
                        />
                        <div className={styles.tileLabel}>Medical Students</div>
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
                        <blockquote>&quot;Enchiridion made it easier to revise and explain concepts to juniors. Sharing it felt natural — the referral rewards were a bonus.&quot;</blockquote>
                        <p>— A., Medical Officer</p>
                    </div>
                    <div className={styles.testimonialCard}>
                        <blockquote>&quot;The ability to refer my study group and earn credits for my next specialty book has been a game changer for my clinical years.&quot;</blockquote>
                        <p>— S., Medical Student</p>
                    </div>
                </div>
            </section>

            {/* 6. WELCOME PROGRAM */}
            <section ref={welcomeProgramRef} className={styles.introBlock} style={{ backgroundColor: '#fff', border: 'none' }}>
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
                        <div className={styles.appIcon}>
                            <Image
                                src="/Gemini_Generated_Image_59zt2r59zt2r59zt (1).png"
                                alt="Enchiridion App Logo"
                                width={320}
                                height={320}
                                className={styles.appIconImg}
                            />
                        </div>
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

                    {/* How It Works - 4 Steps */}
                    <div className={styles.registrationSteps}>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>1</div>
                            <h3>Register</h3>
                            <p>Sign up as an Enchiridion Referral Partner in less than 2 minutes.</p>
                        </div>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>2</div>
                            <h3>Get Your Referral Code</h3>
                            <p>Instantly receive a unique referral code and shareable link.</p>
                        </div>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>3</div>
                            <h3>Send Your Review Video</h3>
                            <p>
                                Send your review video to our WhatsApp number{" "}
                                <a href="https://wa.me/2348057442660" target="_blank" rel="noopener noreferrer">+234 805 744 2660</a>{" "}
                                along with your referral code, or tag us on Instagram and TikTok{" "}
                                <a href="https://www.instagram.com/enchiridion.md/" target="_blank" rel="noopener noreferrer">@enchiridion.md</a>.
                            </p>
                        </div>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>4</div>
                            <h3>Earn & Track</h3>
                            <p>Earn rewards, discounts, and early access when people join through you.</p>
                        </div>
                    </div>

                    {/* Terms Gate, Registration Form, OR Success State */}
                    {!isRegistered ? (
                        !termsAccepted ? (
                            <div className={styles.termsGate} id="referral-terms">
                                <Accordion title="Referral Partner Terms & Conditions">
                                    <p className={styles.termsIntro}>Please read the following before registering as an Enchiridion Referral Partner.</p>
                                    {referralTerms.map((section) => (
                                        <div key={section.title} className={styles.termsSection}>
                                            <h4>{section.title}</h4>
                                            {section.body.map((paragraph, i) => (
                                                <p key={i}>{paragraph}</p>
                                            ))}
                                        </div>
                                    ))}
                                </Accordion>
                                <label className={styles.termsCheckboxLabel}>
                                    <input
                                        type="checkbox"
                                        checked={formData.acceptTerms}
                                        aria-invalid={!!formErrors.acceptTerms}
                                        aria-describedby={formErrors.acceptTerms ? "referral-terms-error" : undefined}
                                        onChange={(e) => {
                                            setFormData(prev => ({ ...prev, acceptTerms: e.target.checked }));
                                            if (formErrors.acceptTerms) setFormErrors(prev => ({ ...prev, acceptTerms: "" }));
                                        }}
                                    />
                                    <span>
                                        I have read and agree to the Referral Partner Terms &amp; Conditions above, the Enchiridion{" "}
                                        <a href="/terms" target="_blank">Terms and Conditions</a> and <a href="/privacy" target="_blank">Privacy Policy</a>. *
                                    </span>
                                </label>
                                {formErrors.acceptTerms && (
                                    <span id="referral-terms-error" tabIndex={-1} role="alert" className={styles.error}>
                                        {formErrors.acceptTerms}
                                    </span>
                                )}
                                <button type="button" className={styles.submitBtn} onClick={handleAcceptReferralTerms}>
                                    Agree &amp; Continue to Registration
                                </button>
                            </div>
                        ) : (
                        <form className={styles.registrationForm} onSubmit={handleSubmit}>
                            {Object.keys(formErrors).length > 0 && (
                                <div id="registration-errors" tabIndex={-1} role="alert" className="error-summary">
                                    <h3>Check your account details</h3>
                                    <ul>{Object.entries(formErrors).map(([field, message]) => (
                                        <li key={field}><a href={`#${field}`} onClick={event => { event.preventDefault(); document.getElementById(field)?.focus(); }}>{message}</a></li>
                                    ))}</ul>
                                </div>
                            )}
                            <div className={styles.formGrid}>
                                <div className={styles.formGroup}>
                                    <label htmlFor="fullName">Full Name *</label>
                                    <input
                                        type="text"
                                        id="fullName" autoComplete="name"
                                        aria-invalid={!!formErrors.fullName}
                                        aria-describedby={formErrors.fullName ? "registration-fullName-error" : undefined}
                                        name="fullName"
                                        value={formData.fullName}
                                        onChange={handleInputChange}
                                        placeholder="Dr. Jane Smith"
                                        aria-required="true"
                                    />
                                    {formErrors.fullName && <span id="registration-fullName-error" className={styles.error}>{formErrors.fullName}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="email">Email Address *</label>
                                    <input
                                        type="email"
                                        id="email" autoComplete="email"
                                        aria-invalid={!!formErrors.email}
                                        aria-describedby={formErrors.email ? "registration-email-error" : undefined}
                                        name="email"
                                        value={formData.email}
                                        onChange={handleInputChange}
                                        placeholder="jane@hospital.com"
                                        aria-required="true"
                                    />
                                    {formErrors.email && <span id="registration-email-error" className={styles.error}>{formErrors.email}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="country">Country *</label>
                                    <input
                                        type="text"
                                        id="country" autoComplete="country-name"
                                        aria-invalid={!!formErrors.country}
                                        aria-describedby={formErrors.country ? "registration-country-error" : undefined}
                                        name="country"
                                        value={formData.country}
                                        onChange={handleInputChange}
                                        placeholder="Nigeria"
                                        aria-required="true"
                                    />
                                    {formErrors.country && <span id="registration-country-error" className={styles.error}>{formErrors.country}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="state">State</label>
                                    <input
                                        type="text"
                                        id="state" autoComplete="address-level1"
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
                                        aria-invalid={!!formErrors.profession}
                                        aria-describedby={formErrors.profession ? "registration-profession-error" : undefined}
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
                                    {formErrors.profession && <span id="registration-profession-error" className={styles.error}>{formErrors.profession}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="phone">Phone Number *</label>
                                    <input
                                        type="tel"
                                        id="phone" autoComplete="tel"
                                        aria-invalid={!!formErrors.phone}
                                        aria-describedby={formErrors.phone ? "registration-phone-error" : undefined}
                                        name="phone"
                                        value={formData.phone}
                                        onChange={handleInputChange}
                                        placeholder="+234 800 000 0000"
                                        aria-required="true"
                                    />
                                    {formErrors.phone && <span id="registration-phone-error" className={styles.error}>{formErrors.phone}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="password">Password *</label>
                                    <input
                                        type="password"
                                        id="password" autoComplete="new-password"
                                        aria-invalid={!!formErrors.password}
                                        aria-describedby={formErrors.password ? "registration-password-error" : undefined}
                                        name="password"
                                        value={formData.password}
                                        onChange={handleInputChange}
                                        placeholder="Min. 6 characters"
                                        aria-required="true"
                                    />
                                    {formErrors.password && <span id="registration-password-error" className={styles.error}>{formErrors.password}</span>}
                                </div>
                                <div className={styles.formGroup}>
                                    <label htmlFor="confirmPassword">Confirm Password *</label>
                                    <input
                                        type="password"
                                        id="confirmPassword" autoComplete="new-password"
                                        aria-invalid={!!formErrors.confirmPassword}
                                        aria-describedby={formErrors.confirmPassword ? "registration-confirmPassword-error" : undefined}
                                        name="confirmPassword"
                                        value={formData.confirmPassword}
                                        onChange={handleInputChange}
                                        placeholder="Confirm password"
                                        aria-required="true"
                                    />
                                    {formErrors.confirmPassword && <span id="registration-confirmPassword-error" className={styles.error}>{formErrors.confirmPassword}</span>}
                                </div>
                                <div className={styles.formGroup} style={{ gridColumn: '1 / -1' }}>
                                    <label htmlFor="institution">Institution (Optional)</label>
                                    <input
                                        type="text"
                                        id="institution" autoComplete="organization"
                                        name="institution"
                                        value={formData.institution}
                                        onChange={handleInputChange}
                                        placeholder="University or Hospital Name"
                                    />
                                </div>
                                <div className={styles.formGroup} style={{ gridColumn: '1 / -1' }}>
                                    <label style={{ display: 'flex', gap: '10px', alignItems: 'flex-start', fontWeight: 500 }}>
                                        <input type="checkbox" name="marketingOptIn" checked={formData.marketingOptIn} onChange={handleInputChange} style={{ width: 'auto', marginTop: '6px' }} />
                                        <span>Email me Enchiridion offers, including Premium plans. Optional; unsubscribe any time. Account and security emails are sent regardless.</span>
                                    </label>
                                </div>
                            </div>
                            <button type="submit" className={styles.submitBtn} disabled={isLoading}>
                                {isLoading ? "Creating Account..." : "Create My Referral Account"}
                            </button>
                            {apiError && <p role="alert" className={styles.error} style={{ textAlign: 'center', marginTop: '15px' }}>{apiError}</p>}
                            <GoogleButton onClick={handleGoogleSignup} disabled={isLoading}
                                note="Tick the Terms box above first. Your Google name and email are used for your account." />
                        </form>
                        )
                    ) : (
                        <div role="status" className={styles.successState}>
                            <div className={styles.successIcon}>✓</div>
                            <h3>Welcome to the Inner Circle, {formData.fullName.split(' ')[0]}!</h3>
                            <p style={{ fontSize: '1.2rem', marginBottom: '24px' }}>
                                We&apos;ve sent an eight-digit verification code to <b>{formData.email}</b>. Select Verify My Email below and enter that code to activate your account. The same account works on the website and in the Enchiridion app.
                            </p>

                            <Link href="/verify-email" className={styles.primaryBtn}>
                                Verify My Email
                            </Link>

                            <div className={styles.onboardingSteps}>
                                <div className={styles.onboardingCard}>
                                    <h3>Register as a Distributor</h3>
                                    <p>Unlock higher earning tiers and take control of your distribution.</p>
                                    <span className={styles.badge}>Action Required</span>
                                </div>
                                <div className={styles.onboardingCard}>
                                    <h3>Order the Book</h3>
                                    <p>Get the physical copy delivered. Physical tools for a digital world.</p>
                                    <span className={styles.badgeHighlight}>5 Points Value</span>
                                </div>
                            </div>

                            <div className={styles.inviteInfo} style={{ background: '#f8fafc', padding: '24px', borderRadius: '12px', margin: '24px 0', textAlign: 'left', border: '1px solid #e2e8f0' }}>
                                <h3 style={{ color: '#1e293b', marginBottom: '12px' }}>Start Building Your Network</h3>
                                <ul style={{ listStyle: 'none', padding: 0 }}>
                                    <li style={{ marginBottom: '8px', color: '#000000' }}>• Earn <b>10 Naira</b> for every verified friend who joins.</li>
                                    <li style={{ marginBottom: '8px', color: '#000000' }}>• Earn <b>500 Naira</b> for every verified book purchase.</li>
                                    <li style={{ marginBottom: '8px', color: '#000000' }}>• <b>₦2,000 Bonus</b> after 50 confirmed referrals.</li>
                                    <li style={{ marginBottom: '8px', color: '#000000' }}>• <b>₦5,000 Bonus</b> after 100 confirmed referrals.</li>
                                </ul>
                            </div>

                            <div className={styles.codeDisplay}>
                                <span className={styles.codeLabel}>Your Personal Referral Code</span>
                                <span className={styles.codeValue}>{referralCode}</span>
                                <button className={styles.copyBtn} onClick={() => copyToClipboard(referralCode)}>
                                    {copied ? "Copied!" : "Copy Code"}
                                </button>
                            </div>

                            <div className={styles.shareButtons}>
                                <button
                                    className={styles.primaryBtn}
                                    style={{ width: '100%', marginBottom: '20px' }}
                                    onClick={() => window.location.hash = "#login"}
                                >
                                    Login to Partner Dashboard
                                </button>
                                <div style={{ display: 'flex', gap: '10px' }}>
                                    <a
                                        href={`https://wa.me/?text=${encodeURIComponent(`Hey! I’ve been using these Concise Medical Handbooks from Enchiridion—they are incredibly practical for students and clinicians. Plus, check out the official Book—it’s a game-changer!\n\nJoin here: https://enchiridion.site/refer?ref=${referralCode}`)}`}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className={styles.shareBtn}
                                        style={{ flex: 1, textAlign: 'center' }}
                                    >
                                        WhatsApp
                                    </a>
                                </div>
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

            {/* 10. BECOME A DISTRIBUTOR - SECTION */}
            <section id="become-distributor" className={styles.distributorSection}>
                <div className={styles.registrationContainer}>
                    <div className={styles.registrationHeader}>
                        <h1 className="serif">Become an Enchiridion Distributor</h1>
                        <h2>Unlock scale. Manage territories. Earn wholesale margins.</h2>
                        <p>Our Distributor program is for those ready to take leadership in their regions. Distributors manage bulk orders, institutional partnerships, and local supply chains.</p>
                    </div>

                    <div className={styles.registrationSteps}>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>1</div>
                            <h3>Apply</h3>
                            <p>Submit your application with your location and contact details.</p>
                        </div>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>2</div>
                            <h3>Consultation</h3>
                            <p>A Regional Director will contact you to discuss territorial goals.</p>
                        </div>
                        <div className={styles.regStep}>
                            <div className={styles.regStepIcon}>3</div>
                            <h3>Launch</h3>
                            <p>Place your first wholesale order and start distributing in your region.</p>
                        </div>
                    </div>

                    <div className={styles.distributorFormWrapper}>
                        <DistributorForm />
                    </div>
                </div>
            </section>


            {/* 11. FAQ */}
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
            {(!isRegistered && !isModalOpen) && (
                <div className={`${styles.floatingReferralCta} ${showFloatingBtn ? styles.visible : styles.hidden}`}>
                    <button className={styles.primaryBtn} onClick={scrollToRegistration}>Become a Referral Partner</button>
                </div>
            )}
            <GlobalToast />
        </div>
    );
}
