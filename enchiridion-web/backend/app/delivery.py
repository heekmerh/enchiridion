"""Book delivery pricing: the single source of truth for what checkout charges and what the site shows.

Hub states (a live Enchiridion distributor) deliver for a flat fee or allow free pickup.
Other states pay the same-zone rate when their zone has a hub, otherwise the out-of-zone rate.
The website renders these rules from GET /referral/checkout-config, so the amount a buyer sees
is computed by the same code that creates the order.
"""

from typing import Literal

Fulfillment = Literal["delivery", "pickup"]

HUB_DELIVERY_COST = 1500
SAME_ZONE_COST = 3000
OTHER_ZONE_COST = 5000

HUB_STATES = (
    "Federal Capital Territory (Abuja)",
    "Benue",
    "Kano",
    "Lagos",
    "Oyo",
)

ZONES = (
    {"id": "central", "title": "Central Zone (Abuja/Benue Hub)",
     "states": ("Federal Capital Territory (Abuja)", "Benue", "Nasarawa", "Niger", "Kogi", "Kwara", "Plateau")},
    {"id": "northwest", "title": "North West Zone (Kano Hub)",
     "states": ("Kano", "Kaduna", "Katsina", "Kebbi", "Sokoto", "Zamfara", "Jigawa")},
    {"id": "southwest", "title": "South West Zone (Lagos/Oyo Hub)",
     "states": ("Lagos", "Oyo", "Ogun", "Osun", "Ondo", "Ekiti")},
    {"id": "southsouth-east", "title": "South South / East Zone (Hub Coming Soon)",
     "states": ("Rivers", "Abia", "Akwa Ibom", "Anambra", "Bayelsa", "Cross River", "Delta", "Ebonyi", "Edo",
                "Enugu", "Imo", "Gombe", "Taraba", "Adamawa", "Bauchi", "Borno", "Yobe")},
)


class UnknownState(ValueError):
    pass


def normalize_state(name: str) -> str:
    value = (name or "").strip().lower()
    if "abuja" in value or "federal capital territory" in value or value == "fct":
        return "abuja"
    return value


def canonical_state(name: str) -> str:
    """The state's name as the zone list spells it, or UnknownState."""
    target = normalize_state(name)
    for zone in ZONES:
        for state in zone["states"]:
            if normalize_state(state) == target:
                return state
    raise UnknownState(name)


def is_hub(name: str) -> bool:
    target = normalize_state(name)
    return any(normalize_state(hub) == target for hub in HUB_STATES)


def delivery_cost(name: str, fulfillment: Fulfillment = "delivery") -> int:
    state = canonical_state(name)
    if is_hub(state):
        return 0 if fulfillment == "pickup" else HUB_DELIVERY_COST
    if fulfillment == "pickup":
        raise ValueError("Pickup is only available in hub states")
    zone = next(z for z in ZONES if state in z["states"])
    return SAME_ZONE_COST if any(is_hub(s) for s in zone["states"]) else OTHER_ZONE_COST


def all_states() -> list[str]:
    return sorted(state for zone in ZONES for state in zone["states"])


def pricing_config() -> dict:
    return {
        "hubStates": list(HUB_STATES),
        "zones": [{"id": z["id"], "title": z["title"], "states": list(z["states"])} for z in ZONES],
        "hubDeliveryCost": HUB_DELIVERY_COST,
        "sameZoneCost": SAME_ZONE_COST,
        "otherZoneCost": OTHER_ZONE_COST,
    }
