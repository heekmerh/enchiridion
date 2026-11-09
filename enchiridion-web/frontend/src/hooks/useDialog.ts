"use client";

import { useEffect, useRef } from "react";

type OpenDialog = { element: HTMLDivElement; trigger: HTMLElement | null };
const dialogs: OpenDialog[] = [];
let background: { element: HTMLElement; inert: boolean }[] = [];
let originalOverflow = "";

function syncBackground() {
    background.forEach(item => { item.element.inert = item.inert; });
    background = [];
    const active = dialogs.at(-1)?.element;
    if (!active) return;
    let ancestor: HTMLElement = active;
    while (ancestor.parentElement && ancestor !== document.body) {
        for (const sibling of ancestor.parentElement.children) {
            if (sibling !== ancestor && sibling instanceof HTMLElement) {
                background.push({ element: sibling, inert: sibling.inert });
                sibling.inert = true;
            }
        }
        ancestor = ancestor.parentElement;
    }
}

/** Manages stacked dialogs, changing form views, scroll locking, and focus restoration. */
export function useDialog(open: boolean, onClose: () => void, canDismiss = true) {
    const ref = useRef<HTMLDivElement>(null);
    const closeRef = useRef(onClose);
    const dismissRef = useRef(canDismiss);
    useEffect(() => { closeRef.current = onClose; dismissRef.current = canDismiss; }, [onClose, canDismiss]);

    useEffect(() => {
        if (!open || !ref.current) return;
        const element = ref.current;
        const entry = { element, trigger: document.activeElement as HTMLElement | null };
        if (!dialogs.length) originalOverflow = document.body.style.overflow;
        dialogs.push(entry);
        document.body.style.overflow = "hidden";
        syncBackground();
        const controls = () => Array.from(element.querySelectorAll<HTMLElement>(
            'a[href], button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex="0"]',
        )).filter(item => item.getClientRects().length && !item.closest('[hidden], [inert]'));
        const focusFirst = () => (controls()[0] || element).focus();
        const isTop = () => dialogs.at(-1) === entry;
        focusFirst();
        const keydown = (event: KeyboardEvent) => {
            if (!isTop()) return;
            if (event.key === "Escape" && dismissRef.current) {
                event.preventDefault();
                event.stopPropagation();
                closeRef.current();
            }
            if (event.key !== "Tab") return;
            const items = controls();
            const first = items[0];
            const last = items.at(-1);
            if (!first) { event.preventDefault(); element.focus(); return; }
            if (event.shiftKey && (document.activeElement === first || !element.contains(document.activeElement))) {
                event.preventDefault(); last?.focus();
            } else if (!event.shiftKey && (document.activeElement === last || !element.contains(document.activeElement))) {
                event.preventDefault(); first.focus();
            }
        };
        const maintainFocus = () => {
            if (isTop() && !element.contains(document.activeElement)) focusFirst();
        };
        document.addEventListener("keydown", keydown, true);
        document.addEventListener("focusin", maintainFocus);
        const observer = new MutationObserver(maintainFocus);
        observer.observe(element, { childList: true, subtree: true });
        return () => {
            observer.disconnect();
            document.removeEventListener("keydown", keydown, true);
            document.removeEventListener("focusin", maintainFocus);
            const wasTop = isTop();
            const index = dialogs.indexOf(entry);
            if (index !== -1) dialogs.splice(index, 1);
            syncBackground();
            if (!dialogs.length) document.body.style.overflow = originalOverflow;
            if (wasTop) {
                if (entry.trigger?.isConnected && !entry.trigger.closest('[hidden], [inert]') && entry.trigger.getClientRects().length) entry.trigger.focus();
                else dialogs.at(-1)?.element.focus();
            }
        };
    }, [open]);
    return ref;
}
