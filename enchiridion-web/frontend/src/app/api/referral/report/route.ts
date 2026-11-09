import { proxyBackend } from "@/lib/backend";

export async function GET(request: Request) {
    return proxyBackend(request, "/referral/report/monthly/csv" + new URL(request.url).search);
}
