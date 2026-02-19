import os
import sys
import asyncio
import uuid

# Add backend to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__))))
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'app')))

from app.sheets import sheets_client

def test_sheets():
    print("Testing sheets connectivity...")
    try:
        ws = sheets_client.get_worksheet("Partners")
        if ws:
            print("Successfully accessed Partners worksheet.")
            all_values = ws.get_all_values()
            print(f"Found {len(all_values)} rows.")
        else:
            print("Failed to access Partners worksheet.")
    except Exception as e:
        print(f"Sheets test failed: {e}")

if __name__ == "__main__":
    test_sheets()
