import sys
import os
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from app.sheets import sheets_client

def inspect_row(row_idx):
    print(f"--- Inspecting Row {row_idx} of Partners ---")
    ws = sheets_client.get_worksheet("Partners")
    row = ws.row_values(row_idx)
    headers = ws.row_values(1)
    
    for i, val in enumerate(row):
        h = headers[i] if i < len(headers) else f"COL_{i+1}"
        safe_h = str(h).encode('ascii', 'replace').decode('ascii')
        safe_v = str(val).encode('ascii', 'replace').decode('ascii')
        print(f"  {chr(65+i) if i < 26 else '?'}{i+1} ({safe_h}): {safe_v}")

if __name__ == "__main__":
    inspect_row(5)
