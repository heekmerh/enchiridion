import os
import sys
import asyncio
from fastapi_users.password import PasswordHelper

# Add parent dir to path
sys.path.append(os.getcwd())

from backend.app.auth import sheets_client

async def reset_password(email: str, new_password: str):
    ph = PasswordHelper()
    new_hash = ph.hash(new_password)
    
    ws = sheets_client.get_worksheet("Partners")
    records = ws.get_all_records()
    
    target_email = email.lower().strip()
    row_idx = None
    for i, r in enumerate(records):
        record_email = ""
        for k, v in r.items():
            if k.lower().replace(" ", "") in ["username", "email", "emailaddress"]:
                record_email = str(v).lower().strip()
                break
        
        if record_email == target_email:
            row_idx = i + 2
            break
            
    if row_idx:
        ws.update_cell(row_idx, 2, new_hash)
        print(f"SUCCESS: Reset password for {email} (Row {row_idx}) to '{new_password}'")
    else:
        print(f"ERROR: User {email} not found.")

if __name__ == "__main__":
    email = "heekmerh@gmail.com"
    password = "Welcome2026"
    asyncio.run(reset_password(email, password))

