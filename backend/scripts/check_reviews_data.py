import os
import sys
from dotenv import load_dotenv

# Add the parent directory to sys.path to import from 'app'
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.sheets import sheets_client

def check_reviews():
    print("DEBUG: Fetching all records from Reviews sheet...")
    records = sheets_client.get_all_records("Reviews")
    
    if not records:
        print("INFO: No records found in Reviews sheet.")
        return

    print(f"INFO: Found {len(records)} records.")
    
    for i, record in enumerate(records):
        print(f"\n--- Record {i+1} ---")
        for key, value in record.items():
            print(f"{key}: {value} (type: {type(value).__name__})")
            
        # Check specific fields that are problematic
        rating = record.get("Rating")
        try:
            int_rating = int(rating) if rating else 0
            print(f"VALIDATION: Rating '{rating}' converted to int: {int_rating}")
        except (ValueError, TypeError) as e:
            print(f"ERROR: Failed to convert Rating '{rating}' to int: {e}")
            
        created_at = record.get("CreatedAt")
        if not created_at:
            print("WARNING: CreatedAt is missing.")
            
if __name__ == "__main__":
    check_reviews()
