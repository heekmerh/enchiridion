# Enchiridion PRD — Product Requirements Document

**Last Updated:** 2026-05-21  
**Status:** In Development

---

## 1. PROJECT OVERVIEW

Enchiridion is a mobile-first clinical reader application for healthcare students and professionals. It combines:
- Offline-capable medical textbooks (reader mode)
- Interactive clinical calculators
- OSCE practice tools
- Question banks
- Device-locked access with email verification

### Target Platforms
- Android (primary)
- iOS (secondary)
- Windows/macOS/Linux (desktop, secondary)

---

## 2. COMPLETED FEATURES

### 2.1 Core App Infrastructure
- [x] Authentication (Supabase email/password)
- [x] State management (Provider)
- [x] Local storage (SharedPreferences)
- [x] Dark/light theme support
- [x] Settings drawer (theme, text size, font)
- [x] Profile screen (read-only)
- [x] Navigation structure (Library, Tools, Profile)

### 2.2 Reader
- [x] Floating back + TOC buttons (top-left pill)
- [x] Chapter navigation (previous/next)
- [x] Table of contents sidebar (search within chapters)
- [x] Bookmarks (favorite chapters)
- [x] Chapter notes (save/edit per chapter)
- [x] Reading progress bar
- [x] Auto-hide controls on scroll
- [x] Paediatrics book with content (1 chapter free)

### 2.3 Library
- [x] Full-screen book carousel (vertical scroll)
- [x] Book covers as page indicators
- [x] Open book → Reader
- [x] Long-press → Book options menu
- [x] Recent books sorting
- [x] Freemium access (1 free book, 1 free chapter per book)

### 2.4 Profile
- [x] Display user info (email, role, display name)
- [x] Edit display name (inline edit)
- [x] Upload profile photo (camera/gallery)
- [x] Avatar display with initials fallback
- [x] Logout button

### 2.5 Tools / Calculators
- [x] 7 core calculators implemented:
  - Weight-Based Drug Dosing
  - IV Infusion Rate
  - Glasgow Coma Scale
  - BMI
  - EDD / Gestational Age
  - Anion Gap
  - Creatinine Clearance
  - Paediatric Maintenance Fluids (Holliday-Segar)
- [x] Calculator categories & grouping
- [x] Favorites system
- [x] Freemium gating (1 free calculator per category)
- [x] Disclaimer framework

### 2.6 Mobile-Specific
- [x] Android INTERNET permission
- [x] Image picker (camera + gallery)
- [x] Supabase Storage integration (avatars)

---

## 3. PENDING FEATURES

### 3.1 CRITICAL (Blocking Release)

#### 3.1.1 Email Confirmation Flow
- [ ] Sign-up requires email confirmation
- [ ] Confirmation link sent to user email
- [ ] User clicks link to verify
- [ ] Only then can app be accessed
- [ ] Clear UI messaging on login/signup screens

#### 3.1.2 Device Binding & Monthly Switch
- [ ] App installation tied to device fingerprint
- [ ] User can switch to new device once per calendar month
- [ ] After switch, old device becomes unauthorized
- [ ] Clear user messaging on first login about device binding
- [ ] Admin panel (future) to manage device switches
- **Implementation:** Store device_id + binding timestamp in profiles table

#### 3.1.3 Locked Content Access Control
- [ ] Only Chapter 1 visible to free/unsubscribed users
- [ ] Subsequent chapters show lock icon + "Unlock to continue"
- [ ] Tap unlock → Paywall/subscription screen (future: UnlockScreen)
- [ ] Freemium threshold: `kFreeChapterCount = 1` (already defined, verify usage)
- [ ] All books except first chapter should show "Coming soon" or locked

---

### 3.2 HIGH PRIORITY (Reader UX)

#### 3.2.1 Reader Content Rendering
- [ ] **Table Wrapping:** No horizontal scroll in tables
  - Use `overflow: TextOverflow.ellipsis` + flexible columns
  - Or wrap cell content with `Flexible` + `Wrap`
  - Test with complex medical tables (labs, drug dosing)

#### 3.2.2 Top App Bar (SliverAppBar)
- [ ] Change from floating to fixed
  - Set `floating: false` or replace with fixed `AppBar`
  - Keep back + TOC pill always visible
  - Title always visible
  - Actions (notes, bookmark, settings) always accessible

#### 3.2.3 Sidebar Tree Structure
- [ ] Chapters panel shows expandable tree:
  ```
  Chapter 1
    ├─ Section 1.1
    │  ├─ Subsection 1.1.1
    │  └─ Subsection 1.1.2
    └─ Section 1.2
  Chapter 2
    └─ ...
  ```
- [ ] Tap subsection → Jump directly to that content
- [ ] Expand/collapse sections via chevron icon
- [ ] Highlight current section
- [ ] Search still works at top

---

### 3.3 MEDIUM PRIORITY (Tools Section Redesign)

#### 3.3.1 Tools Section Name
Select one of six suggestions:
1. Clinical Toolkit
2. Resources
3. Exam & Lab Tools
4. Professional Tools
5. Medical Tools
6. Study Suite

#### 3.3.2 Tools UI Redesign
- [ ] Rename tab from "Tools" to chosen name
- [ ] Display 4 tool categories as full-screen carousel (like Library):
  - **Calculators** (image: `assets/tools/calculators.png`)
  - **OSCE** (image: `assets/tools/osce.png`)
  - **Questions** (image: `assets/tools/questions.png`)
  - **Instrumentation** (image: `assets/tools/instrumentation.png`)
- [ ] Each category shows full-screen image + title overlay
- [ ] Vertical scroll (PageView)
- [ ] Page indicator dots on right side
- [ ] Tap category → Open that section
  - Calculators → Calculator list (existing)
  - OSCE → OSCE question bank (new, future)
  - Questions → Question bank (existing, embedded in books)
  - Instrumentation → Procedure guides (new, future)

#### 3.3.3 Asset Setup
- [ ] Create directory: `enchiridion/assets/tools/`
- [ ] Add 4 PNG/JPEG images:
  - `calculators.png` (high-res, ~540x960)
  - `osce.png`
  - `questions.png`
  - `instrumentation.png`
- [ ] Update `pubspec.yaml`:
  ```yaml
  assets:
    - assets/tools/
  ```

---

### 3.4 CALCULATOR ROADMAP

#### Phase 1: Core Missing Calculators (High Priority)

**Emergency & Critical Care** (add 7)
- qSOFA / SOFA score
- NEWS2 (Early Warning Score)
- Shock Index (HR/SBP)
- Osmolality & Osmolar Gap
- Corrected Sodium (Hyperglycemia)
- A-a Gradient
- PaO₂/FiO₂ Ratio

**Drug Dosing & Pharmacology** (add 5)
- Body Surface Area (BSA)
- eGFR (CKD-EPI)
- Gentamicin / Vancomycin dosing
- Insulin dose calculator
- Paracetamol dosing (pediatric & adult)

**Pediatrics** (add 6)
- Weight estimation (APLS)
- Broselow Tape equivalent
- Pediatric BP percentiles
- Neonatal bilirubin (nomogram)
- APGAR score
- Growth percentile (WHO)

#### Phase 2: Additional Specialties (Medium Priority)

**Cardiology** (7 calculators)
- CHA₂DS₂-VASc, HAS-BLED, TIMI, Framingham, QTc, MAP, Cardiac Output

**Respiratory** (5 calculators)
- PEFR, FEV1, ABG interpreter, Alveolar gas, CaO₂

**Surgery & Trauma** (5 calculators)
- Revised Trauma Score, ISS, Rule of 9s, Alvarado, Wells

**Obs & Gynae Additions** (3 calculators)
- Bishop Score, Partograph, Preeclampsia risk, GTPAL

**General Medicine** (add 3)
- Corrected Calcium, MELD, Child-Pugh

**Simple Utility** (5 calculators)
- Unit conversions (mg↔mmol, lbs↔kg)
- Time-based infusion
- Calorie requirements
- Ideal Body Weight (IBW)
- Waist-to-hip ratio

#### Phase 3: Enhanced Calculator Features

All calculators should include:
- [ ] **Result Explanation:** Plain-language interpretation
- [ ] **Clinical Interpretation:** How to act on result, risk stratification
- [ ] **Safety Notes:** When NOT to use, edge cases
- [ ] **Common Pitfalls:** Student/clinician mistakes
- [ ] **OSCE Tips:** Exam-focused guidance, how examiners ask
- [ ] **Copy/Save:** Copy result as text, save to history (opt.)

---

### 3.5 CALCULATOR-SPECIFIC ENHANCEMENTS

#### 3.5.1 BMI Calculator Unit Auto-Conversion
- [ ] When user switches unit (e.g., kg → lb, cm → ft/in):
  - Automatically convert all entered values
  - Maintain same physical quantity
  - Example: 70 kg → 154 lb (not reset to 0)
- [ ] Trigger on unit picker change
- [ ] Show visual feedback (subtle animation or toast)

---

### 3.6 INFRASTRUCTURE & BACKEND

#### 3.6.1 Supabase Tables
Verify/create:
- [ ] `profiles` table has `avatar_url` column (TEXT)
- [ ] `profiles` table has `device_id` column (TEXT)
- [ ] `profiles` table has `device_bound_at` column (TIMESTAMP)
- [ ] `profiles` table has `last_device_switch` column (TIMESTAMP)
- [ ] `profiles` table has `email_confirmed` column (BOOLEAN, default false)

#### 3.6.2 Supabase Storage
- [ ] `avatars` bucket created (public read access)
- [ ] `tools` bucket created (if storing tool images in cloud; optional if local assets)

#### 3.6.3 Supabase Auth Config
- [ ] Email confirmation required on signup
- [ ] Confirmation email template configured
- [ ] Auto-confirm OFF in development (if testing without email)
- [ ] Auto-confirm ON in production

---

## 4. CURRENT METRICS

| Category | Progress | Notes |
|----------|----------|-------|
| Calculators | 7/38 | 18% coverage |
| Reader Features | 80% | Missing tree TOC, fixed navbar |
| Access Control | 0% | Email + device binding not implemented |
| Tools Redesign | 0% | Library design exists, apply to tools |
| Calculator Enhancements | 0% | Result explanation, clinical interpretation pending |

---

## 5. KNOWN ISSUES & TECHNICAL DEBT

- [ ] Table content overflow (horizontal scroll on small screens)
- [ ] SliverAppBar disappears on scroll (should be fixed)
- [ ] Settings drawer footer covered by navigation bar (fixed with bottom padding)
- [ ] Device binding logic not yet designed
- [ ] Email confirmation UI flow not wired
- [ ] Tree structure for TOC not implemented
- [ ] No calculator result history/save feature

---

## 6. DEPLOYMENT NOTES

### Android Build
```bash
cd enchiridion
flutter build apk --release
```

Requires:
- `android.permission.INTERNET` ✓ (added)
- `image_picker` for profile photo ✓
- `file_selector` for desktop file picking ✓

### Release Checklist
- [ ] All CRITICAL features complete
- [ ] Email confirmation tested
- [ ] Device binding tested on 2+ devices
- [ ] Locked content verified
- [ ] Tables tested for wrapping
- [ ] Play Store key setup
- [ ] Privacy policy linked in app

---

## 7. SUCCESS CRITERIA

### MVP Release
- Email confirmation working
- Device binding enforced
- Locked content access control
- Table wrapping (no horizontal scroll)
- Fixed app bar
- Tools section renamed & redesigned
- 10+ calculators with basic features

### Post-MVP
- Full calculator roadmap (Phase 1 & 2)
- Result explanation + clinical interpretation on all calculators
- Tree-structured TOC with jump-to
- OSCE questions module
- Question bank module
- Instrumentation/procedure guides

---

## 8. USER FEEDBACK INTEGRATION

This PRD incorporates feedback from:
- User testing on mobile (Android)
- Desktop (Windows) testing
- UX review of reader layout
- Calculator ideas from medical curriculum

Open items awaiting user feedback:
- [ ] Tools section name (pick 1 of 6)
- [ ] Tools section images (provide 4 PNGs)
- [ ] Calculator feature priorities (Phase 1 vs Phase 2)
- [ ] Clinical interpretation guidance per calculator

---

## Appendix: Quick Links

- **Ideas file:** `/Ideas/ideas.md`
- **Calculator definitions:** `lib/models/calculator_definition.dart`
- **Auth service:** `lib/services/auth_service.dart`
- **Reader screen:** `lib/screens/reader_screen.dart`
- **Library screen:** `lib/screens/library_screen.dart`
- **Profile screen:** `lib/screens/profile_screen.dart`
- **Supabase config:** `lib/config/supabase_config.dart`
