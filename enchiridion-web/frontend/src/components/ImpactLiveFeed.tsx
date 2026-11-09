"use client";
import CommunityUpdates from "./CommunityUpdates";

export default function ImpactLiveFeed() {
    return <CommunityUpdates endpoint="/api/referral/recent-milestones" label="Recent community milestones" preview="milestone" />;
}
