---
quick_id: 260919-kix
phase: quick-260919-kix
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/generate_resource_content.py
  - scripts/tests/test_generate_resource_content.py
  - enchiridion/assets/data/resources/iv_cannula.json
autonomous: true
requirements: [260919-kix]
subsystem: content
tags: [iv-cannula, docx, resource-extraction, subtopics]

estimate:
  tokens: 55000
  raw_tokens: 55000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - Opening the IV Cannula module shows Advantages, Disadvantages, Precautions and Complications as their own subtopics, each holding its own body content.
    - None of those four words appears as a bullet inside another subtopic's content list.
    - The last complication ("Cannula blockage") is still a list item under Complications, not a subtopic of its own.
    - Sutures and Abdominal Examination render exactly as they did before this change.
  artifacts:
    - scripts/generate_resource_content.py
    - scripts/tests/test_generate_resource_content.py
    - enchiridion/assets/data/resources/iv_cannula.json
  key_links:
    - "TopicSpec.bold_heading_min_pt -> is_heading() -> build_topic_json() subsection boundary"
    - "iv_cannula.json subsections -> subtopicTabsFor() in enchiridion/lib/widgets/common/subtopic_tabs.dart -> one tab per subtopic"
---

<objective>
Teach the shared resource extractor to recognise Word paragraphs that are visually
headings (bold + an explicit large run size) but carry the `Normal` paragraph style,
then re-extract IV Cannula so "Advantages", "Disadvantages", "Precautions" and
"Complications" become subtopic sections holding their body content instead of
flat bullets sitting beside that content.

Purpose: the IV Cannula module currently renders its entire first half as one
undifferentiated 45-item bullet list, because the source document expresses its
early section headings through direct run formatting rather than a `Heading N`
style. The reader has no way to tell a heading from a fact.

Output: a paragraph-formatting-aware heading rule in
`scripts/generate_resource_content.py` (opt-in per topic), a regenerated
`iv_cannula.json`, and a Python regression test that locks both the new behaviour
and the unchanged behaviour of the already-shipped topics.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

@scripts/generate_resource_content.py
@scripts/tests/test_convert_paediatrics.py
@enchiridion/lib/widgets/common/subtopic_tabs.dart

Prior art on this exact source document and topic-only regeneration:
@.planning/quick/260915-r9g-fix-the-iv-cannula-resource-extraction-error-reported-in-tes/260915-r9g-SUMMARY.md
</context>

<research_findings>
Measured directly from the source document and the shipped JSON before planning.
The executor should treat these as established facts and not re-derive them.

**Repo layout.** The repository root is
`/home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion`. The Flutter app is the
nested `enchiridion/` directory inside it. All paths in this plan are repo-root-relative,
so the extractor lives at `scripts/generate_resource_content.py` and the generated
asset at `enchiridion/assets/data/resources/iv_cannula.json`.

**The content model.** `build_topic_json` emits
`sections[] -> subsections[] -> content_groups[] -> blocks[]`. A *subtopic* is a
`subsection` (`subsection_title`). `enchiridion/lib/widgets/common/subtopic_tabs.dart`
turns one subsection into one tab for a chapter that has a single section with two or
more subsections — the branch `iv_cannula.json` takes today.

**Root cause.** `is_heading(text, style_name)` recognises only three things: a
`Heading*` paragraph style, a numbered prefix like `4. CLASSIFICATION`, or text whose
letters are entirely uppercase. In `IV_Cannula_instrumentation.docx` the first six
section headings are `Normal`-styled paragraphs whose runs are bold with an explicit
run font size:

| Paragraph | Style | All runs bold | Explicit run size |
|---|---|---|---|
| `IV Cannula (Peripheral Venous Cannula)` (doc title) | Normal | yes | 18.0 pt |
| `Well-labelled parts` | Normal | yes | 13.5 pt |
| `Uses` | Normal | yes | 18.0 pt |
| `Advantages` | Normal | yes | 18.0 pt |
| `Disadvantages` | Normal | yes | 18.0 pt |
| `Precautions` | Normal | yes | 18.0 pt |
| `Complications` | Normal | yes | 18.0 pt |

Being mixed-case, `Normal`-styled and unnumbered, each one falls past `is_heading`
into `checklist_candidate` (one or two words, no terminal punctuation) and is appended
to `pending_checklist` as a peer bullet of the body content it was meant to introduce.
From paragraph 46 onward the document switches to real `Heading 2`/`Heading 3` styles,
which is why the second half of the module is correctly sectioned and the first half
is not.

**The trap that rules out a bold-only heuristic.** Paragraph 45, `Cannula blockage`,
is bold but carries **no explicit run size** (it inherits the body size). It is the
final entry of the Complications list, not a heading. Requiring an explicit run size
at or above 13.5 pt keeps it a list item; a bold-only rule would wrongly promote it.
This case is the single most valuable assertion in the regression test.

**Blast radius — why the rule must be opt-in per topic.** The same
bold + large-run-size pattern matches paragraphs in the other two shipped sources that
are genuinely *not* subtopic headings:

- `SUTURES_instrumentation.docx`: 27 matches, including `Natural:` (14 pt, currently a
  `group_title`) and the content line
  `Polyglactin 910(VICRYL )  Absorbable/Synthetic/Braided` (14 pt).
- `ABDOMINAL_EXAMINATION_osce.docx`: 84 matches, including `Shape`, `Skin`,
  `Umbilicus`, `Patient condition`.

Applying the rule globally would restructure both already-shipped topics and change
their tab strips. The task's constraint is explicit that they must be unaffected, so the
threshold is carried on `TopicSpec` and enabled for `iv_cannula` only.

**Verified outcome of the fix.** A prototype run of the exact rule below produced:
34 subsections (up from 28) — the six new subtopics are `Well-labelled parts` (7
entries), `Uses` (5), `Advantages` (5), `Disadvantages` (5), `Precautions` (8),
`Complications` (8). `Cannula blockage` remained the eighth entry inside
`Complications`. The `Overview` subsection retained both images and shed all body text.
The doc-title paragraph becomes a heading whose subsection is empty, and
`flush_subsection`'s existing empty guard drops it — no extra suppression logic needed.

**Toolchain.** `python-docx` is installed; `pytest` is **not**. The existing tests use
stdlib `unittest`; `python3 -m unittest discover -s scripts/tests -p 'test_*.py'` from
the repo root runs all 12 and passes today.
</research_findings>

<tasks>

<task type="tracer">
  <name>Task 1: Paragraph-formatting-aware headings, end to end, for IV Cannula only</name>
  <files>scripts/generate_resource_content.py, enchiridion/assets/data/resources/iv_cannula.json</files>
  <action>
Wire one new signal — Word run formatting — from the source document all the way
through to the generated asset, for the single topic that needs it.

1. Add a field to the frozen `TopicSpec` dataclass: `bold_heading_min_pt: float | None = None`.
   Give it a default so the two existing entries are untouched. Set it to `13.5` on the
   `iv_cannula` spec only; leave `sutures` and `abdominal_examination` at the default.
   Put a short docstring or comment on the field explaining that it opts a topic into
   detecting headings by run formatting, and that the other two topics stay opted out
   because the same pattern matches ordinary content lines in their sources (see the
   counts in this plan's research findings).

2. Add a module-level helper `styled_heading_paragraph(paragraph, min_pt)` returning
   `bool`:
   - return `False` immediately when `min_pt` is `None`;
   - take the paragraph runs whose `.text.strip()` is non-empty; return `False` if there
     are none;
   - return `False` unless every one of those runs has a truthy `.bold`;
   - collect `run.font.size.pt` for the runs where `run.font.size` is not `None`;
   - return `False` when that collection is empty — a bold run with no explicit size is
     emphasis, not a heading — and otherwise return whether its maximum is `>= min_pt`.

3. Widen `is_heading` to `is_heading(text, style_name, paragraph=None, bold_heading_min_pt=None)`.
   Keep the three existing rules exactly as they are and evaluate them first; fall back
   to `styled_heading_paragraph(paragraph, bold_heading_min_pt)` only when they all miss.
   Both new parameters must default, so any existing two-argument caller keeps working.

4. Update the single call site inside `build_topic_json` (the `if is_heading(...)` branch
   in the block loop) to pass the live `paragraph` object and `spec.bold_heading_min_pt`.
   Pass the paragraph explicitly at the call site. Do not try to track a "current
   paragraph" through a generator side-channel: `body_items` is materialised with
   `list(iter_block_items(document))` before the loop starts, so any such side-channel
   holds the final paragraph for every iteration.

5. Add a repeatable `--topic SLUG` argument to `main()`. When supplied, filter `TOPICS`
   to the named slugs and skip `normalize_questions()` entirely, so regenerating one
   module cannot rewrite the exam question asset. Raise a clear error naming the
   unknown slug (and listing the valid ones) if a slug does not match any `TopicSpec`.
   With the flag absent, `main()` must behave exactly as it does today.

6. Regenerate this module only:
   `python3 scripts/generate_resource_content.py --topic iv_cannula`

Do not change `checklist_candidate`, `clean_heading`, the group-title rule, or the
image handling. Do not edit the source `.docx` — the correct signal is already in it.
  </action>
  <verify>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion && python3 scripts/generate_resource_content.py --topic iv_cannula && python3 -c "
import json
d=json.load(open('enchiridion/assets/data/resources/iv_cannula.json',encoding='utf-8'))
subs=d['sections'][0]['subsections']
titles=[s['subsection_title'] for s in subs]
want=['Advantages','Disadvantages','Precautions','Complications']
for w in want:
    assert w in titles, ('not a subtopic: '+w)
flat=[i for s in subs for g in s['content_groups'] for b in g['blocks'] if b['type']=='checklist' for i in b['items']]
for w in want:
    assert w not in flat, ('still a flat content item: '+w)
assert len(subs)==34, ('subtopic count '+str(len(subs)))
comp=[s for s in subs if s['subsection_title']=='Complications'][0]
items=[i for g in comp['content_groups'] for b in g['blocks'] if b['type']=='checklist' for i in b['items']]
assert len(items)==8 and items[-1]=='Cannula blockage', items
print('OK', len(subs), 'subtopics')
"</automated>
  </verify>
  <done>
`iv_cannula.json` has 34 subsections. Advantages (5 entries), Disadvantages (5),
Precautions (8) and Complications (8) are subsection titles carrying their own body
content, and none of the four survives as a bullet inside another subtopic. The final
Complications entry is `Cannula blockage`. `Overview` still holds both images.
`--topic iv_cannula` regenerated nothing else.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Lock the new rule and the untouched topics behind a regression test</name>
  <files>scripts/tests/test_generate_resource_content.py</files>
  <behavior>
    - A synthetic `Normal` paragraph whose runs are all bold at 18 pt is a styled heading when `min_pt` is 13.5.
    - The same paragraph is not a styled heading when the topic opts out (`min_pt` is `None`) — this is the guard that keeps Sutures and Abdominal Examination frozen.
    - A bold paragraph carrying no explicit run size is not a styled heading, even when `min_pt` is set. This is the `Cannula blockage` case.
    - A non-bold 18 pt paragraph is not a styled heading.
    - Against the real `IV_Cannula_instrumentation.docx`, all four named labels are subsection titles and none of them appears in any checklist; `Cannula blockage` is the last entry of the Complications checklist.
    - Regenerating `sutures` and `abdominal_examination` into a temporary directory reproduces the committed JSON byte for byte.
  </behavior>
  <action>
Create `scripts/tests/test_generate_resource_content.py` using stdlib `unittest`.
`pytest` is not installed — do not import it. Follow the import convention already
used by `scripts/tests/test_convert_paediatrics.py`: insert
`Path(__file__).resolve().parents[1]` onto `sys.path`, then import
`generate_resource_content`.

Cover the behaviours listed above:

- Unit tests for `styled_heading_paragraph`. Build documents in memory with
  `docx.Document()` and size runs with `docx.shared.Pt`, the way
  `test_convert_paediatrics.py` constructs its fixtures. Cover all four unit cases:
  bold + large size with a threshold set; the same paragraph with the threshold as
  `None`; bold with the run size left unset; and large size without bold.

- An integration test over the real source document. Read the committed
  `enchiridion/assets/data/resources/iv_cannula.json` rather than regenerating, so the
  test asserts what actually ships. Assert each of the four labels is a
  `subsection_title`, that no checklist anywhere in the file contains any of them as an
  entry, and that the Complications subtopic's checklist ends with `Cannula blockage`.

- A stability test for the opted-out topics. For each of `sutures` and
  `abdominal_examination`: point the module's `RESOURCE_DATA_DIR` and
  `RESOURCE_ASSET_DIR` globals at a `tempfile.TemporaryDirectory`, call
  `build_topic_json(spec)`, and assert the produced bytes equal the committed asset's
  bytes. Restore the module globals in `tearDown` (or `addCleanup`) so test ordering
  cannot leak a temp path into another test. Read and compare as bytes, not as decoded
  text, so any encoding or line-ending drift is caught too.

Keep the file free of network access and of any write into `enchiridion/assets/`.
  </action>
  <verify>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion && python3 -m unittest discover -s scripts/tests -p 'test_*.py' && test -z "$(git status --porcelain enchiridion/assets/ scripts/content/ | grep -v 'assets/data/resources/iv_cannula.json')" && echo "OK: iv_cannula.json is the only changed asset"</automated>
  </verify>
  <done>
The full `scripts/tests` suite passes, including the new module. The byte-identity
tests prove `sutures.json` and `abdominal_examination.json` are unchanged by the
extractor edit, and `git status` shows `iv_cannula.json` as the only modified file
under `enchiridion/assets/` — the bundled IV Cannula images and the exam question
asset are untouched.
  </done>
</task>

<task type="auto">
  <name>Task 3: Confirm the Flutter reader picks up the new subtopics with no Dart change</name>
  <files>(verification only — this task modifies no files)</files>
  <action>
Establish that the app needs no rendering change, rather than assuming it.

1. Re-read the `subtopicTabsFor` contract in
   `enchiridion/lib/widgets/common/subtopic_tabs.dart`. Confirm the branch a chapter
   with one section and two-or-more subsections takes, and confirm that the IV Cannula
   detail screen (`enchiridion/lib/screens/resource_topic_detail_screen.dart`) calls it
   without the optional `isSectionHeading` predicate — that predicate is
   Abdominal-Examination-specific and lives in `enchiridion/lib/utils/osce_subtopics.dart`.
   If both hold, the six new subsections become six new tabs automatically and no
   production Dart edit is required.

2. Run the analyzer and the Dart tests that touch resource topics and subtopic tabs:
   `flutter analyze` plus `flutter test test/widgets/subtopic_tabs_test.dart
   test/models/ test/screens/resource_topic_list_screen_grouping_test.dart
   test/utils/osce_subtopics_test.dart`, all from the `enchiridion/` app directory.

3. Only if a Dart test hard-codes a stale IV Cannula subsection count and now fails,
   update that expectation under `enchiridion/test/` and record the edit in the summary
   — no test is expected to, since the shipped assertions check asset paths and ordering
   rather than counts. Do not edit any file under `enchiridion/lib/`. In particular
   leave `subtopic_tabs.dart` alone: sibling batch item `260919-kiw` is rewriting that
   file's scroll behaviour, and an edit here would collide. The illustrative subsection
   count in its doc comment is knowingly left stale for that reason; note it in the
   summary so `260919-kiw` can refresh it.

Record the conclusion in the summary either way: that the reader groups by subtopic
already, or exactly what is missing.
  </action>
  <verify>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion/enchiridion && flutter analyze && flutter test test/widgets/subtopic_tabs_test.dart test/models/ test/screens/resource_topic_list_screen_grouping_test.dart test/utils/osce_subtopics_test.dart</automated>
    <human-check>Open the IV Cannula module in the running app and page through the tab strip: Advantages, Disadvantages, Precautions and Complications each appear as their own tab holding their own bullets, and no tab lists those four words as bullets.</human-check>
  </verify>
  <done>
`flutter analyze` is clean and the listed Dart tests pass against the regenerated
asset. The summary states whether the reader already groups by subtopic (expected) or
names the concrete gap. No file under `enchiridion/lib/` was modified.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| `scripts/content/*.docx` → extractor | A Word document is a zip archive parsed by `python-docx`; its text and embedded image parts are author-supplied input crossing into generated app assets. |
| generated JSON → Flutter reader | `iv_cannula.json` is bundled at build time and rendered as block content in the app. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-kix-01 | Tampering | `build_topic_json` writing outside its topic | medium | mitigate | `--topic` filters `TOPICS` and skips `normalize_questions()`; Task 2 asserts byte-identity for the two opted-out topics and gates on `git status` showing a single modified asset. |
| T-kix-02 | Information disclosure | `extract_images` writing embedded image parts to `enchiridion/assets/resources/content/<slug>/` | low | accept | The output directory is derived from the in-repo `spec.slug` constant, never from document-supplied data, so a crafted archive cannot redirect the write. The source documents are first-party course material. |
| T-kix-03 | Denial of service | Unbounded parse of a large `.docx` | low | accept | Build-time developer script over three committed first-party files; not reachable from the shipped app or from any user input. |
| T-kix-SC | Tampering | Package installs | n/a | n/a | No package-manager install occurs in this plan. `python-docx` and the Flutter toolchain are already present dependencies, so no legitimacy gate is required. |
</threat_model>

<verification>
1. `python3 scripts/generate_resource_content.py --topic iv_cannula` is idempotent — running it twice leaves the working tree unchanged after the first run.
2. `python3 -m unittest discover -s scripts/tests -p 'test_*.py'` passes.
3. `git status --porcelain enchiridion/assets/` lists `enchiridion/assets/data/resources/iv_cannula.json` and nothing else.
4. `flutter analyze` is clean and the scoped Dart tests pass from `enchiridion/`.
</verification>

<success_criteria>
- Advantages, Disadvantages, Precautions and Complications are IV Cannula subtopics carrying their own body content; none remains a flat bullet.
- `Cannula blockage` is still the last entry of the Complications list.
- The heading rule lives in the shared extractor as reusable, opt-in machinery, not as a hand-edit of the output file or of the source document.
- Sutures, Abdominal Examination, the exam question asset and both IV Cannula images are byte-identical to before.
- The Flutter reader renders the new subtopics with no change under `enchiridion/lib/`.
</success_criteria>

<output>
Create `.planning/quick/260919-kix-content-extraction-re-extract-scripts-content-iv-cannula-ins/260919-kix-SUMMARY.md` when done.
</output>
