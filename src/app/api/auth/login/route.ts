import { NextResponse } from "next/server";

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000";

export async function POST(request: Request) {
    try {
        const formData = await request.formData();

        const response = await fetch(`${BACKEND_URL}/auth/jwt/login`, {
            method: "POST",
            body: formData,
        });

        const data = await response.json();

        if (!response.ok) {
            return NextResponse.json({ detail: data.detail || "Login failed" }, { status: response.status });
        }

        return NextResponse.json(data);
    } catch (error) {
        console.error("Error in login proxy:", error);
        return NextResponse.json({ detail: "Internal Server Error" }, { status: 500 });
    }
}
