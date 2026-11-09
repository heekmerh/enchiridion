import { proxyBackend } from "@/lib/backend";

export async function POST(request: Request) {
    return proxyBackend(request, "/referral/mark-as-paid" + new URL(request.url).search);
}
