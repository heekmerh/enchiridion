import { test, expect, type Page } from "@playwright/test";
import { fixtures, stats } from "./fixtures";
import { accessible } from "./assertions";

async function trap(page: Page) {
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    for (let count = 0; count < 20; count++) {
        await page.keyboard.press("Tab");
        expect(await dialog.evaluate(element => element.contains(document.activeElement))).toBe(true);
    }
    for (let count = 0; count < 10; count++) {
        await page.keyboard.press("Shift+Tab");
        expect(await dialog.evaluate(element => element.contains(document.activeElement))).toBe(true);
    }
    await accessible(page);
}
async function login(page: Page) {
    if (page.viewportSize()!.width < 1281) {
        await page.getByRole("button", { name: "Open navigation" }).click();
        await page.getByRole("button", { name: "Partnership", exact: true }).click();
    }
    await page.getByRole("button", { name: "Partner Login", exact: true }).click();
}

test.beforeEach(async ({ page }) => { await fixtures(page); });

test("navigation, login, reset view, focus restoration and Escape", async ({ page }) => {
    await page.goto("/");
    if (page.viewportSize()!.width < 1281) {
        await page.getByRole("button", { name: "Open navigation" }).click();
        await trap(page);
        await page.keyboard.press("Escape");
        await expect(page.getByRole("button", { name: "Open navigation" })).toBeFocused();
    } else {
        await page.getByRole("button", { name: "Open Books menu" }).focus();
        await page.keyboard.press("Enter");
        await accessible(page);
        await page.keyboard.press("Escape");
        await expect(page.getByRole("button", { name: "Open Books menu" })).toBeFocused();
    }
    await login(page);
    await trap(page);
    await page.getByRole("button", { name: /Forgot/ }).click();
    await accessible(page);
    await page.keyboard.press("Escape");
    await expect(page.getByRole("dialog")).toHaveCount(0);
});

test("desktop navigation expands on hover and remains dismissible", async ({ page }) => {
    test.skip(page.viewportSize()!.width < 1281, "Desktop hover navigation");
    await page.goto("/");
    const panel = page.locator("#desktop-navigation-panel");
    const nav = page.getByRole("navigation", { name: "Primary navigation" });
    for (const label of ["Books", "App", "Referral Program"]) {
        await nav.getByRole("link", { name: label, exact: true }).hover();
        await expect(panel).toBeVisible();
        await expect(panel).toHaveAttribute("aria-label", `${label} navigation`);
        await panel.hover();
        await expect(panel).toBeVisible();
        await page.mouse.move(1400, 950);
        await expect(panel).toBeHidden();
    }
    await nav.getByRole("link", { name: "Books", exact: true }).hover();
    await nav.getByRole("button", { name: "Close Books menu" }).focus();
    await page.keyboard.press("Escape");
    await expect(panel).toBeHidden();
    await expect(nav.getByRole("button", { name: "Open Books menu" })).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(panel).toBeVisible();
    await panel.getByRole("link").first().focus();
    await page.mouse.move(1400, 950);
    await expect(panel).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(panel).toBeHidden();
});

test("newsletter and keyboard-operable review rating", async ({ page }) => {
    await page.goto("/reviews");
    await expect(page.locator("#review-form-panel")).toBeHidden();
    await page.getByRole("button", { name: "Write a Review" }).click();
    await accessible(page);
    await page.getByRole("radio", { name: "5 stars", exact: true }).focus();
    await page.keyboard.press("ArrowRight");
    await expect(page.getByRole("radio", { name: "4 stars", exact: true })).toBeChecked();
    await page.getByRole("button", { name: "Join the Newsletter" }).click();
    await accessible(page);
    await page.getByLabel("Email address", { exact: true }).fill("reader@example.test");
    await page.route("**/api/referral/subscribe-newsletter", route => route.fulfill({ status: 503, json: { error: "Try again" } }));
    await page.locator("#newsletter-panel").getByRole("button", { name: /Subscribe|Join|Sign/ }).click();
    await accessible(page);
});

test("sample dialog, checkout shipping, delivery and payment states", async ({ page }) => {
    await page.goto("/about");
    await page.getByRole("button", { name: "Unlock Sample Now" }).click();
    await trap(page);
    await page.keyboard.press("Escape");
    await expect(page.getByRole("button", { name: "Unlock Sample Now" })).toBeFocused();
    await page.goto("/books/pediatrics");
    await page.getByRole("button", { name: /Buy Edition/ }).click();
    await trap(page);
    await page.getByLabel("Full Name", { exact: true }).fill("Example Reader");
    await page.getByLabel("State", { exact: true }).selectOption("Lagos");
    await page.getByLabel("City", { exact: true }).fill("Lagos");
    await page.getByLabel("Apartment Number / Detailed Address").fill("12 Example Street");
    await page.getByLabel("Phone Number", { exact: true }).fill("+2348000000000");
    await page.getByLabel("Email", { exact: true }).fill("reader@example.test");
    await page.getByRole("button", { name: "Continue to Delivery" }).click();
    await expect(page.getByRole("button", { name: /Lagos.*2,000/ })).toBeVisible();
    await accessible(page);
    await page.getByRole("button", { name: /Lagos.*2,000/ }).click();
    await page.getByRole("button", { name: "Continue to Pay" }).click();
    await accessible(page);
    await page.keyboard.press("Escape");
    await expect(page.getByRole("dialog")).toHaveCount(0);
});

test("password mismatch has a connected error and focuses confirmation", async ({ page }) => {
    await page.goto("/reset-password");
    await page.getByLabel("Email", { exact: true }).fill("reader@example.test");
    await page.getByLabel("Reset code").fill("12345678");
    await page.getByLabel("New Password", { exact: true }).fill("example-password");
    await page.getByLabel("Confirm New Password").fill("different-password");
    await page.getByRole("button", { name: "Update Password" }).click();
    await expect(page.getByLabel("Confirm New Password")).toBeFocused();
    await expect(page.getByLabel("Confirm New Password")).toHaveAttribute("aria-invalid", "true");
    await accessible(page);
});

test("dashboard rules and distributor terms dialogs", async ({ page }) => {
    await fixtures(page, true);
    await page.goto("/dashboard");
    await expect(page.getByRole("dialog", { name: "Rank achievement" })).toBeVisible();
    await trap(page);
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: "How points work" }).first().click();
    await trap(page);
    await page.keyboard.press("Escape");
    await page.goto("/refer");
    await page.getByRole("button", { name: "Terms & Conditions", exact: true }).click();
    await trap(page);
    await page.keyboard.press("Escape");
});

test("text spacing and large text preserve reflow and the oval hero", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    for (const path of ["/", "/refer", "/dashboard", "/admin", "/terms"]) {
        await page.goto(path);
        await page.addStyleTag({ content: "p, li, label, button, a { line-height: 1.5 !important; letter-spacing: .12em !important; word-spacing: .16em !important; } p { margin-bottom: 2em !important; }" });
        expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), path).toBe(true);
    }
    await page.goto("/");
    const panel = page.locator('[class*="heroCircleContainer"]');
    await expect(panel).toHaveCSS("border-top-left-radius", "50%");
});

test("rewards disclosures and partner handbook", async ({ page }) => {
    await page.goto("/rewards");
    for (const name of ["View Prize Redemption Rules", "Account & Payout Rules"]) {
        const button = page.getByRole("button", { name, exact: true });
        await button.click();
        await expect(button).toHaveAttribute("aria-expanded", "true");
        const id = await button.getAttribute("aria-controls");
        await expect(page.locator(`#${id}`)).toBeVisible();
        await accessible(page);
        await button.click();
        await expect(page.locator(`#${id}`)).toBeHidden();
    }
    await page.getByRole("button", { name: /New to the program/ }).click();
    await trap(page);
    await page.keyboard.press("Escape");
});

test("registration validation summary links to invalid fields", async ({ page }) => {
    await page.goto("/refer");
    await page.locator('form button[type="submit"]').first().click();
    const summary = page.locator("#registration-errors");
    await expect(summary).toBeFocused();
    await accessible(page);
    await summary.getByRole("link").first().click();
    await expect(page.locator("#fullName")).toBeFocused();
    await expect(page.locator("#fullName")).toHaveAttribute("aria-invalid", "true");
});

test("subscription and moderation service errors provide feedback", async ({ page }) => {
    await fixtures(page, true);
    await page.route("**/api/v1/subscription/current", route => route.fulfill({ status: 503, json: {} }));
    await page.goto("/account/subscription");
    await expect(page.getByRole("alert").filter({ hasText: "could not be loaded" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Try again" })).toBeVisible();
    await accessible(page);
    await page.route("**/api/reviews**", route => route.fulfill({ status: 503, json: {} }));
    await page.goto("/admin/reviews");
    await expect(page.getByRole("alert").filter({ hasText: "could not be loaded" })).toBeVisible();
    await accessible(page);
});

test("populated mastery cards, filters and community updates", async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem("enchiridion_user_city", "Lagos"));
    await page.route("**/api/referral/masters", route => route.fulfill({ json: [{ username: "Example Master", soulsGuided: 12, masteryDate: "2026-01-01", city: "Lagos", avatar: "/assets/logo.png" }] }));
    await page.route("**/api/referral/global-broadcasts", route => route.fulfill({ json: [{ id: "1", text: "Example Partner reached a milestone." }] }));
    await page.goto("/rewards");
    await expect(page.getByRole("heading", { name: "Example Master", exact: true })).toBeVisible();
    await page.getByRole("button", { name: "Masters from Lagos", exact: true }).click();
    await expect(page.getByRole("button", { name: "Masters from Lagos", exact: true })).toHaveAttribute("aria-pressed", "true");
    await page.getByRole("button", { name: "Community updates", exact: true }).click();
    await expect(page.getByText("Example Partner reached a milestone.")).toBeVisible();
    await accessible(page);
});


test("submitted review persists and receives focus", async ({ page }) => {
    await page.goto("/reviews");
    await page.getByRole("button", { name: "Write a Review" }).click();
    await page.getByLabel("Full Name").fill("Example Reader");
    await page.getByLabel("Job Title / Profession").fill("Doctor");
    await page.getByLabel("Your Review").fill("The handbook is useful for studying and reviewing everyday medical knowledge.");
    await page.getByRole("button", { name: "Submit Review", exact: true }).click();
    const success = page.getByRole("status").filter({ hasText: "Review Submitted!" });
    await expect(success).toBeFocused();
    await accessible(page);
    await page.getByRole("button", { name: "Close", exact: true }).click();
    await expect(page.getByRole("button", { name: "Write a Review" })).toBeFocused();
});

test("milestone and underlying rank dialogs manage focus in sequence", async ({ page }) => {
    await fixtures(page, true);
    await page.route("**/api/referral/stats**", route => route.fulfill({ json: { ...stats, totalReferrals: 50 } }));
    await page.goto("/dashboard");
    await expect(page.getByRole("dialog", { name: "Referral milestone reached" })).toBeVisible();
    await trap(page);
    await page.keyboard.press("Escape");
    await expect(page.getByRole("dialog", { name: "Rank achievement" })).toBeVisible();
    await trap(page);
    await page.keyboard.press("Escape");
    await expect(page.getByRole("dialog")).toHaveCount(0);
});

test("sample chapter heading stays readable on its dark gradient", async ({ page }) => {
    await page.goto("/");
    const heading = page.getByRole("heading", { name: "See Inside the Enchiridion", exact: true });
    await heading.scrollIntoViewIfNeeded();
    await expect(heading).toHaveCSS("color", "rgb(255, 255, 255)");
    // axe may mark text over gradients as incomplete; assert the actual rendered colour.
    const section = heading.locator("xpath=ancestor::section");
    await expect(section).toHaveCSS("background-image", "linear-gradient(135deg, rgb(10, 17, 40) 0%, rgb(28, 37, 65) 100%)");
});


test("dark page headings have explicit light foregrounds", async ({ page }) => {
    for (const [path, name] of [
        ["/about", "Author’s Vision"],
        ["/reviews", "Reviews & Feedback"],
        ["/rewards", "Download the App, Climb the Ranks, and Win!"],
    ]) {
        await page.goto(path);
        const heading = page.getByRole("heading", { name, exact: true });
        await heading.scrollIntoViewIfNeeded();
        await expect(heading).toHaveCSS("color", "rgb(255, 255, 255)");
    }
});
