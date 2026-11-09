---
status: partial
phase: 04-phase-1-calculators-enhancements-high-priority
source: [04-VERIFICATION.md]
started: 2026-06-05T00:00:00Z
updated: 2026-06-05T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. BMI Unit Conversion — Device Interaction
expected: Open BMI calculator, enter 70 in weight field, tap kg dropdown, select lb — weight reads 154.32. Enter 170 in height field (cm), tap cm dropdown, select m — height reads 1.70. Values do not reset to zero on unit change.
result: [pending]

### 2. Clinical Notes Section — All 26 Calculators
expected: All 26 calculators show 'Clinical Notes' ExpansionTile with populated content. Tile expands and collapses correctly. No calculator shows an empty tile.
result: [pending]

### 3. New Calculator Forms — Inputs, Calculation, Validation
expected: For shock-index, egfr-ckd-epi, apgar, neonatal-bilirubin: valid inputs produce a non-empty result string with units and band label. Invalid/empty inputs show a SnackBar error. No crash or silent failure.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
