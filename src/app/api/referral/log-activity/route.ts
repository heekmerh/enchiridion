import { NextResponse } from "next/server";

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000";

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { type, refCode, timestamp, details } = body;

        console.log(`Logging activity: ${type} for ref: ${refCode}`);

        // Points logic:
        let points = 0;
        if (type === "browsing") points = 0.1;
        else if (type === "registration") points = 0.1;
        else if (type === "purchase") points = 5;

        const response = await fetch(`${BACKEND_URL}/referral/log-activity`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                type,
                refCode,
                points,
                timestamp,
                details
            })
        });

        if (!response.ok) {
            const errorData = await response.json();
            return NextResponse.json({ success: false, error: errorData.detail || "Backend error" }, { status: response.status });
        }

        return NextResponse.json({ success: true, pointsLogged: points });
    } catch (error) {
        console.error("Error in log-activity API:", error);
        return NextResponse.json({ success: false, error: "Internal Server Error" }, { status: 500 });
    }
}
