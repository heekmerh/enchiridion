"use client";

import { useEffect } from "react";
import { useSearchParams } from "next/navigation";
import { logActivity } from "@/lib/record";

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

    const logActivityHandler = async (type: "browsing" | "registration" | "purchase", refCode: string) => {
        await logActivity(type, refCode);
    };

    return null; // This component doesn't render anything
}
