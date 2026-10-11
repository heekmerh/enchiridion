import { proxyBackend } from "@/lib/backend";

export async function POST(request: Request) {
    return proxyBackend(request, "/referral/debug/mock-register" + new URL(request.url).search);
}
