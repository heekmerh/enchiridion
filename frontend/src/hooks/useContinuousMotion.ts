"use client";

import { useEffect, useState } from "react";

export function useContinuousMotion() {
    const [enabled, setEnabled] = useState(false);
    useEffect(() => {
        const preference = window.matchMedia("(prefers-reduced-motion: reduce)");
        const update = () => setEnabled(!preference.matches && document.documentElement.dataset.motionPaused !== "true");
        update();
        preference.addEventListener("change", update);
        window.addEventListener("motion-preference-change", update);
        return () => {
            preference.removeEventListener("change", update);
            window.removeEventListener("motion-preference-change", update);
        };
    }, []);
    return enabled;
}
