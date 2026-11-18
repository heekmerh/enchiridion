"use client";

import { useState } from "react";
import styles from "@/components/Premium.module.css";
import PartnerLoginModal from "@/components/PartnerLoginModal";
import { authorizedFetch, signOut } from "@/lib/supabase";
import { removeOwnFiles } from "@/lib/accountDeletion";
import { useSession } from "@/lib/useSession";
import { errorDetail } from "@/lib/billing";

const SUPPORT_EMAIL = "support@enchiridion.site";
const CONFIRM_WORD = "DELETE";

export default function DeleteAccountPage() {
    const { ready, signedIn, session } = useSession();
    const [loginOpen, setLoginOpen] = useState(false);
    const [typed, setTyped] = useState("");
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [playUrl, setPlayUrl] = useState<string | null>(null);
    const [deleted, setDeleted] = useState(false);

    async function deleteAccount() {
        if (!session) return;
        setBusy(true);
        setError(null);
        setPlayUrl(null);
        try {
            await removeOwnFiles(session.user.id).catch(() => undefined);
            const response = await authorizedFetch("/api/v1/account", { method: "DELETE" });
            if (!response.ok) {
                const body = await response.clone().json().catch(() => null);
                if (body?.detail?.code === "cancel_google_play_first") setPlayUrl(body.detail.url);
                setError(await errorDetail(response, "Your account could not be deleted. Please try again."));
                return;
            }
            await signOut();
            setDeleted(true);
        } catch {
            setError("Your account could not be deleted. Please try again.");
        } finally {
            setBusy(false);
        }
    }

    if (deleted) {
        return (
            <div className={styles.page}>
                <div className={styles.panel}>
                    <h1>Your account has been deleted</h1>
                    <p>Your Enchiridion account and the data linked to it have been removed. Thank you for studying with us.</p>
                </div>
            </div>
        );
    }

    return (
        <div className={styles.page}>
            <div className={styles.panel}>
                <h1>Delete your Enchiridion account</h1>
                <p>
                    You can delete your account from the Enchiridion app (Profile, then Delete account) or on this page.
                    Deletion is permanent and cannot be undone.
                </p>
                <h2>What we delete</h2>
                <ul>
                    <li>Your sign-in, name, role, profile photo and device registration</li>
                    <li>Your notes, notebook pages and photos, bookmarks, clips and reading settings</li>
                    <li>Your answers, review progress and study statistics</li>
                    <li>Your email preferences and any newsletter or sample sign-ups under your email</li>
                </ul>
                <h2>What we keep</h2>
                <p>
                    Records of payments you made (amount, date, plan and the payment reference) are kept, no longer linked
                    to your account, because tax and accounting law requires it. Notes already saved on your own phone stay
                    there until you uninstall the app.
                </p>
                <h2>Before you delete</h2>
                <p>
                    If you subscribe through Google Play, cancel it in Google Play first so you are not charged again.
                    A renewing website subscription is cancelled for you when you delete your account.
                </p>

                {error && <div className={styles.alert} role="alert">{error}</div>}
                {playUrl && (
                    <a className={styles.secondaryBtn} href={playUrl} target="_blank" rel="noreferrer">
                        Open Google Play subscriptions
                    </a>
                )}

                {ready && !signedIn && (
                    <>
                        <p>Sign in to the account you want to delete.</p>
                        <button className={styles.primaryBtn} onClick={() => setLoginOpen(true)}>Sign in</button>
                    </>
                )}

                {signedIn && (
                    <>
                        <label htmlFor="confirm-delete">
                            Signed in as {session?.user.email}. Type {CONFIRM_WORD} to confirm.
                        </label>
                        <input id="confirm-delete" value={typed} onChange={event => setTyped(event.target.value)}
                            autoComplete="off" />
                        <button className={styles.primaryBtn} onClick={deleteAccount}
                            disabled={busy || typed.trim().toUpperCase() !== CONFIRM_WORD}>
                            {busy ? "Deleting..." : "Delete my account permanently"}
                        </button>
                    </>
                )}

                <p>
                    Can&apos;t sign in? Email <a href={`mailto:${SUPPORT_EMAIL}?subject=Delete%20my%20account`}>{SUPPORT_EMAIL}</a> from
                    the address on your account with the subject &quot;Delete my account&quot;. We confirm by email and delete it
                    within 30 days.
                </p>
            </div>
            <PartnerLoginModal isOpen={loginOpen} onClose={() => setLoginOpen(false)} onLoginSuccess={() => undefined}
                redirectTo="/account/delete" />
        </div>
    );
}
