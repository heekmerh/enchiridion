"use client";

import AdminTestConsole from "@/components/AdminTestConsole";
import styles from "./AdminPage.module.css";
import Link from "next/link";

export default function AdminPage() {
    return (
        <div className={styles.container}>
            <nav aria-label="Administration breadcrumb" className={styles.nav}>
                <Link href="/" className={styles.backLink}>← Back to Site</Link>
                <div className={styles.statusBadge}>System Monitor Active</div>
            </nav>

            <nav aria-label="Administration sections" className={styles.adminNav}>
                <Link href="/admin/reviews" className={styles.navLink}>
                    <span className={styles.navIcon}>💬</span>
                    Review Moderation
                </Link>
            </nav>

            <AdminTestConsole />

            <footer className={styles.footer}>
                <p>Enchiridion Administrative Protocol &copy; 2026. Data verified against Partners Database.</p>
            </footer>
        </div>
    );
}
