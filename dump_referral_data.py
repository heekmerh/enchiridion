import os
import sys
import json

# Add the project root to sys.path
sys.path.append(os.getcwd())

from backend.app.sheets import sheets_client

def dump_data():
    try:
        print("DEBUG: Fetching ActivityLog...")
        activity_ws = sheets_client.get_worksheet('ActivityLog')
        activity_vals = activity_ws.get_all_values()
        
        print("DEBUG: Fetching Partners...")
        partners_ws = sheets_client.get_worksheet('Partners')
        partners_vals = partners_ws.get_all_values()
        
        data = {
            "activity_headers": activity_vals[0] if activity_vals else [],
            "recent_activity": activity_vals[-20:] if activity_vals else [],
            "partners_headers": partners_vals[0] if partners_vals else [],
            "sample_partners": partners_vals[1:21] if partners_vals else []
        }
        
        with open("debug_dump.json", "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4, ensure_ascii=False)
        print("DEBUG: Data dumped to debug_dump.json")
        
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    dump_data()
