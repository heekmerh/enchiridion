import { NextResponse } from "next/server";

export async function GET(request: Request) {
    const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8000";
    const authHeader = request.headers.get("Authorization");

    try {
        const response = await fetch(`${backendUrl}/referral/debug/sync-all`, {
            cache: 'no-store',
            headers: {
                "Authorization": authHeader || "",
            },
        });

        if (!response.ok) {
            const errorText = await response.text();
            return NextResponse.json({ error: errorText || response.statusText }, { status: response.status });
        }

        const data = await response.json();
        return NextResponse.json(data);
    } catch (error: any) {
        console.error("Error in sync-all proxy:", error);
        return NextResponse.json({ error: error.message || "Internal Server Error" }, { status: 500 });
    }
}
