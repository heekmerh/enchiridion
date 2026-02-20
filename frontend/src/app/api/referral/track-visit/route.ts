import { NextResponse } from 'next/server';

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || 'http://127.0.0.1:8002';

        const response = await fetch(`${backendUrl}/referral/track-visit`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
        });

        const data = await response.json();
        const res = NextResponse.json(data);

        // Forward cookies if set by backend
        const setCookie = response.headers.get('set-cookie');
        if (setCookie) {
            res.headers.set('set-cookie', setCookie);
        }

        return res;
    } catch (error) {
        console.error('Error in track-visit proxy:', error);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
