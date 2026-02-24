import sys
import os
import json

sys.path.append(os.getcwd())
from backend.app.sheets import sheets_client

def list_partners():
    try:
        ws = sheets_client.get_worksheet("Partners")
        records = ws.get_all_records()
        print(json.dumps(records, indent=2))
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    list_partners()
