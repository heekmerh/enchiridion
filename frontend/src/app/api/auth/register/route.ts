import { NextResponse } from "next/server";

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000";

export async function POST(request: Request) {
    try {
        const body = await request.json();

        const response = await fetch(`${BACKEND_URL}/auth/register`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify(body),
        });

        const data = await response.json();

        if (!response.ok) {
            return NextResponse.json({ detail: data.detail || "Registration failed" }, { status: response.status });
        }

        return NextResponse.json(data);
    } catch (error) {
        console.error("Error in register proxy:", error);
        return NextResponse.json({ detail: "Internal Server Error" }, { status: 500 });
    }
}
