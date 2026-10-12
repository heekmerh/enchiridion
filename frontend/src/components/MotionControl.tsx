"use client";

import { useState } from "react";

export default function MotionControl() {
    const [paused, setPaused] = useState(false);
    return <button type="button" className="motion-control" aria-pressed={paused} onClick={() => {
        const next = !paused;
        setPaused(next);
        document.documentElement.dataset.motionPaused = String(next);
        window.dispatchEvent(new Event("motion-preference-change"));
    }}>{paused ? "Resume animations" : "Pause animations"}</button>;
}
