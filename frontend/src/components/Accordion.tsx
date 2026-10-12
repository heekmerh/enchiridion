"use client";

import { useState, useId } from "react";
import styles from "./Accordion.module.css";

interface AccordionProps {
    title: string;
    children: React.ReactNode;
    defaultOpen?: boolean;
    isOpen?: boolean;
    onToggle?: () => void;
}

export default function Accordion({
    title,
    children,
    defaultOpen = false,
    isOpen: controlledOpen,
    onToggle
}: AccordionProps) {
    const panelId = useId();
    const [internalOpen, setInternalOpen] = useState(defaultOpen);

    const isExpanded = controlledOpen !== undefined ? controlledOpen : internalOpen;
    const handleToggle = () => {
        if (onToggle) {
            onToggle();
        } else {
            setInternalOpen(!internalOpen);
        }
    };

    return (
        <div className={`${styles.item} ${isExpanded ? styles.open : ""}`}>
            <button
                className={styles.header}
                onClick={handleToggle}
                aria-expanded={isExpanded}
                aria-controls={panelId}
                type="button"
            >
                <span className={styles.title}>{title}</span>
                <span className={styles.icon}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                        <polyline points="6 9 12 15 18 9"></polyline>
                    </svg>
                </span>
            </button>
            <div id={panelId} className={styles.content} hidden={!isExpanded}>
                <div className={styles.inner}>
                    {children}
                </div>
            </div>
        </div>
    );
}
