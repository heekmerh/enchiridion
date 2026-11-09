import { proxyBackend } from "@/lib/backend";

export async function POST(request: Request) {
    return proxyBackend(request, "/referral/audit/revert-payout" + new URL(request.url).search);
}
