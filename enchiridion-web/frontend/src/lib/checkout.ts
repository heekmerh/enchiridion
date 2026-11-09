import { getAccessToken } from "@/lib/supabase";
export interface StateDelivery {
    name: string;
    cost: number;
    costLabel: string;
}

export type FulfillmentMode = "delivery" | "pickup";

// States with a live Enchiridion Hub (distributor) right now.
export const HUB_STATES = [
    "Federal Capital Territory (Abuja)",
    "Benue",
    "Kano",
    "Lagos",
    "Oyo",
];

export const DELIVERY_ZONES = [
    {
        id: "central",
        title: "Central Zone (Abuja/Benue Hub)",
        states: ["Federal Capital Territory (Abuja)", "Benue", "Nasarawa", "Niger", "Kogi", "Kwara", "Plateau"]
    },
    {
        id: "northwest",
        title: "North West Zone (Kano Hub)",
        states: ["Kano", "Kaduna", "Katsina", "Kebbi", "Sokoto", "Zamfara", "Jigawa"]
    },
    {
        id: "southwest",
        title: "South West Zone (Lagos/Oyo Hub)",
        states: ["Lagos", "Oyo", "Ogun", "Osun", "Ondo", "Ekiti"]
    },
    {
        id: "southsouth-east",
        title: "South South / East Zone (Hub Coming Soon)",
        states: ["Rivers", "Abia", "Akwa Ibom", "Anambra", "Bayelsa", "Cross River", "Delta", "Ebonyi", "Edo", "Enugu", "Imo", "Gombe", "Taraba", "Adamawa", "Bauchi", "Borno", "Yobe"]
    }
];

const HUB_DELIVERY_COST = 1500;
const SAME_ZONE_COST = 3000;
const OTHER_ZONE_COST = 5000;

export const normalizeStateName = (name: string): string => {
    if (!name) return "";
    const n = name.toLowerCase().trim();
    if (n.includes("abuja") || n.includes("federal capital territory")) return "abuja";
    return n;
};

export const isHubState = (stateName: string): boolean => {
    const norm = normalizeStateName(stateName);
    return HUB_STATES.some((h) => normalizeStateName(h) === norm);
};

const zoneForState = (stateName: string) => {
    const norm = normalizeStateName(stateName);
    return DELIVERY_ZONES.find((zone) => zone.states.some((s) => normalizeStateName(s) === norm));
};

/**
 * Preview-only pricing formula (see /AskUserQuestion decision):
 * hub state + delivery = 1500, hub state + pickup = free,
 * non-hub state in a zone with a live hub = 3000, non-hub state in a zone with no live hub = 5000.
 * Not yet enforced by the backend, which still charges from its own `shipping_rates` table.
 */
export const getDeliveryCost = (stateName: string, mode: FulfillmentMode = "delivery"): number => {
    if (isHubState(stateName)) return mode === "pickup" ? 0 : HUB_DELIVERY_COST;
    const zone = zoneForState(stateName);
    const zoneHasHub = zone ? zone.states.some((s) => isHubState(s)) : false;
    return zoneHasHub ? SAME_ZONE_COST : OTHER_ZONE_COST;
};

export const deliveryCostLabel = (cost: number): string => (cost === 0 ? "Free (Pickup)" : `₦${cost.toLocaleString()}`);

export const NIGERIAN_STATES: StateDelivery[] = [
    { name: "Abia", cost: 4500, costLabel: "₦4,500" },
    { name: "Adamawa", cost: 5000, costLabel: "₦5,000" },
    { name: "Akwa Ibom", cost: 4500, costLabel: "₦4,500" },
    { name: "Anambra", cost: 4000, costLabel: "₦4,000" },
    { name: "Bauchi", cost: 4500, costLabel: "₦4,500" },
    { name: "Bayelsa", cost: 5000, costLabel: "₦5,000" },
    { name: "Benue", cost: 4200, costLabel: "₦4,200" },
    { name: "Borno", cost: 5500, costLabel: "₦5,500" },
    { name: "Cross River", cost: 4500, costLabel: "₦4,500" },
    { name: "Delta", cost: 4000, costLabel: "₦4,000" },
    { name: "Ebonyi", cost: 4500, costLabel: "₦4,500" },
    { name: "Edo", cost: 4000, costLabel: "₦4,000" },
    { name: "Ekiti", cost: 3500, costLabel: "₦3,500" },
    { name: "Enugu", cost: 4000, costLabel: "₦4,000" },
    { name: "Gombe", cost: 4500, costLabel: "₦4,500" },
    { name: "Imo", cost: 4200, costLabel: "₦4,200" },
    { name: "Jigawa", cost: 4500, costLabel: "₦4,500" },
    { name: "Kaduna", cost: 3500, costLabel: "₦3,500" },
    { name: "Kano", cost: 3500, costLabel: "₦3,500" },
    { name: "Katsina", cost: 4000, costLabel: "₦4,000" },
    { name: "Kebbi", cost: 4500, costLabel: "₦4,500" },
    { name: "Kogi", cost: 3500, costLabel: "₦3,500" },
    { name: "Kwara", cost: 3500, costLabel: "₦3,500" },
    { name: "Lagos", cost: 3000, costLabel: "₦3,000" },
    { name: "Nasarawa", cost: 3500, costLabel: "₦3,500" },
    { name: "Niger", cost: 3500, costLabel: "₦3,500" },
    { name: "Ogun", cost: 3000, costLabel: "₦3,000" },
    { name: "Ondo", cost: 3500, costLabel: "₦3,500" },
    { name: "Osun", cost: 3000, costLabel: "₦3,000" },
    { name: "Oyo", cost: 3000, costLabel: "₦3,000" },
    { name: "Plateau", cost: 4000, costLabel: "₦4,000" },
    { name: "Rivers", cost: 4500, costLabel: "₦4,500" },
    { name: "Sokoto", cost: 4500, costLabel: "₦4,500" },
    { name: "Taraba", cost: 5000, costLabel: "₦5,000" },
    { name: "Yobe", cost: 5000, costLabel: "₦5,000" },
    { name: "Zamfara", cost: 4500, costLabel: "₦4,500" },
    { name: "Federal Capital Territory (Abuja)", cost: 3500, costLabel: "₦3,500" },
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
