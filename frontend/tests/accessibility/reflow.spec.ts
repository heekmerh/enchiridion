import { test, expect } from "@playwright/test";
import { fixtures } from "./fixtures";
import { routes } from "./routes";

for (const mode of ["text spacing", "200 percent text", "landscape"]) {
    test(`every route reflows with ${mode}`, async ({ page }) => {
        test.setTimeout(180_000);
        await page.setViewportSize(mode === "text spacing" ? { width: 320, height: 800 }
            : mode === "landscape" ? { width: 667, height: 375 } : { width: 1280, height: 800 });
        await page.emulateMedia({ reducedMotion: "reduce" });
        await fixtures(page, true);
        for (const path of routes) {
            await page.goto(path);
            await page.waitForTimeout(250);
            if (mode !== "landscape") await page.addStyleTag({ content: mode === "text spacing"
                ? "* { line-height: 1.5 !important; letter-spacing: .12em !important; word-spacing: .16em !important; } p { margin-bottom: 2em !important; }"
                : "html { font-size: 200% !important; }" });
            expect.soft(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), path).toBe(true);
        }
    });
}
