# Enchiridion — Feature Outline

## 1. User Authentication & Access

- **Sign up / Log in** — email + password registration and login
- **Session persistence** — stay logged in across app restarts
- **Password reset** — via email link
- **User profile** — display name, role (e.g. student, clinician), basic preferences
- **Access control** — only authenticated users can access book content and calculators
- **Logout**

---

## 2. Library Landing Page

The first screen after login. Displays all available Enchiridion books as a browsable grid.

### Books (with thumbnails)

| Book | Thumbnail |
|---|---|
| Paediatrics | `Ideas/books/Paediatrics.jpeg` |
| Internal Medicine | `Ideas/books/Internal Medicine.jpeg` |
| Surgery | `Ideas/books/Surgery.jpeg` |
| Obstetrics & Gynaecology | `Ideas/books/Obstetrics & Gynaecology.jpeg` |
| Psychiatry | `Ideas/books/Psychiatry.jpeg` |
| Radiology | `Ideas/books/Radiology.jpeg` |
| Orthopedics | `Ideas/books/Orthopedics.jpeg` |
| Dermatology | `Ideas/books/Dermatology.jpeg` |


### UX details

- Each book displayed as a card: thumbnail image + title
- Tapping a card navigates into that book's content
- Grid layout, scrollable, mobile-optimized
- Visual indicator for books the user has recently opened

---

## 3. Content & Reading Experience

- **Mobile-optimized content layout** — all book/reference content rendered for mobile view
- **Keyword tags under topics** — surface related keywords that link to relevant sections in the book
- **Collapsible side notes panel** — users can expand/collapse a section to add personal notes per topic
- **Floating clip-ins / annotations** — attach floating notes to specific topics

---

## 4. Clinical Calculators

A dedicated calculator module, organized by specialty. Every calculator follows a **shared screen pattern**:

| Section | Content |
|---|---|
| Title + purpose | One-line description |
| Inputs | With explicit unit selectors, large tap targets |
| Result block | Large numeric answer, unit, short interpretation |
| Interpretation | Explain result, clinical interpretation, next step suggestion |
| Educational | Common pitfalls, OSCE tips tied to result |
| Safety note | Disclaimer / caution banner |
| Actions | Calculate · Copy Result · Reset · Save · Add to Favorites |

### Fully specified (v1 ready)

| # | Calculator | Key Inputs | Key Outputs |
|---|---|---|---|
| 1 | Weight-based drug dosing (mg/kg) | Weight (kg/lb), dose/kg, unit, frequency, max dose | Total dose, max-dose cap warning |
| 2 | IV infusion rate | Volume, time, drop factor (modes: mL/hr or gtt/min) | mL/hour, drops/min |
| 3 | Glasgow Coma Scale (GCS) | Eye/Verbal/Motor scores, intubated toggle | Total score, E_V_M display, severity |
| 4 | BMI | Weight (kg/lb), height (cm/m/ft-in) | BMI value, weight category |
| 5 | EDD / EGA calculator | LMP date, optional reference date | EDD, gestational age (weeks + days) |
| 6 | Anion Gap | Na⁺, Cl⁻, HCO₃⁻ | Gap value, normal/elevated/low |
| 7 | Creatinine Clearance (Cockcroft-Gault) | Age, sex, weight, serum creatinine (mg/dL or µmol/L) | CrCl mL/min, kidney function band |
| 8 | Pediatric Maintenance Fluids (Holliday-Segar) | Weight (kg/lb) | mL/day, mL/hr (4-2-1 rule) |

### Planned by category (backlog)

- **Emergency & Critical Care:** GCS, qSOFA/SOFA score, NEWS2 (Early Warning Score), Shock Index (HR/SBP), Anion Gap, Osmolality & Osmolar Gap, Corrected Sodium (Hyperglycemia), A-a Gradient, PaO₂/FiO₂ Ratio, Parkland Formula (burns fluid resuscitation)
- **Drug Dosing & Pharmacology:** Weight-based dosing (mg/kg), Body Surface Area (BSA), IV Infusion Rate, Creatinine Clearance (Cockcroft-Gault), eGFR (CKD-EPI), Gentamicin/Vancomycin dosing, Insulin dose calculators, Paracetamol dosing (pediatric & adult), Adrenaline dose (resuscitation)
- **Pediatrics:** APLS weight estimation, Broselow tape equivalent, BP percentiles, neonatal bilirubin, APGAR, WHO growth percentile
- **Cardiology:** CHA₂DS₂-VASc, HAS-BLED, TIMI, Framingham Risk, QTc, MAP, Cardiac Output
- **Respiratory:** PEFR, FEV1 predicted, ABG interpreter, alveolar gas equation, CaO₂
- **General Medicine / Metabolic:** Waist-to-hip ratio, corrected calcium, serum osmolality, LDL (Friedewald), MELD, Child-Pugh
- **Obs & Gynae:** Bishop Score, partograph plotting, preeclampsia risk, GTPAL
- **Surgery & Trauma:** Revised Trauma Score, ISS, Rule of 9s (burns), Alvarado, Wells Score (DVT/PE)
- **Utility:** Unit conversions, time-based infusion, calorie requirements, IBW

---

## 5. Calculator UX System

- **Real-time calculation** as inputs become valid, or explicit "Calculate" button
- **Inline validation** with plain-English error messages (e.g. "Enter a weight greater than 0")
- **Unit persistence** — last used unit remembered within session
- **One-tap copy** — formatted result text to clipboard (e.g. "Weight-based dose result: 240 mg per dose for 24 kg at 10 mg/kg")
- **Reset** — clears all fields
- **Save / Favorites** — persist a calculator to a quick-access list

---

## 6. Data Model per Calculator

Each calculator is defined as a structured object:

```
id, title, category, description,
inputs[], formula(), validationRules[],
formatter(), interpretationRules[], disclaimer
```

---

## 7. Safety & Disclaimer Framework

- **Global disclaimer** shown app-wide: *"Enchiridion calculators are clinical support tools and do not replace professional judgment, institutional guidelines, or senior review."*
- All calculators must: show units, reject negative/zero values, use cautious language ("Calculated estimate", "Verify clinically")
- High-risk calculators get a caution banner
- Forbidden phrasing: "Definitive diagnosis", "Guaranteed safe dose", "Correct treatment"

---

## 8. Question Bank

Per-book question banks for self-assessment.

- Questions organized per book / chapter
- **Freemium gate:** first 10 questions per book free, rest require unlock
- Question format: MCQ with explanation of correct answer
- Track answered questions and scores per user
- OSCE-style tips tied to questions where relevant

---

## 9. Freemium Access Model

| Feature | Free | Paid / Unlocked |
|---|---|---|
| Book content | First chapter per book | Full book |
| Question bank | First 10 questions per book | All questions |
| Calculators | One per category | All calculators |
| Notes / annotations | Available to all logged-in users | — |

- Access gates enforced after user is authenticated
- Unlock options: per-book purchase or full subscription (TBD)

---

## Priority Order for Implementation

1. User authentication (gate to all other features)
2. Library landing page with book thumbnails
3. Book reader with content (JSON already exists)
4. Freemium access gates
5. Calculator engine + shared screen pattern
6. The 8 fully-specified v1 calculators
7. Question bank
8. Notes/annotations system (collapsible side notes, floating clip-ins)
9. Keyword cross-referencing in content
10. Backlog calculators by category
