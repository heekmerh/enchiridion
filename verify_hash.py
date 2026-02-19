import os
import sys
from fastapi_users.password import PasswordHelper

# Add parent dir to path
sys.path.append(os.getcwd())

def verify_hash(password: str, hash_str: str):
    ph = PasswordHelper()
    verified, _ = ph.verify_and_update(password, hash_str)
    print(f"DEBUG: Password verification for '{password}': {verified}")

    
    # Also show what a new hash would look like for comparison
    new_hash = ph.hash(password)
    print(f"DEBUG: New hash for reference: {new_hash}")

if __name__ == "__main__":
    import asyncio
    from backend.app.auth import sheets_client
    
    async def main():
        email = "heekmerh@gmail.com"
        password = "Enchiridion2026!"
        
        ws = sheets_client.get_worksheet("Partners")
        records = ws.get_all_records()
        
        target_email = email.lower().strip()
        found_hash = None
        for r in records:
            record_email = ""
            for k, v in r.items():
                if k.lower().replace(" ", "") in ["username", "email", "emailaddress"]:
                    record_email = str(v).lower().strip()
                    break
            
            if record_email == target_email:
                for k, v in r.items():
                    if k.lower().replace(" ", "") == "password":
                        found_hash = str(v)
                        break
                break
        
        if found_hash:
            print(f"DEBUG: Found hash in sheet for {email}: {found_hash[:20]}...")
            verify_hash(password, found_hash)
        else:
            print(f"DEBUG: Could not find hash for {email}")

    asyncio.run(main())
