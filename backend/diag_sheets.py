import os
import sys

# Add the current directory to sys.path so we can import from app
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'app')))

from sheets import sheets_client

def diag():
    print("Fetching records from Partners...")
    records = sheets_client.get_all_records("Partners")
    if not records:
        print("No records found or sheet is empty.")
        return
    
    print(f"Total records: {len(records)}")
    headers = list(records[0].keys())
    print(f"Headers: {[h.replace('\u20a6', 'N') for h in headers]}")
    
    for i, record in enumerate(records):
        print(f"\nRecord {i+1}:")
        for k, v in record.items():
            k_clean = k.replace('\u20a6', 'N')
            v_clean = str(v).replace('\u20a6', 'N')
            print(f"  {k_clean}: {v_clean}")

            
if __name__ == "__main__":
    diag()
