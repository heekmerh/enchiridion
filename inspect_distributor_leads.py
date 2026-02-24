import os
import sys
import json

# Add backend directory to sys.path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from dotenv import load_dotenv
from app.sheets import GoogleSheetsClient

load_dotenv(dotenv_path="backend/.env")

client = GoogleSheetsClient()

def inspect_distributor_leads():
    sheet_name = "Distributor Leads"
    print(f"Inspecting '{sheet_name}'...")
    ws = client.get_worksheet(sheet_name)
    if ws:
        headers = ws.row_values(1)
        print("Headers:", headers)
        records = ws.get_all_records()
        print(f"Found {len(records)} existing records.")
        if records:
            print("Sample record:", json.dumps(records[0], indent=2))
    else:
        print(f"Worksheet '{sheet_name}' not found.")
        # Try case variations
        for s in client._sheet.worksheets():
            if "distributor" in s.title.lower():
                print(f"Possible match found: '{s.title}'")

if __name__ == "__main__":
    inspect_distributor_leads()
