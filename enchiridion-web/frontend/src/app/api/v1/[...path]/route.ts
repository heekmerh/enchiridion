import { proxyBackend } from "@/lib/backend";

function upstreamPath(request: Request) {
    const url = new URL(request.url);
    return url.pathname + url.search;
}

export async function GET(request: Request) {
    return proxyBackend(request, upstreamPath(request));
}

export async function POST(request: Request) {
    return proxyBackend(request, upstreamPath(request));
}

export async function PUT(request: Request) {
    return proxyBackend(request, upstreamPath(request));
}
