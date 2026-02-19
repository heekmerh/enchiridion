import os
import sys

# Add the current directory to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'app')))

from sheets import sheets_client

def fix_headers():
    print("Checking Partners sheet headers...")
    ps = sheets_client.get_worksheet("Partners")
    if ps:
        headers = ps.row_values(1)
        # print check removed to avoid UnicodeEncodeError
        updates = False
        
        # Partners headers: Q(17), R(18)
        if len(headers) < 17:
             ps.update_cell(1, 17, "PAYOUT_STATUS")
             print("Added PAYOUT_STATUS header to Partners.")
             updates = True
        if len(headers) < 18:
             ps.update_cell(1, 18, "LIFETIME_EARNINGS")
             print("Added LIFETIME_EARNINGS header to Partners.")
             updates = True
        
        if not updates:
            print("Partners headers already sufficient.")
            
    print("\nChecking ActivityLog sheet headers...")
    als = sheets_client.get_worksheet("ActivityLog")
    if als:
        headers = als.row_values(1)
        print(f"Current headers: {headers}")
        # ActivityLog headers: G(7)
        if len(headers) < 7:
            als.update_cell(1, 7, "Payout Status")
            print("Added Payout Status header to ActivityLog.")
        else:
            print("ActivityLog headers already sufficient.")

if __name__ == "__main__":
    fix_headers()
