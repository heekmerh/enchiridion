import os
import sys
import json

# Add backend directory to sys.path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from dotenv import load_dotenv
from app.sheets import GoogleSheetsClient

load_dotenv(dotenv_path="backend/.env")

client = GoogleSheetsClient()

print("Checking 'Delivery Pricing' records...")
records = client.get_all_records("Delivery Pricing")
print(json.dumps(records[:5], indent=2))

print("\nChecking 'Partners' headers...")
ws = client.get_worksheet("Partners")
if ws:
    headers = ws.row_values(1)
    print(json.dumps(headers, ensure_ascii=True))
else:
    print("Partners sheet not found")
