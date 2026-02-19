import os
import sys
import asyncio
import uuid
import hashlib
from datetime import datetime

# Add backend to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'app')))

from sheets import sheets_client
from auth import GoogleSheetsUserDatabase, safe_float
from models import User, UserRead

async def debug_audit():
    print("Testing Audit logic...")
    try:
        ws = sheets_client.get_worksheet("Partners")
        all_values = ws.get_all_values()
        headers = [h.strip().upper() for h in all_values[0]]
        print(f"Headers: {headers}")
        
        last_rows = all_values[-5:]
        for i, row in enumerate(last_rows):
            if row[0].upper() in ["USERNAME", "EMAIL"]:
                continue
            print(f"Auditing row: {row}")
            # Simulate verify_integrity logic
            # (Truncated for space, just checking the prone parts)
            try:
                # Mock indices
                user_idx = 0
                points_idx = 4
                rev_idx = 5
                
                username = row[user_idx]
                p_val = row[points_idx]
                r_val = row[rev_idx]
                
                points = safe_float(p_val)
                revenue = safe_float(r_val)
                print(f"  Points: {points}, Revenue: {revenue}")
            except Exception as e:
                print(f"  Error in row audit: {e}")
                import traceback
                traceback.print_exc()
                
    except Exception as e:
        print(f"Audit failed: {e}")
        import traceback
        traceback.print_exc()

async def debug_auth(email):
    print(f"\nTesting Auth logic for {email}...")
    db = GoogleSheetsUserDatabase(User, uuid.UUID)
    try:
        user = await db.get_by_email(email)
        if user:
            print(f"User found: {user.email}")
            print(f"Model validation check: OK")
        else:
            print("User not found")
    except Exception as e:
        print(f"Auth failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(debug_audit())
    asyncio.run(debug_auth("heekmerh@gmail.com"))
