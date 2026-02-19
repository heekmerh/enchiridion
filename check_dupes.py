import os
import sys
import asyncio

# Add parent dir to path
sys.path.append(os.getcwd())

from backend.app.auth import sheets_client

async def check_dupes(email: str):
    ws = sheets_client.get_worksheet("Partners")
    records = ws.get_all_records()
    
    email = email.lower().strip()
    matches = []
    for i, r in enumerate(records):
        record_email = ""
        for k, v in r.items():
            if k.lower().replace(" ", "") in ["username", "email", "emailaddress"]:
                record_email = str(v).lower().strip()
                break
        
        if record_email == email:
            matches.append((i + 2, r))
            
    print(f"FOUND {len(matches)} matches for {email}")
    for row_idx, r in matches:
        p_hash = r.get("PASSWORD", "")
        print(f"  Row {row_idx}: Hash starts with {p_hash[:15]}...")

if __name__ == "__main__":
    email = sys.argv[1] if len(sys.argv) > 1 else "heekmerh@gmail.com"
    asyncio.run(check_dupes(email))
