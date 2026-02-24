export interface StateDelivery {
    name: string;
    cost: number;
    costLabel: string;
}

export const HUB_STATES = [
    "Federal Capital Territory (Abuja)",
    "Benue",
    "Kano",
    "Kaduna",
    "Lagos",
    "Ogun",
    "Rivers"
];

export const DELIVERY_ZONES = [
    {
        id: "central",
        title: "Central Zone (Abuja/Benue Hub)",
        states: ["Federal Capital Territory (Abuja)", "Benue", "Nasarawa", "Niger", "Kogi", "Kwara", "Plateau"]
    },
    {
        id: "northwest",
        title: "North West Zone (Kano/Kaduna Hub)",
        states: ["Kano", "Kaduna", "Katsina", "Kebbi", "Sokoto", "Zamfara", "Jigawa"]
    },
    {
        id: "southwest",
        title: "South West Zone (Lagos/Ogun Hub)",
        states: ["Lagos", "Ogun", "Oyo", "Osun", "Ondo", "Ekiti"]
    },
    {
        id: "southsouth-east",
        title: "South South / East Zone (Port Harcourt Hub)",
        states: ["Rivers", "Abia", "Akwa Ibom", "Anambra", "Bayelsa", "Cross River", "Delta", "Ebonyi", "Edo", "Enugu", "Imo", "Gombe", "Taraba", "Adamawa", "Bauchi", "Borno", "Yobe"]
    }
];

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
    const token = typeof window !== "undefined" ? localStorage.getItem("enchiridion_token") : null;
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
