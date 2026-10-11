import type { Metadata } from "next";
import LegalDocument from "@/components/LegalDocument";

export const metadata: Metadata = { title: "Terms and Conditions — Enchiridion" };

export default function TermsPage() {
    return <LegalDocument file="terms" />;
}
