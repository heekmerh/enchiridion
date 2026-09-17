# OSCE and instrumentation sourcing checklist

This inventory compares the numbered station outlines in `scripts/content/OSCE.md` with the registrations in `enchiridion/lib/models/resource_topic.dart` and the available source and asset files. **Full** means a registered `dataAssetPath` points to a resource JSON with populated subsections and content groups. **Missing** means a registered OSCE topic has an outline but no `dataAssetPath` or matching full-content DOCX and JSON. **Source-only** means an item appears in the OSCE outline without its own `ResourceTopic` registration. The eleven missing OSCE rows need separately sourced, author-reviewed content before an asset can be generated; outline labels alone are not full content.

## Registered OSCE topic status

| Topic | App dataAssetPath | DOCX source | Resource JSON | Full-content status | Sourcing | Author review | Asset generation | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cardiovascular System | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Respiratory System | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Abdominal Examination | assets/data/resources/abdominal_examination.json | scripts/content/ABDOMINAL_EXAMINATION_osce.docx | enchiridion/assets/data/resources/abdominal_examination.json | full | source present | not assessed | asset present | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart`; `scripts/content/ABDOMINAL_EXAMINATION_osce.docx`; `enchiridion/assets/data/resources/abdominal_examination.json` |
| Neurological Examination | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Musculoskeletal Examination | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Eye | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Ear | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Nose | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Throat & Oral Cavity | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Neck | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Other Stations | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |
| Surgical Instruments & Devices | null | none | none | missing | [ ] | [ ] | [ ] | `scripts/content/OSCE.md`; `enchiridion/lib/models/resource_topic.dart` |

The Abdominal Examination DOCX contains non-empty source text, and its resource JSON has 69 populated subsections and 77 content groups. The other eleven rows have outline entries in `scripts/content/OSCE.md` and `enchiridion/lib/models/resource_topic.dart`, but no matching full-content sources or registered assets.

## Instrumentation status

| Instrumentation topic | App dataAssetPath | Tracked source | Populated resource JSON | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| Sutures | assets/data/resources/sutures.json | scripts/content/SUTURES_instrumentation.docx | enchiridion/assets/data/resources/sutures.json | full: non-empty DOCX; 36 subsections and 51 content groups | `enchiridion/lib/models/resource_topic.dart`; `scripts/content/SUTURES_instrumentation.docx`; `enchiridion/assets/data/resources/sutures.json` |
| IV Cannula | assets/data/resources/iv_cannula.json | scripts/content/IV_Cannula_instrumentation.docx | enchiridion/assets/data/resources/iv_cannula.json | full: non-empty DOCX; 28 subsections and 32 content groups | `enchiridion/lib/models/resource_topic.dart`; `scripts/content/IV_Cannula_instrumentation.docx`; `enchiridion/assets/data/resources/iv_cannula.json` |

Sutures and IV Cannula are registered under `kSurgicalInstrumentationTopics` and `kMedicalInstrumentationTopics`, respectively, in `enchiridion/lib/models/resource_topic.dart`. They are separate from the outline-only Surgical Instruments & Devices tab under `kOsceTopics`; their existing DOCX and JSON files do not supply full content for that OSCE tab. `scripts/content/medical_instrumentation.md` exists but is empty and untracked, so it supplies no full content; this agrees with the content-gap note in `.planning/STATE.md`.

## Source-only Section 12 instrument names

The following unique names appear in Section 12 of `scripts/content/OSCE.md`, in source order. They are outline entries and have no separate standalone `ResourceTopic` registrations in `enchiridion/lib/models/resource_topic.dart`.

- Scalpel
- Scalpel blade
- Mayo scissors
- Metzenbaum scissors
- Dissecting forceps
- Toothed forceps
- Artery forceps
- Mosquito forceps
- Kocher forceps
- Allis tissue forceps
- Babcock forceps
- Sponge-holding forceps
- Towel clip
- Needle holder
- Sinus forceps
- Dressing forceps
- Skin hook
- Retractor
- Langenbeck retractor
- Volkmann retractor
- Deaver retractor
- Self-retaining retractor
- Balfour retractor
- Abdominal retractor
- Speculum
- Vaginal speculum
- Cusco speculum
- Sims' speculum
- Proctoscope
- Sigmoidoscope
- Anoscope
- Laryngoscope
- Endotracheal tube
- Tracheostomy tube
- Chest tube
- Chest drain bottle
- Trocar and cannula
- Drainage catheter
- Foley catheter
- Suction catheter
- Feeding tube
- Ryle's tube
- Surgical suction tip
- Diathermy/electrocautery
- Surgical stapler
- Skin stapler
- Suture material
- Surgical needle
- Drain
- T-tube
- Malecot catheter
- Pezzer catheter
- Colostomy bag
- Ileostomy bag
- Plaster of Paris
- POP bandage
- Crepe bandage
- Elastic bandage
- Splint
- Cervical collar
- Thomas splint
- External fixator
- Orthopaedic cast
- Tourniquet
- Bone saw
- Gigli saw
- Osteotome
- Bone rongeur
- Periosteal elevator
- Mallet
- Bone lever
- Curette
- Amputation knife
- Doyen intestinal clamp
- Non-crushing bowel clamp
- Intestinal scissors
- Hernia mesh
- Breast biopsy needle
- Core biopsy device
- Fine-needle aspiration needle
- Lumbar puncture set
- Central venous catheter
- Arterial cannula
- Surgical drain
- Wound dressing set

Foley catheter appears twice in `scripts/content/OSCE.md`; it is listed once above.
