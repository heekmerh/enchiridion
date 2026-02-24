import { NextResponse } from "next/server";

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8000";

export async function POST(request: Request) {
    try {
        const { searchParams } = new URL(request.url);
        const platform = searchParams.get("platform") || "unknown";
        const body = await request.json();

        // Proxy to backend
        const response = await fetch(`${BACKEND_URL}/referral/record-share?platform=${platform}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify(body),
        });

        if (!response.ok) {
            const data = await response.json().catch(() => ({}));
            return NextResponse.json({ detail: data.detail || response.statusText }, { status: response.status });
        }

        const data = await response.json();
        return NextResponse.json(data);
    } catch (error: any) {
        console.error("Error in referral/record-share proxy:", error);
        return NextResponse.json({ detail: error.message || "Internal Server Error" }, { status: 500 });
    }
}
