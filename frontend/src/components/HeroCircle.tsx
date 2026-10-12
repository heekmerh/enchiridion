"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import styles from "@/app/page.module.css";

export default function HeroCircle({ children }: { children: ReactNode }) {
    const contentRef = useRef<HTMLDivElement>(null);
    const [scrollable, setScrollable] = useState(false);
    useEffect(() => {
        const content = contentRef.current;
        if (!content) return;
        const update = () => {
            setScrollable(content.scrollHeight > content.clientHeight + 1);
            const focused = document.activeElement;
            if (focused instanceof HTMLElement && focused !== content && content.contains(focused)) {
                focused.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "instant" });
            }
        };
        const observer = new ResizeObserver(update);
        observer.observe(content);
        for (const child of content.children) observer.observe(child);
        document.fonts.ready.then(update);
        update();
        return () => observer.disconnect();
    }, []);
    return <>
        <div className={styles.heroCircleContainer}>
            <div ref={contentRef} className={styles.heroCircleContent} role="region"
                aria-label="Introduction and book links" tabIndex={scrollable ? 0 : undefined}
                aria-describedby={scrollable ? "hero-scroll-hint" : undefined}>
                {children}
            </div>
        </div>
        {scrollable && <p id="hero-scroll-hint" className={styles.heroScrollHint}>Scroll inside the circle for the book and app links.</p>}
    </>;
}
