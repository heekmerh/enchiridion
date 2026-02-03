export interface Book {
    id: string;
    title: string;
    specialty: string;
    description: string;
    coverImage: string;
    status: "Available" | "Coming Soon";
    slug: string;
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
    },
    {
        id: "2",
        title: "Enchiridion of Internal Medicine",
        specialty: "Internal Medicine",
        description: "Essential protocols and management strategies for adult clinical medicine.",
        coverImage: "/covers/internal-medicine.jpg",
        status: "Coming Soon",
        slug: "internal-medicine",
    },
    {
        id: "3",
        title: "Enchiridion of Surgery",
        specialty: "Surgery",
        description: "Operative techniques and perioperative care for the modern surgical resident.",
        coverImage: "/covers/surgery.jpg",
        status: "Coming Soon",
        slug: "surgery",
    },
    {
        id: "4",
        title: "Enchiridion of Obstetrics & Gynecology",
        specialty: "OBGYN",
        description: "Evidence-based maternal and fetal medicine at your fingertips.",
        coverImage: "/covers/obgyn.jpg",
        status: "Coming Soon",
        slug: "obgyn",
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
