import sys
import os
import uuid
from datetime import datetime
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from app.sheets import sheets_client

def simulate_registration():
    print("--- Simulating Registration Logic ---")
    user_dict = {
        "email": f"sim_user_{uuid.uuid4().hex[:6]}@example.com",
        "hashed_password": "sim_hashed_password",
        "name": "Simulated User",
        "referral_code": "SIM" + uuid.uuid4().hex[:4].upper(),
        "is_active": True,
        "is_superuser": False,
        "is_verified": False
    }
    
    now = datetime.now()
    row = [
        user_dict["email"],             # A: USERNAME
        user_dict["hashed_password"],  # B: PASSWORD
        user_dict.get("name", ""),      # C: FULL NAME
        user_dict.get("referral_code", ""), # D: REFERRAL CODE
        0.0,                            # E: POINTS
        0.0,                            # F: REVENUE
        0.0,                            # G: LIFETIME EARNINGS
        0,                              # H: TOTAL REFERRALS
        "PENDING",                       # I: PAYOUT STATUS
        user_dict.get("bank_name", ""), # J: BANK NAME
        user_dict.get("account_name", ""), # K: ACCOUNT NAME
        user_dict.get("account_number", ""), # L: ACCOUNT NUMBER
        user_dict.get("referred_by", ""),# M: REFERRED_BY
        user_dict.get("ip", ""),         # N: REGISTRATION_IP
        now.isoformat(),                 # O: DATE_JOINED
        "FALSE",                         # P: is_superuser
        "TRUE",                          # Q: is_active
        "FALSE"                          # R: is_verified
    ]
    
    print(f"Row to append (Length {len(row)}): {row}")
    try:
        sheets_client.append_row("Partners", row)
        print("Successfully appended. Now checking where it landed...")
        
        ws = sheets_client.get_worksheet("Partners")
        all_values = ws.get_all_values()
        last_row = all_values[-1]
        
        print("\nResulting Row Values:")
        for i, val in enumerate(last_row):
            if val:
                print(f"  Col {i+1}: {val}")
                
    except Exception as e:
        print(f"Error during simulation: {e}")

if __name__ == "__main__":
    simulate_registration()
