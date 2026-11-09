import { proxyBackend } from "@/lib/backend";

export async function POST(request: Request) {
    return proxyBackend(request, "/referral/initialize-purchase" + new URL(request.url).search);
}
