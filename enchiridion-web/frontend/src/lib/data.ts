export interface Book {
    id: string;
    title: string;
    specialty: string;
    description: string;
    coverImage: string;
    status: "Available" | "Coming Soon";
    slug: string;
    overview: string;
    highlights: string[];
}

export const books: Book[] = [
    {
        id: "1",
        title: "Enchiridion of Pediatrics",
        specialty: "Pediatrics",
        description: "A comprehensive guide to clinical pediatrics, from neonatology to adolescent medicine.",
        coverImage: "/ped cover.png",
        status: "Available",
        slug: "pediatrics",
        overview: "The Enchiridion of Pediatrics distills neonatology through adolescent medicine into a single bedside reference, organized the way pediatric rounds actually move: history, exam, red flags, management. Each chapter closes with weight-based dosing tables and age-specific differentials you can scan in seconds.",
        highlights: [
            "Neonatal resuscitation and NICU admission criteria",
            "Weight-based pediatric drug dosing tables",
            "Developmental milestones and red-flag screening",
            "Common pediatric emergencies and management algorithms",
        ],
    },
    {
        id: "2",
        title: "Enchiridion of Internal Medicine",
        specialty: "Internal Medicine",
        description: "Essential protocols and management strategies for adult clinical medicine.",
        coverImage: "/2.png",
        status: "Coming Soon",
        slug: "internal-medicine",
        overview: "Built for the adult medicine ward and clinic alike, the Enchiridion of Internal Medicine condenses diagnostic workups and management ladders for the conditions residents see every day, from electrolyte derangements to chronic disease management.",
        highlights: [
            "Stepwise diagnostic algorithms for common presentations",
            "Electrolyte and acid-base management at a glance",
            "Chronic disease management ladders (diabetes, hypertension, CKD)",
            "Evidence-based guideline summaries, updated as they change",
        ],
    },
    {
        id: "3",
        title: "Enchiridion of Surgery",
        specialty: "Surgery",
        description: "Operative techniques and perioperative care for the modern surgical resident.",
        coverImage: "/3.png",
        status: "Coming Soon",
        slug: "surgery",
        overview: "The Enchiridion of Surgery walks the surgical resident from pre-operative workup through post-operative care, pairing operative technique summaries with the perioperative checklists that actually get used on the ward.",
        highlights: [
            "Pre-operative risk assessment and consent checklists",
            "Step-by-step summaries of core operative techniques",
            "Post-operative complication recognition and management",
            "Surgical scoring systems and when to use them",
        ],
    },
    {
        id: "4",
        title: "Enchiridion of Obstetrics & Gynecology",
        specialty: "OBGYN",
        description: "Evidence-based maternal and fetal medicine at your fingertips.",
        coverImage: "/6.png",
        status: "Coming Soon",
        slug: "obgyn",
        overview: "Covering antenatal care through gynaecological emergencies, the Enchiridion of Obstetrics & Gynecology keeps maternal and fetal medicine protocols within reach for busy labour wards and outpatient clinics alike.",
        highlights: [
            "Antenatal care schedules and risk stratification",
            "Labour and delivery management protocols",
            "Gynaecological emergency recognition and response",
            "Contraception and family planning quick-reference",
        ],
    },
    {
        id: "5",
        title: "Enchiridion of Orthopaedics",
        specialty: "Orthopaedics",
        description: "A practical guide to musculoskeletal trauma, sports medicine, and reconstructive surgery.",
        coverImage: "/4.png",
        status: "Coming Soon",
        slug: "orthopaedics",
        overview: "From fracture classification to rehabilitation timelines, the Enchiridion of Orthopaedics is a practical field guide to musculoskeletal trauma, sports injuries, and reconstructive surgery.",
        highlights: [
            "Fracture classification systems and management pathways",
            "Common sports injury assessment and treatment",
            "Joint examination techniques by region",
            "Post-operative rehabilitation timelines",
        ],
    },
    {
        id: "6",
        title: "Enchiridion of Dermatology",
        specialty: "Dermatology",
        description: "Clinical patterns, diagnostic criteria, and cutting-edge therapies for skin conditions.",
        coverImage: "/5.png",
        status: "Coming Soon",
        slug: "dermatology",
        overview: "The Enchiridion of Dermatology pairs recognizable clinical patterns with diagnostic criteria and current therapies, built to help you name it, confirm it, and treat it in the same consult.",
        highlights: [
            "Visual pattern recognition for common skin conditions",
            "Diagnostic criteria for ambiguous presentations",
            "Topical and systemic therapy quick-reference",
            "When-to-refer guidance for dermatologic emergencies",
        ],
    },
    {
        id: "7",
        title: "Enchiridion of Radiology",
        specialty: "Radiology",
        description: "Interpret images with confidence. A concise atlas for residents and clinicians.",
        coverImage: "/7.png",
        status: "Coming Soon",
        slug: "radiology",
        overview: "A concise atlas for residents and clinicians, the Enchiridion of Radiology builds image interpretation confidence through structured reading approaches and annotated findings across modalities.",
        highlights: [
            "Systematic reading approaches by modality",
            "Annotated normal vs. pathological findings",
            "Appropriate imaging selection by clinical scenario",
            "Common reporting pitfalls and how to avoid them",
        ],
    },
    {
        id: "8",
        title: "Enchiridion of Psychiatry",
        specialty: "Psychiatry",
        description: "Modern psychopharmacology and diagnostic frameworks for mental health professionals.",
        coverImage: "/8.png",
        status: "Coming Soon",
        slug: "psychiatry",
        overview: "The Enchiridion of Psychiatry brings modern psychopharmacology and diagnostic frameworks together, built for clinicians who need a clear path from presentation to management plan.",
        highlights: [
            "DSM-aligned diagnostic frameworks by presentation",
            "Psychopharmacology quick-reference and titration guidance",
            "Risk assessment tools for acute presentations",
            "Therapy modality overview and referral pathways",
        ],
    },
    {
        id: "9",
        title: "Enchiridion OSCE: Obstetrics & Gynaecology",
        specialty: "OBGYN OSCE",
        description: "Station-by-station OSCE prep for obstetrics and gynaecology exams, from history-taking to clinical skills.",
        coverImage: "/covers/obgyn-osce.png",
        status: "Coming Soon",
        slug: "obgyn-osce",
        overview: "Built station-by-station the way the exam actually runs, this guide walks through history-taking, examination routines, and counselling scenarios for obstetrics and gynaecology OSCEs, with mark-scheme-style checklists for each.",
        highlights: [
            "Full history-taking stations with model structures",
            "Examination routines (abdominal, speculum, bimanual)",
            "Counselling and communication station scripts",
            "Examiner-style checklists for self-marking practice",
        ],
    },
    {
        id: "10",
        title: "Enchiridion OSCE: Pediatrics",
        specialty: "Pediatrics OSCE",
        description: "Structured OSCE stations covering pediatric history, examination, and common exam scenarios.",
        coverImage: "/covers/pediatrics-osce.png",
        status: "Coming Soon",
        slug: "pediatrics-osce",
        overview: "Covering the stations that come up again and again, this guide pairs pediatric history and examination routines with common exam scenarios, so you walk in having already rehearsed the room.",
        highlights: [
            "Pediatric history-taking frameworks by age group",
            "Examination routines for common systems stations",
            "Developmental assessment and growth chart stations",
            "Examiner-style checklists for self-marking practice",
        ],
    },
    {
        id: "11",
        title: "Enchiridion of Instrumentation in Surgery",
        specialty: "Surgical Instrumentation",
        description: "A visual reference to surgical instruments, their names, and their uses in the operating theatre.",
        coverImage: "/covers/instrumentation-surgery.png",
        status: "Coming Soon",
        slug: "instrumentation-surgery",
        overview: "A visual reference built for the scrub room: name the instrument, know its use, and recognise it on the tray without hesitation. Organised by surgical phase and instrument family.",
        highlights: [
            "Labelled photographs of core surgical instruments",
            "Grouped by function: cutting, grasping, retracting, suturing",
            "Standard tray setups by procedure type",
            "Common instrument name variations and regional terms",
        ],
    },
    {
        id: "12",
        title: "Enchiridion of Instrumentation in Medicine & Pediatrics",
        specialty: "Clinical Instrumentation",
        description: "Identify and understand the everyday instruments used in medical and pediatric clinical practice.",
        coverImage: "/covers/instrumentation-medicine-pediatrics.png",
        status: "Coming Soon",
        slug: "instrumentation-medicine-pediatrics",
        overview: "The everyday instruments of the medical and pediatric wards, identified and explained: what it's called, what it's for, and how it's used at the bedside.",
        highlights: [
            "Labelled photographs of ward and clinic instruments",
            "Pediatric-specific equipment and sizing considerations",
            "Correct technique notes for common bedside tools",
            "Quick-reference index by clinical use",
        ],
    },
    {
        id: "13",
        title: "Enchiridion OSCE: Medicine & Surgery",
        specialty: "Medicine & Surgery OSCE",
        description: "Core OSCE stations spanning internal medicine and surgery, built for exam-day confidence.",
        coverImage: "/covers/osce-medicine-surgery.png",
        status: "Coming Soon",
        slug: "osce-medicine-surgery",
        overview: "Core stations spanning internal medicine and surgery, built to rehearse the format as much as the content: history, examination, data interpretation, and procedure stations with examiner-style checklists.",
        highlights: [
            "History and examination stations across both specialties",
            "Data interpretation stations (ECGs, bloods, imaging)",
            "Procedural and communication skill stations",
            "Examiner-style checklists for self-marking practice",
        ],
    },
];

export interface Review {
    id: string;
    name: string;
    gender: "male" | "female";
    text: string;
}

export const reviews: Review[] = [
    {
        id: "1",
        name: "Dr. Sarah Jenkins",
        gender: "female",
        text: "The Enchiridion of Pediatrics has become my go-to bedside reference during rounds. The clarity of the protocols and the clinical pearls are unmatched. It truly bridges the gap between text-book theory and real-world practice.",
    },
    {
        id: "2",
        name: "Dr. Mark Thompson",
        gender: "male",
        text: "As a resident, the mobile app is a lifesaver. Being able to quickly check drug dosages and management guidelines for rare conditions has definitely improved my confidence in the ER.",
    },
    {
        id: "3",
        name: "Prof. Elizabeth Vance",
        gender: "female",
        text: "I recommend Enchiridion to all my medical students. It provides the right level of depth for clinical reference without being overwhelming. The editorial quality is excellent.",
    },
];
