import os
import sys

# Add backend directory to sys.path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from dotenv import load_dotenv
from app.sheets import GoogleSheetsClient

load_dotenv(dotenv_path="backend/.env")

client = GoogleSheetsClient()

print("Updating headers for 'Partners'...")
ws = client.get_worksheet("Partners")
if ws:
    # Target headers (A to AB)
    target_headers = [
        "USERNAME", "PASSWORD", "FULL NAME", "REFERRAL CODE", 
        "POINTS", "REVENUE (₦)", "LIFETIME EARNINGS", "TOTAL REFERRALS", 
        "PAYOUT STATUS", "BANK NAME", "ACCOUNT NAME", "ACCOUNT NUMBER", 
        "REFERRED_BY", "REGISTRATION_IP", "DATE_JOINED", 
        "is_superuser", "is_active", "is_verified",
        "last payout amount", "EMPTY_19", "EMPTY_20", "Milestone 1 status", "Milestone 2 status",
        "STATE", "COUNTRY", "PROFESSION", "PHONE", "INSTITUTION"
    ]
    
    print(f"Ensuring headers are correct up to column AB (Total {len(target_headers)} columns).")
    client.update_range("Partners", "A1:AB1", [target_headers])
    print("Headers updated successfully.")
else:
    print("Could not find 'Partners' worksheet.")
