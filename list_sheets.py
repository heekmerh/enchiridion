import gspread
from google.oauth2.service_account import Credentials
import os
from dotenv import load_dotenv

# Load .env
env_path = os.path.join("backend", ".env")
load_dotenv(env_path)

creds_file = os.getenv("GOOGLE_SHEETS_CREDS_FILE")
spreadsheet_id = os.getenv("GOOGLE_SHEETS_ID")

def list_worksheets():
    if not creds_file or not os.path.exists(creds_file):
        print(f"Error: Credentials file not found at {creds_file}")
        return

    scopes = [
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive"
    ]
    creds = Credentials.from_service_account_file(creds_file, scopes=scopes)
    client = gspread.authorize(creds)
    
    print(f"Opening spreadsheet: {spreadsheet_id}")
    spreadsheet = client.open_by_key(spreadsheet_id)
    worksheets = spreadsheet.worksheets()
    
    print("\nWorksheets found:")
    for ws in worksheets:
        print(f"- {ws.title}")

if __name__ == "__main__":
    list_worksheets()
