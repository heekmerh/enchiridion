"use client";
import CommunityUpdates from "./CommunityUpdates";

export default function GlobalToast() {
    return <CommunityUpdates endpoint="/api/referral/global-broadcasts" label="Community updates" />;
}
