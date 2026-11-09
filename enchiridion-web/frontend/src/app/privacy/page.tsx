import type { Metadata } from "next";
import LegalDocument from "@/components/LegalDocument";

export const metadata: Metadata = { title: "Privacy Policy — Enchiridion" };

export default function PrivacyPage() {
    return <LegalDocument file="privacy" />;
}
