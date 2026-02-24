import sys
import os

sys.path.append(os.getcwd())
from backend.app.sheets import sheets_client

def raw_dump(ws_name):
    print(f"\n--- Raw dump of {ws_name} ---")
    try:
        ws = sheets_client.get_worksheet(ws_name)
        rows = ws.get_all_values()
        print(f"Total rows: {len(rows)}")
        for i, r in enumerate(rows[-10:]):
            print(f"Row {len(rows)-10+i}: {r}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    raw_dump("Admin Audit")
    raw_dump("ActivityLog")
