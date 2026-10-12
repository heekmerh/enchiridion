import type { Metadata } from "next";

export const metadata: Metadata = { title: "Premium plans" };

export default function Layout({ children }: { children: React.ReactNode }) {
    return children;
}
