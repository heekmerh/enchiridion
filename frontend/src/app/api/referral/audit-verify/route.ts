import { NextResponse } from 'next/server';

export async function GET(request: Request) {
    try {
        const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8002";



        const authHeader = request.headers.get("Authorization");

        const response = await fetch(`${BACKEND_URL}/referral/audit/verify`, {
            cache: 'no-store',
            headers: {
                "Authorization": authHeader || "",
            },
        });
        if (!response.ok) {
            const errorText = await response.text();
            console.error('Backend error:', errorText);
            return NextResponse.json({ error: errorText || response.statusText }, { status: response.status });
        }

        const data = await response.json();
        return NextResponse.json(data);
    } catch (error: any) {
        console.error('Error in audit-verify proxy:', error);
        return NextResponse.json({ error: error.message || 'Internal Server Error' }, { status: 500 });
    }
}

