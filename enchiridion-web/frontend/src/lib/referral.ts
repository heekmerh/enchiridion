// Referral links and share text, shared by the sign-up welcome screen and the partner dashboard.

const FALLBACK_ORIGIN = "https://www.enchiridion.site";

/** The site the visitor is actually on, so a shared link always opens a domain that serves the site. */
export const siteOrigin = (): string =>
    typeof window === "undefined" ? FALLBACK_ORIGIN : window.location.origin;

export const referralLink = (code: string): string =>
    `${siteOrigin()}/refer?ref=${encodeURIComponent(code.trim())}`;

/**
 * Client-side code proposed at sign-up. The database keeps it only if it is unused and matches
 * ^[a-z0-9_-]{3,64}$, so initials are limited to A-Z and six digits keep collisions rare.
 */
export const proposeReferralCode = (name: string): string => {
    const initials = name
        .normalize("NFD")
        .replace(/[^A-Za-z\s]/g, "")
        .split(/\s+/)
        .filter(Boolean)
        .map((part) => part[0])
        .join("")
        .toUpperCase()
        .slice(0, 2) || "RE";
    const digits = Math.floor(100000 + Math.random() * 900000);
    return `${initials}${digits}`;
};

export const referralShareMessage = (code: string): string =>
    [
        "Hey! I've been using Enchiridion, the concise medical handbooks and app for medical students and clinicians. The official Enchiridion book is out now too.",
        `Please use my link when you sign up or buy the book, so it counts as my referral: ${referralLink(code)}`,
        `You can read a free sample chapter first at ${siteOrigin()}`,
    ].join("\n\n");

export const whatsappShareUrl = (code: string): string =>
    `https://wa.me/?text=${encodeURIComponent(referralShareMessage(code))}`;
