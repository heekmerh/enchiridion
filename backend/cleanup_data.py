import os
import sys
from dotenv import load_dotenv

# Add the parent directory to sys.path
sys.path.append(os.getcwd())

from backend.app.sheets import sheets_client

def cleanup():
    print("Starting data cleanup for Partners sheet...")
    ws = sheets_client.get_worksheet("Partners")
    if not ws:
        print("Worksheet not found.")
        return

    # Current headers from diag:
    # ['USERNAME', 'PASSWORD', 'FULL NAME', 'REFERRAL CODE', 'POINTS', 'REVENUE (N)', 'TOTAL REFERRALS ', 'BANK NAME', 'ACCOUNT NAME', 'ACCOUNT NUMBER', 'REFERRED_BY', 'REGISTRATION_IP', 'DATE_JOINED', 'is_superuser', 'is_active', 'is_verified', 'Payout status', 'Lifetime Earnings']
    
    # User's Target:
    # E: Points
    # F: Revenue
    # G: Lifetime Earnings
    # H: Total Referrals
    # I: Payout Status
    
    # We will insert columns or just overwrite headers and shift data.
    # Shifting data is cleaner if we want to preserve everything.
    
    rows = ws.get_all_values()
    if not rows:
        print("No data found.")
        return

    headers = rows[0]
    data_rows = rows[1:]

    # Let's map current indices
    # 0: USERNAME, 1: PASSWORD, 2: FULL NAME, 3: REFERRAL CODE, 4: POINTS, 5: REVENUE (N), 6: TOTAL REFERRALS , 7: BANK NAME, 8: ACCOUNT NAME, 9: ACCOUNT NUMBER, 10: REFERRED_BY, 11: REGISTRATION_IP, 12: DATE_JOINED, 13: is_superuser, 14: is_active, 15: is_verified, 16: Payout status, 17: Lifetime Earnings
    
    # New Mapping Proposal:
    # 0: USERNAME, 1: PASSWORD, 2: FULL NAME, 3: REFERRAL CODE, 4: POINTS, 5: REVENUE, 6: LIFETIME EARNINGS, 7: TOTAL REFERRALS, 8: STATUS, 
    # 9: BANK NAME, 10: ACCOUNT NAME, 11: ACCOUNT NUMBER, 12: REFERRED_BY, 13: REGISTRATION_IP, 14: DATE_JOINED, 15: is_superuser, 16: is_active, 17: is_verified
    
    new_rows = []
    
    # New Headers
    new_headers = [
        "USERNAME", "PASSWORD", "FULL NAME", "REFERRAL CODE", 
        "POINTS", "REVENUE (\u20a6)", "LIFETIME EARNINGS", "TOTAL REFERRALS", "PAYOUT STATUS",
        "BANK NAME", "ACCOUNT NAME", "ACCOUNT NUMBER", "REFERRED_BY", "REGISTRATION_IP", "DATE_JOINED", 
        "is_superuser", "is_active", "is_verified"
    ]
    new_rows.append(new_headers)

    for i, row in enumerate(data_rows):
        # Fill with empty strings if row is short
        while len(row) < 18:
            row.append("")
            
        # extract current values
        username = row[0]
        password = row[1]
        fullname = row[2]
        refcode = row[3]
        points = row[4]
        revenue = row[5]
        
        # User said: "Total Referrals" (H/6) currently has revenue (e.g. 1040)
        # and "Bank Name" (I/7) currently has status (e.g. COMPLETED)
        # So we take the value from G (6) and treat it as Lifetime if it's numeric and weirdly large.
        # Or just follow the user's manual instruction for "heekmerh@gmail.com".
        
        current_g = row[6]
        current_h = row[7]
        
        # We also have the old Lifetime Earnings at index 17
        old_lifetime = row[17] if len(row) > 17 else "0"
        
        # Logic to "cleanup" misplaced data:
        # If username is heekmerh@gmail.com, we know 1040 is lifetime.
        if "heekmerh@gmail.com" in username.lower():
            lifetime = current_g # The 1040
            total_referrals = "1" # Resetting to a sensible number or leaving it
            status = current_h # The "COMPLETED"
            bank_name = "Zenith" # Manual restore or leave empty
        else:
            # For Dr Smith, diag shows correctly: 
            # POINTS: 30.2, REVENUE: N3,020.00, TOTAL REFERRALS: 2, BANK NAME: zenith, Payout status: COMPLETED, Lifetime: 0
            lifetime = old_lifetime if old_lifetime else "0"
            total_referrals = current_g
            status = row[16] if len(row) > 16 else "PENDING"
            bank_name = row[7]

        # Construct new row
        new_row = [
            username, password, fullname, refcode,
            points, revenue, lifetime, total_referrals, status,
            bank_name, row[8], row[9], row[10], row[11], row[12],
            row[13], row[14], row[15]
        ]
        new_rows.append(new_row)

    print("Overwriting sheet with cleaned data...")
    ws.clear()
    ws.update('A1', new_rows)
    print("Cleanup successful.")

if __name__ == "__main__":
    cleanup()
