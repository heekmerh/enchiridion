"use client";

import { useState } from "react";
import styles from "./Referral.module.css";
import Accordion from "./Accordion";

export default function Referral() {
    const [code, setCode] = useState("");
    const [activeAccordion, setActiveAccordion] = useState<number | null>(null);
    const [isCopied, setIsCopied] = useState(false);

    const [showShareModal, setShowShareModal] = useState(false);

    const generateCode = () => {
        const newCode = "ENCH-" + Math.random().toString(36).substring(2, 6).toUpperCase() + "-" + Math.random().toString(36).substring(2, 6).toUpperCase();
        setCode(newCode);
        setIsCopied(false);
    };

    const copyToClipboard = () => {
        if (code) {
            navigator.clipboard.writeText(code);
            setIsCopied(true);
            setTimeout(() => setIsCopied(false), 2000);
        }
    };

    const handleShare = async () => {
        const shareData = {
            title: 'Enchiridion Referral',
            text: `Join the Enchiridion medical community with my referral code: ${code}`,
            url: window.location.origin
        };

        if (navigator.share && navigator.canShare(shareData)) {
            try {
                await navigator.share(shareData);
            } catch (err) {
                if (err instanceof Error && err.name !== 'AbortError') {
                    setShowShareModal(true);
                }
            }
        } else {
            setShowShareModal(true);
        }
    };

    const shareVia = (platform: 'twitter' | 'whatsapp' | 'email') => {
        const text = encodeURIComponent(`Join the Enchiridion medical community with my referral code: ${code}`);
        const url = encodeURIComponent(window.location.origin);

        let shareUrl = '';
        if (platform === 'twitter') shareUrl = `https://twitter.com/intent/tweet?text=${text}&url=${url}`;
        if (platform === 'whatsapp') shareUrl = `https://wa.me/?text=${text}%20${url}`;
        if (platform === 'email') shareUrl = `mailto:?subject=Enchiridion Referral&body=${text}%20${url}`;

        window.open(shareUrl, '_blank');
        setShowShareModal(false);
    };

    const toggleAccordion = (index: number) => {
        setActiveAccordion(activeAccordion === index ? null : index);
    };

    return (
        <section id="refer" className={styles.section}>
            <div className={styles.container}>
                {/* 1. Hero Section */}
                <div className={styles.hero}>
                    <p className={styles.eyebrow}>Professional Growth</p>
                    <h2 className="serif">Referral Program — Unlock Exclusive Benefits</h2>
                    <p className={styles.subtitle}>Invite peers, unlock rewards, grow the Enchiridion community.</p>
                </div>

                {/* 2. Referral Code Display (Shows when generated) */}
                <div className={`${styles.codeDisplay} ${code ? styles.hasCode : ""}`}>
                    {code ? (
                        <div className={styles.codeBox}>
                            <span className={styles.label}>Your Unique Credential</span>
                            <div className={styles.codeRow}>
                                <code className={styles.code}>{code}</code>
                                <button onClick={copyToClipboard} className={styles.copyBtn} aria-label="Copy code">
                                    {isCopied ? "Copied!" : (
                                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
                                    )}
                                </button>
                            </div>
                        </div>
                    ) : (
                        <div className={styles.codePlaceholder}>
                            <p>Generate your code below to start participating.</p>
                        </div>
                    )}
                </div>

                {/* 3. Main Content - Sidebar & Accordion Grid */}
                <div className={styles.mainGrid}>
                    {/* Accordion List */}
                    <div className={styles.accordionContainer}>
                        <Accordion
                            title="How the Referral Program Works"
                            isOpen={activeAccordion === 0}
                            onToggle={() => toggleAccordion(0)}
                        >
                            <p>Enchiridion thrives on peer-to-peer knowledge sharing. Our referral program is designed to reward clinicians who help expand our professional network.</p>
                            <ul>
                                <li><strong>Generate:</strong> Create your unique institutional code in one click.</li>
                                <li><strong>Share:</strong> Distribute your code to colleagues, interns, or students.</li>
                                <li><strong>Validate:</strong> Once they sign up and validate their status, both parties are credited.</li>
                                <li><strong>Reward:</strong> Access premium features and specialty updates immediately.</li>
                            </ul>
                        </Accordion>

                        <Accordion
                            title="Who Can Participate"
                            isOpen={activeAccordion === 1}
                            onToggle={() => toggleAccordion(1)}
                        >
                            <p>The program is open to all verified members of the Enchiridion ecosystem:</p>
                            <ul>
                                <li>Current users with active clinical profiles.</li>
                                <li>Students and residents with institutional email addresses.</li>
                                <li>Healthcare practitioners who have downloaded the digital companion.</li>
                            </ul>
                        </Accordion>

                        <Accordion
                            title="Rewards & Benefits"
                            isOpen={activeAccordion === 2}
                            onToggle={() => toggleAccordion(2)}
                        >
                            <p>We provide tangible incentives for both the referrer and the referee:</p>
                            <ul>
                                <li><strong>Premium Access:</strong> Unlock advanced clinical calculators and offline database sync.</li>
                                <li><strong>Educational Credits:</strong> Earn points toward institutional handbook updates.</li>
                                <li><strong>Specialty Previews:</strong> Get early access to "Coming Soon" specialties.</li>
                            </ul>
                        </Accordion>

                        <Accordion
                            title="How to Generate Your Referral Code"
                            isOpen={activeAccordion === 3}
                            onToggle={() => toggleAccordion(3)}
                        >
                            <ol>
                                <li>Navigate to this Referral section on the home page or via the app settings.</li>
                                <li>Click the <strong>"Generate My Referral Code"</strong> button at the bottom of this page.</li>
                                <li>Your unique alphanumeric credential will appear in the display box above.</li>
                                <li>The code is persistent and remains linked to your professional identity.</li>
                            </ol>
                        </Accordion>

                        <Accordion
                            title="How to Use Your Referral Code"
                            isOpen={activeAccordion === 4}
                            onToggle={() => toggleAccordion(4)}
                        >
                            <p>Sharing is seamless across multiple platforms:</p>
                            <ul>
                                <li><strong>On Signup:</strong> New users can enter the code during the initial registration phase.</li>
                                <li><strong>In-App:</strong> Redemption is available under the "Institutional Access" menu.</li>
                                <li><strong>Direct Link:</strong> Sharing the generated link automatically applies the code.</li>
                            </ul>
                        </Accordion>

                        <Accordion
                            title="Terms & Conditions"
                            isOpen={activeAccordion === 5}
                            onToggle={() => toggleAccordion(5)}
                        >
                            <p>Program guidelines for professional conduct:</p>
                            <ul>
                                <li>Codes are intended for personal professional networks only.</li>
                                <li>Public posting on coupon sites is strictly prohibited.</li>
                                <li>Rewards are subject to clinical status validation.</li>
                                <li>Enchiridion reserves the right to modify benefits based on regional availability.</li>
                            </ul>
                        </Accordion>
                    </div>

                    {/* Sidebar Visual Guide */}
                    <div className={styles.sidebar}>
                        <div className={styles.flowCard}>
                            <h4 className={styles.flowTitle}>Quick Flow</h4>
                            <div className={styles.flowItems}>
                                <div className={styles.flowItem}>
                                    <span className={styles.flowNumber}>1</span>
                                    <p>Generate</p>
                                </div>
                                <div className={styles.flowLine}></div>
                                <div className={styles.flowItem}>
                                    <span className={styles.flowNumber}>2</span>
                                    <p>Share</p>
                                </div>
                                <div className={styles.flowLine}></div>
                                <div className={styles.flowItem}>
                                    <span className={styles.flowNumber}>3</span>
                                    <p>Sign Up</p>
                                </div>
                                <div className={styles.flowLine}></div>
                                <div className={styles.flowItem}>
                                    <span className={styles.flowNumber}>4</span>
                                    <p>Reward</p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* 4. CTA Buttons */}
                <div className={styles.actions}>
                    <button onClick={generateCode} className={styles.primaryBtn}>
                        {code ? "Re-generate Code" : "Generate My Referral Code"}
                    </button>
                    <button
                        onClick={handleShare}
                        className={styles.secondaryBtn}
                        disabled={!code}
                    >
                        Share Referral Link
                    </button>
                </div>

                {/* Share Modal Overlay */}
                {showShareModal && (
                    <div className={styles.modalOverlay} onClick={() => setShowShareModal(false)}>
                        <div className={styles.modal} onClick={e => e.stopPropagation()}>
                            <h4 className={styles.modalTitle}>Share Your Referral</h4>
                            <div className={styles.shareGrid}>
                                <button onClick={() => shareVia('twitter')} className={styles.shareOption}>
                                    <span>Twitter</span>
                                </button>
                                <button onClick={() => shareVia('whatsapp')} className={styles.shareOption}>
                                    <span>WhatsApp</span>
                                </button>
                                <button onClick={() => shareVia('email')} className={styles.shareOption}>
                                    <span>Email</span>
                                </button>
                                <button onClick={() => { copyToClipboard(); setShowShareModal(false); }} className={styles.shareOption}>
                                    <span>{isCopied ? "Copied!" : "Copy Link"}</span>
                                </button>
                            </div>
                            <button className={styles.closeBtn} onClick={() => setShowShareModal(false)}>Cancel</button>
                        </div>
                    </div>
                )}
            </div>
        </section>
    );
}
