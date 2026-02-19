"use client";

import { useEffect } from "react";
import { useSearchParams } from "next/navigation";

export default function ReferralTracker() {
    const searchParams = useSearchParams();

    useEffect(() => {
        const ref = searchParams.get("ref");

        if (ref) {
            // Persist the referral code in localStorage
            localStorage.setItem("enchiridion_ref", ref);
            console.log(`Referral code detected and cached: ${ref}`);

            // Log browsing activity
            logActivity("browsing", ref);
        } else {
            // Check if a referral code exists in localStorage
            const cachedRef = localStorage.getItem("enchiridion_ref");
            if (cachedRef) {
                // Still log browsing activity even if coming back without the param
                // Use a session-based lock to prevent duplicate browsing logs in a single session
                const sessionLogged = sessionStorage.getItem("enchiridion_browsing_logged");
                if (!sessionLogged) {
                    logActivity("browsing", cachedRef);
                    sessionStorage.setItem("enchiridion_browsing_logged", "true");
                }
            }
        }
    }, [searchParams]);

    const logActivity = async (type: "browsing" | "registration" | "purchase", refCode: string) => {
        try {
            if (type === "browsing") {
                // Get IP for fraud prevention (simple client-side retrieval)
                let ip = "unknown";
                try {
                    const ipRes = await fetch("https://api.ipify.org?format=json");
                    const ipData = await ipRes.json();
                    ip = ipData.ip;
                } catch (e) { console.error("Could not fetch IP:", e); }

                const response = await fetch("/api/referral/track-visit", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        refCode,
                        ip,
                        userAgent: navigator.userAgent
                    }),
                });

                const data = await response.json();
                console.log("Visit tracked:", data);
                return;
            }

            // Fallback for other types
            await fetch("/api/referral/log-activity", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    type,
                    refCode,
                    timestamp: new Date().toISOString(),
                    details: {
                        url: window.location.href,
                        userAgent: navigator.userAgent,
                    },
                }),
            });
        } catch (error) {
            console.error("Error logging activity:", error);
        }
    };

    return null; // This component doesn't render anything
}
