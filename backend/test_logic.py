import os
import sys

# Add backend to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'app')))

from sheets import sheets_client

def clean_num(v):
    if v is None: return "0.0"
    return str(v).replace(",", "").replace("₦", "").replace("$", "").replace("NGN", "").strip() or "0.0"

def safe_disp(v):
    return "".join(c if ord(c) < 128 else f"<{hex(ord(c))}>" for c in str(v))

def test_logic(email):
    print(f"Testing logic for {email}...")
    records = sheets_client.get_all_records("Partners")
    partner_record = None
    for r in records:
        if str(r.get("USERNAME", "")).lower().strip() == email.lower().strip():
            partner_record = r
            break
    
    if not partner_record:
        print("User not found")
        return

    # Extract current earnings
    p_raw = partner_record.get("POINTS", 0.0)
    r_raw = partner_record.get("REVENUE (₦)", partner_record.get("Revenue", 0.0))
    # Note: Header name in sheet is "Lifetime Earnings" (Mixed Case)
    lt_raw = partner_record.get("Lifetime Earnings", partner_record.get("LIFETIME_EARNINGS", 0.0))

    print(f"Raw Points: {safe_disp(p_raw)}")
    print(f"Raw Revenue: {safe_disp(r_raw)}")
    print(f"Raw Lifetime: {safe_disp(lt_raw)}")

    points = float(clean_num(p_raw))
    revenue = float(clean_num(r_raw))
    lifetime = float(clean_num(lt_raw))

    print(f"Cleaned Points: {points}")
    print(f"Cleaned Revenue: {revenue}")
    print(f"Cleaned Lifetime: {lifetime}")

    new_lifetime = round(lifetime + revenue, 2)
    print(f"NEW Lifetime will be: {new_lifetime}")

if __name__ == "__main__":
    test_logic("heekmerh@gmail.com")
