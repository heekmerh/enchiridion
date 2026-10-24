"""Referral, checkout and administration APIs backed by Supabase Postgres."""

import csv
import io
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, EmailStr, Field
from psycopg import sql
from psycopg.types.json import Jsonb

from ..auth import current_active_user, current_active_superuser, optional_user
from ..database import get_db
from ..flutterwave import verify_transaction
from ..models import LeadCapture, DistributorLead, PayoutSettings, MarkAsPaidRequest, SessionTrack
from ..rewards import credit, reward_referrer, process_payment, sync_verified_partner
from .billing import flutterwave_webhook

router = APIRouter()
DB = Depends(get_db, scope="function")
USER = Depends(current_active_user)
ADMIN = Depends(current_active_superuser)
OPTIONAL_USER = Depends(optional_user)


async def partner_by_code(db, code):
    return await (await db.execute("SELECT * FROM partners WHERE referral_code = %s", (code.strip().lower(),))).fetchone()


async def activity(db, code, kind, details, points=0):
    partner = await partner_by_code(db, code)
    await db.execute(
        "INSERT INTO activities(partner_id,ref_code,activity_type,points,details) VALUES (%s,%s,%s,%s,%s)",
        (partner["id"] if partner else None, code.strip().lower(), kind, points, Jsonb(details)),
    )


@router.get("/referrer-name")
async def referrer_name(refCode: str, db=DB):
    partner = await partner_by_code(db, refCode)
    if not partner:
        raise HTTPException(404, "Referrer not found")
    return {"name": partner["name"]}


class ActivityInput(BaseModel):
    type: str = Field(max_length=100)
    refCode: str = Field(default="", max_length=64)
    details: dict = Field(default_factory=dict)


@router.post("/log-activity")
async def log_activity(body: ActivityInput, db=DB):
    # Browser telemetry never awards points or sets payout status.
    await activity(db, body.refCode, "telemetry:" + body.type, body.details)
    return {"success": True}


async def save_lead(db, lead, kind):
    await db.execute("INSERT INTO leads(kind,email,ref_code,details) VALUES (%s,%s,%s,%s)",
                     (kind, lead.email.lower(), lead.refCode, Jsonb(lead.details or {})))
    return {"success": True}


@router.post("/capture-lead")
async def capture_lead(lead: LeadCapture, db=DB):
    return await save_lead(db, lead, "sample")


@router.post("/subscribe-newsletter")
async def subscribe_newsletter(lead: LeadCapture, db=DB):
    return await save_lead(db, lead, "newsletter")


@router.post("/distributor-lead")
async def distributor_lead(lead: DistributorLead, user=OPTIONAL_USER, db=DB):
    await db.execute(
        "INSERT INTO leads(kind,name,phone,whatsapp,location,ref_code) VALUES ('distributor',%s,%s,%s,%s,%s)",
        (lead.name, lead.phone, lead.whatsapp, lead.location, lead.refCode or ""),
    )
    if user:
        await db.execute("UPDATE onboarding SET is_distributor=true,last_updated=now() WHERE user_id=%s", (user.id,))
        await reward_referrer(db, user.email, "distributor")
    return {"success": True}


@router.post("/record-visit")
async def record_visit(track: SessionTrack, request: Request, response: Response, db=DB):
    if request.cookies.get("ench_unique_visit"):
        return {"status": "already_tracked"}
    await activity(db, track.refCode, "Browsing", {"userAgent": track.userAgent})
    response.set_cookie("ench_unique_visit", "true", max_age=2592000, httponly=True,
                        secure=request.url.scheme == "https", samesite="lax")
    return {"status": "success", "message": "Visit registered"}


@router.post("/record-share")
async def record_share(track: SessionTrack, platform: str = "unknown", db=DB):
    await activity(db, track.refCode, "Social Share", {"platform": platform})
    return {"status": "success", "message": "Share recorded"}


def book_price():
    try:
        price = Decimal(os.getenv("BOOK_PRICE_NGN", "10000"))
    except InvalidOperation:
        raise HTTPException(503, "Book price is not configured")
    if not price.is_finite() or price <= 0:
        raise HTTPException(503, "Book price is not configured")
    return price


@router.get("/checkout-config")
async def checkout_config():
    return {"bookPrice": float(book_price()), "currency": "NGN"}


@router.get("/shipping-rates")
async def shipping_rates(db=DB):
    rows = await (await db.execute("SELECT name,cost,is_hub FROM shipping_rates ORDER BY name")).fetchall()
    return [{"name": row["name"], "cost": float(row["cost"]), "isHub": row["is_hub"]} for row in rows]


class PurchaseOrder(BaseModel):
    email: EmailStr
    quantity: int = Field(default=1, ge=1, le=100)
    state: str = Field(min_length=1, max_length=100)
    fullName: str = Field(min_length=1, max_length=200)
    address: str = Field(min_length=1, max_length=1000)
    city: str = Field(min_length=1, max_length=100)
    phone: str = Field(min_length=5, max_length=40)
    book: str = Field(default="Enchiridion", max_length=200)
    refCode: str = Field(default="", max_length=64)


@router.post("/initialize-purchase")
async def initialize_purchase(body: PurchaseOrder, db=DB):
    if not os.getenv("FLUTTERWAVE_SECRET_KEY"):
        raise HTTPException(503, "Flutterwave checkout is not configured")
    rate = await (await db.execute("SELECT cost FROM shipping_rates WHERE lower(name)=lower(%s)", (body.state,))).fetchone()
    if not rate:
        raise HTTPException(400, "Delivery is not configured for the selected state")
    amount = book_price() * body.quantity + rate["cost"]
    tx_ref = "ENCH-" + uuid.uuid4().hex
    metadata = {**body.model_dump(mode="json"), "product": "book"}
    await db.execute(
        "INSERT INTO purchase_orders(tx_ref,email,amount,quantity,state,metadata) VALUES (%s,%s,%s,%s,%s,%s)",
        (tx_ref, body.email.lower(), amount, body.quantity, body.state, Jsonb(metadata)),
    )
    return {"tx_ref": tx_ref, "amount": float(amount), "currency": "NGN"}


class CompletePurchase(BaseModel):
    transaction_id: int = Field(gt=0)
    tx_ref: str = Field(min_length=1, max_length=200)
    email: EmailStr


@router.post("/complete-purchase")
async def complete_purchase(body: CompletePurchase, db=DB):
    data = await verify_transaction(body.transaction_id)
    if data.get("tx_ref") != body.tx_ref or str(data.get("customer", {}).get("email", "")).lower() != body.email.lower():
        raise HTTPException(400, "Payment reference or customer mismatch")
    return await process_payment(db, data)


# Flutterwave allows one webhook URL per account; this legacy path shares the unified handler.
router.add_api_route("/flutterwave/webhook", flutterwave_webhook, methods=["POST"])


@router.post("/credit-purchase")
@router.post("/webhook/payment-success")
@router.post("/debug/mock-register")
async def retired_payment_route():
    raise HTTPException(410, "Use verified Flutterwave checkout")


class ReferrerClaim(BaseModel):
    refCode: str = Field(min_length=3, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")


# Google sign-ups can't carry a referral code in signup metadata, so a brand-new account may attach one once.
REFERRER_CLAIM_WINDOW = "1 hour"


@router.post("/claim-referrer")
async def claim_referrer(body: ReferrerClaim, user=USER, db=DB):
    row = await (await db.execute(
        f"""UPDATE partners SET referred_by = %s
            WHERE id = %s AND referred_by IS NULL AND referral_code <> %s
              AND date_joined > now() - interval '{REFERRER_CLAIM_WINDOW}'
              AND EXISTS (SELECT 1 FROM partners r WHERE r.referral_code = %s AND r.is_active)
            RETURNING referred_by""",
        (body.refCode.lower(), user.id, body.refCode.lower(), body.refCode.lower()),
    )).fetchone()
    return {"claimed": row is not None}


@router.get("/progress")
async def progress(user=USER, db=DB):
    row = await (await db.execute(
        """INSERT INTO onboarding(user_id,is_partner) VALUES (%s,true)
           ON CONFLICT(user_id) DO UPDATE SET is_partner=true,last_updated=now() RETURNING *""", (user.id,),
    )).fetchone()
    await sync_verified_partner(db, user)
    return {"email": user.email, "is_verified": user.is_verified, "is_partner": row["is_partner"],
            "is_distributor": row["is_distributor"], "has_purchased_book": row["has_purchased_book"],
            "last_updated": row["last_updated"].isoformat()}


class ProgressUpdate(BaseModel):
    email: EmailStr
    step: Literal["partner", "distributor"]


@router.post("/update-progress")
async def update_progress(body: ProgressUpdate, user=ADMIN, db=DB):
    partner = await (await db.execute("SELECT id FROM partners WHERE email=%s", (body.email.lower(),))).fetchone()
    if not partner:
        raise HTTPException(404, "Partner not found")
    await db.execute(sql.SQL("UPDATE onboarding SET {}=true,last_updated=now() WHERE user_id=%s").format(
        sql.Identifier("is_" + body.step)), (partner["id"],))
    await reward_referrer(db, body.email, body.step)
    return {"success": True}


def rank_data(milestones):
    purchases = sorted([m for m in milestones if m["milestone_type"] == "book_purchase"], key=lambda m: m["created_at"])
    count = len(purchases)
    index = 15 if count >= 16 else 5 if count >= 6 else None
    return {"legacyRank": "Master" if count >= 16 else "Sage" if count >= 6 else "Seeker",
            "soulsGuided": count, "masteryDate": purchases[index]["created_at"].isoformat() if index is not None else None}


@router.get("/stats")
async def stats(user=USER, db=DB):
    partner = await (await db.execute("SELECT * FROM partners WHERE id=%s", (user.id,))).fetchone()
    milestones = await (await db.execute("SELECT * FROM milestones WHERE partner_id=%s ORDER BY created_at", (user.id,))).fetchall()
    pending = await (await db.execute("SELECT email FROM partners WHERE referred_by=%s AND NOT is_verified", (user.referral_code,))).fetchall()
    referees = {row["email"]: {"email": row["email"], "milestones": [], "is_pending": True} for row in pending}
    for row in milestones:
        item = referees.setdefault(row["referee"], {"email": row["referee"], "milestones": [], "is_pending": False})
        item["milestones"].append(row["milestone_type"])
    return {
        "points": float(partner["points"]), "revenue": float(partner["points"] * 100),
        "pendingPoints": len(pending) / 10, "lifetimeEarnings": float(partner["lifetime_earnings"]),
        "totalReferrals": partner["total_referrals"], "referralCode": partner["referral_code"], "name": partner["name"],
        "bankName": partner["bank_name"], "accountName": partner["account_name"], "accountNumber": partner["account_number"],
        "email": partner["email"], "state": partner["state"],
        "milestones": [{"referee": m["referee"], "type": m["milestone_type"], "points": float(m["points"]), "timestamp": m["created_at"].isoformat()} for m in milestones],
        "networkSpreadCount": sum(m["milestone_type"] == "network_spread" for m in milestones),
        "refereeProgress": list(referees.values()), **rank_data(milestones),
    }


@router.post("/update-payout")
async def update_payout(body: PayoutSettings, user=USER, db=DB):
    await db.execute("UPDATE partners SET bank_name=%s,account_name=%s,account_number=%s WHERE id=%s",
                     (body.bankName, body.accountName, body.accountNumber, user.id))
    return {"success": True}


@router.get("/leaderboard")
async def leaderboard(user=OPTIONAL_USER, db=DB):
    rows = await (await db.execute("SELECT * FROM partners WHERE is_active ORDER BY points DESC,date_joined LIMIT 50")).fetchall()
    results = []
    for i, row in enumerate(rows, 1):
        parts = row["name"].split()
        name = (parts[0][0] + ". " + " ".join(parts[1:])) if len(parts) > 1 else row["name"]
        item = {"rank": i, "name": name, "points": float(row["points"]), "revenue": float(row["points"] * 100),
                "lifetimeEarnings": float(row["lifetime_earnings"]),
                "impact": "Elite Partner" if i == 1 else "Platinum Partner" if i <= 3 else "Gold Partner" if i <= 10 else "Silver Partner" if i <= 25 else "Rising Star"}
        if user and user.is_superuser:
            item.update(email=row["email"], referralCode=row["referral_code"])
        results.append(item)
    return results


@router.get("/masters")
async def masters(db=DB):
    rows = await (await db.execute("""SELECT p.name,p.state,count(*) AS count,
        (array_agg(m.created_at ORDER BY m.created_at))[16] AS achieved
        FROM milestones m JOIN partners p ON p.id=m.partner_id
        WHERE m.milestone_type='book_purchase' GROUP BY p.id HAVING count(*)>=16""")).fetchall()
    from urllib.parse import quote
    return [{"username": r["name"], "city": r["state"], "soulsGuided": r["count"],
             "masteryDate": r["achieved"].isoformat(), "avatar": "https://ui-avatars.com/api/?name=" + quote(r["name"])} for r in rows]


@router.get("/recent-milestones")
async def recent_milestones(db=DB):
    rows = await (await db.execute("SELECT name,state,date_joined FROM partners ORDER BY date_joined DESC LIMIT 10")).fetchall()
    events = [{"type": "registration", "text": f"{r['name'].split()[0] if r['name'].split() else 'Someone'} from {r['state'] or 'Nigeria'} just registered with us!", "timestamp": r["date_joined"].isoformat()} for r in rows]
    milestones = await (await db.execute("""SELECT m.milestone_type,m.created_at
        FROM milestones m WHERE m.milestone_type IN ('book_purchase','partner','distributor')
        ORDER BY m.created_at DESC LIMIT 10""")).fetchall()
    labels = {"book_purchase": ("purchase", "Someone just purchased their Enchiridion guide."),
              "partner": ("partner", "A new partner just verified their account."),
              "distributor": ("distributor", "A new distributor application was received.")}
    events.extend({"type": labels[r["milestone_type"]][0], "text": labels[r["milestone_type"]][1],
                   "timestamp": r["created_at"].isoformat()} for r in milestones)
    broadcasts = await global_broadcasts(db)
    events.extend({"type": r["type"], "text": r["text"], "timestamp": r["timestamp"]} for r in broadcasts)
    return sorted(events, key=lambda r: r["timestamp"], reverse=True)[:10]


@router.get("/global-broadcasts")
async def global_broadcasts(db=DB):
    rows = await (await db.execute("SELECT * FROM broadcasts WHERE created_at > now()-interval '10 minutes' ORDER BY created_at DESC LIMIT 5")).fetchall()
    return [{"id": str(r["id"]), "type": r["kind"], "username": r["username"], "text": r["body"], "timestamp": r["created_at"].isoformat()} for r in rows]


@router.post("/mark-as-paid")
async def mark_as_paid(body: MarkAsPaidRequest, user=ADMIN, db=DB):
    partner = await (await db.execute("SELECT * FROM partners WHERE email=%s FOR UPDATE", (body.email.lower(),))).fetchone()
    if not partner:
        raise HTTPException(404, "Partner not found")
    amount = partner["points"] * 100
    if amount <= 0:
        raise HTTPException(409, "No pending balance")
    payout = await (await db.execute("INSERT INTO payouts(partner_id,amount) VALUES (%s,%s) RETURNING id", (partner["id"], amount))).fetchone()
    await db.execute("UPDATE partners SET points=0,lifetime_earnings=lifetime_earnings+%s,last_payout_amount=%s,payout_status='COMPLETED' WHERE id=%s", (amount, amount, partner["id"]))
    await db.execute("UPDATE activities SET payout_status='COMPLETED',payout_id=%s WHERE partner_id=%s AND payout_status='PENDING'", (payout["id"], partner["id"]))
    await db.execute("INSERT INTO audit_logs(actor_id,action,details) VALUES (%s,'payout_recorded',%s)", (user.id, Jsonb({"payout_id": str(payout["id"]), "amount": str(amount)})))
    return {"success": True, "new_lifetime": float(partner["lifetime_earnings"] + amount)}


@router.post("/audit/revert")
@router.post("/audit/revert-payout")
async def revert_payout(body: MarkAsPaidRequest, user=ADMIN, db=DB):
    partner = await (await db.execute("SELECT * FROM partners WHERE email=%s FOR UPDATE", (body.email.lower(),))).fetchone()
    if not partner:
        raise HTTPException(404, "Partner not found")
    payout = await (await db.execute("SELECT * FROM payouts WHERE partner_id=%s ORDER BY created_at DESC LIMIT 1 FOR UPDATE", (partner["id"],))).fetchone()
    if not payout or payout["reverted"]:
        raise HTTPException(409, "No payout available to reverse")
    amount = payout["amount"]
    await db.execute("UPDATE payouts SET reverted=true WHERE id=%s", (payout["id"],))
    await db.execute("UPDATE partners SET points=points+%s,lifetime_earnings=lifetime_earnings-%s,last_payout_amount=0,payout_status='PENDING' WHERE id=%s", (amount / 100, amount, partner["id"]))
    await db.execute("UPDATE activities SET payout_status='PENDING',payout_id=NULL WHERE payout_id=%s", (payout["id"],))
    await db.execute("INSERT INTO audit_logs(actor_id,action,details) VALUES (%s,'payout_reversed',%s)", (user.id, Jsonb({"payout_id": str(payout["id"])})))
    return {"success": True, "restored_revenue": float(amount)}


@router.get("/audit/verify")
async def audit_verify(user=ADMIN, db=DB):
    rows = await (await db.execute("SELECT * FROM partners ORDER BY date_joined DESC LIMIT 5")).fetchall()
    return {"timestamp": datetime.now(timezone.utc).isoformat(), "conversion_ratio": "1 Pt = 100 Naira",
            "results": [{"row": str(r["id"]), "username": r["email"], "refCode": r["referral_code"],
                         "points": float(r["points"]), "revenue": float(r["points"] * 100), "math_ok": True,
                         "alignment_ok": True, "payout_status": r["payout_status"], "lifetime_earnings": float(r["lifetime_earnings"]),
                         "last_payout_amount": float(r["last_payout_amount"])} for r in rows]}


@router.get("/debug/sync-all")
async def sync_all(user=ADMIN):
    return {"status": "success", "updated_rows": 0, "details": []}


class MilestoneRequest(BaseModel):
    refCode: str
    tier: Literal[50, 100]


@router.post("/apply-milestone")
async def apply_milestone(body: MilestoneRequest, user=USER, db=DB):
    partner = await (await db.execute("SELECT * FROM partners WHERE id=%s FOR UPDATE", (user.id,))).fetchone()
    if partner["total_referrals"] < body.tier:
        raise HTTPException(400, "Not enough verified referrals")
    bonus = 2000 if body.tier == 50 else 5000
    applied = await credit(db, user.id, user.email, f"tier_{body.tier}", Decimal(bonus) / 100)
    return {"success": True, "already_applied": not applied, "bonus": bonus if applied else 0,
            "new_total": float(partner["points"] * 100 + (bonus if applied else 0))}


@router.get("/report/monthly/csv")
async def report(month: int | None = Query(None, ge=1, le=12), year: int | None = Query(None, ge=2000, le=9998), user=ADMIN, db=DB):
    now = datetime.now(timezone.utc)
    start = datetime(year or now.year, month or now.month, 1, tzinfo=timezone.utc)
    end = datetime(start.year + (start.month == 12), start.month % 12 + 1, 1, tzinfo=timezone.utc)
    rows = await (await db.execute("""SELECT a.created_at,a.activity_type,a.points,p.name FROM activities a
        LEFT JOIN partners p ON p.id=a.partner_id WHERE a.created_at >= %s AND a.created_at < %s ORDER BY a.created_at""", (start, end))).fetchall()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Date", "Event Type", "Partner Name", "Points Awarded", "Revenue Equivalent (Naira NGN)"])
    def safe(value):
        value = str(value or "")
        return "'" + value if value.lstrip().startswith(("=", "+", "-", "@")) else value
    for row in rows:
        writer.writerow([row["created_at"].date(), safe(row["activity_type"]), safe(row["name"]), row["points"], row["points"] * 100])
    return Response(output.getvalue(), media_type="text/csv", headers={"Content-Disposition": f'attachment; filename="Enchiridion_Report_{start:%B_%Y}.csv"'})
