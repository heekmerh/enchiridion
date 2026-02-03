"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import styles from "./AppSection.module.css";

export default function AppSection() {
    const [platform, setPlatform] = useState<"iOS" | "Android" | "other">("other");

    useEffect(() => {
        const ua = navigator.userAgent.toLowerCase();
        if (/iphone|ipad|ipod/.test(ua)) {
            setPlatform("iOS");
        } else if (/android/.test(ua)) {
            setPlatform("Android");
        }
    }, []);

    const features = [
        { title: "Clinical Protocols", description: "Standardized medical procedures at your fingertips." },
        { title: "Drug Dosing", description: "Accurate dosing calculators for pediatric and adult care." },
        { title: "Offline Access", description: "Reference critical information even without internet." },
        { title: "Regular Updates", description: "Always stay current with the latest medical guidelines." },
    ];

    return (
        <section id="app" className={styles.section}>
            <div className={styles.appContainer}>
                <div className={styles.logoCol}>
                    <div className={styles.appIconWrapper}>
                        <span>E</span>
                    </div>
                </div>

                <div className={styles.detailCol}>
                    <p className={styles.eyebrow}>The Digital Companion</p>
                    <h2 className="serif">Clinical Authority, Everywhere.</h2>
                    <p className={styles.description}>
                        The Enchiridion digital ecosystem ensures you have the
                        most accurate medical data at the point of care. Designed
                        to be the definitive bedside companion for modern clinicians.
                    </p>

                    <div className={styles.features}>
                        {features.map((f, i) => (
                            <div key={i} className={styles.feature}>
                                <div className={styles.featureIcon}>
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M20 6 9 17l-5-5" /></svg>
                                </div>
                                <div>
                                    <h4>{f.title}</h4>
                                    <p>{f.description}</p>
                                </div>
                            </div>
                        ))}
                    </div>

                    <div className={styles.downloadSection}>
                        <p>Immediate Point-Of-Care Access</p>
                        <div className={styles.badges}>
                            <a href="#" className={styles.badge} target="_blank">
                                App Store
                            </a>
                            <a href="#" className={styles.badge} target="_blank">
                                Play Store
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
