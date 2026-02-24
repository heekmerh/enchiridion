import sys
import os
import json

sys.path.append(os.getcwd())
from backend.app.sheets import sheets_client

def check_latest_audit():
    print("Checking latest audit logs...")
    try:
        ws = sheets_client.get_worksheet("Admin Audit")
        all_rows = ws.get_all_values()
        filtered = [r for r in all_rows if any(c.strip() for c in r)]
        print(f"Total entries: {len(filtered)}")
        for r in filtered[-10:]:
            print(r)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_latest_audit()
