import { NextResponse } from "next/server";

export async function GET(request: Request) {
    const backendUrl = process.env.BACKEND_URL || "http://127.0.0.1:8000";
    const authHeader = request.headers.get("Authorization");

    try {
        const response = await fetch(`${backendUrl}/referral/report/monthly/csv`, {
            cache: 'no-store',
            headers: {
                "Authorization": authHeader || "",
            },
        });

        if (!response.ok) {
            const error = await response.text();
            return NextResponse.json({ error }, { status: response.status });
        }

        const blob = await response.blob();
        const headers = new Headers();
        headers.set("Content-Type", "text/csv");
        headers.set("Content-Disposition", response.headers.get("Content-Disposition") || "attachment; filename=report.csv");

        return new Response(blob, {
            status: 200,
            headers,
        });
    } catch (err) {
        return NextResponse.json({ error: String(err) }, { status: 500 });
    }
}
