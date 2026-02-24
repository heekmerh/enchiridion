"use client";

import { useState, useEffect, useRef } from "react";
import styles from "./CheckoutModal.module.css";
import { NIGERIAN_STATES, StateDelivery, findClosestDistributor, DELIVERY_ZONES, HUB_STATES, fetchShippingRates, getUserStats } from "@/lib/checkout";
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
    const [dynamicRates, setDynamicRates] = useState<any[]>([]);
    const [userRegisteredState, setUserRegisteredState] = useState<string | null>(null);
    const dropdownRef = useRef<HTMLDivElement>(null);
    const zoneRefs = useRef<Record<string, HTMLDivElement | null>>({});

    // Fetch dynamic data
    useEffect(() => {
        if (isOpen) {
            fetchShippingRates().then(rates => {
                if (rates && rates.length > 0) setDynamicRates(rates);
            });
            getUserStats().then(stats => {
                if (stats?.state) {
                    setUserRegisteredState(stats.state);
                    // Pre-fill state if not already set
                    setFormData(prev => ({ ...prev, state: prev.state || stats.state, email: prev.email || stats.email || "" }));
                }
            });

            // Load Paystack script
            const script = document.createElement("script");
            script.src = "https://js.paystack.co/v1/inline.js";
            script.async = true;
            document.body.appendChild(script);
            return () => {
                document.body.removeChild(script);
            };
        }
    }, [isOpen]);

    const payWithPaystack = () => {
        const buyerEmail = formData.email || "customer@example.com";
        const handler = (window as any).PaystackPop.setup({
            key: process.env.NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY,
            email: buyerEmail,
            amount: total * 100, // Kobo
            currency: "NGN",
            ref: `ENCH-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
            metadata: {
                product: "book",
                refCode: localStorage.getItem("enchiridion_ref") || "direct",
                custom_fields: [
                    {
                        display_name: "Customer Name",
                        variable_name: "customer_name",
                        value: formData.fullName
                    }
                ]
            },
            callback: (response: any) => {
                console.log("Paystack Payment Success:", response);
                // Immediately update HasPurchasedBook and award 1.0 cashback to buyer
                fetch("/api/referral/complete-purchase", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ email: buyerEmail })
                })
                    .then(res => res.json())
                    .then(data => console.log("Purchase milestone triggered:", data))
                    .catch(err => console.error("Error triggering purchase milestone:", err));

                setStep("success");
            },
            onClose: () => {
                alert("Transaction was not completed.");
            }
        });
        handler.openIframe();
    };

    // Trigger referrer credit when success reached (rewards the referrer 5.0 pts)
    useEffect(() => {
        if (step === "success" && !refCredited) {
            const cachedRef = localStorage.getItem("enchiridion_ref");
            if (cachedRef) {
                fetch("/api/referral/credit-purchase", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ refCode: cachedRef, email: formData.email || "" })
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
    const scrollContainerRef = useRef<HTMLDivElement>(null);
    const normalizeStateName = (name: string) => {
        if (!name) return "";
        let n = name.toLowerCase().trim();
        if (n.includes("abuja") || n.includes("federal capital territory")) return "abuja";
        return n;
    };

    // Auto-scroll to registered zone or top when entering delivery step
    useEffect(() => {
        if (step === "delivery") {
            const targetState = formData.state || userRegisteredState;
            if (targetState) {
                const normTarget = normalizeStateName(targetState);
                const targetZone = DELIVERY_ZONES.find(z =>
                    z.states.some(s => normalizeStateName(s) === normTarget)
                );
                if (targetZone && zoneRefs.current[targetZone.id]) {
                    setTimeout(() => {
                        zoneRefs.current[targetZone.id]?.scrollIntoView({ behavior: "smooth", block: "start" });
                    }, 100);
                    return;
                }
            }
            if (scrollContainerRef.current) {
                scrollContainerRef.current.scrollTop = 0;
            }
        }
    }, [step, formData.state, userRegisteredState]);

    // Dynamic Prioritization Logic
    const prioritizedZones = [...DELIVERY_ZONES].sort((a, b) => {
        const preferredState = formData.state || userRegisteredState || "";
        const normPreferred = normalizeStateName(preferredState);
        const isAInZone = a.states.some(s => normalizeStateName(s) === normPreferred);
        const isBInZone = b.states.some(s => normalizeStateName(s) === normPreferred);
        if (isAInZone) return -1;
        if (isBInZone) return 1;
        return 0;
    });

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
                        <p className={styles.subtitle}>Find your state delivery cost below.</p>

                        <div className={styles.zonedWrapper} ref={scrollContainerRef}>
                            {prioritizedZones.map((zone, index) => (
                                <div
                                    key={zone.id}
                                    className={styles.zoneSection}
                                    ref={el => { zoneRefs.current[zone.id] = el }}
                                >
                                    {index > 0 && <hr className={styles.zoneDivider} />}
                                    <h3 className={styles.zoneHeader}>{zone.title}</h3>
                                    <div className={styles.stateGrid}>
                                        {zone.states.map((stateName: string) => {
                                            const normName = normalizeStateName(stateName);
                                            const dynamicData = dynamicRates.find(r => normalizeStateName(r.name) === normName);
                                            const localData = NIGERIAN_STATES.find(s => normalizeStateName(s.name) === normName);

                                            if (!dynamicData && !localData) return null;

                                            const stateData = dynamicData ? {
                                                name: stateName,
                                                cost: dynamicData.cost,
                                                costLabel: `₦${dynamicData.cost.toLocaleString()}`
                                            } : localData!;

                                            const isHub = dynamicData ? dynamicData.isHub : HUB_STATES.some(s => normalizeStateName(s) === normName);
                                            const priceClass = isHub ? styles.priceGreen : styles.priceRed;

                                            return (
                                                <div
                                                    key={stateName}
                                                    className={`${styles.stateCard} ${selectedState && normalizeStateName(selectedState.name) === normName ? styles.selected : ""}`}
                                                    onClick={() => handleDeliverySelect(stateData)}
                                                >
                                                    <span className={styles.stateName}>{stateName}</span>
                                                    <span className={`${styles.statePrice} ${priceClass}`}>
                                                        {stateData.costLabel}
                                                    </span>
                                                </div>
                                            );
                                        })}
                                    </div>
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
                        <h2>Finalize Your Order</h2>
                        <p className={styles.subtitle}>Ready to purchase {book.title} Handbook</p>

                        <div className={styles.paymentSummary}>
                            <div className={styles.summaryRow}>
                                <span>Item:</span>
                                <span>{book.title}</span>
                            </div>
                            <div className={styles.summaryRow}>
                                <span>Shipping to {formData.state}:</span>
                                <span>{selectedState?.costLabel}</span>
                            </div>
                            <div className={styles.paymentTotal}>
                                <span>Amount Due:</span>
                                <span>₦{total.toLocaleString()}</span>
                            </div>
                        </div>

                        <div className={styles.paymentActions}>
                            <button
                                className={styles.payBtn}
                                onClick={payWithPaystack}
                            >
                                <i className="fas fa-lock" style={{ marginRight: '10px' }}></i>
                                Pay Securely with Paystack
                            </button>
                            <p className={styles.paymentNotice}>
                                <i className="fas fa-shield-alt"></i> Payments are processed securely via Paystack.
                            </p>
                        </div>
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
