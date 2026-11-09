import { proxyBackend } from "@/lib/backend";

export async function GET(request: Request) {
    return proxyBackend(request, "/referral/recent-milestones" + new URL(request.url).search,
        "public, s-maxage=120, stale-while-revalidate=300");
}
