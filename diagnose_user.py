import os
import sys
import asyncio
from dotenv import load_dotenv

# Add the parent directory to sys.path
sys.path.append(os.getcwd())

from backend.app.auth import sheets_client

async def diagnose_user(email: str):
    try:
        ws = sheets_client.get_worksheet("Partners")
        records = ws.get_all_records()
        
        target_email = email.lower().strip()
        found = False
        for r in records:
            # Flexible email finding
            record_email = ""
            for k, v in r.items():
                if k.lower().replace(" ", "") in ["username", "email", "emailaddress"]:
                    record_email = str(v).lower().strip()
                    break
            
            if record_email == target_email:
                print(f"DEBUG: Found record for {email}")
                for k, v in r.items():
                    try:
                        if k.lower() == "password":
                            # Use repr to see escape sequences and avoid encoding issues
                            print(f"  {k}: {repr(str(v)[:15])}... (len: {len(str(v))})")
                        else:
                            print(f"  {k}: {repr(v)}")
                    except Exception:
                        print(f"  {k}: [Encoding error in display]")
                found = True
                break
        
        if not found:
            print(f"DEBUG: User {email} not found.")
            
    except Exception as e:
        print(f"ERROR: Diagnostic failed: {e}")

if __name__ == "__main__":
    email = sys.argv[1] if len(sys.argv) > 1 else "heekmerh@gmail.com"
    asyncio.run(diagnose_user(email))
