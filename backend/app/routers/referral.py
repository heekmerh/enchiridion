from fastapi import APIRouter, Depends, HTTPException, Request, Response, BackgroundTasks
from typing import Optional, List
from pydantic import BaseModel
from ..models import ActivityLog, PayoutSettings, SessionTrack, MarkAsPaidRequest, UserRead, LeadCapture, DistributorLead, ShareTrack, UserProgress
from ..sheets import sheets_client, safe_float
from ..auth import current_active_user, current_active_superuser, UserRead, conf, FastMail, MessageSchema, MessageType
from datetime import datetime, timedelta
import csv
import io
from dateutil import parser as date_parser
import hmac
import hashlib
import json
import os

router = APIRouter()

@router.get("/referrer-name")
async def get_referrer_name(refCode: str):
    """Returns the name of the referrer for a given code."""
    records = sheets_client.get_all_records("Partners")
    target_code = refCode.strip().lower()
    for record in records:
        if str(record.get("REFERRAL CODE", "")).strip().lower() == target_code:
            return {"name": record.get("NAME", record.get("FULL NAME", "a friend"))}
    raise HTTPException(status_code=404, detail="Referrer not found")

def _log_activity_background(row: list):
    """Saves activity log in the background."""
    try:
        sheets_client.append_row("ActivityLog", row)
    except Exception as e:
        print(f"ERROR: Background ActivityLog append failed: {e}")

def _log_global_broadcast(type: str, username: str, city: str = "Nigeria"):
    """
    Logs a community-wide broadcast event to the 'GlobalNotifications' sheet.
    """
    try:
        # Format: Timestamp, BroadcastType, Username, City, Text
        text = ""
        if type == "sage_rank":
            text = f"Community Alert: {username} has just achieved the rank of Enchiridion Sage! 🥈"
        elif type == "master_rank":
            text = f"A New Master has joined the Pantheon! 🏆 {username} just achieved Enchiridion Mastery."
        
        row = [datetime.now().isoformat(), type, username, city, text]
        sheets_client.append_row("GlobalNotifications", row)
        print(f"DEBUG: Global broadcast logged: {text}")
    except Exception as e:
        print(f"ERROR: Failed to log global broadcast: {e}")

@router.post("/log-activity")
async def log_activity(activity: ActivityLog, background_tasks: BackgroundTasks):
    """Logs activity in the background."""
    row = [
        activity.timestamp,
        activity.refCode,
        activity.type,
        activity.points,
        activity.details.get("url", ""),
        "", # F: REPORTED Status (For Apps Script)
        activity.payoutStatus # G: Payout Status
    ]
    background_tasks.add_task(_log_activity_background, row)
    return {"success": True}

def _save_lead_to_sheet(lead_data: list, sheet_name: str):
    """Internal helper to save lead data in the background (runs in threadpool)."""
    try:
        # Check if worksheet needs headers (if empty)
        ws = sheets_client.get_worksheet(sheet_name)
        if ws:
            try:
                # Optimized check: if row 1 is empty, add headers
                first_row = ws.row_values(1)
                if not first_row or not any(cell.strip() for cell in first_row):
                    headers = ["Timestamp", "Email", "RefCode", "Context"]
                    print(f"DEBUG: Initializing headers for '{sheet_name}'...")
                    ws.append_row(headers, table_range="A1")
            except Exception as header_err:
                print(f"WARNING: Could not check/init headers for {sheet_name}: {header_err}")

        sheets_client.append_row(sheet_name, lead_data)
        print(f"DEBUG: Background lead save successful for {lead_data[1]}")
    except Exception as e:
        print(f"ERROR: Background lead save failed: {e}")

@router.post("/capture-lead")
async def capture_lead(lead: LeadCapture, background_tasks: BackgroundTasks):
    """Captures a lead email before sample preview and logs it to a dedicated sheet in the background."""
    sheet_name = "sample chapter"
    
    timestamp = lead.timestamp or datetime.now().isoformat()
    details = lead.details or {}
    url = details.get("url", "About Page Gate")
    
    # row format: Timestamp, Email, RefCode, Context
    row = [timestamp, lead.email, lead.refCode, url]
    
    # Dispatch to background (FastAPI runs 'def' functions in a threadpool)
    background_tasks.add_task(_save_lead_to_sheet, row, sheet_name)
    
    return {"success": True}

@router.post("/subscribe-newsletter")
async def subscribe_newsletter(lead: LeadCapture, background_tasks: BackgroundTasks):
    """Captures a newsletter subscription email and logs it to a dedicated sheet."""
    sheet_name = "Newsletter"
    
    timestamp = lead.timestamp or datetime.now().isoformat()
    details = lead.details or {}
    url = details.get("url", "Newsletter Popup")
    
    # row format: Timestamp, Email, RefCode, Context
    row = [timestamp, lead.email, lead.refCode or "direct", url]
    
    background_tasks.add_task(_save_lead_to_sheet, row, sheet_name)
    
    return {"success": True}


def _save_distributor_lead_background(row: list):
    """Saves distributor lead data in the background."""
    sheet_name = "Distributor Leads"
    try:
        ws = sheets_client.get_worksheet(sheet_name)
        if ws:
            try:
                first_row = ws.row_values(1)
                if not first_row or not any(cell.strip() for cell in first_row):
                    headers = ["Timestamp", "Name", "Phone", "WhatsApp", "Location"]
                    ws.append_row(headers, table_range="A1")
            except Exception as header_err:
                print(f"WARNING: Could not init headers for {sheet_name}: {header_err}")
        
        sheets_client.append_row(sheet_name, row)
        print(f"DEBUG: Distributor lead save successful for {row[1]}")
    except Exception as e:
        print(f"ERROR: Distributor lead save failed: {e}")
    
    # 2. Send email notification to Admin
    try:
        from ..auth import conf # Re-import safely if needed, though already at top
        import os
        admin_email = os.getenv("MAIL_FROM", "enchiridion.med@gmail.com")
        
        html = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
            <h2 style="color: #ff6b00; margin-bottom: 24px;">New Distributor Interest</h2>
            <p style="color: #475569; line-height: 1.6;">A new distributor application has been received:</p>
            <div style="background-color: #f8fafc; padding: 16px; border-radius: 6px; margin: 20px 0;">
                <p style="margin: 8px 0;"><strong>Name:</strong> {row[1]}</p>
                <p style="margin: 8px 0;"><strong>Phone:</strong> {row[2]}</p>
                <p style="margin: 8px 0;"><strong>WhatsApp:</strong> {row[3]}</p>
                <p style="margin: 8px 0;"><strong>Location:</strong> {row[4]}</p>
                <p style="margin: 8px 0;"><strong>Timestamp:</strong> {row[0]}</p>
            </div>
            <p style="color: #475569; line-height: 1.6; font-size: 14px;">This data has also been saved to the "Distributor Leads" worksheet.</p>
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 24px 0;">
            <p style="color: #94a3b8; font-size: 12px;">Enchiridion Admin System</p>
        </div>
        """
        
        message = MessageSchema(
            subject=f"New Distributor Lead: {row[1]}",
            recipients=[admin_email],
            body=html,
            subtype=MessageType.html
        )
        
        # We need to run this async in the background task context
        # Since _save_distributor_lead_background is NOT async, we need a helper or use asyncio
        import asyncio
        fm = FastMail(conf)
        
        # Use a new loop or the current one if it exists
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                # If we're already in a loop, we can just schedule it
                asyncio.ensure_future(fm.send_message(message))
            else:
                loop.run_until_complete(fm.send_message(message))
        except Exception as loop_err:
            # Fallback for thread context
            asyncio.run(fm.send_message(message))
            
        print(f"DEBUG: Distributor email notification sent for {row[1]}")
    except Exception as email_err:
        print(f"ERROR: Failed to send distributor notification email: {email_err}")

@router.post("/distributor-lead")
async def distributor_lead(lead: DistributorLead, background_tasks: BackgroundTasks):
    """Captures a distributor lead and logs it to Google Sheets in the background."""
    timestamp = lead.timestamp or datetime.now().isoformat()
    row = [timestamp, lead.name, lead.phone, lead.whatsapp, lead.location]
    background_tasks.add_task(_save_distributor_lead_background, row)
    
    # NEW: Trigger Milestone Credit for Distributor Lead if referred
    if lead.refCode:
        # Use a background task to handle milestone logic (Partner onboarding helper equivalent)
        # We use a dummy email or phone to identify the referee since they might not have an account yet
        # But for milestone idempotency, we need a unique ID. Using phone number.
        referee_id = lead.phone.strip()
        background_tasks.add_task(_credit_distributor_milestone_background, lead.refCode, lead.name, referee_id)
        
    return {"success": True}

def _credit_distributor_milestone_background(ref_code: str, referee_name: str, referee_id: str):
    """Credits the referrer for a distributor lead milestone."""
    try:
        # Re-using the logic from purchase milestone but for 'distributor'
        target_code = ref_code.strip().lower()
        records = sheets_client.get_all_records("Partners")
        referrer_email = None
        for r in records:
            if str(r.get("REFERRAL CODE", "")).strip().lower() == target_code:
                referrer_email = str(r.get("USERNAME", "")).lower().strip()
                break
        
        if referrer_email:
            unique_key = f"{referee_id}_distributor"
            # Idempotency
            m_records = sheets_client.get_all_records("ReferralMilestones")
            if any(str(r.get("UniqueKey", "")).lower().strip() == unique_key.lower().strip() for r in m_records):
                return
            
            # Find Referrer Indices
            for i, record in enumerate(records):
                if str(record.get("USERNAME", "")).lower().strip() == referrer_email:
                    row_idx = i + 2
                    pts = safe_float(sheets_client.get_case_insensitive_val(record, "POINTS", "points")) + 0.1
                    sheets_client.update_range("Partners", f"E{row_idx}:F{row_idx}", [[pts, pts*100]])
                    # Milestone log
                    sheets_client.append_row("ReferralMilestones", [datetime.now().isoformat(), referrer_email, referee_id, "distributor", 0.1, unique_key])
                    # Activity log
                    sheets_client.append_row("ActivityLog", [datetime.now().isoformat(), ref_code, "Distributor Setup", 0.1, f"Referee: {referee_name}", "", "PENDING"])
                    break
    except Exception as e:
        print(f"ERROR: Distributor milestone failed: {e}")


def _credit_visit_background(ref_code: str, ip: str):
    """Handles the entire visit processing (lookup + credit) in the background."""
    try:
        target_code = ref_code.strip().lower()
        records = sheets_client.get_all_records("Partners")
        
        referrer_row_idx = None
        referrer_record = None
        for i, record in enumerate(records):
            ref_val = sheets_client.get_case_insensitive_val(record, "REFERRAL CODE", "ReferralCode", "referral_code", "REFERRAL_CODE")
            if str(ref_val or "").strip().lower() == target_code:
                referrer_record = record
                referrer_row_idx = i + 2 # 1-indexed + header
                break
        
        if not referrer_record:
            sheets_client.log_audit("Point Credit", f"Referrer code {ref_code} NOT FOUND. Visit credit skipped.", "WARNING")
            print(f"DEBUG: Referrer code {ref_code} not found. Skipping credit.")
            return

        # Fraud Prevention: Self-referral check (IP)
        referrer_ip = referrer_record.get("LAST_IP", "")
        if referrer_ip == ip:
            sheets_client.log_audit("Point Credit", f"Self-referral blocked for {ref_code} (IP: {ip})", "BLOCKED")
            print(f"DEBUG: Self-referral blocked in background for {ref_code} (IP: {ip})")
            return

        p_val = sheets_client.get_case_insensitive_val(referrer_record, "POINTS", "points", "Pts")
        current_points = safe_float(p_val)
        new_points = round(current_points + 0.0, 2)
        new_revenue = round(new_points * 100, 2)
        
        # Atomic update
        sheets_client.update_range("Partners", f"E{referrer_row_idx}:F{referrer_row_idx}", [[new_points, new_revenue]])
        sheets_client.update_cell("Partners", referrer_row_idx, 9, "PENDING")
        
        # Log Activity
        activity_row = [
            datetime.now().isoformat(),
            ref_code,
            "Browsing",
            0.0,
            f"Referral visit from IP: {ip}",
            "", # F: REPORTED Status
            "PENDING" # G: Payout Status
        ]
        sheets_client.append_row("ActivityLog", activity_row)
        sheets_client.log_audit("Visit Record", f"Visit recorded for {ref_code} (IP: {ip}).")
        print(f"DEBUG: Background visit recording successful for {ref_code}")
    except Exception as e:
        sheets_client.log_audit("Point Credit", f"Failed visit credit for {ref_code}: {e}", "FAILED")
        print(f"ERROR: Background full credit failed for {ref_code}: {e}")

@router.post("/record-share")
async def record_share(track: SessionTrack, background_tasks: BackgroundTasks, platform: str = "unknown"):
    """Awards points for a share action."""
    background_tasks.add_task(_credit_share_background, track.refCode, track.ip, platform)
    return {"status": "success", "message": "Share recorded"}

def _credit_share_background(ref_code: str, ip: str, platform: str):
    """Awards points for sharing the referral link."""
    try:
        target_code = ref_code.strip().lower()
        records = sheets_client.get_all_records("Partners")
        
        referrer_row_idx = None
        referrer_record = None
        for i, record in enumerate(records):
            ref_val = sheets_client.get_case_insensitive_val(record, "REFERRAL CODE", "ReferralCode", "referral_code")
            if str(ref_val or "").strip().lower() == target_code:
                referrer_record = record
                referrer_row_idx = i + 2
                break
        
        if not referrer_record:
            sheets_client.log_audit("Share Credit", f"Referrer code '{ref_code}' NOT FOUND. Share reward skipped.", "WARNING")
            print(f"DEBUG: Referrer code '{ref_code}' NOT FOUND in sheet. Sharing reward skipped.")
            return

        p_val = sheets_client.get_case_insensitive_val(referrer_record, "POINTS", "points", "Pts")
        current_points = safe_float(p_val)
        new_points = round(current_points + 0.0, 2)
        new_revenue = round(new_points * 100, 2)
        
        # Atomic update of Columns E (Points) and F (Revenue)
        sheets_client.update_range("Partners", f"E{referrer_row_idx}:F{referrer_row_idx}", [[new_points, new_revenue]])
        
        # Log Activity
        activity_row = [
            datetime.now().isoformat(),
            ref_code,
            "Social Share",
            0.0,
            f"Shared via {platform} (IP: {ip})",
            "", 
            "PENDING"
        ]
        sheets_client.append_row("ActivityLog", activity_row)
        sheets_client.log_audit("Share Record", f"Recorded share for {ref_code} via {platform}")
        print(f"DEBUG: Share recorded successfully for {ref_code} via {platform}")
    except Exception as e:
        sheets_client.log_audit("Share Credit", f"Failed share credit for {ref_code}: {e}", "FAILED")
        print(f"ERROR: Background share credit failed for {ref_code}: {e}")

@router.post("/record-visit")
async def record_visit(track: SessionTrack, request: Request, response: Response, background_tasks: BackgroundTasks):
    """Records a unique visit and offloads ALL sheet processing to the background."""
    # 1. Quick cookie check
    unique_cookie = request.cookies.get("ench_unique_visit")
    if unique_cookie:
        return {"status": "already_tracked"}

    # 2. Set 30-day cookie immediately
    response.set_cookie(
        key="ench_unique_visit",
        value="true",
        max_age=30 * 24 * 60 * 60, # 30 days
        httponly=True,
        samesite="lax"
    )

    # 3. Offload EVERYTHING else to background threadpool
    background_tasks.add_task(_credit_visit_background, track.refCode, track.ip)
    
    return {"status": "success", "message": "Visit registered"}

# Removed duplicate track_share logic

@router.get("/audit/verify")
async def verify_integrity(user: UserRead = Depends(current_active_user)):
    """Audit endpoint to check Google Sheets column alignment and math."""
    if not user.is_superuser:
        raise HTTPException(status_code=403, detail="Admin access required")
    try:
        # Get raw values to check mapping explicitly (no header mapping)
        ws = sheets_client.get_worksheet("Partners")
        if not ws:
            return {"error": f"Worksheet 'Partners' not found in spreadsheet {sheets_client.spreadsheet_id}. Check backend logs for gspread errors."}

        
        # Get last 5 rows to audit
        all_values = ws.get_all_values()
        if len(all_values) < 2:
            return {"error": "Sheet is empty"}
            
        last_rows = all_values[-5:] # Take last 5 for a representative sample
        audit_results = []
        


        # 1. Map headers to indices
        headers = [h.strip().upper() for h in all_values[0]]
        
        def find_idx(target_names: list):
            for i, h in enumerate(headers):
                if h in [t.upper() for t in target_names]:
                    return i
            return -1

        # Helper indices
        user_idx = find_idx(["USERNAME", "Email"])
        ref_idx = find_idx(["REFERRAL CODE", "ReferralCode"])
        points_idx = find_idx(["POINTS"])
        rev_idx = find_idx(["REVENUE (₦)", "REVENUE", "REVENUE (N)"])
        status_idx = find_idx(["PAYOUT STATUS", "PAYOUT_STATUS", "Payout status"])
        lifetime_idx = find_idx(["LIFETIME EARNINGS", "LIFETIME_EARNINGS", "Lifetime Earnings"])
        
        # Robust fallbacks for specific columns requested by USER (Feb 19):
        # Column G is index 6 (LIFETIME EARNINGS)
        # Column I is index 8 (PAYOUT STATUS)
        if lifetime_idx == -1 and len(headers) > 6:
            lifetime_idx = 6
        if status_idx == -1 and len(headers) > 8:
            status_idx = 8
            
        # Column S (Index 18) for Last Payout Amount
        last_payout_idx = 18 if len(headers) > 18 else -1



        last_rows = all_values[-5:] # Take last 5 for a representative sample
        audit_results = []
        
        for i, row in enumerate(last_rows):
            # Skip Header row if it appears in the sample
            if row[0].upper() in ["USERNAME", "EMAIL"]:
                continue

            # Basic Info
            username = row[user_idx] if user_idx != -1 and len(row) > user_idx else "N/A"
            ref_code = row[ref_idx] if ref_idx != -1 and len(row) > ref_idx else ""
            
            # Points & Revenue
            p_val = row[points_idx] if points_idx != -1 and len(row) > points_idx else "0.0"
            r_val = row[rev_idx] if rev_idx != -1 and len(row) > rev_idx else "0.0"
            
            try:
                # Clean and parse strings using the global safe_float
                points = safe_float(p_val)
                revenue = safe_float(r_val)

                
                math_ok = abs(revenue - (points * 100)) < 0.01
                
                # Payouts
                payout_status = row[status_idx] if status_idx != -1 and len(row) > status_idx else "PENDING"
                lt_val = row[lifetime_idx] if lifetime_idx != -1 and len(row) > lifetime_idx else "0.0"
                lifetime_earnings = safe_float(lt_val)


                audit_results.append({
                    "row": len(all_values) - len(last_rows) + i + 1,
                    "username": username,
                    "refCode": ref_code,
                    "points": points,
                    "revenue": revenue,
                    "math_ok": math_ok,
                    "alignment_ok": status_idx != -1 and lifetime_idx != -1,
                    "payout_status": payout_status,
                    "lifetime_earnings": lifetime_earnings,
                    "milestone_claimed": row[22] if len(row) > 22 else "NOT_CLAIMED", # Column W
                    "last_payout_amount": safe_float(row[last_payout_idx]) if last_payout_idx != -1 and len(row) > last_payout_idx else 0.0
                })

            except (ValueError, TypeError) as e:
                audit_results.append({
                    "row": len(all_values) - len(last_rows) + i + 1,
                    "username": username,
                    "error": f"Invalid numeric data: {e}",
                    "raw_points": p_val,
                    "raw_revenue": r_val
                })

                
        return {
            "timestamp": datetime.now().isoformat(),
            "results": audit_results,
            "conversion_ratio": "1 Pt = 100 Naira",
            "required_cols": {"A": "Username", "E": "Points", "F": "Revenue"}
        }
    except Exception as e:
        # Standardize error message to avoid encoding issues
        err_msg = str(e).replace("\u20a6", "N")
        print(f"ERROR: Audit failed: {err_msg[:100]}")
        raise HTTPException(status_code=500, detail=err_msg)




@router.post("/debug/mock-register")
async def mock_register(email: str, refCode: str, request: Request):
    """Debug endpoint to simulate a registration event for testing."""
    from ..auth import get_user_db, UserManager, UserCreate
    
    # We bypass the full FastAPI-users flow to simulate exactly what we need
    try:
        # Search for referrer
        records = sheets_client.get_all_records("Partners")
        referrer_row = None
        for i, r in enumerate(records):
            if str(r.get("REFERRAL CODE", "")).strip().lower() == refCode.strip().lower():
                referrer_row = i + 2
                break
        
        if not referrer_row:
            return {"error": "Referrer not found"}

        # Simulate the 'on_after_register' logic
        # Increment points by 0.1
        current = float(records[referrer_row-2].get("POINTS", 0.0))
        new_points = round(current + 0.1, 2)
        new_revenue = round(new_points * 100, 2)
        
        # Atomic update of columns E (Points) and F (Revenue)
        # And reset status to PENDING in Column I (9th col)
        sheets_client.update_range("Partners", f"E{referrer_row}:F{referrer_row}", [[new_points, new_revenue]])
        sheets_client.update_cell("Partners", referrer_row, 9, "PENDING")

        
        # Log to ActivityLog
        activity_row = [
            datetime.now().isoformat(),
            refCode,
            "Registration (Legacy Mock)",
            0.1,
            f"Mock signup: {email} (Simulating immediate credit)",
            "", # F: REPORTED Status
            "PENDING" # G: Payout Status
        ]
        sheets_client.append_row("ActivityLog", activity_row)
        
        return {"success": True, "credited": 0.1, "referrer_row": referrer_row}
    except Exception as e:
        return {"error": str(e)}

@router.get("/debug/sync-all")
async def sync_all_revenue(user: UserRead = Depends(current_active_user)):
    """Debug endpoint to force sync all Revenue = Points * 100 in the sheet."""
    if not user.is_superuser:
        raise HTTPException(status_code=403, detail="Admin access required")
    try:
        records = sheets_client.get_all_records("Partners")
        updates = []
        for i, record in enumerate(records):
            row_idx = i + 2
            try:
                # Clean and parse points
                p_raw = str(record.get("POINTS", "0.0")).replace(",", "").replace("₦", "").strip() or "0.0"
                points = float(p_raw)
                revenue = points * 100
                
                # Check if current revenue matches (sanity check)
                r_raw = str(record.get("REVENUE (₦)", "0.0")).replace(",", "").replace("₦", "").strip() or "0.0"
                current_revenue = float(r_raw)
                
                if abs(current_revenue - revenue) > 0.01:
                    updates.append({"row": row_idx, "points": points, "revenue": revenue})
                    # Perform update for this row
                    sheets_client.update_range("Partners", f"E{row_idx}:F{row_idx}", [[points, revenue]])
            except Exception as e:
                print(f"Skipping row {row_idx} due to error: {e}")
                
        return {"status": "success", "updated_rows": len(updates), "details": updates}
    except Exception as e:
        return {"error": str(e)}

from pydantic import BaseModel

class PurchaseCredit(BaseModel):
    refCode: str
    email: str # Required to identify referee

class PaystackWebhook(BaseModel):
    event: str
    data: dict

@router.post("/credit-purchase")
async def credit_purchase(purchase: PurchaseCredit, background_tasks: BackgroundTasks):
    """Manual trigger for purchase credit."""
    background_tasks.add_task(_credit_purchase_background, purchase.refCode, purchase.email)
    return {"success": True, "message": "Credit processing in background"}

class BuyerEmail(BaseModel):
    email: str

@router.post("/complete-purchase")
async def complete_purchase(body: BuyerEmail, background_tasks: BackgroundTasks):
    """
    Called by the frontend after a successful Paystack payment.
    Runs the full buyer-side milestone:
      1. Sets HasPurchasedBook = TRUE in UserOnboarding
      2. Awards 1.0 cashback to the buyer
      3. Credits the referrer 5.0 pts via existing background logic
    This is the fallback for when the Paystack webhook hasn't been configured yet.
    """
    background_tasks.add_task(_handle_payment_milestone, body.email)
    return {"success": True, "message": "Purchase milestone processing started"}

@router.post("/paystack/webhook")
async def paystack_webhook(request: Request, background_tasks: BackgroundTasks):
    """Securely handle Paystack webhooks with HMAC verification."""
    # 1. Verify Signature
    paystack_signature = request.headers.get("x-paystack-signature")
    if not paystack_signature:
        print("ERROR: Missing x-paystack-signature header")
        raise HTTPException(status_code=400, detail="Missing signature")
    
    secret = os.getenv("PAYSTACK_SECRET_KEY", "")
    body = await request.body()
    
    computed_hmac = hmac.new(
        secret.encode("utf-8"),
        body,
        hashlib.sha512
    ).hexdigest()
    
    if computed_hmac != paystack_signature:
        print(f"ERROR: Invalid Paystack signature. Computed: {computed_hmac[:10]}... Header: {paystack_signature[:10]}...")
        raise HTTPException(status_code=400, detail="Invalid signature")
    
    # 2. Parse Payload
    try:
        payload = json.loads(body)
    except Exception as e:
        print(f"ERROR: Failed to parse Paystack webhook body: {e}")
        raise HTTPException(status_code=400, detail="Invalid JSON")
        
    event = payload.get("event")
    data = payload.get("data", {})
    
    if event == "charge.success":
        status = data.get("status")
        customer_email = data.get("customer", {}).get("email")
        metadata = data.get("metadata", {})
        product = metadata.get("product")
        
        if status == "success" and product == "book":
            print(f"INFO: Verified Paystack purchase for {customer_email}")
            # Identify the referee and trigger the dual-reward milestone logic
            background_tasks.add_task(_handle_payment_milestone, customer_email)
            return {"status": "success", "message": "Signature verified, milestone processing started"}
            
    return {"status": "ignored"}

# Deprecated mock webhook (Left for internal transitions if needed, but not protected by HMAC)
@router.post("/webhook/payment-success")
async def payment_webhook(payload: PaystackWebhook, background_tasks: BackgroundTasks):
    """
    [DEPRECATED] Handle mock/unsecured payment success signals. 
    New implementation: /api/paystack/webhook (with prefix /referral)
    """
    event = payload.event
    data = payload.data
    
    if event == "charge.success":
        status = data.get("status")
        customer_email = data.get("customer", {}).get("email")
        metadata = data.get("metadata", {})
        product = metadata.get("product")
        
        if status == "success" and product == "book":
            background_tasks.add_task(_handle_payment_milestone, customer_email)
            return {"status": "success", "message": "Milestone processing started"}
            
    return {"status": "ignored"}

async def _handle_payment_milestone(referee_email: str):
    """Finds the referrer for a referee and credits them, and also credits the buyer (cash-back)."""
    try:
        # 1. Update UserOnboarding status
        try:
            on_records = sheets_client.get_all_records("UserOnboarding")
            o_row = None
            for i, r in enumerate(on_records):
                if str(r.get("Email", "")).lower().strip() == referee_email.lower().strip():
                    o_row = i + 2
                    break
            if o_row:
                sheets_client.update_cell("UserOnboarding", o_row, 5, "TRUE")
                sheets_client.update_cell("UserOnboarding", o_row, 6, datetime.now().isoformat())
        except Exception as e:
            print(f"ERROR: Failed to update onboarding purchase state for {referee_email}: {e}")

        # 2. Credit the Buyer (Cash-Back)
        buyer_name = "Master"
        try:
            p_records = sheets_client.get_all_records("Partners")
            for r in p_records:
                if str(r.get("USERNAME", "")).lower().strip() == referee_email.lower().strip():
                    buyer_name = r.get("FULL NAME", r.get("NAME", "Master"))
                    break
            
            await _credit_buyer_cashback(referee_email)
            await _send_cashback_confirmation_email(referee_email, buyer_name)
        except Exception as e:
            print(f"ERROR: Failed buyer cashback for {referee_email}: {e}")

        # 3. Credit the Referrer
        records = sheets_client.get_all_records("Partners")
        referred_by = None
        for r in records:
            if str(r.get("USERNAME", "")).lower().strip() == referee_email.lower().strip():
                referred_by = str(r.get("REFERRED_BY", "")).strip()
                break
        
        if referred_by:
            # Trigger the purchase credit logic (Credits Referrer 5.0)
            _credit_purchase_background(referred_by, referee_email)
            
    except Exception as e:
        print(f"ERROR: Failed to handle payment milestone for {referee_email}: {e}")

async def _get_legacy_rank_data(email: str):
    """Calculates Legacy Rank and Souls Guided count based on ReferralMilestones."""
    try:
        email = email.lower().strip()
        milestones = sheets_client.get_all_records("ReferralMilestones")
        
        # Filter for book_purchase milestones where this user is the referrer
        book_refs = [
            m for m in milestones 
            if str(m.get("MilestoneType", "")).lower().strip() == "book_purchase" and 
            str(m.get("ReferrerEmail", "")).lower().strip() == email
        ]
        
        # Sort by timestamp to find attainment dates
        book_refs.sort(key=lambda x: x.get("Timestamp", ""))
        
        count = len(book_refs)
        rank = "Seeker"
        mastery_date = None
        
        if count >= 16:
            rank = "Master"
            # 16th referral date
            mastery_date = book_refs[15].get("Timestamp")
        elif count >= 6:
            rank = "Sage"
            # 6th referral date
            mastery_date = book_refs[5].get("Timestamp")
            
        return {
            "rank": rank,
            "soulsGuided": count,
            "masteryDate": mastery_date
        }
    except Exception as e:
        print(f"ERROR calculating legacy rank for {email}: {e}")
        return {"rank": "Seeker", "soulsGuided": 0, "masteryDate": None}

async def _trigger_onboarding_reward(target_email: str, step: str):
    """Internal helper to find referrer and award points for onboarding steps."""
    try:
        # Find the user's referrer code
        p_records = sheets_client.get_all_records("Partners")
        referred_by_code = None
        for p in p_records:
            if str(p.get("USERNAME", "")).lower().strip() == target_email.lower().strip():
                referred_by_code = str(p.get("REFERRED_BY", "")).strip()
                break
        
        if referred_by_code:
            # Find referrer email
            referrer_email = None
            for p in p_records:
                if str(p.get("REFERRAL CODE", "")).lower().strip() == referred_by_code.lower().strip():
                    referrer_email = str(p.get("USERNAME", "")).lower().strip()
                    break
            
            if referrer_email:
                from ..auth import GoogleSheetsUserDatabase, UserManager, User
                import uuid
                db = GoogleSheetsUserDatabase(User, uuid.UUID)
                manager = UserManager(db)
                await manager.record_milestone_and_credit(referrer_email, target_email, step, 0.1)
                print(f"DEBUG: Auto-rewarded {referrer_email} for {target_email} {step}")
    except Exception as e:
        print(f"ERROR triggering auto-reward for {target_email}: {e}")

@router.get("/progress", response_model=UserProgress)
async def get_user_progress(user: UserRead = Depends(current_active_user)):
    """Fetches the onboarding progress for the current user and auto-syncs login milestones."""
    records = sheets_client.get_all_records("UserOnboarding")
    target = user.email.lower().strip()
    
    current_progress = None
    row_idx = None
    for i, r in enumerate(records):
        if str(r.get("Email", "")).lower().strip() == target:
            row_idx = i + 2
            current_progress = r
            break
    
    if not current_progress:
        # Create record if missing (legacy users)
        onboarding_row = [target, "TRUE" if user.is_verified else "FALSE", "TRUE", "FALSE", "FALSE", datetime.now().isoformat()]
        sheets_client.get_or_create_worksheet("UserOnboarding", ["Email", "IsVerified", "IsPartner", "IsDistributor", "HasPurchasedBook", "LastUpdated"])
        sheets_client.append_row("UserOnboarding", onboarding_row)
        # Award reward for partner status
        await _trigger_onboarding_reward(target, "partner")
        return UserProgress(email=target, is_verified=user.is_verified, is_partner=True)

    # Sync state
    is_verified_sheet = str(current_progress.get("IsVerified", "FALSE")).upper() == "TRUE"
    is_partner_sheet = str(current_progress.get("IsPartner", "FALSE")).upper() == "TRUE"
    
    updates_made = False
    
    # 1. Sync Verification
    if user.is_verified and not is_verified_sheet:
        sheets_client.update_cell("UserOnboarding", row_idx, 2, "TRUE")
        is_verified_sheet = True
        updates_made = True
        
    # 2. Sync Partner Status (Accessing dashboard = Partner)
    if not is_partner_sheet:
        sheets_client.update_cell("UserOnboarding", row_idx, 3, "TRUE")
        is_partner_sheet = True
        updates_made = True
        # Trigger reward logic
        await _trigger_onboarding_reward(target, "partner")

    if updates_made:
        sheets_client.update_cell("UserOnboarding", row_idx, 6, datetime.now().isoformat())

    return UserProgress(
        email=target,
        is_verified=is_verified_sheet,
        is_partner=is_partner_sheet,
        is_distributor=str(current_progress.get("IsDistributor", "FALSE")).upper() == "TRUE",
        has_purchased_book=str(current_progress.get("HasPurchasedBook", "FALSE")).upper() == "TRUE",
        last_updated=datetime.now().isoformat() if updates_made else str(current_progress.get("LastUpdated", ""))
    )

class ProgressUpdate(BaseModel):
    email: str
    step: str # 'partner' or 'distributor'

@router.get("/recent-milestones")
async def get_recent_milestones():
    """Fetches the latest 10 milestones and registrations for the live feed."""
    try:
        # 1. Fetch latest milestones
        milestone_records = sheets_client.get_all_records("ReferralMilestones")
        latest_milestones = sorted(milestone_records, key=lambda x: x.get("Timestamp", ""), reverse=True)[:10]
        
        # 2. Fetch latest partners (for "New Partner" notifications)
        partner_records = sheets_client.get_all_records("Partners")
        latest_partners = sorted(partner_records, key=lambda x: x.get("DATE_JOINED", ""), reverse=True)[:10]

        # 3. Fetch latest global broadcasts (rank ups)
        broadcast_records = sheets_client.get_all_records("GlobalNotifications")
        latest_broadcasts = sorted(broadcast_records, key=lambda x: x.get("Timestamp", ""), reverse=True)[:10]

        all_impacts = []
        
        # Process global broadcasts
        for b in latest_broadcasts:
            b_type = b.get("BroadcastType", "").lower()
            name = b.get("Username", "Someone")
            if b_type == "sage_rank":
                all_impacts.append({
                    "type": "sage",
                    "text": f"{name} just achieved the rank of Sage! 🥈",
                    "timestamp": b.get("Timestamp")
                })
            elif b_type == "master_rank":
                all_impacts.append({
                    "type": "master",
                    "text": f"{name} just reached Enchiridion Mastery! 🏆",
                    "timestamp": b.get("Timestamp")
                })

        # Process milestones
        for m in latest_milestones:
            m_type = m.get("MilestoneType", "").lower()
            name = m.get("RefereeEmail", "").split("@")[0]
            # Try to capitalize first letter
            name = name.capitalize() if name else "Someone"
            
            if m_type == "book_purchase":
                all_impacts.append({
                    "type": "purchase",
                    "text": f"{name} just bought their Enchiridion guide (Book)! 📘",
                    "timestamp": m.get("Timestamp")
                })
            elif m_type == "distributor":
                all_impacts.append({
                    "type": "distributor",
                    "text": f"{name} just promoted to Distributor Status! 🚀",
                    "timestamp": m.get("Timestamp")
                })
            elif m_type == "partner":
                all_impacts.append({
                    "type": "partner",
                    "text": f"{name} just reached Partner Status! 🎉",
                    "timestamp": m.get("Timestamp")
                })

        # Process partners
        for p in latest_partners:
            name = p.get("FULL NAME", p.get("NAME", "Someone")).split()[0]
            state = p.get("STATE", "Nigeria")
            all_impacts.append({
                "type": "registration",
                "text": f"{name} from {state} just registered with us! ✨",
                "timestamp": p.get("DATE_JOINED")
            })

        # Sort and return top 10
        all_impacts.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
        return all_impacts[:10]
    except Exception as e:
        print(f"ERROR fetching recent milestones: {e}")
        return []

@router.get("/global-broadcasts")
async def get_global_broadcasts():
    """Fetches the latest global community alerts for real-time toasts."""
    try:
        # Fetch last 5 global notifications from the past 10 minutes (to avoid stale toasts)
        records = sheets_client.get_all_records("GlobalNotifications")
        if not records:
            return []
            
        now = datetime.now()
        threshold = now - timedelta(minutes=10)
        
        recent = []
        for r in sorted(records, key=lambda x: x.get("Timestamp", ""), reverse=True):
            try:
                ts = date_parser.parse(r.get("Timestamp", ""))
                if ts >= threshold:
                    recent.append({
                        "id": f"{r.get('BroadcastType')}_{r.get('Timestamp')}",
                        "type": r.get("BroadcastType"),
                        "username": r.get("Username"),
                        "text": r.get("Text"),
                        "timestamp": r.get("Timestamp")
                    })
                if len(recent) >= 5:
                    break
            except:
                continue
        return recent
    except Exception as e:
        print(f"ERROR fetching global broadcasts: {e}")
        return []

@router.post("/update-progress")
async def update_user_progress(update: ProgressUpdate, user: UserRead = Depends(current_active_superuser)):
    """
    Internal/Admin endpoint to move User B along the checklist.
    Awards rewards to their Referrer (User A).
    """
    target_email = update.email.lower().strip()
    step = update.step.lower().strip()
    
    if step not in ["partner", "distributor"]:
        raise HTTPException(status_code=400, detail="Invalid step. Use 'partner' or 'distributor'.")

    # 1. Find the onboarding row
    records = sheets_client.get_all_records("UserOnboarding")
    row_idx = None
    current_status = None
    for i, r in enumerate(records):
        if str(r.get("Email", "")).lower().strip() == target_email:
            row_idx = i + 2
            current_status = r
            break
    
    if not row_idx:
        raise HTTPException(status_code=404, detail="User progress record not found.")

    # 2. Check if already completed
    col_idx = 3 if step == "partner" else 4
    col_name = "IsPartner" if step == "partner" else "IsDistributor"
    
    if str(current_status.get(col_name, "FALSE")).upper() == "TRUE":
        return {"success": True, "message": f"Step {step} already completed."}

    # 3. Update the sheet
    sheets_client.update_cell("UserOnboarding", row_idx, col_idx, "TRUE")
    sheets_client.update_cell("UserOnboarding", row_idx, 6, datetime.now().isoformat())

    # 4. Award Referrer
    await _trigger_onboarding_reward(target_email, step)

    return {"success": True, "message": f"Step {step} completed and reward processed."}

def _credit_purchase_background(ref_code: str, referee_email: str):
    """Internal helper to credit purchase reward using Milestone logic."""
    try:
        from ..auth import UserManager
        # We need a UserManager instance or a static helper. 
        # Since UserManager handles the sheet logic, let's use a temporary instance or just call its logic.
        # For simplicity, I'll refactor record_milestone_and_credit to be easily accessible.
        # But wait, I can just use the existing helper logic here since Sheets are global.
        
        # Actually, let's import the record_milestone_and_credit logic carefully.
        # I'll update referral.py to use the new milestone logic.
        
        records = sheets_client.get_all_records("Partners")
        referrer_email = None
        for record in records:
            ref_val = sheets_client.get_case_insensitive_val(record, "REFERRAL CODE", "ReferralCode", "referral_code")
            if str(ref_val or "").strip().lower() == ref_code.strip().lower():
                referrer_email = str(record.get("USERNAME", "")).lower().strip()
                break
        
        if referrer_email:
            # Credit 5.0 for purchase Milestone
            # We can't easily call UserManager here without an instance, 
            # so I'll replicate the core logic or call a helper.
            # I'll create a shared helper if needed, but for now, I'll update it here.
            
            # REPLICATING logic for now to avoid circular imports / complex DI
            unique_key = f"{referee_email.lower().strip()}_book_purchase"
            
            # Idempotency
            milestone_records = sheets_client.get_all_records("ReferralMilestones")
            for r in milestone_records:
                if str(r.get("UniqueKey", "")).lower().strip() == unique_key:
                    return

            # Find row index again for update
            for i, record in enumerate(records):
                 if str(record.get("USERNAME", "")).lower().strip() == referrer_email:
                     row_idx = i + 2
                     p_val = sheets_client.get_case_insensitive_val(record, "POINTS", "points")
                     pts = safe_float(p_val) + 5.0
                     sheets_client.update_range("Partners", f"E{row_idx}:F{row_idx}", [[pts, pts*100]])
                     
                     # Log Activity
                     sheets_client.append_row("ActivityLog", [datetime.now().isoformat(), ref_code, "Book Purchase", 5.0, f"Referee: {referee_email}", "", "PENDING"])
                     
                     # Log Milestone
                     sheets_client.append_row("ReferralMilestones", [datetime.now().isoformat(), referrer_email, referee_email, "book_purchase", 5.0, unique_key])

                     # Rank-Up Detection
                     # Since we just added a milestone, we need to check if they hit a threshold
                     # But _get_legacy_rank_data recalculates everything, which is safe.
                     # However, to know if they *just* ranked up, we'd need to know their count before.
                     # We can just check if count == 6 or 16 specifically right now.
                     
                     import asyncio
                     # We are in a sync background task, so we need a loop to call async rank helper
                     try:
                         loop = asyncio.new_event_loop()
                         asyncio.set_event_loop(loop)
                         rank_data = loop.run_until_complete(_get_legacy_rank_data(referrer_email))
                         loop.close()
                         
                         count = rank_data.get("soulsGuided", 0)
                         username = sheets_client.get_case_insensitive_val(record, "NAME", "FULL NAME", default=referrer_email.split("@")[0])
                         city = record.get("STATE", record.get("CITY", "Nigeria"))
                         
                         if count == 6:
                             _log_global_broadcast("sage_rank", username, city)
                         elif count == 16:
                             _log_global_broadcast("master_rank", username, city)
                             # Trigger Mastery Email
                             loop = asyncio.new_event_loop()
                             asyncio.set_event_loop(loop)
                             loop.run_until_complete(_send_mastery_email(referrer_email, username))
                             loop.close()
                     except Exception as rank_err:
                         print(f"ERROR in rank-up detection: {rank_err}")

                     break
    except Exception as e:
        print(f"ERROR: Failed to credit purchase milestone: {e}")

async def _credit_buyer_cashback(buyer_email: str):
    """Awards 1.0 point to the buyer as cash-back for purchase."""
    try:
        unique_key = f"{buyer_email.lower().strip()}_cashback_purchase"
        
        # Idempotency
        milestone_records = sheets_client.get_all_records("ReferralMilestones")
        for r in milestone_records:
            if str(r.get("UniqueKey", "")).lower().strip() == unique_key:
                print(f"DEBUG: Cashback already awarded to {buyer_email}")
                return

        records = sheets_client.get_all_records("Partners")
        for i, record in enumerate(records):
            if str(record.get("USERNAME", "")).lower().strip() == buyer_email.lower().strip():
                row_idx = i + 2
                p_val = sheets_client.get_case_insensitive_val(record, "POINTS", "points")
                pts = safe_float(p_val) + 1.0
                sheets_client.update_range("Partners", f"E{row_idx}:F{row_idx}", [[pts, pts*100]])
                
                # Log Milestone
                sheets_client.append_row("ReferralMilestones", [datetime.now().isoformat(), "SYSTEM", buyer_email, "cashback_purchase", 1.0, unique_key])
                
                # Log Activity
                ref_code = record.get("REFERRAL CODE", "N/A")
                sheets_client.append_row("ActivityLog", [datetime.now().isoformat(), ref_code, "Cash-Back: Enchiridion Book Purchase", 1.0, f"Buyer: {buyer_email}", "", "PENDING"])
                print(f"DEBUG: Successfully awarded 1.0 cashback to {buyer_email}")
                break
    except Exception as e:
        print(f"ERROR: Failed to credit buyer cashback: {e}")

async def _send_mastery_email(email: str, name: str):
    """Sends a celebratory email when a user alcanza Enchiridion Mastery."""
    subject = "UNLOCKED: Enchiridion Mastery Status! 🏆✨"
    
    html = f"""
    <div style="font-family: 'Georgia', serif; max-width: 650px; margin: 0 auto; padding: 40px; border: 15px solid #D4AF37; border-image: linear-gradient(to bottom right, #D4AF37, #FBF2C0, #D4AF37) 1; background: #fff; box-shadow: 0 10px 30px rgba(0,0,0,0.1); text-align: center;">
        <div style="margin-bottom: 30px;">
            <h2 style="color: #1e293b; text-transform: uppercase; letter-spacing: 5px; margin: 0;">Enchiridion Mastery</h2>
            <div style="width: 100px; height: 2px; background: #D4AF37; margin: 15px auto;"></div>
            <p style="font-size: 14px; color: #64748b; font-style: italic;">Certificate of Achievement</p>
        </div>
        
        <p style="font-size: 18px; color: #334155;">This is to certify that</p>
        <h1 style="font-size: 36px; color: #1e293b; margin: 10px 0; border-bottom: 1px solid #e2e8f0; display: inline-block; padding: 0 40px;">{name}</h1>
        <p style="font-size: 18px; color: #334155; margin-top: 10px;">has successfully guided</p>
        
        <div style="background: #1e293b; color: white; display: inline-block; padding: 15px 40px; border-radius: 50px; margin: 20px 0;">
            <h2 style="color: #D4AF37; margin: 0; font-size: 24px;">16 SOULS GUIDED</h2>
        </div>
        
        <p style="font-size: 18px; color: #334155;">and is hereby recognized as an <strong>Enchiridion Master</strong>.</p>
        
        <div style="margin: 40px 0; padding: 20px; background: #f8fafc; border-radius: 10px; border: 1px dashed #cbd5e1;">
            <p style="font-size: 15px; color: #475569; margin: 0;">
                <strong>Digital Achievement Card Unlocked:</strong> Your shareable card is now available on your dashboard. 
                Use it to share your legacy with the world!
            </p>
        </div>

        <div style="text-align: center; margin: 30px 0;">
            <a href="https://enchiridion.ng/dashboard" style="background: #D4AF37; color: #1e293b; padding: 15px 35px; border-radius: 5px; text-decoration: none; font-weight: bold; display: inline-block; font-family: sans-serif; text-transform: uppercase; letter-spacing: 1px;">Claim My Rank & Share Card</a>
        </div>

        <div style="margin-top: 50px; border-top: 1px solid #f1f5f9; padding-top: 20px;">
            <p style="font-size: 12px; color: #94a3b8; text-transform: uppercase;">The Enchiridion Registry • Verified {datetime.now().year}</p>
        </div>
    </div>
    """
    
    message = MessageSchema(
        subject=subject,
        recipients=[email],
        body=html,
        subtype=MessageType.html
    )
    
    fm = FastMail(conf)
    try:
        await fm.send_message(message)
        print(f"DEBUG: Mastery email sent to {email}")
    except Exception as e:
        print(f"ERROR: Failed to send mastery email to {email}: {e}")

async def _send_cashback_confirmation_email(email: str, name: str):
    """Sends confirmation email with 1.0 point reward notification."""
    subject = "Your Mastery is Confirmed (Plus a Reward!) 📘✨"
    
    html = f"""
    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
        <h2 style="color: #4169E1;">Welcome to the Inner Circle, {name}</h2>
        <p>Your purchase of <strong>The Enchiridion</strong> is confirmed, and your journey toward mastery has officially accelerated.</p>
        
        <div style="background: #f0fdf4; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0; border: 1px solid #bbf7d0;">
            <p style="margin: 0; color: #166534; font-weight: bold;">Bonus Reward Added!</p>
            <span style="font-size: 28px; font-weight: bold; color: #16a34a;">+ 1.0 Point</span>
            <p style="margin: 5px 0 0 0; color: #15803d; font-size: 14px;">(subsidized mastery reward)</p>
        </div>

        <h3 style="color: #1e293b;">What's Next?</h3>
        <ul style="color: #475569; line-height: 1.6;">
            <li><strong>Check your Dashboard:</strong> Your "Enchiridion Mastery" milestone is now complete.</li>
            <li><strong>Start Referring:</strong> Now that you have the blueprint, share your link and earn <b>5.0 points</b> whenever someone you invite buys the book!</li>
        </ul>

        <p style="color: #64748b; font-size: 14px; margin-top: 30px;">Keep Rising,<br>The Enchiridion Team</p>
    </div>
    """

    message = MessageSchema(
        subject=subject,
        recipients=[email],
        body=html,
        subtype=MessageType.html
    )
    fm = FastMail(conf)
    try:
        await fm.send_message(message)
        print(f"DEBUG: Cashback confirmation email sent to {email}")
    except Exception as e:
        print(f"DEBUG: Cashback email failed for {email}: {e}")

# Removed local redundant get_case_insensitive helper


@router.post("/mark-as-paid")
async def mark_as_paid(request: MarkAsPaidRequest, user: UserRead = Depends(current_active_user)):
    """Marks a partner as paid, resets current earnings, and updates lifetime earnings."""
    if not user.is_superuser:
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        # 1. Find the partner in the Partners sheet
        records = sheets_client.get_all_records("Partners")
        partner_row_idx = None
        partner_record = None
        
        for i, record in enumerate(records):
            if str(record.get("USERNAME", "")).lower().strip() == request.email.lower().strip():
                partner_record = record
                partner_row_idx = i + 2
                break
        
        if not partner_record:
            raise HTTPException(status_code=404, detail="Partner not found")
            
        # 2. Extract current earnings and lifetime earnings using robust sheets_client helper
        current_points = safe_float(sheets_client.get_case_insensitive_val(partner_record, "POINTS", "points", default=0.0))
        current_revenue = safe_float(sheets_client.get_case_insensitive_val(partner_record, "REVENUE (\u20a6)", "REVENUE", "Revenue", default=0.0))

        
        # 3. Extract lifetime earnings using robust sheets_client helper
        lifetime_earnings = safe_float(sheets_client.get_case_insensitive_val(partner_record, "LIFETIME_EARNINGS", "LIFETIME EARNINGS", "Lifetime Earnings", default=0.0))
        
        # 4. Calculate new values
        new_lifetime = round(lifetime_earnings + current_revenue, 2)
        
        # 5. Atomic update of Partners sheet (E: Points, F: Revenue, G: Lifetime, I: Status)
        # Mapping aligned with USER request (Feb 19 evening):
        # Col E: Points -> 0
        # Col F: Revenue -> 0
        # Col G: Lifetime -> new_lifetime
        # Col I (9th col): Status -> 'COMPLETED'
        
        print(f"DEBUG: Atomic update for Partners E{partner_row_idx}:G{partner_row_idx} -> [0, 0, {new_lifetime}]")
        sheets_client.update_range("Partners", f"E{partner_row_idx}:G{partner_row_idx}", [[0.0, 0.0, new_lifetime]])
        
        print(f"DEBUG: Updating Status in Column I and Last Payout in Column S for row {partner_row_idx}")
        # Column I = 9, Column S = 19 (1-indexed)
        sheets_client.update_cell("Partners", partner_row_idx, 9, "COMPLETED")
        sheets_client.update_cell("Partners", partner_row_idx, 19, current_revenue)



        
        # 5. Log the payout in ActivityLog
        print("DEBUG: Appending payout log to ActivityLog")
        activity_row = [
            datetime.now().isoformat(),
            request.refCode,
            "Payout",
            0.0,
            f"Payout COMPLETED for {request.email}. Amount: N{current_revenue}",

            "", # F: REPORTED Status
            "COMPLETED" # G: Payout Status
        ]
        sheets_client.append_row("ActivityLog", activity_row)
        
        # 6. Update Payout Status in ActivityLog for all PENDING entries for this refCode
        # This is optional but keeps logs consistent
        print(f"DEBUG: Updating pending statuses in ActivityLog for {request.refCode}")
        activity_ws = sheets_client.get_worksheet("ActivityLog")
        all_activities = activity_ws.get_all_values()
        
        updated_count = 0
        if all_activities and len(all_activities) > 1:
            act_headers = [h.strip().upper() for h in all_activities[0]]
            def find_idx(targets):
                for i, h in enumerate(act_headers):
                    if h in [t.upper() for t in targets]: return i
                return -1
            
            ref_idx = find_idx(["ReferralCode"])
            stat_idx = find_idx(["PayoutStatus", "Payout status"])
            
            for i, row in enumerate(all_activities[1:]):
                row_idx = i + 2
                current_ref = row[ref_idx] if ref_idx != -1 and len(row) > ref_idx else ""
                current_stat = row[stat_idx] if stat_idx != -1 and len(row) > stat_idx else "PENDING"
                
                if str(current_ref).strip().lower() == request.refCode.strip().lower() and \
                   str(current_stat).upper() == "PENDING":
                    print(f"DEBUG: Updating ActivityLog row {row_idx} to COMPLETED")
                    # Column I (Payout status) is index 7 in [Timestamp, RefCode, Type, Pts, URL, ReportedStatus, Status]
                    # Let's find index dynamically or use the fixed 7 since we know it
                    target_col = stat_idx + 1 if stat_idx != -1 else 7
                    sheets_client.update_cell("ActivityLog", row_idx, target_col, "COMPLETED")
                    updated_count += 1
        print(f"DEBUG: Updated {updated_count} rows in ActivityLog")


        return {"success": True, "new_lifetime": new_lifetime}
        
    except Exception as e:
        print(f"ERROR: Failed to mark as paid: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/report/monthly/csv")
async def generate_monthly_csv(
    month: Optional[int] = None,
    year: Optional[int] = None,
    user: UserRead = Depends(current_active_user)
):
    """Generates a downloadable CSV report for a given month/year's performance (defaults to current)."""
    if not user.is_superuser:
        raise HTTPException(status_code=403, detail="Admin access required")
        
    try:
        # 1. Setup temporal filters
        now = datetime.now()
        target_month = month if month is not None else now.month
        target_year = year if year is not None else now.year
        
        # Display name for the file
        month_name = datetime(target_year, target_month, 1).strftime("%B")
        
        # 2. Fetch data (Gspread robust way)
        activity_ws = sheets_client.get_worksheet("ActivityLog")
        all_activities = activity_ws.get_all_values()
        partner_records = sheets_client.get_all_records("Partners")
        
        if not all_activities or len(all_activities) < 2:
            print("DEBUG: ActivityLog is empty or only contains headers")
            return Response(content="Date,Event Type,Partner Name,Points Awarded,Revenue Equivalent (Naira NGN)\n", media_type="text/csv")

        # Map headers manually for robustness
        act_headers = [h.strip().upper() for h in all_activities[0]]
        
        def find_act_idx(targets: list):
            for i, h in enumerate(act_headers):
                if h in [t.upper() for t in targets]: return i
            return -1

        ts_idx = find_act_idx(["Timestamp"])
        ref_idx = find_act_idx(["ReferralCode", "RefCode"])
        type_idx = find_act_idx(["ActivityType", "Type"])
        pts_idx = find_act_idx(["Points", "Pts"])

        # 3. Build Partner Name Map (RefCode -> Name)
        name_map = {}
        for p in partner_records:
            ref = str(p.get("REFERRAL CODE", "")).strip().lower()
            name = p.get("FULL NAME", p.get("C: FULL NAME", p.get("USERNAME", "Unknown")))
            name_map[ref] = name
            
        # 4. Filter and process logs
        report_rows = []
        for row in all_activities[1:]: # Skip header
             if ts_idx == -1 or len(row) <= ts_idx: continue
             
             ts_str = row[ts_idx]
             if not ts_str: continue
             
             try:
                # Use date_parser for flexibility
                ts = date_parser.parse(ts_str)
                if ts.month == target_month and ts.year == target_year:
                    ref_code = str(row[ref_idx]).strip().lower() if ref_idx != -1 and len(row) > ref_idx else ""
                    type_str = row[type_idx] if type_idx != -1 and len(row) > type_idx else "Unknown"
                    points_str = row[pts_idx] if pts_idx != -1 and len(row) > pts_idx else "0"
                    points = float(str(points_str).replace(",", "").strip() or 0)
                    
                    report_rows.append({
                        "Date": ts.strftime("%Y-%m-%d"),
                        "Event Type": type_str,
                        "Partner Name": name_map.get(ref_code, f"Code: {ref_code}"),
                        "Points Awarded": points,
                        "Revenue Equivalent (Naira NGN)": points * 100
                    })
             except Exception as e:
                print(f"DEBUG: Skipping row due to parse error: {e}")
                continue
                
        # 5. Generate CSV
        output = io.StringIO()
        fieldnames = ["Date", "Event Type", "Partner Name", "Points Awarded", "Revenue Equivalent (Naira NGN)"]
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(report_rows)

        
        csv_content = output.getvalue()
        filename = f"Enchiridion_Report_{month_name}_{target_year}.csv"
        
        return Response(
            content=csv_content.encode("utf-8"),
            media_type="text/csv",
            headers={
                "Content-Disposition": f"attachment; filename={filename}"
            }
        )
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Generation error: {str(e)}")

@router.post("/audit/revert")
async def revert_payout(request: MarkAsPaidRequest, user=Depends(current_active_superuser)):
    """
    Safety feature: Moves Lifetime Earnings back to Points/Revenue and sets status to PENDING.
    """
    try:
        email = request.email.strip().lower()
        records = sheets_client.get_all_records("Partners")
        user_record = None
        row_idx = None
        for i, r in enumerate(records):
            if str(r.get("USERNAME", "")).lower().strip() == email:
                user_record = r
                row_idx = i + 2
                break
        
        if not user_record or not row_idx:
            raise HTTPException(status_code=404, detail="User not found")
            
        # Get values for reversal
        # We use explicit index 18 (Column S) for the last payout amount to avoid "full lifetime reversion"
        # We need to fetch the row values directly to ensure we get Column S even if header is missing
        ws = sheets_client.get_worksheet("Partners")
        row_values = ws.row_values(row_idx)
        
        revert_amount = 0.0
        if len(row_values) > 18:
            revert_amount = safe_float(row_values[18])
            
        if revert_amount <= 0:
             # Fallback to lifetime if S is empty, but warn
             print(f"WARNING: Column S empty for {email}, falling back to lifetime reversion")
             revert_amount = safe_float(user_record.get("LIFETIME EARNINGS", 0.0))
        
        if revert_amount <= 0:
             return {"success": False, "error": "No amount found to revert (Column S and Lifetime are 0)"}
             
        # Calculate restoration
        lifetime = safe_float(user_record.get("LIFETIME EARNINGS", 0.0))
        
        # Integrity Check: Milestone protection (Floor logic)
        # Tier 50 (N2,000) in Column V (Index 21)
        # Tier 100 (N5,000) in Column W (Index 22)
        total_bonus_protection = 0.0
        if len(row_values) > 21 and str(row_values[21]).strip().upper() == "CLAIMED":
            total_bonus_protection += 2000.0
        if len(row_values) > 22 and str(row_values[22]).strip().upper() == "CLAIMED":
            total_bonus_protection += 5000.0
            
        # The Lifetime Earnings should never drop below the total bonus protection
        # We calculate the new lifetime first, ensuring it respects the floor
        new_lifetime = max(total_bonus_protection, lifetime - revert_amount)
        
        # The amount we actually revert back to the partner's balance is the difference
        actual_revert_amount = lifetime - new_lifetime
        
        if total_bonus_protection > 0:
            print(f"DEBUG: Payout revert for {email}. Protection floor: N{total_bonus_protection}. Original revert request: N{revert_amount}. Actual revert: N{actual_revert_amount}.")

        restored_revenue = actual_revert_amount
        restored_points = round(actual_revert_amount / 100.0, 2)
        
        # Atomic update (E:I): E=Points, F=Revenue, G=Lifetime(new), H=Referrals(keep), I=Status(PENDING)
        sheets_client.update_range("Partners", f"E{row_idx}:I{row_idx}", 
                                   [[restored_points, restored_revenue, new_lifetime, user_record.get("TOTAL REFERRALS", 0), "PENDING"]])
                                   
        # Reset Column S to 0 (1-indexed = 19)
        sheets_client.update_cell("Partners", row_idx, 19, 0.0)

                                   
        # Log the revert
        activity_row = [
            datetime.now().isoformat(),
            request.refCode,
            "Payout Reverted",
            -restored_points, # Indicated as a negative correction for points logic if needed
            f"Payout reversed for {email}. Restored N{lifetime}",
            "", # F: Reported status
            "PENDING" # G: New status
        ]
        sheets_client.append_row("ActivityLog", activity_row)
        
        return {
            "success": True,
            "message": f"Payout reverted for {email}",
            "restored_revenue": restored_revenue
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
@router.get("/shipping-rates")
async def get_shipping_rates():
    """Fetch shipping rates and hub status from the 'Delivery Pricing' sheet."""
    try:
        records = sheets_client.get_all_records("Delivery Pricing")
        # Normalize keys to match what frontend expects
        normalized = []
        for r in records:
            # Expected columns: STATE NAME, COST, HUB STATES
            state_name = sheets_client.get_case_insensitive_val(r, "STATE NAME", "STATE", "name", default="")
            cost = safe_float(sheets_client.get_case_insensitive_val(r, "COST", "price", default=0.0))
            is_hub = str(sheets_client.get_case_insensitive_val(r, "HUB STATES", "HUB", "is_hub", default="FALSE")).upper() == "TRUE"
            
            if state_name:
                normalized.append({
                    "name": state_name,
                    "cost": cost,
                    "isHub": is_hub
                })
        return normalized
    except Exception as e:
        print(f"ERROR fetching shipping rates: {e}")
        return []

@router.get("/stats")
async def get_stats(user: UserRead = Depends(current_active_user)):
    # 1. Fetch user record from Partners sheet
    records = sheets_client.get_all_records("Partners")
    target_email = user.email.lower().strip()
    partner_record = None
    
    for record in records:
        record_email = str(record.get("USERNAME", record.get("Email Address", ""))).lower().strip()
        if record_email == target_email:
            partner_record = record
            break
            
    if not partner_record:
        raise HTTPException(status_code=404, detail="Stats not found")

    partner_code = sheets_client.get_case_insensitive_val(partner_record, "REFERRAL CODE", "ReferralCode", default="")
    
    # 2. Fetch Detailed Activity and Milestones
    activity_records = sheets_client.get_all_records("ActivityLog")
    milestone_records = sheets_client.get_all_records("ReferralMilestones")
    
    # 3. Calculate Pending Points (Registration but not verified)
    pending_count = 0
    for act in activity_records:
        if str(act.get("REFERRED_BY", "")).lower().strip() == partner_code.lower().strip():
            status = str(act.get("Payout Status", "")).strip()
            if status == "PENDING_VERIFICATION":
                pending_count += 1
    
    pending_points = round(pending_count * 0.1, 2)

    # 4. Fetch Milestones for this partner
    user_milestones = []
    for m in milestone_records:
        if str(m.get("ReferrerEmail", "")).lower().strip() == target_email:
            user_milestones.append({
                "referee": m.get("RefereeEmail", ""),
                "type": m.get("MilestoneType", ""),
                "points": safe_float(m.get("PointsAwarded", 0)),
                "timestamp": m.get("Timestamp", "")
            })

    # 5. Calculate Network Spread (Tier-2)
    network_spread_count = sum(1 for m in user_milestones if m["type"] == "network_spread")

    # 6. Group by Referee for Progress UI
    referee_map = {}
    # First, add those who have milestones
    for m in user_milestones:
        email = m["referee"]
        if email not in referee_map:
            referee_map[email] = {"email": email, "milestones": [], "is_pending": False}
        referee_map[email]["milestones"].append(m["type"])

    # Second, add those who are pending verification (don't have 'partner' milestone yet)
    for act in activity_records:
        if str(act.get("REFERRED_BY", "")).lower().strip() == partner_code.lower().strip():
            if str(act.get("Payout Status", "")) == "PENDING_VERIFICATION":
                desc = str(act.get("DESCRIPTION", ""))
                email = desc.split(": ")[-1].strip() if ": " in desc else None
                if email and email not in referee_map:
                    referee_map[email] = {"email": email, "milestones": [], "is_pending": True}

    # 7. Aggregate stats
    points = safe_float(sheets_client.get_case_insensitive_val(partner_record, "POINTS", "points", default=0.0))
    revenue = safe_float(sheets_client.get_case_insensitive_val(partner_record, "REVENUE (\u20a6)", "REVENUE", default=0.0))
    total_referrals = int(safe_float(sheets_client.get_case_insensitive_val(partner_record, "TOTAL REFERRALS", default=0.0)))
    lifetime_earnings = safe_float(sheets_client.get_case_insensitive_val(partner_record, "LIFETIME EARNINGS", default=0.0))

    # 8. Legacy Rank Logic
    rank_data = await _get_legacy_rank_data(target_email)

    return {
        "points": points,
        "revenue": revenue,
        "pendingPoints": pending_points,
        "lifetimeEarnings": lifetime_earnings,
        "totalReferrals": total_referrals,
        "referralCode": partner_code,
        "milestones": user_milestones,
        "networkSpreadCount": network_spread_count,
        "refereeProgress": list(referee_map.values()),
        "bankName": partner_record.get("BANK NAME", ""),
        "accountName": partner_record.get("ACCOUNT NAME", ""),
        "accountNumber": partner_record.get("ACCOUNT NUMBER", ""),
        "legacyRank": rank_data["rank"],
        "soulsGuided": rank_data["soulsGuided"],
        "masteryDate": rank_data["masteryDate"]
    }

@router.get("/masters")
async def get_enchiridion_masters():
    """Fetches all users with the 'Master' legacy rank for the gallery."""
    try:
        milestones = sheets_client.get_all_records("ReferralMilestones")
        partners = sheets_client.get_all_records("Partners")
        
        # Count book referrals per user
        book_counts = {}
        attainment_dates = {}
        for m in milestones:
            if str(m.get("MilestoneType", "")).lower().strip() == "book_purchase":
                ref_email = str(m.get("ReferrerEmail", "")).lower().strip()
                book_counts[ref_email] = book_counts.get(ref_email, 0) + 1
                if book_counts[ref_email] == 16:
                    attainment_dates[ref_email] = m.get("Timestamp")
        
        master_emails = [email for email, count in book_counts.items() if count >= 16]
        
        masters_gallery = []
        for p in partners:
            email = str(p.get("USERNAME", "")).lower().strip()
            if email in master_emails:
                name = p.get("FULL NAME", p.get("NAME", "Master"))
                city = p.get("CITY", p.get("LOCATION", "Nigeria"))
                masters_gallery.append({
                    "username": name,
                    "soulsGuided": book_counts[email],
                    "masteryDate": attainment_dates.get(email),
                    "city": city,
                    "avatar": f"https://ui-avatars.com/api/?name={name.replace(' ', '+')}&background=D4AF37&color=fff"
                })
        
        return masters_gallery
    except Exception as e:
        print(f"ERROR fetching masters gallery: {e}")
        return []

@router.post("/update-payout")
async def update_payout(settings: PayoutSettings, user: UserRead = Depends(current_active_user)):
    print(f"DEBUG: Updating payout for {user.email}")
    # Find matching row in Partners sheet by USERNAME (Column 1)
    cell = sheets_client.find_cell("Partners", user.email, column=1)
    if not cell:
        # Fallback to search all records if find_cell fails due to case/formatting
        records = sheets_client.get_all_records("Partners")
        row_idx = None
        for i, r in enumerate(records):
            if str(r.get("USERNAME", "")).lower().strip() == user.email.lower().strip():
                row_idx = i + 2 # 1-indexed + header
                break
        
        if not row_idx:
            raise HTTPException(status_code=404, detail="User record not found in Partners sheet")
    else:
        row_idx = cell.row

    try:
        # Update Columns: J: BANK NAME (10), K: ACCOUNT NAME (11), L: ACCOUNT NUMBER (12)
        sheets_client.update_cell("Partners", row_idx, 10, settings.bankName)
        sheets_client.update_cell("Partners", row_idx, 11, settings.accountName)
        sheets_client.update_cell("Partners", row_idx, 12, settings.accountNumber)

        print(f"DEBUG: Successfully updated payout details for {user.email} at row {row_idx}")
        return {"success": True}
    except Exception as e:
        print(f"DEBUG: Failed to update payout details: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to save payout details: {e}")

@router.get("/leaderboard")
async def get_leaderboard():
    """Returns a sorted list of top referral partners with privacy-filtered names."""
    try:
        print("DEBUG: Leaderboard endpoint called")
        records = sheets_client.get_all_records("Partners")
        print(f"DEBUG: Fetched {len(records)} records for leaderboard")
    except Exception as e:
        print(f"ERROR: Failed to fetch records: {e}")
        return []
    
    def safe_float(val):
        if val is None:
            return 0.0
        # Convert to string and strip spaces, currency symbols, and commas
        s_val = str(val).strip().replace("₦", "").replace(",", "").replace("$", "")
        if s_val == "":
            return 0.0
        try:
            return float(s_val)
        except (ValueError, TypeError):
            return 0.0

    leaderboard_data = []
    for i, record in enumerate(records):
        try:
            if i == 0:
                print(f"DEBUG: First record keys: {list(record.keys())}")
            
            # Flexible matching for common fields
            name_val = sheets_client.get_case_insensitive_val(record, "FULL NAME", "Name", "NAME", "C: FULL NAME")
            
            name = str(name_val).strip() if name_val else "Anonymous Partner"
            
            points_val = sheets_client.get_case_insensitive_val(record, "POINTS", default=0.0)
            revenue_val = sheets_client.get_case_insensitive_val(record, "REVENUE (₦)", "REVENUE", default=0.0)
            
            points = safe_float(points_val)
            revenue = safe_float(revenue_val)
            
            email = str(sheets_client.get_case_insensitive_val(record, "USERNAME", "Email", default="")).lower().strip()
            
            # Ensure they tally based on 1 pt = 100 naira conversion
            if points > 0 and revenue == 0:
                revenue = points * 100
            elif revenue > 0 and points == 0:
                points = revenue / 100

            lifetime_earnings = safe_float(sheets_client.get_case_insensitive_val(record, "LIFETIME_EARNINGS", "LIFETIME EARNINGS", "Lifetime Earnings", default=0.0))

            # Privacy Filter: "B. McLoughlin" instead of "Brendan McLoughlin"
            filtered_name = name
            if name and name != "Anonymous Partner":
                parts = name.split()
                if len(parts) > 1:
                    filtered_name = f"{parts[0][0]}. {' '.join(parts[1:])}"

            leaderboard_data.append({
                "name": filtered_name,
                "points": points,
                "revenue": revenue,
                "lifetimeEarnings": lifetime_earnings,
                "email": email
            })
        except Exception as e:
            print(f"DEBUG: Error processing record {i}: {e}")
            import traceback
            traceback.print_exc()
            continue

    # Sort by points descending
    leaderboard_data.sort(key=lambda x: x["points"], reverse=True)
    print(f"DEBUG: Processed {len(leaderboard_data)} valid records for leaderboard")

    # Assign rank and impact badges
    final_leaderboard = []
    for i, entry in enumerate(leaderboard_data):
        rank = i + 1
        
        # Impact Badge Logic
        impact = "Rising Star"
        if rank == 1: impact = "Elite Partner"
        elif rank <= 3: impact = "Platinum Partner"
        elif rank <= 10: impact = "Gold Partner"
        elif rank <= 25: impact = "Silver Partner"
        
        final_leaderboard.append({
            "rank": rank,
            "name": entry["name"],
            "points": entry["points"],
            "revenue": entry["revenue"],
            "lifetimeEarnings": entry["lifetimeEarnings"],
            "impact": impact,
            "email": entry["email"]
        })

    return final_leaderboard[:50] # Return top 50

class MilestoneRequest(BaseModel):
    refCode: str
    tier: int # 50 or 100

@router.post("/apply-milestone")
async def apply_milestone(request: MilestoneRequest, user: UserRead = Depends(current_active_user)):
    """Applies high-value tier bonuses (₦2,000 for 50, ₦5,000 for 100)."""
    try:
        tier = request.tier
        if tier not in [50, 100]:
            raise HTTPException(status_code=400, detail="Invalid milestone tier. Must be 50 or 100.")

        bonus_amount = 2000.0 if tier == 50 else 5000.0
        bonus_type = "Power Partner Achievement" if tier == 50 else "Elite Ambassador Achievement"
        
        # 1. Find user in Partners sheet
        records = sheets_client.get_all_records("Partners")
        partner_row_idx = None
        partner_record = None
        for i, record in enumerate(records):
            # Match using case-insensitive email/username
            record_email = str(record.get("USERNAME", record.get("Email Address", ""))).lower().strip()
            if record_email == user.email.lower().strip():
                partner_record = record
                partner_row_idx = i + 2
                break
        
        if not partner_record:
            raise HTTPException(status_code=404, detail="Partner not found in records")

        # 2. Check current referrals to verify eligibility
        # Helper to get case-insensitive total referrals
        def get_case_insensitive_val(rec, *keys, default=0):
            for k in keys:
                if k in rec: return rec[k]
            return default

        total_refs_val = get_case_insensitive_val(partner_record, "TOTAL REFERRALS", "Total Referrals", "TOTAL_REFERRALS")
        actual_referrals = int(float(str(total_refs_val or 0)))
        
        if actual_referrals < tier:
            raise HTTPException(status_code=400, detail=f"Ineligible for tier {tier}. Current referrals: {actual_referrals}")

        # 3. Check Audit Logs for Idempotency (Prevent double-crediting)
        activity_type = "ELITE STATUS UNLOCKED" if tier == 100 else bonus_type
        try:
            audit_ws = sheets_client.sheet.worksheet("Admin Audit")
            # Use get_all_records which handles headers/formatting
            audit_records = sheets_client.get_all_records("Admin Audit")
            duplicate = False
            for audit in audit_records:
                if str(audit.get("Details", "")).find(f"{user.email}") != -1 and \
                   (str(audit.get("Activity", "")).find(activity_type) != -1 or 
                    str(audit.get("Activity", "")).find(bonus_type) != -1):
                    duplicate = True
                    break
            
            if duplicate:
                return {"success": True, "message": "Bonus already applied.", "already_applied": True}
        except Exception as e:
            print(f"DEBUG: Idempotency check error: {e}")
            pass

        # 4. Update Balance
        current_points = safe_float(partner_record.get("POINTS", 0.0))
        current_revenue = safe_float(get_case_insensitive(partner_record, "REVENUE (₦)", "Revenue", default=0.0))
        
        new_points = round(current_points + (bonus_amount / 100.0), 2)
        new_revenue = round(current_revenue + bonus_amount, 2)
        
        # Update sheet (Col E, F) and Status (Col I)
        sheets_client.update_range("Partners", f"E{partner_row_idx}:F{partner_row_idx}", [[new_points, new_revenue]])
        
        # Try to find 'Payout Status' column
        sheets_client.update_cell("Partners", partner_row_idx, 9, "PENDING") # Column I is usually Status

        if tier == 50:
            # Update Milestone 1 status logic (Column V / Index 22)
            sheets_client.update_cell("Partners", partner_row_idx, 22, "CLAIMED")
        elif tier == 100:
            # Update Milestone 2 status logic (Column W / Index 23)
            sheets_client.update_cell("Partners", partner_row_idx, 23, "CLAIMED")

        # 5. Log in Admin Audit
        from datetime import datetime
        activity_type = f"ELITE STATUS UNLOCKED" if tier == 100 else bonus_type
        details = f"User: {user.email}. Bonus: {bonus_amount}"
        if tier == 100:
             # Standardized elite log format
             details = f"ELITE STATUS UNLOCKED: {user.email} reached 100 referrals"
             
        log_row = [
            datetime.now().isoformat(),
            activity_type,
            details,
            "SUCCESS",
            f"Tier {tier} Milestone fulfilled."
        ]
        sheets_client.append_row("Admin Audit", log_row)

        return {"success": True, "bonus": bonus_amount, "new_total": new_revenue}

    except Exception as e:
        safe_err = str(e).encode('ascii', 'ignore').decode('ascii')
        print(f"ERROR applying milestone: {safe_err}")
        raise HTTPException(status_code=500, detail=str(e))
@router.post("/distributor-lead")
async def process_distributor_lead(
    lead: DistributorLead, 
    background_tasks: BackgroundTasks,
    user: Optional[UserRead] = Depends(current_active_user)
):
    """
    Captures a distributor lead and saves it to the 'Distributor Leads' sheet.
    Also updates UserOnboarding progress and triggers referral rewards.
    """
    timestamp = lead.timestamp or datetime.now().isoformat()
    
    # NEW: Fallback to authenticated user's refCode if missing
    effective_ref_code = lead.refCode
    if not effective_ref_code and user:
        effective_ref_code = user.referral_code
        print(f"DEBUG: Using authenticated user refCode: {effective_ref_code}")

    # row format: Timestamp, Name, Phone Number, Whatsapp Number, Location, RefCode
    row = [timestamp, lead.name, lead.phone, lead.whatsapp, lead.location, effective_ref_code or ""]
    
    # Ensure worksheet has headers if it's new or misaligned
    sheets_client.get_or_create_worksheet("Distributor Leads", ["Timestamp", "Name", "Phone Number", "Whatsapp Number", "Location", "RefCode"])
    
    background_tasks.add_task(sheets_client.append_row, "Distributor Leads", row)
    
    # NEW: Sync status and awards in background
    if effective_ref_code:
        background_tasks.add_task(_sync_distributor_status, effective_ref_code, lead.name)
        
    return {"success": True}

async def _sync_distributor_status(ref_code: str, name: str):
    """
    Finds the user email for a ref code and marks 'IsDistributor' as TRUE.
    Award rewards to their Referrer.
    """
    print(f"DEBUG: Starting distributor status sync for refCode: {ref_code}")
    try:
        # 1. Resolve Email from RefCode via Partners sheet
        records = sheets_client.get_all_records("Partners")
        target_email = None
        for r in records:
            r_code = sheets_client.get_case_insensitive_val(r, "REFERRAL CODE", "ReferralCode", "referral_code")
            if str(r_code or "").strip().lower() == ref_code.strip().lower():
                target_email = str(r.get("USERNAME", "")).lower().strip()
                break
        
        if not target_email:
            print(f"WARNING: Could not resolve email for refCode {ref_code} during distributor sync. Records checked: {len(records)}")
            return

        print(f"DEBUG: Resolved email {target_email} for refCode {ref_code}. Checking UserOnboarding...")

        # 2. Update UserOnboarding
        o_records = sheets_client.get_all_records("UserOnboarding")
        row_idx = None
        for i, r in enumerate(o_records):
            if str(r.get("Email", "")).lower().strip() == target_email:
                row_idx = i + 2
                current_val = str(r.get("IsDistributor", "FALSE")).upper()
                print(f"DEBUG: Found onboarding row {row_idx} for {target_email}. Current IsDistributor: {current_val}")
                if current_val == "TRUE":
                    print(f"DEBUG: Distributor status already TRUE for {target_email}")
                    return # Already done
                break
        
        if row_idx:
            print(f"DEBUG: Updating UserOnboarding row {row_idx} column 4 for {target_email}...")
            sheets_client.update_cell("UserOnboarding", row_idx, 4, "TRUE")
            sheets_client.update_cell("UserOnboarding", row_idx, 6, datetime.now().isoformat())
            
            # Ensure ReferralMilestones sheet exists
            sheets_client.get_or_create_worksheet("ReferralMilestones", ["Timestamp", "ReferrerEmail", "RefereeEmail", "MilestoneType", "PointsAwarded", "UniqueKey"])
            
            # 3. Award Referrer
            print(f"DEBUG: Triggering onboarding reward for {target_email} (distributor)...")
            await _trigger_onboarding_reward(target_email, "distributor")
            print(f"DEBUG: Sync completed successfully for {target_email}")
        else:
            print(f"WARNING: No onboarding row found for {target_email} (Checked {len(o_records)} records)")
            
    except Exception as e:
        print(f"ERROR: Sync distributor status failed for {ref_code}: {e}")
        import traceback
        traceback.print_exc()
