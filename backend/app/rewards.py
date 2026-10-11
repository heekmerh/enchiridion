"""Atomic reward and payment operations; callers own the database transaction."""

import html
from decimal import Decimal, InvalidOperation

from fastapi import HTTPException
from psycopg.types.json import Jsonb

from . import mailer


async def credit(db, partner_id, referee, milestone_type, points):
    amount = Decimal(str(points))
    if not amount.is_finite() or amount <= 0:
        raise ValueError("Reward points must be positive")
    referee = str(referee).strip().lower()
    result = await (await db.execute(
        """INSERT INTO milestones(partner_id, referee, milestone_type, points)
           VALUES (%s, %s, %s, %s)
           ON CONFLICT DO NOTHING RETURNING id""",
        (partner_id, referee, milestone_type, amount),
    )).fetchone()
    if not result:
        return False
    partner = await (await db.execute(
        """UPDATE partners SET points = points + %s, payout_status = 'PENDING',
           total_referrals = total_referrals + %s WHERE id = %s RETURNING *""",
        (amount, 1 if milestone_type == "partner" else 0, partner_id),
    )).fetchone()
    await db.execute(
        """INSERT INTO activities(partner_id, ref_code, activity_type, points, details)
           VALUES (%s, %s, %s, %s, %s)""",
        (partner_id, partner["referral_code"], milestone_type, amount, Jsonb({"referee": referee})),
    )
    if milestone_type == "book_purchase":
        count = await (await db.execute(
            "SELECT count(*) AS count FROM milestones WHERE partner_id = %s AND milestone_type = 'book_purchase'",
            (partner_id,),
        )).fetchone()
        if count["count"] in (6, 16):
            rank = "Sage" if count["count"] == 6 else "Master"
            await db.execute(
                "INSERT INTO broadcasts(kind, username, city, body) VALUES (%s, %s, %s, %s)",
                (rank.lower() + "_rank", partner["name"], partner["state"],
                 f"{partner['name']} just achieved the rank of {rank}!"),
            )
    # Await optional delivery so a serverless invocation cannot discard the task.
    await mailer.send_email(partner["email"], "Your Enchiridion reward",
                            f"<p>Hello {html.escape(partner['name'])},</p>"
                            f"<p>You earned {amount} points for {html.escape(milestone_type.replace('_', ' '))}.</p>")
    return True


async def reward_referrer(db, email, step):
    points = {"partner": Decimal("0.1"), "distributor": Decimal("0.1"), "book_purchase": Decimal("5")}
    if step not in points:
        raise ValueError("Unknown reward milestone")
    buyer = await (await db.execute(
        "SELECT * FROM partners WHERE email = %s", (email.strip().lower(),),
    )).fetchone()
    if not buyer or not buyer["referred_by"] or (step == "partner" and not buyer["is_verified"]):
        return False
    referrer = await (await db.execute(
        "SELECT * FROM partners WHERE referral_code = %s AND is_active", (buyer["referred_by"],),
    )).fetchone()
    if not referrer or referrer["id"] == buyer["id"]:
        return False
    credited = await credit(db, referrer["id"], buyer["email"], step, points[step])
    if step == "partner" and referrer["referred_by"]:
        ancestor = await (await db.execute(
            "SELECT id FROM partners WHERE referral_code = %s AND is_active", (referrer["referred_by"],),
        )).fetchone()
        if ancestor and ancestor["id"] not in (buyer["id"], referrer["id"]):
            await credit(db, ancestor["id"], buyer["email"], "network_spread", Decimal("0.1"))
    return credited


async def process_payment(db, data):
    """Persist a server-verified Flutterwave payment and its rewards together."""
    reference = str(data.get("tx_ref") or data.get("reference") or "")
    transaction_id = str(data.get("id") or data.get("transaction_id") or "")
    email = str((data.get("customer") or {}).get("email") or "").strip().lower()
    try:
        amount = Decimal(str(data.get("amount", 0)))
    except (InvalidOperation, ValueError):
        raise HTTPException(400, "Invalid payment amount")
    if (not reference or not transaction_id or not email or not amount.is_finite()
            or data.get("status") != "successful" or data.get("currency") != "NGN"):
        raise HTTPException(400, "Payment is not a successful NGN transaction")
    order = await (await db.execute(
        "SELECT * FROM purchase_orders WHERE tx_ref = %s FOR UPDATE", (reference,),
    )).fetchone()
    if not order or order["email"] != email or order["currency"] != data["currency"] or amount < order["amount"]:
        raise HTTPException(400, "Payment does not match the order")
    existing = await (await db.execute(
        "SELECT * FROM payments WHERE reference = %s OR transaction_id = %s", (reference, transaction_id),
    )).fetchone()
    if existing and (existing["reference"] != reference or existing["transaction_id"] != transaction_id):
        raise HTTPException(409, "Transaction has already been used for another order")
    await db.execute(
        """INSERT INTO payments(reference, transaction_id, email, amount, currency, metadata)
           VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT (reference) DO NOTHING""",
        (reference, transaction_id, email, amount, data["currency"], Jsonb(order["metadata"])),
    )
    buyer = await (await db.execute("SELECT * FROM partners WHERE email = %s", (email,))).fetchone()
    if buyer:
        await db.execute(
            """INSERT INTO onboarding(user_id, has_purchased_book) VALUES (%s, true)
               ON CONFLICT (user_id) DO UPDATE SET has_purchased_book = true, last_updated = now()""",
            (buyer["id"],),
        )
        await credit(db, buyer["id"], email, "buyer_cashback", Decimal("1"))
        await reward_referrer(db, email, "book_purchase")
    else:
        ref_code = str(order["metadata"].get("refCode") or "").strip().lower()
        referrer = await (await db.execute(
            "SELECT id, email FROM partners WHERE referral_code = %s AND is_active", (ref_code,),
        )).fetchone()
        if referrer and referrer["email"] != email:
            await credit(db, referrer["id"], email, "book_purchase", Decimal("5"))
    return {"success": True, "reference": reference, "already_processed": existing is not None}


async def sync_verified_partner(db, user):
    if not user.is_verified:
        return
    await reward_referrer(db, user.email, "partner")
    partner = await (await db.execute(
        "SELECT guest_payments_claimed FROM partners WHERE id = %s FOR UPDATE", (user.id,),
    )).fetchone()
    if not partner or partner["guest_payments_claimed"]:
        return
    # Guest book purchases are linked only after the email is proven, so nobody can claim another buyer's rewards.
    rows = await (await db.execute(
        "SELECT reference, transaction_id, email, amount, currency, metadata FROM payments WHERE email = %s",
        (user.email,),
    )).fetchall()
    for row in rows:
        await process_payment(db, {**row, "status": "successful", "customer": {"email": row["email"]}})
    await db.execute("UPDATE partners SET guest_payments_claimed = true WHERE id = %s", (user.id,))
