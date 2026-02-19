"use client";

import { useState, useEffect, useRef } from "react";
import styles from "./CheckoutModal.module.css";
import { NIGERIAN_STATES, StateDelivery, findClosestDistributor } from "@/lib/checkout";
import { Book } from "@/lib/data";

interface CheckoutModalProps {
    book: Book;
    isOpen: boolean;
    onClose: () => void;
}

type Step = "shipping" | "delivery" | "payment" | "success";

export default function CheckoutModal({ book, isOpen, onClose }: CheckoutModalProps) {
    const [step, setStep] = useState<Step>("shipping");
    const [formData, setFormData] = useState({
        fullName: "",
        country: "Nigeria",
        state: "",
        city: "",
        address: "",
        phone: "+234",
        email: ""
    });
    const [selectedState, setSelectedState] = useState<StateDelivery | null>(null);
    const [searchTerm, setSearchTerm] = useState("");
    const [showStateDropdown, setShowStateDropdown] = useState(false);
    const [refCredited, setRefCredited] = useState(false);
    const dropdownRef = useRef<HTMLDivElement>(null);

    // Trigger purchase credit when success reached
    useEffect(() => {
        if (step === "success" && !refCredited) {
            const cachedRef = localStorage.getItem("enchiridion_ref");
            if (cachedRef) {
                fetch("/api/referral/credit-purchase", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ refCode: cachedRef })
                })
                    .then(res => res.json())
                    .then(data => {
                        console.log("Referral purchase credited:", data);
                        setRefCredited(true);
                    })
                    .catch(err => console.error("Error crediting referral purchase:", err));
            }
        }
    }, [step, refCredited]);

    // Filter states based on search
    const filteredStates = NIGERIAN_STATES.filter(s =>
        s.name.toLowerCase().includes(searchTerm.toLowerCase())
    );

    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
                setShowStateDropdown(false);
            }
        };
        document.addEventListener("mousedown", handleClickOutside);
        return () => document.removeEventListener("mousedown", handleClickOutside);
    }, []);

    if (!isOpen) return null;

    const bookPrice = 10000;
    const total = bookPrice + (selectedState?.cost || 0);

    const handleShippingSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        setStep("delivery");
    };

    const handleDeliverySelect = (state: StateDelivery) => {
        setSelectedState(state);
    };

    const handlePaymentSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        setStep("success");
    };

    return (
        <div className={styles.overlay}>
            <div className={styles.modal}>
                <button className={styles.closeBtn} onClick={onClose}>&times;</button>

                {step === "shipping" && (
                    <div className={styles.stepContainer}>
                        <h2>Enter Your Shipping Details</h2>
                        <p className={styles.subtitle}>We'll use this to ship your book via the nearest distributor.</p>

                        <form onSubmit={handleShippingSubmit} className={styles.form}>
                            <div className={styles.field}>
                                <label>Full Name</label>
                                <input
                                    type="text"
                                    required
                                    minLength={3}
                                    maxLength={100}
                                    placeholder="e.g. John Doe"
                                    value={formData.fullName}
                                    onChange={e => setFormData({ ...formData, fullName: e.target.value })}
                                />
                            </div>

                            <div className={styles.field}>
                                <label>Country</label>
                                <input type="text" value="Nigeria" readOnly className={styles.readOnly} />
                            </div>

                            <div className={styles.field} ref={dropdownRef}>
                                <label>State</label>
                                <div className={styles.selectWrapper}>
                                    <input
                                        type="text"
                                        placeholder="Search or select state..."
                                        value={searchTerm || formData.state}
                                        onFocus={() => setShowStateDropdown(true)}
                                        onChange={(e) => {
                                            setSearchTerm(e.target.value);
                                            setFormData({ ...formData, state: "" });
                                        }}
                                        required={!formData.state}
                                    />
                                    {showStateDropdown && (
                                        <div className={styles.dropdown}>
                                            {filteredStates.map(s => (
                                                <div
                                                    key={s.name}
                                                    className={styles.dropdownOption}
                                                    onClick={() => {
                                                        setFormData({ ...formData, state: s.name });
                                                        setSearchTerm(s.name);
                                                        setShowStateDropdown(false);
                                                    }}
                                                >
                                                    {s.name}
                                                </div>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            </div>

                            <div className={styles.field}>
                                <label>City</label>
                                <input
                                    type="text"
                                    required
                                    minLength={2}
                                    value={formData.city}
                                    onChange={e => setFormData({ ...formData, city: e.target.value })}
                                />
                            </div>

                            <div className={styles.field}>
                                <label>Apartment Number / Detailed Address</label>
                                <input
                                    type="text"
                                    required
                                    placeholder="Flat 5, Block A, etc."
                                    value={formData.address}
                                    onChange={e => setFormData({ ...formData, address: e.target.value })}
                                />
                            </div>

                            <div className={styles.row}>
                                <div className={styles.field}>
                                    <label>Phone Number</label>
                                    <input
                                        type="tel"
                                        required
                                        pattern="^\+234\d{10}$"
                                        placeholder="+2348000000000"
                                        value={formData.phone}
                                        onChange={e => setFormData({ ...formData, phone: e.target.value })}
                                    />
                                </div>
                                <div className={styles.field}>
                                    <label>Email (Optional)</label>
                                    <input
                                        type="email"
                                        value={formData.email}
                                        onChange={e => setFormData({ ...formData, email: e.target.value })}
                                    />
                                </div>
                            </div>

                            <button type="submit" className={styles.primaryBtn}>Continue to Delivery</button>
                        </form>
                    </div>
                )}

                {step === "delivery" && (
                    <div className={styles.stepContainer}>
                        <h2>Select Delivery State & Cost</h2>
                        <div className={styles.stateGrid}>
                            {NIGERIAN_STATES.map(s => (
                                <div
                                    key={s.name}
                                    className={`${styles.stateCard} ${selectedState?.name === s.name ? styles.selected : ""}`}
                                    onClick={() => handleDeliverySelect(s)}
                                >
                                    <span className={styles.stateName}>{s.name}</span>
                                    <span className={styles.statePrice}>{s.costLabel}</span>
                                </div>
                            ))}
                        </div>

                        {selectedState && (
                            <div className={styles.summary}>
                                <div className={styles.summaryRow}>
                                    <span>Book Price:</span>
                                    <span>₦10,000</span>
                                </div>
                                <div className={styles.summaryRow}>
                                    <span>Delivery to {selectedState.name}:</span>
                                    <span>{selectedState.costLabel}</span>
                                </div>
                                <div className={styles.summaryTotal}>
                                    <span>Total:</span>
                                    <span>₦{total.toLocaleString()}</span>
                                </div>
                                <button className={styles.primaryBtn} onClick={() => setStep("payment")}>Continue to Pay</button>
                            </div>
                        )}
                        <button className={styles.backBtn} onClick={() => setStep("shipping")}>Back</button>
                    </div>
                )}

                {step === "payment" && (
                    <div className={styles.stepContainer}>
                        <h2>Enter Payment Details</h2>
                        <p className={styles.subtitle}>Purchasing {book.title} Handbook</p>

                        <form onSubmit={handlePaymentSubmit} className={styles.form}>
                            <div className={styles.field}>
                                <label>Card Number</label>
                                <input type="text" placeholder="0000 0000 0000 0000" required pattern="\d{16}" />
                            </div>
                            <div className={styles.row}>
                                <div className={styles.field}>
                                    <label>Expiry Date</label>
                                    <input type="text" placeholder="MM/YY" required pattern="\d{2}/\d{2}" />
                                </div>
                                <div className={styles.field}>
                                    <label>CVV / CCV</label>
                                    <input type="text" placeholder="123" required pattern="\d{3,4}" />
                                </div>
                            </div>
                            <div className={styles.field}>
                                <label>ATM PIN / PIN (Secure)</label>
                                <input type="password" placeholder="****" required pattern="\d{4}" />
                            </div>

                            <button type="submit" className={styles.payBtn}>Pay ₦{total.toLocaleString()}</button>
                        </form>
                        <button className={styles.backBtn} onClick={() => setStep("delivery")}>Back</button>
                    </div>
                )}

                {step === "success" && (
                    <div className={`${styles.stepContainer} ${styles.successCenter}`}>
                        <div className={styles.successIcon}>✓</div>
                        <h2>Payment Successful!</h2>
                        <p>Your order for <strong>{book.title}</strong> has been processed.</p>

                        <div className={styles.distributorMatch}>
                            <p>Assigned Distributor:</p>
                            <h3>{findClosestDistributor(formData.state).name}</h3>
                            <p>They will contact you soon for delivery to {formData.city}, {formData.state}.</p>
                        </div>

                        <button className={styles.primaryBtn} onClick={onClose}>Finish</button>
                    </div>
                )}
            </div>
        </div>
    );
}
