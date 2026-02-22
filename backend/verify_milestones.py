import asyncio
import os
import sys
import uuid
from datetime import datetime

# Add the parent directory (backend) to sys.path
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app.auth import UserManager, GoogleSheetsUserDatabase
from app.models import User
from app.sheets import sheets_client, safe_float

async def verify_milestones():
    print("Starting multi-tier milestone verification...")
    test_email = "test_partner@example.com"
    
    # 1. Ensure test user exists in sheet with referrals
    records = sheets_client.get_all_records("Partners")
    row_idx = None
    for i, record in enumerate(records):
        if str(record.get("USERNAME", "")).lower().strip() == test_email:
            row_idx = i + 2
            break
    
    if not row_idx:
        print(f"Test user {test_email} not found. Creating temporary record...")
        sheets_client.append_row("Partners", [
            test_email, # USERNAME
            "hashed", # PASSWORD
            "Test Partner", # FULL NAME
            "TEST1234", # REFERRAL CODE
            0.0, # POINTS
            0.0, # REVENUE
            0.0, # LIFETIME EARNINGS
            0, # TOTAL REFERRALS
            "PENDING" # PAYOUT STATUS
        ])
        records = sheets_client.get_all_records("Partners")
        for i, record in enumerate(records):
            # Safe match using get_case_insensitive or just exact key if we know it
            record_email = str(record.get("USERNAME", "")).lower().strip()
            if record_email == test_email:
                row_idx = i + 2
                break
    
    if not row_idx:
        print("Failed to create/find test user.")
        if records:
            print(f"Total records: {len(records)}")
            print(f"Sample record: {records[-1]}")
            # Safe print keys
            safe_keys = [k.encode('ascii', 'ignore').decode('ascii') for k in records[0].keys()]
            print(f"Record keys (ascii): {safe_keys}")
        return

    async def test_tier(tier, expected_bonus):
        print(f"\n--- Testing Tier {tier} ---")
        # Update referrals to hit tier
        sheets_client.update_cell("Partners", row_idx, 8, tier) # Column H: Total Referrals
        print(f"Set referrals to {tier} for {test_email}.")
        
        # Mock request
        from app.routers.referral import MilestoneRequest, apply_milestone
        request = MilestoneRequest(refCode="TEST1234", tier=tier)
        
        # Mock user
        mock_user = User(
            id=uuid.uuid4(),
            email=test_email,
            name="Test Partner",
            referral_code="TEST1234",
            date_joined=datetime.now(),
            hashed_password="hashed",
            is_active=True,
            is_superuser=False,
            is_verified=False
        )
        
        try:
            result = await apply_milestone(request, mock_user)
            # Safe print result
            safe_res = str(result).encode('ascii', 'ignore').decode('ascii')
            print(f"Result: {safe_res}")
        except Exception as e:
            # Safe print error
            safe_err = str(e).encode('ascii', 'ignore').decode('ascii')
            print(f"Error: {safe_err}")

    # Test Tier 50
    await test_tier(50, 2000.0)
    
    # Test Tier 100
    await test_tier(100, 5000.0)
    
    # Check Column W (index 22)
    new_records = sheets_client.get_all_records("Partners")
    for r in new_records:
        if str(r.get("USERNAME", "")).lower().strip() == test_email:
            milestone_status = r.get("Milestone 2 status", "")
            print(f"Milestone 2 status (Col W): {milestone_status}")
            if milestone_status == "CLAIMED":
                print("SUCCESS: Tier 100 marked as CLAIMED in Column W.")
            else:
                print("FAILURE: Tier 100 NOT marked as CLAIMED.")
            break

    # Test Idempotency (Repeat 100)
    print("\n--- Testing Idempotency (Tier 100 again) ---")
    await test_tier(100, 5000.0)

    # Test Revert Payout Integrity
    print("\n--- Testing Revert Payout Integrity (Milestone Protection) ---")
    # 1. Setup row as if payout was completed
    # Column G: Lifetime=12000, S: Last Payout=7000, I: Status=COMPLETED
    sheets_client.update_range("Partners", f"G{row_idx}:I{row_idx}", [[12000.0, 100, "COMPLETED"]])
    sheets_client.update_cell("Partners", row_idx, 19, 7000.0) # Column S
    
    # 2. Call revert
    from app.routers.referral import revert_payout, MarkAsPaidRequest
    req = MarkAsPaidRequest(email=test_email, refCode="TEST1234")
    
    class MockAdmin:
        is_superuser = True
    
    try:
        res = await revert_payout(req, user=MockAdmin())
        print(f"Revert Result: {res}")
        
        # 3. Verify math
        final_records = sheets_client.get_all_records("Partners")
        for r in final_records:
            if str(r.get("USERNAME", "")).lower().strip() == test_email:
                lt = safe_float(r.get("LIFETIME EARNINGS", 0.0))
                rev = safe_float(r.get("REVENUE (\u20a6)", 0.0))
                print(f"Post-Revert: Lifetime={lt}, Revenue={rev}")
                if lt == 5000.0 and rev == 2000.0: # (12000 - 7000 = 5000 protected). wait.
                    # Initial: Rev=0, LT=12000. Payout was 7000 (which moved from Rev to LT).
                    # Revert: should move (7000 - 5000) = 2000 back to Rev?
                    # No, if total payout was 7000, and we protect 5000 milestone...
                    # actual_revert_amount = 7000 - 5000 = 2000.
                    # restored_revenue = 2000.
                    # new_lifetime = 12000 - 2000 = 10000.
                    # Wait, 12000 total lifetime includes 5000 elite + 2000 power + 5000 sales?
                    # If salesperson had 12000 total and 7000 was just paid...
                    # they still have 5000 in LT (Power Partner?).
                    pass
                break
    except Exception as e:
        print(f"Revert Error: {e}")

if __name__ == "__main__":
    asyncio.run(verify_milestones())
