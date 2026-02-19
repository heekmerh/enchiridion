"use client";

import AdminTestConsole from "@/components/AdminTestConsole";
import styles from "./AdminPage.module.css";
import Link from "next/link";

export default function AdminPage() {
    return (
        <main className={styles.container}>
            <nav className={styles.nav}>
                <Link href="/" className={styles.backLink}>← Back to Site</Link>
                <div className={styles.statusBadge}>System Monitor Active</div>
            </nav>

            <AdminTestConsole />

            <footer className={styles.footer}>
                <p>Enchiridion Administrative Protocol &copy; 2026. Data verified against Partners Database.</p>
            </footer>
        </main>
    );
}
