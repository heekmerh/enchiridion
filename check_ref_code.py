import os
import sys

# Add the project root to sys.path
sys.path.append(os.getcwd())

from backend.app.sheets import sheets_client

def check_code(code):
    try:
        ws = sheets_client.get_worksheet('Partners')
        rows = ws.get_all_values()
        codes = [r[1] for r in rows if len(r) > 1]
        if code in codes:
            print(f"SUCCESS: {code} found in Partners.")
        else:
            print(f"FAILED: {code} NOT found in Partners.")
            print(f"Sample codes: {codes[1:6]}")
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    check_code("HEEK-TEST-CODE")
