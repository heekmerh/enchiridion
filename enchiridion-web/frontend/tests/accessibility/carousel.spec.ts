import { test, expect } from "@playwright/test";
import { fixtures } from "./fixtures";
import { accessible } from "./assertions";

test("collection previews the next book and supports buttons and keyboard", async ({ page }) => {
    await fixtures(page);
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.goto("/");
    const carousel = page.getByRole("region", { name: "Medical handbooks", exact: true });
    await carousel.scrollIntoViewIfNeeded();
    const fullCards = page.viewportSize()!.width > 1024 ? 3 : 1;
    const peek = await carousel.locator(':scope > div').nth(fullCards).evaluate(element => {
        const track = element.parentElement!.getBoundingClientRect();
        const card = element.getBoundingClientRect();
        return { visible: track.right - card.left, width: card.width };
    });
    expect(peek.visible).toBeGreaterThanOrEqual(24);
    expect(peek.visible).toBeLessThan(peek.width);
    await expect(page.getByText("Browse all 8 handbooks", { exact: true })).toBeVisible();
    const previous = page.getByRole("button", { name: "Previous books", exact: true });
    const next = page.getByRole("button", { name: "Next books", exact: true });
    await expect(previous).toBeDisabled();
    const peekBounds = await carousel.locator(":scope > div").nth(fullCards).boundingBox();
    expect(peekBounds).not.toBeNull();
    await page.mouse.move(peekBounds!.x + 10, peekBounds!.y + 50);
    await expect.poll(() => carousel.evaluate(element => element.scrollLeft)).toBeGreaterThan(0);
    await previous.click();
    await expect.poll(() => carousel.evaluate(element => element.scrollLeft)).toBe(0);
    await next.focus();
    await page.keyboard.press("Enter");
    await expect.poll(() => carousel.evaluate(element => element.scrollLeft)).toBeGreaterThan(100);
    await expect(previous).toBeEnabled();
    const bothPeeks = await carousel.evaluate(element => {
        const viewport = element.getBoundingClientRect();
        return [...element.children].map(card => card.getBoundingClientRect()).reduce((peeks, bounds) => ({
            left: peeks.left || (bounds.left < viewport.left && bounds.right > viewport.left + 15),
            right: peeks.right || (bounds.left < viewport.right - 15 && bounds.right > viewport.right),
        }), { left: false, right: false });
    });
    expect(bothPeeks).toEqual({ left: true, right: true });
    for (let step = 1; step < 8 - fullCards - 1; step++) {
        const before = await carousel.evaluate(element => element.scrollLeft);
        await next.click();
        await expect.poll(() => carousel.evaluate(element => element.scrollLeft)).toBeGreaterThan(before);
    }
    const lastBook = carousel.getByRole("link").last();
    const finalPeek = await lastBook.evaluate(element => {
        const viewport = element.closest("#book-carousel")!.getBoundingClientRect();
        const bounds = element.getBoundingClientRect();
        return bounds.left < viewport.right - 15 && bounds.right > viewport.right;
    });
    expect(finalPeek).toBe(true);
    await lastBook.focus();
    await expect.poll(() => lastBook.evaluate(element => {
        const track = element.closest('#book-carousel')!.getBoundingClientRect();
        const card = element.getBoundingClientRect();
        return card.left >= track.left - 1 && card.right <= track.right + 1;
    })).toBe(true);
    await expect(next).toBeDisabled();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    await accessible(page);
});
