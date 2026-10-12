"use client";

import { useCallback, useEffect, useId, useState } from "react";
import styles from "./CommunityUpdates.module.css";
import toastStyles from "./GlobalToast.module.css";
import impactStyles from "./OnboardingChecklist.module.css";
import { useContinuousMotion } from "@/hooks/useContinuousMotion";

interface Update { text: string; timestamp?: string; id?: string; type?: string }

/** Animated previews accompany a persistent, user-controlled list of updates. */
export default function CommunityUpdates({ endpoint, label, preview }: { endpoint: string; label: string; preview?: "broadcast" | "milestone" }) {
    const panelId = useId();
    const [updates, setUpdates] = useState<Update[]>([]);
    const [open, setOpen] = useState(false);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(false);
    const motionEnabled = useContinuousMotion();
    const [previewIndex, setPreviewIndex] = useState(0);
    const [showPreview, setShowPreview] = useState(preview === "broadcast");
    const load = useCallback(async (): Promise<Update[]> => {
        const response = await fetch(endpoint);
        if (!response.ok) throw new Error("Updates unavailable");
        const data = await response.json();
        return Array.isArray(data) ? data.slice(0, 5) : [];
    }, [endpoint]);
    useEffect(() => {
        let active = true;
        load().then(data => { if (active) setUpdates(data); })
            .catch(() => { if (active) setError(true); })
            .finally(() => { if (active) setLoading(false); });
        return () => { active = false; };
    }, [load]);
    useEffect(() => {
        if (!preview || !motionEnabled) return;
        const interval = window.setInterval(() => {
            load().then(setUpdates).catch(() => { /* Preserve available updates during a temporary outage. */ });
        }, preview === "broadcast" ? 15000 : 300000);
        return () => window.clearInterval(interval);
    }, [load, motionEnabled, preview]);
    useEffect(() => {
        if (!preview || !motionEnabled || open || !updates.length) return;
        const timer = window.setTimeout(() => {
            setPreviewIndex(index => (index + 1) % updates.length);
            setShowPreview(preview === "broadcast" || !showPreview);
        }, preview === "broadcast" ? 6000 : showPreview ? 5000 : 60000 + Math.random() * 60000);
        return () => window.clearTimeout(timer);
    }, [preview, motionEnabled, open, updates.length, previewIndex, showPreview]);
    async function refresh() {
        setLoading(true);
        setError(false);
        try { setUpdates(await load()); }
        catch { setError(true); }
        finally { setLoading(false); }
    }

    return (
        <section className={styles.panel} aria-label={label}>
            {preview && showPreview && !open && updates.length > 0 && <div aria-hidden="true" data-motion-preview
                className={preview === "broadcast" ? toastStyles.globalToastContainer : impactStyles.liveFeedContainer}>
                <div key={previewIndex} className={preview === "broadcast" ? `${toastStyles.toast} ${toastStyles.toastEnter}` : impactStyles.toast}>
                    <div className={preview === "broadcast" ? toastStyles.toastText : impactStyles.toastText}>{updates[previewIndex % updates.length].text}</div>
                    {preview === "broadcast" && updates[previewIndex % updates.length].type === "master_rank" && <div className={toastStyles.confettiMini} />}
                </div>
            </div>}
            <div className={styles.actions}>
                <button type="button" aria-expanded={open} aria-controls={panelId} onClick={() => setOpen(value => !value)}>
                    {label}
                </button>
                <button type="button" disabled={loading} onClick={refresh} aria-label={`Refresh ${label.toLowerCase()}`}>Refresh</button>
            </div>
            <p role="status" className={styles.status}>{loading ? "Loading updates…" : error ? "Updates could not be loaded. Select Refresh to retry." : `${updates.length} recent updates available.`}</p>
            <div id={panelId} hidden={!open}>
                {updates.length ? <ul>{updates.map((update, index) => <li key={update.id || index}>{update.text}</li>)}</ul>
                    : <p>No recent updates.</p>}
            </div>
        </section>
    );
}
