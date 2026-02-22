/**
 * Reusable utility for logging referral-related activities.
 */
export const logActivity = async (
    type: "browsing" | "registration" | "purchase" | "Sample View",
    refCode: string
) => {
    try {
        if (type === "browsing") {
            // Get IP for fraud prevention (simple client-side retrieval)
            let ip = "unknown";
            try {
                const ipRes = await fetch("https://api.ipify.org?format=json");
                const ipData = await ipRes.json();
                ip = ipData.ip;
            } catch (e) {
                console.error("Could not fetch IP:", e);
            }

            const response = await fetch("/api/referral/track-visit", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    refCode,
                    ip,
                    userAgent: typeof navigator !== "undefined" ? navigator.userAgent : "unknown"
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
                    url: typeof window !== "undefined" ? window.location.href : "unknown",
                    userAgent: typeof navigator !== "undefined" ? navigator.userAgent : "unknown",
                },
            }),
        });
        console.log(`Activity logged: ${type}`);
    } catch (error) {
        console.error("Error logging activity:", error);
    }
};

/**
 * Captures a lead email and persists it to Google Sheets.
 */
export const captureLeadAndGetSample = async (email: string, refCode: string): Promise<{ success: boolean; error?: string }> => {
    try {
        console.log(`DEBUG: Capturing lead ${email} for ref ${refCode}`);
        const response = await fetch("/api/referral/capture-lead", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                email,
                refCode,
                timestamp: new Date().toISOString(),
                details: {
                    url: typeof window !== "undefined" ? window.location.href : "About Page Gate",
                    userAgent: typeof navigator !== "undefined" ? navigator.userAgent : "unknown",
                },
            }),
        });

        const data = await response.json();
        console.log("DEBUG: capture-lead API response:", data);

        if (data.success) {
            console.log("Lead captured successfully");
            // Also log a 'Sample View' activity as a follow-up
            await logActivity("Sample View", refCode);
            return { success: true };
        }

        const errorMsg = data.error || "Lead capture failed";
        console.warn("Lead capture API returned success=false:", errorMsg);
        return { success: false, error: errorMsg };
    } catch (error: any) {
        const errorMsg = error?.message || "Internal network error";
        console.error("CRITICAL ERROR capturing lead:", error);
        return { success: false, error: errorMsg };
    }
};
