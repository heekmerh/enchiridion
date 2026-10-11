import type { NextConfig } from "next";

const nextConfig: NextConfig = {
    images: {
        path: process.env.VERCEL ? "/_vercel/image" : "/_next/image",
    },
};

export default nextConfig;
