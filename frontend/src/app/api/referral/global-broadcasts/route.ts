import { proxyBackend } from "@/lib/backend";

export async function GET(request: Request) {
    return proxyBackend(request, "/referral/global-broadcasts" + new URL(request.url).search);
}
