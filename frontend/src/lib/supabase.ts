"use client";

import { createClient, type AuthChangeEvent, type Session, type SupabaseClient } from "@supabase/supabase-js";

let client: SupabaseClient | null = null;

export function supabase(): SupabaseClient {
    if (client) return client;
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !anonKey) throw new Error("Supabase is not configured for this website.");
    client = createClient(url, anonKey, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: "implicit" },
    });
    return client;
}

export async function getAccessToken(): Promise<string | null> {
    if (typeof window === "undefined") return null;
    try {
        const { data } = await supabase().auth.getSession();
        return data.session?.access_token ?? null;
    } catch {
        return null;
    }
}

export async function currentSession(): Promise<Session | null> {
    try {
        const { data } = await supabase().auth.getSession();
        return data.session;
    } catch {
        return null;
    }
}

export function onSessionChange(listener: (session: Session | null, event: AuthChangeEvent) => void): () => void {
    try {
        const { data } = supabase().auth.onAuthStateChange((event, session) => listener(session, event));
        return () => data.subscription.unsubscribe();
    } catch {
        return () => {};
    }
}

export const TERMS_VERSION = "1.2";
export const PENDING_MARKETING_KEY = "enchiridion_pending_marketing_opt_in";

export async function signInWithGoogle(next: string) {
    const redirectTo = `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`;
    const { error } = await supabase().auth.signInWithOAuth({ provider: "google", options: { redirectTo } });
    if (error) throw error;
}

export async function authorizedFetch(input: string, init: RequestInit = {}): Promise<Response> {
    const token = await getAccessToken();
    const headers = new Headers(init.headers);
    if (token) headers.set("Authorization", `Bearer ${token}`);
    return fetch(input, { ...init, headers });
}

export async function signOut() {
    try {
        await supabase().auth.signOut();
    } finally {
        for (const key of ["enchiridion_user_name", "enchiridion_user_ref", "enchiridion_token"]) {
            localStorage.removeItem(key);
        }
    }
}

export function authErrorMessage(error: unknown, fallback: string): string {
    if (error && typeof error === "object" && "message" in error && typeof error.message === "string") {
        return error.message;
    }
    return fallback;
}
