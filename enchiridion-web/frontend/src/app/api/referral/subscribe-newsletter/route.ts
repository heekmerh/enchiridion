import { proxyBackend } from "@/lib/backend";

export async function POST(request: Request) {
    return proxyBackend(request, "/referral/subscribe-newsletter" + new URL(request.url).search);
}
