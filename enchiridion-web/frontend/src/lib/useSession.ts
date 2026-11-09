"use client";

import { useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { currentSession, onSessionChange } from "@/lib/supabase";

export function useSession() {
    const [session, setSession] = useState<Session | null>(null);
    const [ready, setReady] = useState(false);

    useEffect(() => {
        currentSession().then(initial => {
            setSession(initial);
            setReady(true);
        });
        return onSessionChange(next => setSession(next));
    }, []);

    return { session, ready, signedIn: !!session };
}
