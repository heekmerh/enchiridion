import { defineConfig } from "@playwright/test";

export default defineConfig({
    testDir: "./tests/accessibility",
    timeout: 90_000,
    expect: { timeout: 10_000 },
    workers: 2,
    fullyParallel: true,
    reporter: [["list"], ["html", { open: "never" }]],
    use: {
        baseURL: "http://127.0.0.1:3100",
        trace: "retain-on-failure",
        launchOptions: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE
            ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {},
    },
    projects: [
        { name: "phone", use: { viewport: { width: 320, height: 800 } } },
        { name: "desktop", use: { viewport: { width: 1440, height: 1000 } } },
    ],
    webServer: {
        command: "npm run dev -- --hostname 127.0.0.1 --port 3100",
        url: "http://127.0.0.1:3100",
        timeout: 120_000,
        reuseExistingServer: process.env.A11Y_REUSE_SERVER === "1",
        env: {
            NEXT_DIST_DIR: ".next-a11y",
            NEXT_PUBLIC_SUPABASE_URL: "https://a11y.supabase.co",
            NEXT_PUBLIC_SUPABASE_ANON_KEY: "accessibility-fixture-public-key",
            NEXT_PUBLIC_FLUTTERWAVE_PUBLIC_KEY: "accessibility-fixture-public-key",
        },
    },
});
