import { NextResponse } from "next/server";

export async function GET(request: Request) {
    const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8000";
    const authHeader = request.headers.get("Authorization");

    const { searchParams } = new URL(request.url);
    const month = searchParams.get("month");
    const year = searchParams.get("year");

    let url = `${backendUrl}/referral/report/monthly/csv`;
    const params = new URLSearchParams();
    if (month) params.append("month", month);
    if (year) params.append("year", year);
    if (params.toString()) url += `?${params.toString()}`;

    try {
        const response = await fetch(url, {
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
