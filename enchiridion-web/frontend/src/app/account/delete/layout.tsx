import type { Metadata } from "next";

export const metadata: Metadata = {
    title: "Delete your Enchiridion account",
    description: "Permanently delete your Enchiridion account and the data linked to it.",
};

export default function Layout({ children }: { children: React.ReactNode }) {
    return children;
}
