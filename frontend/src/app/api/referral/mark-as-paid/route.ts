import { NextResponse } from "next/server";

export async function POST(request: Request) {
    const backendUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
    const authHeader = request.headers.get("Authorization");

    try {
        const body = await request.json();
        const response = await fetch(`${backendUrl}/referral/mark-as-paid`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": authHeader || "",
            },
            body: JSON.stringify(body),
        });

        const data = await response.json();

        if (!response.ok) {
            return NextResponse.json(data, { status: response.status });
        }

        return NextResponse.json(data);
    } catch (err) {
        console.error("Error in mark-as-paid proxy:", err);
        return NextResponse.json({ error: String(err) }, { status: 500 });
    }
}
