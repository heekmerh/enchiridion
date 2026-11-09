import type { NextConfig } from "next";

const nextConfig: NextConfig = {
    distDir: process.env.NEXT_DIST_DIR || ".next",
    images: {
        path: process.env.VERCEL ? "/_vercel/image" : "/_next/image",
    },
};

export default nextConfig;
