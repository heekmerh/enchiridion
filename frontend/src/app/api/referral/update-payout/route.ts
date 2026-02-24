import { NextResponse } from "next/server";

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8000";

export async function POST(request: Request) {
    try {
        const authHeader = request.headers.get("Authorization");
        const body = await request.json();

        const response = await fetch(`${BACKEND_URL}/referral/update-payout`, {
            method: "POST",
            headers: {
                "Authorization": authHeader || "",
                "Content-Type": "application/json",
            },
            body: JSON.stringify(body),
        });

        const data = await response.json();

        if (!response.ok) {
            return NextResponse.json({ detail: data.detail || "Failed to update payout settings" }, { status: response.status });
        }

        return NextResponse.json(data);
    } catch (error) {
        console.error("Error in update-payout proxy:", error);
        return NextResponse.json({ detail: "Internal Server Error" }, { status: 500 });
    }
}
