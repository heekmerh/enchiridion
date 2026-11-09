import { proxyBackend } from "@/lib/backend";

export async function GET(request: Request) {
    return proxyBackend(request, "/referral/progress" + new URL(request.url).search);
}
