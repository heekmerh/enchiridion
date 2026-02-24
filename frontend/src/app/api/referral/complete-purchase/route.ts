import { NextResponse } from "next/server";

export async function POST(request: Request) {
    const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8000";

    try {
        const body = await request.json();
        const response = await fetch(`${backendUrl}/referral/complete-purchase`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body),
        });

        const data = await response.json();
        return NextResponse.json(data, { status: response.status });
    } catch (err) {
        console.error("Error in complete-purchase proxy:", err);
        return NextResponse.json({ error: String(err) }, { status: 500 });
    }
}
