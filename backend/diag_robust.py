import os
import sys
import json

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
    
    records = ws.get_all_records()
    
    detailed_data = {
        "headers": headers,
        "records": []
    }
    
    for i, record in enumerate(records):
        row_num = i + 2
        detailed_data["records"].append({
            "row": row_num,
            "data": record
        })
    
    # Write to a file instead of printing to console to avoid encoding issues
    with open("sheet_diag.json", "w", encoding="utf-8") as f:
        json.dump(detailed_data, f, indent=2, ensure_ascii=False)
    
    print("Diagnostics written to sheet_diag.json")

if __name__ == "__main__":
    diag()
