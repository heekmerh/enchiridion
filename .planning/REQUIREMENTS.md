# MVP Polish — Scoped Requirements

**Milestone:** MVP Polish  
**Status:** Planning  
**Target:** Shippable MVP with auth, content lock, reader polish, and Phase 1 calculators

---

## 1. ACCESS CONTROL & AUTHENTICATION

### 1.1 Email Confirmation Flow

**Requirement:** Users must confirm their email before accessing the app.

**User Journey:**
1. User fills signup form (email, password, display name, role)
2. Click "Sign Up" → confirmation email sent
3. User sees "Check your email" screen
4. User clicks link in email → redirected to confirmation page
5. Upon confirmation, user can log in
6. Login succeeds → redirected to Library

**Implementation:**
- [ ] Update `LoginScreen` with tab: "Log In" | "Sign Up"
- [ ] Create `SignUpScreen` with email, password, display name, role fields
- [ ] Create `ConfirmEmailScreen` (shown after signup)
- [ ] Supabase Auth email confirmation required (toggle in Supabase console)
- [ ] Handle confirmation link (via deep linking or browser redirect)
- [ ] Store `email_confirmed` in profiles table (boolean)
- [ ] Block app access if `email_confirmed == false`
- [ ] Add "Resend confirmation" button on ConfirmEmailScreen

**UI/UX:**
- Clear messaging: "Confirm your email to get started"
- Resend option (rate-limited, e.g., once per 60s)
- Timeout handling (link expires after 24h)

---

### 1.2 Device Binding & Monthly Switch

**Requirement:** App access is tied to the device it was created on. Users can switch to one new device per calendar month.

**Definitions:**
- **Device Fingerprint:** Unique identifier (device ID via platform channels)
- **Binding:** First login ties user to device
- **Switch:** User can authorize a new device once per month
- **Enforcement:** Logins from unbound devices are rejected after binding

**Data Model:**
```
profiles table additions:
- device_id: TEXT (first device, immutable)
- bound_at: TIMESTAMP (when first device bound)
- authorized_devices: JSONB (array of {device_id, authorized_at})
- last_device_switch: TIMESTAMP
```

**User Journey:**
1. User signs up on Device A → device_id = A, bound_at = now
2. User tries login on Device B → sees "New device detected"
3. Device B prompts: "Authorize this device? (1 per month)"
4. User confirms → Device B added to authorized_devices
5. User tries login on Device C within same month → "Device limit reached"
6. Next month, Device C can be authorized (replaces Device B or oldest)

**Implementation:**
- [ ] Get device fingerprint (Android: ANDROID_ID, iOS: identifierForVendor)
- [ ] Store device_id in profiles on first auth
- [ ] On each login, check if device_id matches
- [ ] If mismatch & no authorized device slot → show device authorization dialog
- [ ] If authorized → add to authorized_devices + update last_device_switch
- [ ] Enforce monthly limit (compare `now()` vs `last_device_switch`)
- [ ] Create `DeviceAuthorizationDialog` (ask user to confirm switch)

**UI/UX:**
- First login message: "This app is tied to your device. You can switch once per month."
- Device auth dialog: "Authorize [Device Name]? You can switch devices once per month."
- Lock screen if unauthorized: "This device is not authorized. Contact support or wait until [date]."

---

### 1.3 Content Access Lock (Chapter 1 Only)

**Requirement:** Only Chapter 1 is visible to free users. Remaining chapters show lock icon and "Unlock" button.

**Implementation:**
- [ ] Update `ReaderScreen` to check user's access level per book
- [ ] If free user & chapter_index >= 1 → show `_LockedChapterOverlay`
- [ ] Locked chapter displays: "This chapter requires a paid subscription"
- [ ] Button: "Unlock" → navigate to `UnlockScreen`
- [ ] Update freemium config: `kFreeChapterCount = 1`
- [ ] Verify library only loads Chapter 1 for free users

**Gating Logic:**
```dart
bool isChapterLocked(int chapterIndex, bool hasAccess) {
  return !hasAccess && chapterIndex >= kFreeChapterCount;
}
```

---

## 2. READER EXPERIENCE IMPROVEMENTS

### 2.1 Table Wrapping (No Horizontal Scroll)

**Requirement:** Table content wraps to fit screen width. Users scroll vertically only.

**Approach:**
- Wrap table cells in `Flexible` + text wrapping
- Use `Wrap` for cell content if needed
- Set max column width based on screen size
- Example: `DataTable` with `columnSpacing: 8.0` and `scrollable: false`

**Implementation:**
- [ ] Audit all `DataTable` and custom table widgets in `ReaderContent`
- [ ] Replace with wrappable columns (or use `DataTable` with horizontal scroll disabled)
- [ ] Test with 3-4 complex medical tables (lab values, dosing, vitals)
- [ ] Verify text is readable at wrapped widths

---

### 2.2 Fixed Top App Bar

**Requirement:** Top app bar (with back, TOC, title, actions) stays fixed when scrolling.

**Current Issue:** `SliverAppBar` with `floating: true` hides on scroll.

**Solution:**
- Change `SliverAppBar` to `floating: false` (stays visible always)
- OR replace with fixed `AppBar` + `CustomScrollView`

**Implementation:**
- [ ] Update `ReaderAppBar` to `floating: false`
- [ ] Test that title, back, TOC, actions are always visible
- [ ] Verify no overlap with content below

---

### 2.3 Tree-Structured TOC with Jump-To

**Requirement:** TOC sidebar shows chapters with expandable sections/subsections. Clicking a subsection jumps to that content.

**Current State:** Basic TOC exists; needs tree structure.

**Implementation:**
- [ ] Update `TocDrawerContent` to display tree:
  ```
  Chapter 1
    ├─ Section 1.1
    │  ├─ Subsection 1.1.1
    │  └─ Subsection 1.1.2
    └─ Section 1.2
  ```
- [ ] Add expand/collapse chevron icons
- [ ] Tap subsection → call `bookProvider.navigateToSubsection(id)`
- [ ] Scroll reader content to that subsection (offset calculation)
- [ ] Highlight current subsection in tree

**Data Model:** Assume chapters/sections/subsections already have IDs in content JSON.

---

## 3. RESOURCES SECTION REDESIGN

### 3.1 Rename & Restructure

**Requirement:** Rename "Tools" tab to "Resources". Display 4 tool categories as full-screen carousel (like Library).

**Categories:**
1. **Calculators** — Clinical calculators (7 current + 18 Phase 1)
2. **OSCE** — Exam prep (future, for now shows placeholder)
3. **Questions** — Question bank per book (existing, integrated)
4. **Instrumentation** — Procedure guides (future, for now shows placeholder)

**Implementation:**
- [ ] Rename tab in `LibraryScreen` from "Tools" to "Resources"
- [ ] Create `_ResourcesTab` (similar to `_LibraryTab`)
- [ ] Use `PageView.builder` with vertical scroll
- [ ] Each page shows full-screen image + category title overlay
- [ ] Load images from `assets/resources/`:
  - `calculators.jpeg` → Calculators
  - `osce.jpeg` → OSCE
  - `exam_prep.jpeg` → Questions
  - `instrumentation.jpeg` → Instrumentation
- [ ] Add page indicator dots (right side)
- [ ] Tap page → open that section:
  - Calculators → Calculator list (existing `CalculatorScreen`)
  - OSCE → Placeholder screen (defer implementation)
  - Questions → Question bank (defer implementation)
  - Instrumentation → Placeholder screen (defer implementation)

**Asset Updates:**
- [ ] Update `pubspec.yaml` to include `assets/resources/`
- [ ] Verify images load correctly

---

## 4. CALCULATOR ENHANCEMENTS

### 4.1 Phase 1 Calculators (18 New)

**Emergency & Critical Care (7):**
- qSOFA / SOFA score
- NEWS2 (Early Warning Score)
- Shock Index (HR/SBP)
- Osmolality & Osmolar Gap
- Corrected Sodium (Hyperglycemia)
- A-a Gradient
- PaO₂/FiO₂ Ratio

**Drug Dosing (5):**
- Body Surface Area (BSA)
- eGFR (CKD-EPI)
- Gentamicin / Vancomycin dosing
- Insulin dose calculator
- Paracetamol dosing (pediatric & adult)

**Pediatrics (6):**
- Weight estimation (APLS)
- Broselow Tape equivalent
- Pediatric BP percentiles
- Neonatal bilirubin (nomogram)
- APGAR score
- Growth percentile (WHO)

**Implementation per Calculator:**
- [ ] Add to `kCalculators` list in `calculator_definition.dart`
- [ ] Create calculator screen (inputs, formula, result display)
- [ ] Add result interpretation section
- [ ] Include disclaimer

---

### 4.2 Enhanced Features (All Calculators)

Each calculator should display:

1. **Result Explanation** — Plain-language interpretation of the number
2. **Clinical Interpretation** — How to act on the result, risk stratification
3. **Safety Notes** — Conditions where result is unreliable, edge cases
4. **Common Pitfalls** — Mistakes students/clinicians make
5. **OSCE Tips** — Exam-focused guidance, how examiners phrase questions

**Implementation:**
- [ ] Add fields to `CalculatorDefinition`:
  ```dart
  final String explanation;
  final String clinicalInterpretation;
  final String safetyNotes;
  final String commonPitfalls;
  final String osceTips;
  ```
- [ ] Update calculator screens to display all sections
- [ ] Provide text for all 25 calculators (7 existing + 18 new)

---

### 4.3 BMI Calculator — Unit Auto-Conversion

**Requirement:** When user switches unit (e.g., kg → lb), all entered values auto-convert.

**Example:**
- User enters: 70 kg, 180 cm, clicks BMI → Result: 21.6
- User switches weight unit: kg → lb
- Values auto-convert: 154 lb (not reset to 0)
- User switches height unit: cm → ft/in
- Values auto-convert: 5'11" (not reset)

**Implementation:**
- [ ] Detect unit picker change in BMI calculator
- [ ] On change, convert all input values to new unit
- [ ] Keep result in sync (no recalculation needed if input unchanged)
- [ ] Trigger conversion via `onChanged` on unit dropdown

**Conversion Formulas:**
- Weight: 1 kg = 2.20462 lb
- Height: 1 cm = 0.01 m = 0.0328084 ft

---

## 5. ACCEPTANCE CRITERIA

### Definition of Done (Per Feature)

**Email Confirmation:**
- [ ] User cannot access app without confirming email
- [ ] Confirmation link works and redirects correctly
- [ ] "Check email" screen shown after signup
- [ ] Resend email button works
- [ ] Timeout handling (link expires)

**Device Binding:**
- [ ] Device fingerprint correctly identified
- [ ] First login ties device to account
- [ ] Second device prompts for authorization
- [ ] Monthly limit enforced
- [ ] Clear user messaging throughout

**Content Lock:**
- [ ] Chapter 1 visible to free users
- [ ] Chapters 2+ show lock icon
- [ ] Unlock button works and shows paywall

**Reader UX:**
- [ ] Tables render without horizontal scroll (tested on 3+ tables)
- [ ] Top app bar always visible
- [ ] TOC tree expands/collapses
- [ ] Clicking subsection jumps correctly

**Resources Redesign:**
- [ ] Tab renamed to "Resources"
- [ ] 4 categories display as full-screen carousel
- [ ] Page indicator dots show position
- [ ] Tapping category opens correct section
- [ ] Images load correctly

**Calculators:**
- [ ] All 25 calculators have definitions + screens
- [ ] Each displays explanation + interpretation + safety notes
- [ ] BMI unit conversion works without data loss
- [ ] All include disclaimer

---

## 6. RISK & MITIGATION

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Email service delays | Auth flow feels slow | Set up Supabase email templates, test delivery |
| Device fingerprint unreliable | Binding fails | Test on 10+ devices, fallback to multiple identifiers |
| TOC tree data structure mismatch | Navigation breaks | Verify JSON structure matches tree model first |
| Table wrapping breaks readability | Users can't read data | Test on multiple screen sizes, get feedback |
| Phase 1 calculator complexity | Timeline slips | Prioritize most common; defer complex ones to v2 |

---

*Requirements finalized: 2026-05-21*
