import { getAccessToken } from "@/lib/supabase";
export interface StateDelivery {
    name: string;
    cost: number;
    costLabel: string;
}

export type FulfillmentMode = "delivery" | "pickup";

export interface DeliveryZone {
    id: string;
    title: string;
    states: string[];
}

// Delivery rules as published by the backend (GET /referral/checkout-config). The backend charges by the
// same rules, so these are never hard-coded here: change them in backend/app/delivery.py.
export interface DeliveryPricing {
    hubStates: string[];
    zones: DeliveryZone[];
    hubDeliveryCost: number;
    sameZoneCost: number;
    otherZoneCost: number;
}

export const normalizeStateName = (name: string): string => {
    if (!name) return "";
    const n = name.toLowerCase().trim();
    if (n.includes("abuja") || n.includes("federal capital territory") || n === "fct") return "abuja";
    return n;
};

export const isHubState = (stateName: string, pricing: DeliveryPricing): boolean => {
    const norm = normalizeStateName(stateName);
    return pricing.hubStates.some((h) => normalizeStateName(h) === norm);
};

/** Mirrors backend/app/delivery.py delivery_cost; the order the backend creates is what is charged. */
export const getDeliveryCost = (stateName: string, mode: FulfillmentMode, pricing: DeliveryPricing): number => {
    if (isHubState(stateName, pricing)) return mode === "pickup" ? 0 : pricing.hubDeliveryCost;
    const norm = normalizeStateName(stateName);
    const zone = pricing.zones.find((z) => z.states.some((s) => normalizeStateName(s) === norm));
    const zoneHasHub = zone ? zone.states.some((s) => isHubState(s, pricing)) : false;
    return zoneHasHub ? pricing.sameZoneCost : pricing.otherZoneCost;
};

export const deliveryCostLabel = (cost: number): string => (cost === 0 ? "Free (Pickup)" : `₦${cost.toLocaleString()}`);

export const NIGERIAN_STATES: string[] = [
    "Abia",
    "Adamawa",
    "Akwa Ibom",
    "Anambra",
    "Bauchi",
    "Bayelsa",
    "Benue",
    "Borno",
    "Cross River",
    "Delta",
    "Ebonyi",
    "Edo",
    "Ekiti",
    "Enugu",
    "Gombe",
    "Imo",
    "Jigawa",
    "Kaduna",
    "Kano",
    "Katsina",
    "Kebbi",
    "Kogi",
    "Kwara",
    "Lagos",
    "Nasarawa",
    "Niger",
    "Ogun",
    "Ondo",
    "Osun",
    "Oyo",
    "Plateau",
    "Rivers",
    "Sokoto",
    "Taraba",
    "Yobe",
    "Zamfara",
    "Federal Capital Territory (Abuja)",
];

export interface Distributor {
    id: string;
    name: string;
    state: string;
    email: string;
    phone: string;
    whatsapp: string;
}

export const DISTRIBUTORS: Distributor[] = [
    {
        id: "d1",
        name: "Enchiridion Hub Lagos",
        state: "Lagos",
        email: "lagos.distro@enchiridion.med",
        phone: "+234 801 000 0001",
        whatsapp: "2348010000001"
    },
    {
        id: "d2",
        name: "Enchiridion Kano Center",
        state: "Kano",
        email: "kano.distro@enchiridion.med",
        phone: "+234 801 000 0002",
        whatsapp: "2348010000002"
    },
    {
        id: "d3",
        name: "Enchiridion Abuja Point",
        state: "Federal Capital Territory (Abuja)",
        email: "abuja.distro@enchiridion.med",
        phone: "+234 801 000 0003",
        whatsapp: "2348010000003"
    }
];

export const findClosestDistributor = (userState: string): Distributor => {
    // Exact match
    const exactMatch = DISTRIBUTORS.find(d => d.state === userState);
    if (exactMatch) return exactMatch;

    // Region mapping fallback
    const northernStates = ["Kaduna", "Katsina", "Kebbi", "Sokoto", "Zamfara", "Jigawa", "Borno", "Adamawa", "Yobe", "Bauchi", "Gombe", "Taraba"];
    const centralStates = ["FCT (Abuja)", "Federal Capital Territory (Abuja)", "Nasarawa", "Niger", "Kogi", "Kwara", "Plateau", "Benue"];

    if (northernStates.includes(userState)) return DISTRIBUTORS.find(d => d.state === "Kano") || DISTRIBUTORS[0];
    if (centralStates.includes(userState)) return DISTRIBUTORS.find(d => d.state === "Federal Capital Territory (Abuja)") || DISTRIBUTORS[0];

    // Default to Lagos for South/West/East
    return DISTRIBUTORS[0];
};

export const fetchShippingRates = async (): Promise<any[]> => {
    try {
        const response = await fetch("/api/referral/shipping-rates");
        if (response.ok) return await response.json();
    } catch (e) {
        console.error("Error fetching shipping rates:", e);
    }
    return [];
};

export const getUserStats = async () => {
    const token = await getAccessToken();
    if (!token) return null;
    try {
        const response = await fetch("/api/referral/stats", {
            headers: { "Authorization": `Bearer ${token}` }
        });
        if (response.ok) return await response.json();
    } catch (e) {
        console.error("Error fetching user stats:", e);
    }
    return null;
};
