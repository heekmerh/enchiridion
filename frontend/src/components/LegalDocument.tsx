import { readFileSync } from "node:fs";
import path from "node:path";
import type { ReactNode } from "react";
import styles from "./Premium.module.css";

type Block =
    | { kind: "heading"; level: number; text: string }
    | { kind: "paragraph"; text: string }
    | { kind: "quote"; text: string }
    | { kind: "list"; ordered: boolean; items: string[] };

const INLINE_PATTERN = /(\*\*[^*]+\*\*|\*[^*]+\*|\[[^\]]+\]\([^)]+\))/g;

function renderInline(text: string): ReactNode[] {
    return text.split(INLINE_PATTERN).filter(Boolean).map((part, index) => {
        if (part.startsWith("**")) return <strong key={index}>{part.slice(2, -2)}</strong>;
        const link = /^\[([^\]]+)\]\(([^)]+)\)$/.exec(part);
        if (link) return <a key={index} href={link[2]}>{link[1]}</a>;
        if (part.startsWith("*") && part.endsWith("*") && part.length > 2) return <em key={index}>{part.slice(1, -1)}</em>;
        return part;
    });
}

function parse(markdown: string): Block[] {
    const blocks: Block[] = [];
    let paragraph: string[] = [];
    const flush = () => {
        if (paragraph.length) blocks.push({ kind: "paragraph", text: paragraph.join(" ") });
        paragraph = [];
    };
    for (const rawLine of markdown.split("\n")) {
        const line = rawLine.trim();
        const heading = /^(#{1,4})\s+(.*)$/.exec(line);
        const bullet = /^[-*]\s+(.*)$/.exec(line);
        const numbered = /^\d+\.\s+(.*)$/.exec(line);
        const last = blocks[blocks.length - 1];
        if (!line) {
            flush();
        } else if (heading) {
            flush();
            blocks.push({ kind: "heading", level: heading[1].length, text: heading[2] });
        } else if (line.startsWith(">")) {
            flush();
            const text = line.replace(/^>\s?/, "");
            if (last?.kind === "quote") last.text += " " + text;
            else blocks.push({ kind: "quote", text });
        } else if (bullet || numbered) {
            flush();
            const ordered = !!numbered;
            const item = (bullet ?? numbered)![1];
            if (last?.kind === "list" && last.ordered === ordered) last.items.push(item);
            else blocks.push({ kind: "list", ordered, items: [item] });
        } else if (last?.kind === "list" && !paragraph.length && rawLine.startsWith("  ")) {
            last.items[last.items.length - 1] += " " + line;
        } else {
            paragraph.push(line);
        }
    }
    flush();
    return blocks;
}

export default function LegalDocument({ file }: { file: "terms" | "privacy" }) {
    const markdown = readFileSync(path.join(process.cwd(), "src", "content", "legal", `${file}.md`), "utf8");
    return (
        <div className={styles.page}>
            <article className={styles.panel}>
                {parse(markdown).map((block, index) => {
                    if (block.kind === "heading") {
                        const Tag = (["h1", "h2", "h3", "h4"] as const)[block.level - 1];
                        return <Tag key={index}>{renderInline(block.text)}</Tag>;
                    }
                    if (block.kind === "quote") return <p key={index} className={styles.info}>{renderInline(block.text)}</p>;
                    if (block.kind === "list") {
                        const List = block.ordered ? "ol" : "ul";
                        return <List key={index} style={{ paddingLeft: 24 }}>
                            {block.items.map((item, itemIndex) => <li key={itemIndex}>{renderInline(item)}</li>)}
                        </List>;
                    }
                    return <p key={index}>{renderInline(block.text)}</p>;
                })}
            </article>
        </div>
    );
}
