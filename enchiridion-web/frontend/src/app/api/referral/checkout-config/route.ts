import { proxyBackend } from "@/lib/backend";

export async function GET(request: Request) {
    return proxyBackend(request, "/referral/checkout-config" + new URL(request.url).search);
}
