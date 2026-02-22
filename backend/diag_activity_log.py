import os
import sys

# Add the current directory to sys.path so we can import from app
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'app')))

from sheets import sheets_client

def diag():
    print("Checking ActivityLog worksheet...")
    ws = sheets_client.get_worksheet("ActivityLog")
    if not ws:
        print("ActivityLog worksheet NOT FOUND!")
        return
    
    print("Worksheet found. Fetching headers...")
    # Show last 5 rows
    all_values = ws.get_all_values()
    print(f"\nLast 5 rows in ActivityLog (Total: {len(all_values)}):")
    for row in all_values[-5:]:
        print(row)

if __name__ == "__main__":
    diag()
