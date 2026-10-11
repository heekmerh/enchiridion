import { proxyBackend } from "@/lib/backend";

export async function GET(request: Request) {
    return proxyBackend(request, "/referral/debug/sync-all" + new URL(request.url).search);
}
