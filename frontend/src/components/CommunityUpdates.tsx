"use client";

import { useCallback, useEffect, useId, useState } from "react";
import styles from "./CommunityUpdates.module.css";

interface Update { text: string; timestamp?: string; id?: string }

/** Updates are user-controlled and remain available until the user closes them. */
export default function CommunityUpdates({ endpoint, label }: { endpoint: string; label: string }) {
    const panelId = useId();
    const [updates, setUpdates] = useState<Update[]>([]);
    const [open, setOpen] = useState(false);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(false);
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
    async function refresh() {
        setLoading(true);
        setError(false);
        try { setUpdates(await load()); }
        catch { setError(true); }
        finally { setLoading(false); }
    }

    return (
        <section className={styles.panel} aria-label={label}>
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
