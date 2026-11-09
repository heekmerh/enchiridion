"""Server-side plan catalogue; the website never supplies its own prices."""

from decimal import Decimal

from fastapi import HTTPException

CATALOG_CURRENCY = "NGN"
PERIOD_LABELS = {"month": "month", "year": "year"}


def format_amount(amount: Decimal, currency: str) -> str:
    symbol = "₦" if currency == "NGN" else currency + " "
    whole = amount == amount.to_integral_value()
    return f"{symbol}{amount:,.0f}" if whole else f"{symbol}{amount:,.2f}"


async def active_plans(db, currency: str = CATALOG_CURRENCY) -> list[dict]:
    return await (await db.execute(
        """SELECT p.id, p.name, p.description, p.billing_interval, p.interval_count, p.benefits,
                  p.entitlement_feature, pr.id AS price_id, pr.amount, pr.currency, pr.tax_inclusive
           FROM billing.plans p
           CROSS JOIN LATERAL billing.current_plan_price(p.id, %s) pr
           WHERE p.is_active AND pr.id IS NOT NULL
           ORDER BY p.display_order""",
        (currency,),
    )).fetchall()


async def plan_or_404(db, plan_id: str) -> dict:
    for plan in await active_plans(db):
        if plan["id"] == plan_id:
            return plan
    raise HTTPException(404, "This plan is not available")


def annual_savings(plans: list[dict]) -> Decimal | None:
    monthly = next((p for p in plans if p["billing_interval"] == "month" and p["interval_count"] == 1), None)
    annual = next((p for p in plans if p["billing_interval"] == "year" and p["interval_count"] == 1), None)
    if not monthly or not annual or monthly["currency"] != annual["currency"]:
        return None
    savings = monthly["amount"] * 12 - annual["amount"]
    return savings if savings > 0 else None


def serialize_plans(plans: list[dict]) -> list[dict]:
    savings = annual_savings(plans)
    result = []
    for plan in plans:
        description = plan["description"]
        plan_savings = None
        if plan["billing_interval"] == "year" and savings is not None:
            plan_savings = {"amount": float(savings), "display": format_amount(savings, plan["currency"])}
            description = f"Save {plan_savings['display']} compared with twelve monthly payments."
        result.append({
            "id": plan["id"],
            "name": plan["name"],
            "description": description,
            "interval": plan["billing_interval"],
            "interval_count": plan["interval_count"],
            "price": {
                "amount": float(plan["amount"]),
                "currency": plan["currency"],
                "display": format_amount(plan["amount"], plan["currency"]),
                "period": PERIOD_LABELS[plan["billing_interval"]],
                "tax_inclusive": plan["tax_inclusive"],
            },
            "savings": plan_savings,
            "benefits": plan["benefits"],
        })
    return result
