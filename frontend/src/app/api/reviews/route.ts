import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || "http://127.0.0.1:8002";

// Interface for Review Data
export interface Review {
    id: string;
    name: string;
    jobTitle: string;
    organization?: string;
    rating: number;
    text: string;
    status: 'pending' | 'approved' | 'rejected';
    createdAt: string;
    approvedAt?: string;
}

// GET: Fetch reviews
export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const isAdmin = searchParams.get('admin') === 'true';

    try {
        console.log(`DEBUG: Proxying GET request to ${BACKEND_URL}/reviews/?admin=${isAdmin}`);
        const response = await fetch(`${BACKEND_URL}/reviews/?admin=${isAdmin}`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
            },
            signal: AbortSignal.timeout(10000), // 10 second timeout
        });

        if (!response.ok) {
            const errorMsg = `Backend returned ${response.status}: ${response.statusText}`;
            console.error(`ERROR: ${errorMsg}`);
            return NextResponse.json({ error: 'Failed to fetch reviews from backend' }, { status: response.status });
        }

        const reviews = await response.json();
        return NextResponse.json(reviews);
    } catch (error: any) {
        console.error('Error fetching reviews:', error);

        if (error.name === 'AbortError') {
            return NextResponse.json({ error: 'Backend request timed out' }, { status: 504 });
        }

        if (error.code === 'ECONNREFUSED' || error.message?.includes('fetch failed')) {
            return NextResponse.json({
                error: 'Backend service is currently unavailable. Please ensure the backend is running on port 8002.'
            }, { status: 503 });
        }

        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// POST: Submit a new review
export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { name, jobTitle, organization, rating, text } = body;

        // Validation
        if (!name || !jobTitle || !rating || !text) {
            return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
        }

        const response = await fetch(`${BACKEND_URL}/reviews/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                name,
                jobTitle,
                organization,
                rating,
                text
            }),
        });

        if (!response.ok) {
            const errorData = await response.json();
            return NextResponse.json({ error: errorData.detail || 'Failed to submit review' }, { status: response.status });
        }

        const result = await response.json();
        return NextResponse.json(result, { status: 201 });
    } catch (error) {
        console.error('Error submitting review:', error);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// PUT: moderate a review (Admin only)
export async function PUT(request: Request) {
    try {
        const authHeader = request.headers.get('Authorization');
        const body = await request.json();
        const { id, status } = body;

        if (!id || !['approved', 'rejected'].includes(status)) {
            return NextResponse.json({ error: 'Invalid ID or status' }, { status: 400 });
        }

        const headers: Record<string, string> = {
            'Content-Type': 'application/json',
        };

        if (authHeader) {
            headers['Authorization'] = authHeader;
        }

        const response = await fetch(`${BACKEND_URL}/reviews/${id}?status=${status}`, {
            method: 'PUT',
            headers: headers
        });

        if (!response.ok) {
            const errorData = await response.json();
            return NextResponse.json({ error: errorData.detail || 'Failed to moderate review' }, { status: response.status });
        }

        const result = await response.json();
        return NextResponse.json(result);
    } catch (error) {
        console.error('Error updating review:', error);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
