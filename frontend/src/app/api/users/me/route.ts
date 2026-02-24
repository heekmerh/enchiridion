import { NextResponse } from "next/server";

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8000";


export async function GET(request: Request) {
    try {
        const authHeader = request.headers.get("Authorization");

        const response = await fetch(`${BACKEND_URL}/users/me`, {
            method: "GET",
            headers: {
                "Authorization": authHeader || "",
            },
        });

        if (!response.ok) {
            const data = await response.json().catch(() => ({}));
            return NextResponse.json({ detail: data.detail || "Failed to fetch user profile" }, { status: response.status });
        }

        const data = await response.json();
        return NextResponse.json(data);
    } catch (error: any) {
        console.error("Error in users/me proxy:", error);
        return NextResponse.json({ detail: error.message || "Internal Server Error" }, { status: 500 });
    }
}
