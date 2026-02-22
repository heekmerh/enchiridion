import sys
import os
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from app.sheets import sheets_client

def check_dimensions():
    print("--- Checking Worksheet Dimensions ---")
    ws = sheets_client.get_worksheet("Partners")
    print(f"Row count: {ws.row_count}")
    print(f"Col count: {ws.col_count}")
    
    # Check if there's any data in far columns
    print("\nChecking for data in columns > 23:")
    all_values = ws.get_all_values()
    max_col_found = 0
    for i, row in enumerate(all_values):
        for j, val in enumerate(row):
            if val and j + 1 > max_col_found:
                max_col_found = j + 1
                if j + 1 > 23:
                    print(f"  Row {i+1}, Col {j+1}: {str(val)[:20]}...")
    
    print(f"\nMax Column with data: {max_col_found}")

if __name__ == "__main__":
    check_dimensions()
