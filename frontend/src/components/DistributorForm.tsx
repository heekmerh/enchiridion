"use client";

import { useState } from "react";
import styles from "./DistributorForm.module.css";

const states = [
    "Abia", "Adamawa", "Akwa Ibom", "Anambra", "Bauchi", "Bayelsa", "Benue", "Borno",
    "Cross River", "Delta", "Ebonyi", "Edo", "Ekiti", "Enugu", "Gombe", "Imo",
    "Jigawa", "Kaduna", "Kano", "Katsina", "Kebbi", "Kogi", "Kwara", "Lagos",
    "Nasarawa", "Niger", "Ogun", "Ondo", "Osun", "Oyo", "Plateau", "Rivers",
    "Sokoto", "Taraba", "Yobe", "Zamfara", "FCT (Abuja)"
];

export default function DistributorForm() {
    const [isLoading, setIsLoading] = useState(false);
    const [isSubmitted, setIsSubmitted] = useState(false);
    const [formShake, setFormShake] = useState(false);
    const [showErrorHint, setShowErrorHint] = useState(false);
    const [showTermsModal, setShowTermsModal] = useState(false);
    const [acceptedTerms, setAcceptedTerms] = useState(false);
    const [formData, setFormData] = useState({
        name: "",
        phone: "",
        whatsapp: "",
        location: "",
        sameAsPhone: false
    });

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!acceptedTerms) {
            setFormShake(true);
            setShowErrorHint(true);
            setTimeout(() => setFormShake(false), 500);
            return;
        }

        const token = localStorage.getItem("enchiridion_token");
        const refCode = localStorage.getItem("enchiridion_user_ref") || localStorage.getItem("enchiridion_ref");

        console.log("DEBUG: Submitting distributor lead. RefCode:", refCode, "Token present:", !!token);

        setIsLoading(true);
        try {
            const res = await fetch("/api/referral/distributor-lead", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    ...(token ? { "Authorization": `Bearer ${token}` } : {})
                },
                body: JSON.stringify({
                    name: formData.name,
                    phone: formData.phone,
                    whatsapp: formData.sameAsPhone ? formData.phone : formData.whatsapp,
                    location: formData.location,
                    refCode: refCode
                })
            });
            if (res.ok) {
                setIsSubmitted(true);
            }
        } catch (err) {
            console.error("Submission failed:", err);
        } finally {
            setIsLoading(false);
        }
    };

    if (isSubmitted) {
        return (
            <div className={styles.successState}>
                <div className={styles.successIcon}>✓</div>
                <h3>Application Received</h3>
                <p>One of our Regional Directors will contact you via WhatsApp/Phone shortly.</p>
            </div>
        );
    }

    return (
        <div className={styles.formContainer}>
            <form
                className={`${styles.leadForm} ${formShake ? styles.shake : ""}`}
                onSubmit={handleSubmit}
            >
                <div className={styles.formField}>
                    <label>Full Name</label>
                    <input
                        type="text"
                        required
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        placeholder="Dr. John Smith"
                    />
                </div>
                <div className={styles.formField}>
                    <label>Phone Number</label>
                    <input
                        type="tel"
                        required
                        value={formData.phone}
                        onChange={(e) => {
                            const val = e.target.value;
                            setFormData(prev => ({
                                ...prev,
                                phone: val,
                                whatsapp: prev.sameAsPhone ? val : prev.whatsapp
                            }));
                        }}
                        placeholder="080 1234 5678"
                    />
                </div>
                <div className={styles.checkboxField}>
                    <input
                        type="checkbox"
                        id="sameAsPhone"
                        checked={formData.sameAsPhone}
                        onChange={(e) => {
                            const checked = e.target.checked;
                            setFormData(prev => ({
                                ...prev,
                                sameAsPhone: checked,
                                whatsapp: checked ? prev.phone : prev.whatsapp
                            }));
                        }}
                    />
                    <label htmlFor="sameAsPhone">WhatsApp same as Phone</label>
                </div>
                {!formData.sameAsPhone && (
                    <div className={styles.formField}>
                        <label>WhatsApp Number</label>
                        <input
                            type="tel"
                            required
                            value={formData.whatsapp}
                            onChange={(e) => setFormData({ ...formData, whatsapp: e.target.value })}
                            placeholder="080 1234 5678"
                        />
                    </div>
                )}
                <div className={styles.formField}>
                    <label>Location (State)</label>
                    <select
                        required
                        value={formData.location}
                        onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                    >
                        <option value="">Select State</option>
                        {states.map(s => <option key={s} value={s}>{s}</option>)}
                    </select>
                </div>
                <div className={styles.termsField}>
                    <div className={styles.checkboxWrapper}>
                        <input
                            type="checkbox"
                            id="acceptedTerms"
                            checked={acceptedTerms}
                            onChange={(e) => {
                                setAcceptedTerms(e.target.checked);
                                if (e.target.checked) setShowErrorHint(false);
                            }}
                        />
                        <label htmlFor="acceptedTerms">
                            I agree to the Enchiridion Distributor <button type="button" className={styles.termsLink} onClick={() => setShowTermsModal(true)}>Terms & Conditions</button>.
                        </label>
                    </div>
                    {showErrorHint && <span className={styles.errorHint}>Please accept the terms to proceed.</span>}
                </div>
                <button
                    type="submit"
                    className={styles.submitBtn}
                    disabled={isLoading || !acceptedTerms}
                >
                    {isLoading ? "Submitting..." : "Submit Application"}
                </button>
            </form>

            {showTermsModal && (
                <div className={styles.modalOverlay} onClick={() => setShowTermsModal(false)}>
                    <div className={styles.termsModal} onClick={(e) => e.stopPropagation()}>
                        <div className={styles.modalHeader}>
                            <h2>Distributor Terms & Conditions</h2>
                            <button className={styles.closeModal} onClick={() => setShowTermsModal(false)}>&times;</button>
                        </div>
                        <div className={styles.modalBody}>
                            <div className={styles.termsContent}>
                                <h3>1. Minimum Order Quantity (MOQ)</h3>
                                <p>Distributors must maintain a minimum opening order of 10 copies of the Enchiridion to qualify for wholesale pricing.</p>

                                <h3>2. Pricing Integrity</h3>
                                <p>To maintain market stability, distributors agree not to retail the book below the Manufacturer’s Suggested Retail Price (MSRP).</p>

                                <h3>3. Territory</h3>
                                <p>This agreement grants a non-exclusive right to distribute within the specified Location provided in the application.</p>

                                <h3>4. Payment Terms</h3>
                                <p>All orders must be paid in full prior to dispatch from the designated Delivery Hub (Abuja, Kano, Lagos, etc.).</p>

                                <h3>5. Marketing</h3>
                                <p>Distributors are encouraged to use official Enchiridion branding materials for promotion but must not alter the core content or cover art.</p>
                            </div>
                        </div>
                        <div className={styles.modalFooter}>
                            <button className={styles.primaryBtn} onClick={() => setShowTermsModal(false)}>Close</button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
