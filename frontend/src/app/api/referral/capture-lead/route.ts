import { NextResponse } from "next/server";

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000";

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { email, refCode, timestamp, details } = body;

        console.log(`Capturing lead: ${email} for ref: ${refCode}`);

        // Add a 10s timeout to prevent long hangs
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000);

        try {
            const response = await fetch(`${BACKEND_URL}/referral/capture-lead`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    email,
                    refCode,
                    timestamp,
                    details
                }),
                signal: controller.signal
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                const errorText = await response.text();
                console.error(`Backend error (${response.status}):`, errorText);
                let errorMessage = "Backend error";
                try {
                    const errorData = JSON.parse(errorText);
                    errorMessage = errorData.detail || errorMessage;
                } catch (e) {
                    // Not JSON
                }
                return NextResponse.json({ success: false, error: errorMessage }, { status: response.status });
            }

            return NextResponse.json({ success: true });
        } catch (fetchError: any) {
            clearTimeout(timeoutId);
            if (fetchError.name === 'AbortError') {
                console.error("Backend fetch timed out after 10s");
                return NextResponse.json({ success: false, error: "Backend timeout" }, { status: 504 });
            }
            throw fetchError;
        }
    } catch (error) {
        console.error("Error in capture-lead API:", error);
        return NextResponse.json({ success: false, error: "Internal Server Error" }, { status: 500 });
    }
}
