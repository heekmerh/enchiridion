import gspread
from google.oauth2.service_account import Credentials
import os
from dotenv import load_dotenv

# Load .env
env_path = os.path.join("backend", ".env")
load_dotenv(env_path)

creds_file = os.getenv("GOOGLE_SHEETS_CREDS_FILE")
spreadsheet_id = os.getenv("GOOGLE_SHEETS_ID")

def inspect_pricing():
    scopes = [
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive"
    ]
    creds = Credentials.from_service_account_file(creds_file, scopes=scopes)
    client = gspread.authorize(creds)
    spreadsheet = client.open_by_key(spreadsheet_id)
    ws = spreadsheet.worksheet("Delivery Pricing")
    
    records = ws.get_all_records()
    print(f"Records from 'Delivery Pricing' ({len(records)} found):")
    if records:
        print("Headers:", list(records[0].keys()))
        for record in records:
            print(record)

if __name__ == "__main__":
    inspect_pricing()
