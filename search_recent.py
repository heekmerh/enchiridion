import sys
import os
from datetime import datetime
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from app.sheets import sheets_client

def find_recent_entries():
    print("--- Searching for Recent Registration Entries ---")
    ws = sheets_client.get_worksheet("Partners")
    all_values = ws.get_all_values()
    headers = all_values[0]
    
    # Try to find recent users in Partners
    print("\nRecent rows in Partners:")
    for i in range(len(all_values)-1, 0, -1):
        row = all_values[i]
        if not row or not row[0]: continue
        # Look at DATE_JOINED (Column O / Index 14)
        if len(row) > 14:
            dt_str = row[14]
            print(f"Row {i+1}: User={row[0]}, DateJoined='{dt_str}'")
        if i < len(all_values) - 5: break # Only check last 5 entries
        
    # Check Admin Audit
    print("\nRecent entries in Admin Audit:")
    audit_ws = sheets_client.get_worksheet("Admin Audit")
    if audit_ws:
        audit_values = audit_ws.get_all_values()
        for i in range(len(audit_values)-1, 0, -1):
            row = audit_values[i]
            if not row: continue
            print(f"Audit {i+1}: {row}")
            if i < len(audit_values) - 10: break

if __name__ == "__main__":
    find_recent_entries()
