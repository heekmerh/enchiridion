import { NextResponse } from 'next/server';
import fs from 'fs';
import path from 'path';

// Path to the reviews JSON file
const reviewsFilePath = path.join(process.cwd(), 'src', 'lib', 'reviews.json');

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

// Helper: Read reviews from file
const getReviews = (): Review[] => {
    if (!fs.existsSync(reviewsFilePath)) {
        return [];
    }
    const data = fs.readFileSync(reviewsFilePath, 'utf8');
    try {
        return JSON.parse(data);
    } catch (error) {
        console.error('Error parsing reviews.json:', error);
        return [];
    }
};

// Helper: Write reviews to file
const saveReviews = (reviews: Review[]) => {
    fs.writeFileSync(reviewsFilePath, JSON.stringify(reviews, null, 2));
};

// GET: Fetch reviews
// Public: Returns only approved reviews
// Admin (?admin=true): Returns all reviews
export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const isAdmin = searchParams.get('admin') === 'true';

    const reviews = getReviews();

    if (isAdmin) {
        // In a real app, you would check authentication here
        return NextResponse.json(reviews.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()));
    } else {
        const approvedReviews = reviews
            .filter((r) => r.status === 'approved')
            .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
        return NextResponse.json(approvedReviews);
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

        if (text.length < 30) {
            return NextResponse.json({ error: 'Review text must be at least 30 characters' }, { status: 400 });
        }

        const newReview: Review = {
            id: Date.now().toString(),
            name,
            jobTitle,
            organization: organization || '',
            rating: Number(rating),
            text,
            status: 'pending', // Always pending by default
            createdAt: new Date().toISOString(),
        };

        const reviews = getReviews();
        reviews.push(newReview);
        saveReviews(reviews);

        return NextResponse.json({ message: 'Review submitted successfully and is pending approval.', review: newReview }, { status: 201 });
    } catch (error) {
        console.error('Error submitting review:', error);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// PUT: moderate a review (Admin only)
export async function PUT(request: Request) {
    try {
        const body = await request.json();
        const { id, status } = body;

        if (!id || !['approved', 'rejected'].includes(status)) {
            return NextResponse.json({ error: 'Invalid ID or status' }, { status: 400 });
        }

        const reviews = getReviews();
        const reviewIndex = reviews.findIndex((r) => r.id === id);

        if (reviewIndex === -1) {
            return NextResponse.json({ error: 'Review not found' }, { status: 404 });
        }

        reviews[reviewIndex].status = status;
        if (status === 'approved') {
            reviews[reviewIndex].approvedAt = new Date().toISOString();
        }

        saveReviews(reviews);

        return NextResponse.json({ message: `Review ${status} successfully`, review: reviews[reviewIndex] });
    } catch (error) {
        console.error('Error updating review:', error);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
