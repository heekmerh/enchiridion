import os
import sys
import json

# Add backend directory to sys.path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from dotenv import load_dotenv
from app.sheets import GoogleSheetsClient

load_dotenv(dotenv_path="backend/.env")

client = GoogleSheetsClient()

print("Checking first data row in 'Partners'...")
records = client.get_all_records("Partners")
if records:
    print(json.dumps(records[0], indent=2))
else:
    print("No records found in Partners sheet")
