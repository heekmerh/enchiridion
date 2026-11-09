"use client";

import { useState, useEffect } from "react";
import styles from "./AdminTestConsole.module.css";
import { getAccessToken } from "@/lib/supabase";

export default function AdminTestConsole() {
    const [auditData, setAuditData] = useState<any>(null);
    const [loading, setLoading] = useState(false);
    const [testLog, setTestLog] = useState<string[]>([]);
    const [isAdmin, setIsAdmin] = useState(false);
    const [payoutFilter, setPayoutFilter] = useState("ALL");
    const [actionLoading, setActionLoading] = useState<string | null>(null);

    const addLog = (msg: string) => {
        setTestLog(prev => [`[${new Date().toLocaleTimeString()}] ${msg}`, ...prev]);
    };

    const revertPayout = async (email: string, refCode: string, amount: number) => {
        if (!window.confirm(`Are you sure you want to revert the last recorded payout of ₦${amount?.toLocaleString() || "?"}? This will move the money back to the pending balance.`)) {
            return;
        }

        setActionLoading(email);
        addLog(`Reverting payout of ₦${amount} for ${email}...`);

        const token = await getAccessToken();

        try {
            const res = await fetch("/api/referral/audit-revert", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${token}`
                },
                body: JSON.stringify({ email, refCode })
            });

            const data = await res.json();
            if (data.success) {
                addLog(`SUCCESS: Payout reverted for ${email}. Restored: ₦${data.restored_revenue}`);
                await runAudit();
            } else {
                addLog(`Error: ${data.detail || data.error}`);
            }
        } catch (err) {
            addLog(`Error: ${err}`);
        }
        setActionLoading(null);
    };

    const runAudit = async () => {
        setLoading(true);
        const token = await getAccessToken();
        try {
            const res = await fetch("/api/referral/audit-verify", {
                headers: { "Authorization": `Bearer ${token}` }
            });
            const data = await res.json();

            if (res.status === 401) {
                addLog("Auth check failed: 401 Unauthorized. [IMPORTANT] PLEASE LOG OUT AND LOG BACK IN.");
                setAuditData({ error: "Unauthorized. Secret configuration may have changed. Please re-login." });
            } else if (!res.ok) {
                addLog(`Audit error: ${res.status} ${data.error || data.detail || "Unknown error"}`);
                setAuditData(data);
            } else {
                setAuditData(data);
                addLog("Audit complete. Balances loaded.");
            }
        } catch (err) {
            const errMsg = String(err);
            if (errMsg.includes("TypeError")) {
                addLog("CRITICAL: System busy—please check for empty rows in your database.");
            } else {
                addLog(`Audit error: ${err}`);
            }
        }

        setLoading(false);
    };


    useEffect(() => {
        const checkAdmin = async () => {
            const token = await getAccessToken();
            addLog(`Auth check: Token found=${!!token}`);
            if (!token) {
                addLog("Auth check: No token found. Please login as Admin.");
                return;
            }
            try {
                const res = await fetch("/api/users/me", {
                    headers: { "Authorization": `Bearer ${token}` }
                });
                if (res.ok) {
                    const user = await res.json();
                    setIsAdmin(user.is_superuser);
                    addLog(`Auth check: OK. Superuser=${user.is_superuser}`);
                } else {
                    if (res.status === 401) {
                        addLog("Auth check failed: 401 Unauthorized. PLEASE LOG OUT AND LOG BACK IN.");
                    } else {
                        addLog(`Auth check failed: ${res.status} ${res.statusText}`);
                    }
                }

            } catch (err) {
                addLog(`Auth check error: ${err}`);
                console.error("Auth check failed", err);
            }
        };
        checkAdmin();
        runAudit();
    }, []);

    const markAsPaid = async (email: string, refCode: string) => {
        if (!confirm(`Mark ${email} as PAID? This will reset their current points/revenue and update Lifetime Earnings.`)) return;

        setActionLoading(email);
        addLog(`Marking ${email} as paid...`);
        const token = await getAccessToken();
        try {
            const res = await fetch("/api/referral/mark-as-paid", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${token}`
                },
                body: JSON.stringify({ email, refCode })
            });
            const data = await res.json();
            if (data.success) {
                addLog(`SUCCESS: ${email} marked as paid. New Lifetime: ₦${data.new_lifetime}`);

                // Real-time refresh immediately after success
                await runAudit();
            } else {

                addLog(`Error: ${data.detail || data.error}`);
            }
        } catch (err) {
            const errMsg = String(err);
            if (errMsg.includes("TypeError")) {
                alert("System busy—please check for empty rows in your database.");
                addLog("CRITICAL ERROR: TypeError detected.");
            } else {
                addLog(`Request failed: ${err}`);
            }
        }

        setActionLoading(null);
    };

    const filteredResults = auditData?.results?.filter((row: any) => {
        if (payoutFilter === "ALL") return true;
        if (payoutFilter === "PENDING") return (row.payout_status || "PENDING").toUpperCase() === "PENDING";
        if (payoutFilter === "COMPLETED") return (row.payout_status || "").toUpperCase() === "COMPLETED";
        return true;
    });

    return (
        <div className={styles.console}>
            <header className={styles.header}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
                    <h1 className={styles.headerTitle}>Referral Administration</h1>

                </div>
                <div className={styles.config}>
                    <a href="/admin/reviews" className={styles.syncBtn} style={{ textDecoration: 'none', background: '#000', color: '#fff' }}>
                        Moderate Reviews 💬
                    </a>
                    {isAdmin && (
                        <button
                            onClick={async () => {
                                addLog("Generating CSV report...");
                                const token = await getAccessToken();
                                try {
                                    const date = new Date();
                                    const currentMonth = date.getMonth() + 1; // 1-indexed
                                    const currentYear = date.getFullYear();

                                    const res = await fetch(`/api/referral/report?month=${currentMonth}&year=${currentYear}`, {
                                        headers: { "Authorization": `Bearer ${token}` }
                                    });
                                    if (res.ok) {
                                        const blob = await res.blob();
                                        const url = window.URL.createObjectURL(blob);
                                        const a = document.createElement('a');
                                        a.href = url;
                                        const monthName = date.toLocaleString('default', { month: 'long' });
                                        a.download = `Enchiridion_Report_${monthName}_${currentYear}.csv`;
                                        document.body.appendChild(a);
                                        a.click();
                                        a.remove();
                                        addLog("Report downloaded successfully.");
                                    } else {
                                        addLog(`Download failed: ${res.statusText}`);
                                    }
                                } catch (err) {
                                    addLog(`Download error: ${err}`);
                                }
                            }}
                            className={styles.downloadBtn}
                        >
                            <span>📥</span> Download Monthly Report (CSV)
                        </button>
                    )}
                </div>
            </header>

            <div className={styles.grid}>
                <section className={styles.simulation}>
                    <div className={styles.log}>
                        <h2 className={styles.logTitle}>Execution Log</h2>
                        <div role="log" tabIndex={0} aria-label="Administration activity" className={styles.logContent}>
                            {testLog.map((log, i) => {
                                const isElite = log.includes("ELITE STATUS UNLOCKED");
                                return (
                                    <div key={i} className={`${styles.logEntry} ${isElite ? styles.logElite : ""}`}>
                                        {log}
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                </section>

                <section className={styles.audit}>
                    <div className={styles.auditHeader}>
                        <h2 className={styles.sectionTitle}>Real-Time Sheet Audit</h2>
                        <div className={styles.filterGroup}>
                            <label htmlFor="payout-filter" className="sr-only">Filter payouts</label>
                            <select id="payout-filter"
                                value={payoutFilter}
                                onChange={(e) => setPayoutFilter(e.target.value)}
                                className={styles.filterSelect}
                            >
                                <option value="ALL">All Payouts</option>
                                <option value="PENDING">Only Pending Payouts</option>
                                <option value="COMPLETED">Completed Payouts</option>
                            </select>
                            <button onClick={runAudit} disabled={loading} className={styles.refreshBtn}>
                                {loading ? "Auditing..." : "Run Audit Now"}
                            </button>
                        </div>
                    </div>

                    {auditData?.error && (
                        <div role="alert" className={styles.errorBanner}>
                            <strong>Audit Failed:</strong> {auditData.error}
                        </div>
                    )}

                    {auditData?.results && (
                        <div role="region" aria-label="Referral payout audit" tabIndex={0} className={styles.auditTableWrapper}>
                            <table className={styles.auditTable}>
                                <caption className="sr-only">Referral balances, calculation checks, and payout actions</caption>
                                <thead>
                                    <tr>
                                        <th scope="col">Row</th>
                                        <th scope="col">Username</th>
                                        <th scope="col">Points</th>
                                        <th scope="col">Revenue</th>
                                        <th scope="col">Lifetime</th>
                                        <th scope="col">Status</th>
                                        <th scope="col">Action</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {filteredResults.map((row: any, i: number) => {
                                        // Status pull directly from Backend (Column I)
                                        const sheetStatus = (row.payout_status || "PENDING").toUpperCase();
                                        const hasPoints = (row.points || 0) > 0;
                                        const hasRevenue = (row.revenue || 0) > 0;

                                        let displayStatus = sheetStatus;
                                        let statusClass = styles.statusPending;

                                        if (sheetStatus === "COMPLETED") {
                                            statusClass = styles.statusCompleted;
                                        } else if (!hasPoints && !hasRevenue) {
                                            displayStatus = "No Balance";
                                            statusClass = styles.statusPending;
                                        }


                                        return (
                                            <tr key={i} className={row.math_ok ? styles.rowOk : styles.rowError}>
                                                <td style={{ color: '#000', fontWeight: 700 }}>{row.row}<span className="sr-only">{row.math_ok ? " — calculation verified" : " — calculation mismatch"}</span></td>
                                                <td style={{ color: '#000', fontWeight: 600 }}>
                                                    {row.username}
                                                    {row.milestone_claimed === 'CLAIMED' && (
                                                        <span className={styles.trophy} title="Elite Ambassador Achievement Unlocked">🏆</span>
                                                    )}
                                                </td>
                                                <td style={{ color: '#000', fontWeight: 800 }}>{row.points}</td>
                                                <td style={{ color: '#000', fontWeight: 800 }}>₦{row.revenue?.toLocaleString()}</td>
                                                <td style={{ color: '#4f46e5', fontWeight: 800 }}>₦{row.lifetime_earnings?.toLocaleString() || 0}</td>

                                                <td className={statusClass}>
                                                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                                        {displayStatus}
                                                        {displayStatus === "COMPLETED" && (
                                                            <button
                                                                onClick={() => revertPayout(row.username, row.refCode || "TEST001", row.last_payout_amount)}
                                                                className={styles.revertBtn}
                                                                title="Revert Payout"
                                                                aria-label={`Revert payout for ${row.username}`}
                                                            >
                                                                <i aria-hidden="true" className="fas fa-rotate-left"></i>
                                                            </button>
                                                        )}
                                                    </div>
                                                </td>
                                                <td>
                                                    {hasPoints ? (
                                                        <button
                                                            onClick={() => markAsPaid(row.username, row.refCode || "TEST001")}
                                                            disabled={actionLoading === row.username}
                                                            className={styles.markPaidBtn}
                                                        >
                                                            {actionLoading === row.username ? "Processing..." : "Mark as Paid"}
                                                        </button>
                                                    ) : (
                                                        <span style={{
                                                            color: sheetStatus === "COMPLETED" ? "#15803d" : "#64748b",
                                                            fontWeight: 600,
                                                            fontSize: '0.875rem',
                                                            display: 'flex',
                                                            alignItems: 'center',
                                                            gap: '4px'
                                                        }}>
                                                            {sheetStatus === "COMPLETED" ? "Paid \u2713" : "No Balance"}
                                                        </span>
                                                    )}

                                                </td>
                                            </tr>
                                        );
                                    })}

                                </tbody>
                            </table>
                        </div>
                    )}

                    <div className={styles.auditLegend}>
                        <p><strong>Strict Validation Rules:</strong></p>
                        <ul>
                            <li>Column A: Username (Email)</li>
                            <li>Column E: Points (Numeric)</li>
                            <li>Column F: Revenue (Points × 100)</li>
                        </ul>
                    </div>
                </section>
            </div>
        </div >
    );
}
