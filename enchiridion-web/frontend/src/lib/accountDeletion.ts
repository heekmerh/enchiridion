"use client";

import { supabase } from "@/lib/supabase";

const USER_FILE_BUCKETS = ["avatars", "notebook-images"];

export async function removeOwnFiles(userId: string) {
    for (const bucket of USER_FILE_BUCKETS) {
        const storage = supabase().storage.from(bucket);
        const { data } = await storage.list(userId, { limit: 1000 });
        const paths = (data ?? []).map(file => `${userId}/${file.name}`);
        if (paths.length) await storage.remove(paths);
    }
}
