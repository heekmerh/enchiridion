from fastapi import APIRouter, Depends, HTTPException, Request, Response
from typing import Optional, List
from pydantic import BaseModel
from ..models import ActivityLog, PayoutSettings, SessionTrack, MarkAsPaidRequest, UserRead
from ..sheets import sheets_client, safe_float
from ..auth import current_active_user, current_active_superuser, UserRead
from datetime import datetime, timedelta
import csv
import io
from dateutil import parser as date_parser

router = APIRouter()

@router.post("/log-activity")
async def log_activity(activity: ActivityLog):
    row = [
        activity.timestamp,
        activity.refCode,
        activity.type,
        activity.points,
        activity.details.get("url", ""),
        "", # F: REPORTED Status (For Apps Script)
        activity.payoutStatus # G: Payout Status
    ]
    sheets_client.append_row("ActivityLog", row)
    return {"success": True}

@router.post("/track-visit")
async def track_visit(track: SessionTrack, request: Request, response: Response):
    """Tracks a unique visit and credits the referrer with 0.1 points."""
    # Check for unique session cookie
    unique_cookie = request.cookies.get("ench_unique_visit")
    
    if unique_cookie:
        return {"status": "already_tracked"}

    # Credit Referrer (0.1 Points)
    records = sheets_client.get_all_records("Partners")
    referrer_row_idx = None
    referrer_record = None
    
    for i, record in enumerate(records):
        if str(record.get("REFERRAL CODE", "")).strip().lower() == track.refCode.strip().lower():
            referrer_record = record
            referrer_row_idx = i + 2 # 1-indexed + header
            break
            
    if referrer_record:
        # Fraud Prevention: Self-referral check (IP)
        # Note: In a real environment, you'd use a more robust IP check
        referrer_ip = referrer_record.get("LAST_IP", "")
        if referrer_ip == track.ip:
            return {"status": "self_referral_blocked"}

        try:
            current_points = float(referrer_record.get("POINTS", 0.0))
            new_points = round(current_points + 0.1, 2)
            new_revenue = round(new_points * 100, 2)
            
            # Atomic update of columns E (Points), F (Revenue)
            # And reset status to PENDING in Column I (9th col)
            sheets_client.update_range("Partners", f"E{referrer_row_idx}:F{referrer_row_idx}", [[new_points, new_revenue]])
            sheets_client.update_cell("Partners", referrer_row_idx, 9, "PENDING")

            
            # Log Activity
            activity_row = [
                datetime.now().isoformat(),
                track.refCode,
                "Browsing",
                0.1,
                f"Referral visit from IP: {track.ip}",
                "", # F: REPORTED Status
                "PENDING" # G: Payout Status
            ]
            sheets_client.append_row("ActivityLog", activity_row)
            
            # Set 30-day cookie
            response.set_cookie(
                key="ench_unique_visit",
                value="true",
                max_age=30 * 24 * 60 * 60, # 30 days
                httponly=True,
                samesite="lax"
            )
            
            return {"status": "success", "points": 0.1}
        except Exception as e:
            print(f"ERROR: Failed to credit visit: {e}")
            raise HTTPException(status_code=500, detail="Failed to credit visit")
            
    return {"status": "referrer_not_found"}

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
            "Registration (Mock)",
            0.1,
            f"Mock signup: {email}",
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

@router.post("/credit-purchase")
async def credit_purchase(purchase: PurchaseCredit):
    """Credits 5.0 points (₦500) to the referring partner."""
    refCode = purchase.refCode
    records = sheets_client.get_all_records("Partners")
    referrer_row_idx = None
    referrer_record = None
    
    for i, record in enumerate(records):
        if str(record.get("REFERRAL CODE", "")).strip().lower() == refCode.strip().lower():
            referrer_record = record
            referrer_row_idx = i + 2
            break
            
    if referrer_record:
        try:
            current_points = float(referrer_record.get("POINTS", 0.0))
            new_points = round(current_points + 5.0, 2)
            new_revenue = round(new_points * 100, 2)
            
            # Atomic update of columns E (Points) and F (Revenue)
            # And reset status to PENDING in Column I (9th col)
            sheets_client.update_range("Partners", f"E{referrer_row_idx}:F{referrer_row_idx}", [[new_points, new_revenue]])
            sheets_client.update_cell("Partners", referrer_row_idx, 9, "PENDING")

            
            # Log Activity
            activity_row = [
                datetime.now().isoformat(),
                refCode,
                "Purchase",
                5.0,
                "Book Sale Referral",
                "", # F: REPORTED Status
                "PENDING" # G: Payout Status
            ]
            sheets_client.append_row("ActivityLog", activity_row)
            
            return {"success": True, "points_added": 5.0}
        except Exception as e:
            print(f"ERROR: Failed to credit purchase: {e}")
            raise HTTPException(status_code=500, detail="Failed to credit purchase")
            
    raise HTTPException(status_code=404, detail="Referrer not found")

def get_case_insensitive(record: dict, *keys: str, default=0.0):
    """Safely gets a value from a record using a list of potential keys (case-insensitive)."""
    normalized_record = {str(k).strip().lower(): v for k, v in record.items()}
    for key in keys:
        norm_key = str(key).strip().lower()
        if norm_key in normalized_record:
            return normalized_record[norm_key]
    return default


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
            
        # 2. Extract current earnings and lifetime earnings using robust safe_float
        current_points = safe_float(get_case_insensitive(partner_record, "POINTS", "Points", default=0.0))
        current_revenue = safe_float(get_case_insensitive(partner_record, "REVENUE (\u20a6)", "REVENUE", "Revenue", default=0.0))

        
        # 3. Extract lifetime earnings using robust safe_float
        lifetime_earnings = safe_float(get_case_insensitive(partner_record, "LIFETIME_EARNINGS", "LIFETIME EARNINGS", "Lifetime Earnings", default=0.0))
        
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
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/stats")
async def get_stats(user: UserRead = Depends(current_active_user)):
    # Fetch user stats from Partners sheet
    records = sheets_client.get_all_records("Partners")
    target_email = user.email.lower().strip()
    for record in records:
        # Match using case-insensitive email/username
        record_email = str(record.get("USERNAME", record.get("Email Address", ""))).lower().strip()
        if record_email == target_email:
            # Extract stats using robust safe_float
            points = safe_float(record.get("POINTS", 0.0))
            revenue = safe_float(record.get("REVENUE (\u20a6)", record.get("Revenue", 0.0)))
            total_referrals = int(safe_float(record.get("TOTAL REFERRALS", 0.0)))

            # Ensure they tally based on 1 pt = 100 naira conversion if one is zero
            if points > 0 and revenue == 0:
                revenue = points * 100
            elif revenue > 0 and points == 0:
                points = revenue / 100
                
            # Extract lifetime earnings using robust safe_float
            lifetime_earnings = safe_float(get_case_insensitive(record, "LIFETIME EARNINGS", "LIFETIME_EARNINGS", default=0.0))

            return {
                "points": points,
                "revenue": revenue,
                "lifetimeEarnings": lifetime_earnings,
                "totalReferrals": total_referrals,
                "referralCode": record.get("REFERRAL CODE", record.get("ReferralCode", "")),
                "bankName": record.get("BANK NAME", ""),
                "accountName": record.get("ACCOUNT NAME", ""),
                "accountNumber": record.get("ACCOUNT NUMBER", "")
            }




    raise HTTPException(status_code=404, detail="Stats not found")

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
    for record in records:
        try:
            # Flexible matching for common fields
            name_val = get_case_insensitive(record, "FULL NAME", "Name", "C: FULL NAME")
            
            name = str(name_val).strip() if name_val else "Anonymous Partner"
            
            points = safe_float(get_case_insensitive(record, "POINTS", default=0.0))
            revenue = safe_float(get_case_insensitive(record, "REVENUE (₦)", "Revenue", default=0.0))
            
            email = str(get_case_insensitive(record, "USERNAME", "Email", default="")).lower().strip()
            
            # Ensure they tally based on 1 pt = 100 naira conversion
            if points > 0 and revenue == 0:
                revenue = points * 100
            elif revenue > 0 and points == 0:
                points = revenue / 100

            lifetime_earnings = safe_float(get_case_insensitive(record, "LIFETIME_EARNINGS", "LIFETIME EARNINGS", "Lifetime Earnings", default=0.0))

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
            print(f"DEBUG: Error processing record: {e}")
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
