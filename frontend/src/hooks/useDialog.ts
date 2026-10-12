"use client";

import { useEffect, useRef } from "react";

/** Keep keyboard focus inside an open overlay and restore its trigger on close. */
export function useDialog(open: boolean, onClose: () => void, canDismiss = true) {
    const ref = useRef<HTMLDivElement>(null);
    const closeRef = useRef(onClose);
    useEffect(() => { closeRef.current = onClose; }, [onClose]);

    useEffect(() => {
        if (!open || !ref.current) return;
        const dialog = ref.current;
        const trigger = document.activeElement as HTMLElement | null;
        const background: { element: HTMLElement; wasInert: boolean }[] = [];
        let ancestor: HTMLElement = dialog;
        while (ancestor.parentElement && ancestor !== document.body) {
            for (const sibling of ancestor.parentElement.children) {
                if (sibling !== ancestor && sibling instanceof HTMLElement && !sibling.contains(dialog)) {
                    background.push({ element: sibling, wasInert: sibling.inert });
                    sibling.inert = true;
                }
            }
            ancestor = ancestor.parentElement;
        }
        const previousOverflow = document.body.style.overflow;
        document.body.style.overflow = "hidden";
        const selector = 'a[href], button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex="0"]';
        const controls = () => Array.from(dialog.querySelectorAll<HTMLElement>(selector))
            .filter(element => element.getClientRects().length > 0 && !element.closest('[hidden], [inert]'));
        (controls()[0] || dialog).focus();
        const keydown = (event: KeyboardEvent) => {
            if (event.key === "Escape" && canDismiss) {
                event.preventDefault();
                event.stopPropagation();
                closeRef.current();
            }
            if (event.key !== "Tab") return;
            const items = controls();
            const first = items[0];
            const last = items[items.length - 1];
            if (!first) { event.preventDefault(); dialog.focus(); return; }
            if (event.shiftKey && (document.activeElement === first || !dialog.contains(document.activeElement))) {
                event.preventDefault(); last.focus();
            } else if (!event.shiftKey && (document.activeElement === last || !dialog.contains(document.activeElement))) {
                event.preventDefault(); first.focus();
            }
        };
        dialog.addEventListener("keydown", keydown);
        return () => {
            dialog.removeEventListener("keydown", keydown);
            document.body.style.overflow = previousOverflow;
            background.forEach(({ element, wasInert }) => { element.inert = wasInert; });
            if (trigger?.isConnected) trigger.focus();
        };
    }, [open, canDismiss]);
    return ref;
}
