import sys
import os
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from app.sheets import sheets_client

def inspect_partners_sheet():
    print("--- Inspecting Partners Sheet Schema ---")
    ws = sheets_client.get_worksheet("Partners")
    if not ws:
        print("Failed to get Partners worksheet")
        return
        
    headers = ws.row_values(1)
    print(f"Headers (Count: {len(headers)}):")
    for i, h in enumerate(headers):
        # Safely encode to ASCII for terminal output
        safe_h = str(h).encode('ascii', 'replace').decode('ascii')
        print(f"  {chr(65+i)} ({i+1}): {safe_h}")
        
    all_values = ws.get_all_values()
    # Filter out empty rows (where first column is empty)
    non_empty_rows = [row for row in all_values if row and str(row[0]).strip()]
    
    if len(non_empty_rows) > 1:
        last_row = non_empty_rows[-1]
        print("\nLast Non-Empty Row Values:")
        for i, val in enumerate(last_row):
            header = headers[i] if i < len(headers) else f"EMPTY_{i}"
            safe_h = str(header).encode('ascii', 'replace').decode('ascii')
            safe_v = str(val).encode('ascii', 'replace').decode('ascii')
            print(f"  {safe_h}: {safe_v}")
    else:
        print("\nNo data rows found.")

if __name__ == "__main__":
    inspect_partners_sheet()
