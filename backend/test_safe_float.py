def safe_float(v):
    """Robust conversion of sheet values (strings/None/numbers) to float."""
    if v is None:
        return 0.0
    if isinstance(v, (int, float)):
        return float(v)
    
    # Clean string: remove currency symbols, commas, and whitespace
    # Replace longer codes first to avoid partial matches (e.g., NGN before N)
    clean_v = str(v).replace("NGN", "").replace("₦", "").replace(",", "").replace("$", "").replace("N", "").strip()
    if not clean_v:
        return 0.0
    try:
        return float(clean_v)
    except (ValueError, TypeError):
        return 0.0

def test_safe_float():
    test_cases = [
        ("₦5,000.00", 5000.0),
        ("₦ 500", 500.0),
        ("500", 500.0),
        ("500.5", 500.5),
        ("$10.50", 10.5),
        ("N1,234", 1234.0),
        ("NGN 100", 100.0),
        ("  1,000.00  ", 1000.0),
        (None, 0.0),
        ("", 0.0),
        (100, 100.0),
        (100.5, 100.5),
        ("invalid", 0.0)
    ]
    
    print("Running safe_float unit tests...")
    failed = 0
    for inp, expected in test_cases:
        res = safe_float(inp)
        inp_disp = str(inp).replace("₦", "N") if inp else repr(inp)
        if res == expected:
            print(f"PASS: {inp_disp} -> {res}")
        else:
            print(f"FAIL: {inp_disp} -> {res} (Expected {expected})")
            failed += 1
            
    if failed == 0:
        print("\nAll tests PASSED!")
    else:
        print(f"\n{failed} tests FAILED.")

if __name__ == "__main__":
    test_safe_float()
