import { proxyBackend } from "@/lib/backend";

export async function POST(request: Request) {
    return proxyBackend(request, "/referral/record-visit" + new URL(request.url).search);
}
