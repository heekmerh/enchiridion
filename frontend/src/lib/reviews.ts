import { Review } from '@/app/api/reviews/route';

export type ReviewAction = 'SUBMIT' | 'FETCH';

export async function manageReviews(action: 'SUBMIT', data: Omit<Review, 'id' | 'status' | 'createdAt'>): Promise<any>;
export async function manageReviews(action: 'FETCH', data?: { limit?: number; admin?: boolean }): Promise<Review[]>;
export async function manageReviews(action: ReviewAction, data?: any): Promise<any> {
    if (action === 'SUBMIT') {
        const response = await fetch('/api/reviews', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(data),
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || 'Failed to submit review');
        }

        return await response.json();
    }

    if (action === 'FETCH') {
        const { limit, admin = false } = data || {};
        const url = `/api/reviews?admin=${admin}`;

        const response = await fetch(url);
        if (!response.ok) {
            throw new Error('Failed to fetch reviews');
        }

        let reviews: Review[] = await response.json();

        if (limit) {
            reviews = reviews.slice(0, limit);
        }

        return reviews;
    }

    throw new Error(`Unsupported action: ${action}`);
}
