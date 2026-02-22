import sys
import os
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from app.sheets import sheets_client

def find_user_anywhere(email):
    print(f"--- Searching for {email} in Partners ---")
    ws = sheets_client.get_worksheet("Partners")
    all_values = ws.get_all_values()
    found = False
    for i, row in enumerate(all_values):
        row_str = " | ".join(map(str, row))
        if email.lower() in row_str.lower():
            print(f"Found on Row {i+1}: {row_str}")
            found = True
    
    if not found:
        print(f"User {email} not found in first column or any other column.")
        print(f"Total rows searched: {len(all_values)}")

if __name__ == "__main__":
    email = sys.argv[1] if len(sys.argv) > 1 else "muhikenterprises@gmail.com"
    find_user_anywhere(email)
