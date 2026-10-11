import "server-only";

export async function proxyBackend(request: Request, path: string) {
    const base = process.env.BACKEND_URL || (process.env.VERCEL ? "" : "http://127.0.0.1:8000");
    if (!base) return Response.json({ detail: "Backend is not configured" }, { status: 503 });
    try {
        const headers = new Headers();
        for (const name of ["authorization", "content-type", "cookie", "flutterwave-signature", "verif-hash"]) {
            const value = request.headers.get(name);
            if (value) headers.set(name, value);
        }
        const upstream = await fetch(`${base.replace(/\/$/, "")}${path}`, {
            method: request.method,
            headers,
            body: ["GET", "HEAD"].includes(request.method) ? undefined : await request.arrayBuffer(),
            cache: "no-store",
            signal: AbortSignal.timeout(45000),
            redirect: "manual",
        });
        const responseHeaders = new Headers({ "Cache-Control": "no-store" });
        for (const name of ["content-type", "content-disposition"]) {
            const value = upstream.headers.get(name);
            if (value) responseHeaders.set(name, value);
        }
        for (const cookie of upstream.headers.getSetCookie()) responseHeaders.append("set-cookie", cookie);
        return new Response(upstream.body, { status: upstream.status, headers: responseHeaders });
    } catch {
        return Response.json({ detail: "Backend is temporarily unavailable" }, { status: 502 });
    }
}
