import { test, expect } from "@playwright/test";
import { fixtures } from "./fixtures";
import { accessible } from "./assertions";

test.beforeEach(async ({ page }) => { await fixtures(page); });

test("continuous heartbeat supports pause, resume, and reduced motion", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "no-preference" });
    await page.goto("/");
    const heart = page.locator('[class*="heartBackground"]');
    await expect(heart).toHaveCSS("animation-iteration-count", "infinite");
    await expect(heart).toHaveCSS("animation-duration", "1.2s");
    await expect(heart).toHaveCSS("animation-play-state", "running");
    await page.getByRole("button", { name: "Pause animations", exact: true }).click();
    await expect(heart).toHaveCSS("animation-play-state", "paused");
    await page.getByRole("button", { name: "Resume animations", exact: true }).click();
    await expect(heart).toHaveCSS("animation-play-state", "running");
    await page.emulateMedia({ reducedMotion: "reduce" });
    await expect(heart).toHaveCSS("animation-iteration-count", "1");
});

test("hero is circular and keeps enlarged content and links inside", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.goto("/");
    for (const enlarged of [false, true]) {
        if (enlarged) await page.addStyleTag({ content: "html { font-size: 200%; } p, a { line-height: 1.5 !important; letter-spacing: .12em; word-spacing: .16em; }" });
        const circle = page.locator('[class*="heroCircleContainer"]');
        const bounds = await circle.boundingBox();
        expect(Math.abs(bounds!.width - bounds!.height)).toBeLessThan(1);
        const safe = await circle.getByRole("region").evaluate(element => {
            const box = element.getBoundingClientRect();
            const circle = element.parentElement!.getBoundingClientRect();
            const radius = circle.width / 2;
            return [[box.left, box.top], [box.right, box.top], [box.left, box.bottom], [box.right, box.bottom]]
                .every(([x, y]) => Math.hypot(x - circle.left - radius, y - circle.top - radius) < radius);
        });
        expect(safe).toBe(true);
        const link = circle.getByRole("link", { name: "Download the App" });
        await link.focus();
        await expect.poll(() => link.evaluate(element => {
            const box = element.getBoundingClientRect();
            const region = element.closest('[role="region"]')!.getBoundingClientRect();
            const vertical = box.height > region.height - 16
                ? box.bottom > region.top && box.top < region.bottom
                : box.top >= region.top - 1 && box.bottom <= region.bottom + 1;
            return vertical && box.left >= region.left - 1 && box.right <= region.right + 1;
        })).toBe(true);
        expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize()!.width + 1);
    }
    await accessible(page);
});

test("book carousel automatically scrolls and pauses during interaction", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "no-preference" });
    await page.goto("/");
    const track = page.locator("#book-carousel");
    await expect.poll(() => track.evaluate(element => element.scrollLeft), { timeout: 10000 }).toBeGreaterThan(0);
    await page.getByRole("button", { name: "Pause book scrolling" }).click();
    const left = await track.evaluate(element => element.scrollLeft);
    await page.mouse.move(0, 0);
    await page.getByRole("button", { name: "Pause animations", exact: true }).focus();
    await page.waitForTimeout(5500);
    expect(await track.evaluate(element => element.scrollLeft)).toBe(left);
});

test("About covers rotate automatically and support the pause control", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "no-preference" });
    await page.clock.install();
    await page.goto("/about");
    const covers = page.locator('[class*="bookCoverWrapper"]');
    await expect(covers.first()).toHaveAttribute("aria-hidden", "false");
    await expect(page.getByRole("button", { name: "Pause book covers" })).toBeVisible();
    await page.clock.runFor(4500);
    await expect(covers.nth(1)).toHaveAttribute("aria-hidden", "false");
    await page.getByRole("button", { name: "Pause animations", exact: true }).click();
    await page.clock.runFor(4500);
    await expect(covers.nth(1)).toHaveAttribute("aria-hidden", "false");
});

test("community previews rotate and preserve the accessible message list", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "no-preference" });
    await page.clock.install();
    await page.route("**/api/referral/global-broadcasts", route => route.fulfill({ json: [
        { id: "1", type: "registration", text: "First community update" },
        { id: "2", type: "registration", text: "Second community update" },
    ] }));
    await page.goto("/refer");
    const preview = page.locator('[data-motion-preview]');
    await expect(preview).toHaveText("First community update");
    await page.clock.runFor(6500);
    await expect(preview).toHaveText("Second community update");
    await page.getByRole("button", { name: "Pause animations", exact: true }).click();
    await page.clock.runFor(6500);
    await expect(preview).toHaveText("Second community update");
    await page.getByRole("button", { name: "Community updates", exact: true }).click();
    await expect(preview).toHaveCount(0);
    const list = page.getByRole("region", { name: "Community updates", exact: true });
    await expect(list.getByRole("listitem")).toHaveCount(2);
    await accessible(page);
});

test("review carousel resumes its automatic scrolling", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "no-preference" });
    await page.clock.install();
    await page.route("**/api/reviews**", route => route.fulfill({ json: Array.from({ length: 5 }, (_, i) => ({
        id: String(i), name: `Example Reader ${i}`, jobTitle: "Medical Officer", rating: 4,
        text: "Useful clinical reference for everyday learning.", status: "approved", createdAt: "2026-10-01T12:00:00Z",
    })) }));
    await page.goto("/");
    const carousel = page.locator('#user-reviews [class*="__carousel"]').last();
    await expect(carousel.locator(':scope > div')).toHaveCount(5);
    await page.clock.runFor(5500);
    await expect.poll(() => carousel.evaluate(element => element.scrollLeft)).toBeGreaterThan(0);
});
