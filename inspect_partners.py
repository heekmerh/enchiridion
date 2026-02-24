import os
import sys
import json

# Add backend directory to sys.path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from dotenv import load_dotenv
from app.sheets import GoogleSheetsClient

load_dotenv(dotenv_path="backend/.env")

client = GoogleSheetsClient()

print("Fetching headers for 'Partners'...")
ws = client.get_worksheet("Partners")
if ws:
    headers = ws.row_values(1)
    # Print as JSON to avoid encoding issues in terminal
    print(json.dumps(headers, ensure_ascii=True))
else:
    print("Could not find 'Partners' worksheet.")
