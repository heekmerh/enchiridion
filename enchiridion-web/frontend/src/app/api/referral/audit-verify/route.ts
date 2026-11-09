import { proxyBackend } from "@/lib/backend";

export async function GET(request: Request) {
    return proxyBackend(request, "/referral/audit/verify" + new URL(request.url).search);
}
