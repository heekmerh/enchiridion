import { proxyBackend } from "@/lib/backend";

export async function POST(request: Request) {
    return proxyBackend(request, "/referral/distributor-lead" + new URL(request.url).search);
}
