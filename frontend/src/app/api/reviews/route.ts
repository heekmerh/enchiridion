import { proxyBackend } from "@/lib/backend";

export interface Review {
    id: string;
    name: string;
    jobTitle: string;
    organization?: string;
    rating: number;
    text: string;
    status: "pending" | "approved" | "rejected";
    createdAt: string;
    approvedAt?: string;
}

export async function GET(request: Request) {
    return proxyBackend(request, "/reviews/" + new URL(request.url).search);
}

export async function POST(request: Request) {
    return proxyBackend(request, "/reviews/");
}

export async function PUT(request: Request) {
    try {
        const body = await request.clone().json();
        if (typeof body.id !== "string" || !["approved", "rejected"].includes(body.status)) {
            return Response.json({ detail: "Invalid review or status" }, { status: 400 });
        }
        return proxyBackend(request, `/reviews/${encodeURIComponent(body.id)}?status=${body.status}`);
    } catch {
        return Response.json({ detail: "Invalid request" }, { status: 400 });
    }
}
