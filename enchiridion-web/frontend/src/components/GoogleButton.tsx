"use client";

import styles from "./GoogleButton.module.css";

interface GoogleButtonProps {
    onClick: () => void;
    disabled?: boolean;
    note?: string;
}

export default function GoogleButton({ onClick, disabled, note }: GoogleButtonProps) {
    return (
        <div className={styles.wrapper}>
            <div className={styles.divider}><span>or</span></div>
            <button type="button" className={styles.button} onClick={onClick} disabled={disabled}>
                <span className={styles.mark} aria-hidden="true">G</span>
                Continue with Google
            </button>
            {note && <p className={styles.note}>{note}</p>}
        </div>
    );
}
