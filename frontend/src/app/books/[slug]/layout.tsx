import type { Metadata } from "next";
import { books } from "@/lib/data";

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
    const { slug } = await params;
    return { title: books.find(book => book.slug === slug)?.title || "Book not found" };
}
export default function Layout({ children }: { children: React.ReactNode }) { return children; }
