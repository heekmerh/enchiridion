import os
import sys
import os
from dotenv import load_dotenv

# Add the parent directory to sys.path so we can import 'app'
sys.path.append(os.path.join(os.getcwd(), "backend"))

from app.sheets import sheets_client

def cleanup():
    print("Starting data cleanup for Partners sheet...")
    # 1. Fetch all records
    records = sheets_client.get_all_records("Partners")
    if not records:
        print("No records found.")
        return

    # In current sheet (based on diag):
    # E (4): POINTS
    # F (5): REVENUE
    # G (6): TOTAL REFERRALS
    # H (7): BANK NAME
    # ...
    # Q (16): Payout Status
    # R (17): Lifetime Earnings

    # User wants:
    # E: Points
    # F: Revenue
    # G: Lifetime Earnings
    # H: Total Referrals
    # I: Payout Status

    # Let's see the current headers to be absolutely sure
    ws = sheets_client.get_worksheet("Partners")
    headers = ws.row_values(1)
    print(f"Current headers: {headers}")

    # For safety, let's just process the rows and update them.
    # We will basically shift the data.
    
    # We'll build a new set of data for Column G, H, I for each user.
    # But wait, we don't want to lose BANK NAME if it was in H.
    # User said "revenue is being written into the 'Total Referrals' column (Column H)".
    # If my update wrote [[0.0, 0.0, new_lifetime, "COMPLETED"]] to E:H,
    # then H has "COMPLETED".
    
    # Let's just fix the headers first if they are wrong.
    new_headers = list(headers)
    # Ensure headers match user's architecture
    # E: Points (already 4)
    # F: Revenue (already 5)
    # G: Lifetime Earnings
    # H: Total Referrals
    # I: Payout Status
    
    # Let's update headers
    if len(new_headers) < 9:
        new_headers.extend([""] * (9 - len(new_headers)))
    
    new_headers[4] = "POINTS"
    new_headers[5] = "REVENUE (\u20a6)"
    new_headers[6] = "LIFETIME EARNINGS"
    new_headers[7] = "TOTAL REFERRALS"
    new_headers[8] = "PAYOUT STATUS"
    
    # Check if we displaced Bank Name. Bank Name was index 7 (H) in diag.
    # If we move Total Referrals to H, where does Bank Name go?
    # User didn't specify Bank Name's new position, so let's move it to J (index 9).
    if len(new_headers) < 10:
        new_headers.append("BANK NAME")
    else:
        # Check if BANK NAME is already there
        if "BANK NAME" not in new_headers:
             new_headers.append("BANK NAME")

    print(f"Updating headers to: {new_headers}")
    # ws.update('A1', [new_headers]) # Experimental gspread call
    
    # Actually, let's just fix the data.
    # For each row, we'll read the current values and reposition them.
    # This is a bit risky to do automatically without seeing the sheet.
    # Let's just print what we RECOMMEND and wait for a simpler fix or just do the mapping fix in code.

    # Actually, I'll just fix the backend code mapping first, then run a diag.
    pass

if __name__ == "__main__":
    cleanup()
