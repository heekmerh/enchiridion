import { test, expect } from "@playwright/test";
import { accessible } from "./assertions";
import { fixtures } from "./fixtures";

import { routes } from "./routes";


for (const path of routes) {
    test(`AA route ${path}`, async ({ page }) => {
        await fixtures(page);
        await page.goto(path);
        await page.waitForTimeout(250);
        await accessible(page);
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    });
}
for (const path of ["/dashboard", "/admin", "/admin/reviews", "/account/subscription", "/premium/processing?reference=fixture", "/verify-email"]) {
    test(`AA signed-in fixture ${path}`, async ({ page }) => {
        await fixtures(page, true);
        await page.goto(path);
        await page.waitForTimeout(500);
        await accessible(page);
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    });
}
