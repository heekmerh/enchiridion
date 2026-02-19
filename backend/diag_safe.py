import os
import sys

# Add backend to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'app')))

from sheets import sheets_client

def diag():
    print("Fetching worksheet Partners...")
    ws = sheets_client.get_worksheet("Partners")
    if not ws:
        print("Worksheet not found.")
        return
    
    headers = ws.row_values(1)
    print(f"Total columns in header: {len(headers)}")
    for i, h in enumerate(headers):
        # Print index (1-based for A-Z) and safe header name
        safe_h = "".join(c for h_name in [h] for h_char in h_name for c in (h_char if ord(h_char) < 128 else "_"))
        print(f"Col {i+1} ({chr(65+i) if i < 26 else '?'}): {safe_h}")
    
    records = ws.get_all_records()
    if records:
        print(f"\nTotal records: {len(records)}")
        first = records[0]
        for k, v in first.items():
            safe_k = "".join(c for h_char in k for c in (h_char if ord(h_char) < 128 else "_"))
            print(f"Key: {safe_k}, Value: {v}")

if __name__ == "__main__":
    diag()
