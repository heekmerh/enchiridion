import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

export async function accessible(page: Page) {
    const results = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"])
        .analyze();
    const unresolvedContrast = results.incomplete.filter(result => result.id === "color-contrast");
    if (unresolvedContrast.length) await test.info().attach("contrast-needs-visual-review", {
        body: JSON.stringify(unresolvedContrast, null, 2), contentType: "application/json",
    });
    if (results.violations.length) console.log(JSON.stringify({ url: page.url(), issues: results.violations.map(v => ({ id: v.id, nodes: v.nodes.map(n => ({ target: n.target, failure: n.failureSummary })) })) }));
    expect(results.violations.map(v => ({ id: v.id, nodes: v.nodes.map(n => ({ target: n.target, failure: n.failureSummary })) }))).toEqual([]);
}
