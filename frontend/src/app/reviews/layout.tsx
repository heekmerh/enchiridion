import type { Metadata } from "next";

export const metadata: Metadata = { title: "Reviews and feedback" };

export default function Layout({ children }: { children: React.ReactNode }) {
    return children;
}
