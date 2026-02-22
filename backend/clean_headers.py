from app.sheets import sheets_client

def clean_headers():
    ws = sheets_client.sheet.worksheet("Partners")
    headers = ws.row_values(1)
    print(f"Current headers: {headers}")
    
    # Remove empty headers at the end
    cleaned = [h for h in headers if h.strip()]
    print(f"Cleaned headers: {cleaned}")
    
    # If we need to fix it in the sheet, we might need to delete empty columns
    # But for our script, we can just use expected_headers or get all records more carefully.
    
if __name__ == "__main__":
    clean_headers()
