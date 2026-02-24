import gspread
from google.oauth2.service_account import Credentials
from typing import List, Optional
import os
from dotenv import load_dotenv

# Load .env from the backend directory (parent of this 'app' folder)
env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
load_dotenv(env_path)


class GoogleSheetsClient:
    def __init__(self):
        self.scopes = [
            "https://www.googleapis.com/auth/spreadsheets",
            "https://www.googleapis.com/auth/drive"
        ]
        self.creds_file = os.getenv("GOOGLE_SHEETS_CREDS_FILE")
        self.spreadsheet_id = os.getenv("GOOGLE_SHEETS_ID")
        self._client = None
        self._sheet = None
        self._initialized = False

    def _ensure_initialized(self):
        if self._initialized:
            return
        
        print(f"DEBUG: Initializing Google Sheets Client (Target: {self.spreadsheet_id})...")
        if self.creds_file and os.path.exists(self.creds_file):
            try:
                # Use a shorter timeout for the HTTP requests used by gspread
                self.creds = Credentials.from_service_account_file(self.creds_file, scopes=self.scopes)
                
                # We can't easily pass a timeout to authorize(), 
                # but we can wrap the blocking calls. 
                # For now, we'll use a try/except pattern with the lazy init 
                # and add a custom check if it survives.
                self._client = gspread.authorize(self.creds)
                
                # This is a network-bound call that often hangs on this environment
                print(f"DEBUG: Opening spreadsheet {self.spreadsheet_id}...")
                self._sheet = self._client.open_by_key(self.spreadsheet_id)
                
                self._initialized = True
                print("DEBUG: Google Sheets Client initialized successfully.")
            except Exception as e:
                print(f"CRITICAL ERROR: Failed to lazy-load Google Sheets: {e}")
                self._client = None
                self._sheet = None
                self._initialized = True # Mark as "attempted" to prevent boot loops
        else:
            print("WARNING: Google Sheets credentials not found. Using mock client.")
            self._initialized = True

    @property
    def client(self):
        self._ensure_initialized()
        return self._client

    @property
    def sheet(self):
        self._ensure_initialized()
        return self._sheet

    def get_worksheet(self, name: str):
        if not self.sheet:
            print(f"ERROR: Google Sheets not initialized. Cannot access worksheet '{name}'.")
            return None
        try:
            return self.sheet.worksheet(name)
        except Exception as e:
            print(f"ERROR: Could not find worksheet '{name}' in sheet {self.spreadsheet_id}: {e}")
            return None

    def get_or_create_worksheet(self, name: str, headers: List[str] = None):
        """Returns existing worksheet or creates a new one with optional headers."""
        ws = self.get_worksheet(name)
        if ws:
            return ws
        
        if not self.sheet:
            return None
            
        try:
            print(f"DEBUG: Creating missing worksheet '{name}'...")
            ws = self.sheet.add_worksheet(title=name, rows="1000", cols="20")
            if headers:
                ws.append_row(headers, table_range="A1")
            return ws
        except Exception as e:
            print(f"ERROR: Failed to create worksheet '{name}': {e}")
            return None


    def append_row(self, worksheet_name: str, row: List):
        ws = self.get_worksheet(worksheet_name)
        if ws:
            try:
                # Force appending starting from column A to prevent accidental shifts
                ws.append_row(row, table_range="A1")
                print(f"Successfully appended row to {worksheet_name} starting at Col A")
            except Exception as e:
                print(f"ERROR: Failed to append row to {worksheet_name}: {e}")
                raise e # Re-raise to let the caller know it failed

    def get_all_records(self, worksheet_name: str):
        print(f"DEBUG: Fetching all records from {worksheet_name}...")
        ws = self.get_worksheet(worksheet_name)
        if ws:
            try:
                # Use get_all_values and filter headers manually to avoid gspread error with duplicate/empty headers
                all_values = ws.get_all_values()
                if not all_values:
                    return []
                
                headers = all_values[0]
                # Clean headers: handle duplicates and empty strings
                cleaned_headers = []
                seen = {}
                for i, h in enumerate(headers):
                    h = h.strip()
                    if not h:
                        h = f"EMPTY_{i}"
                    if h in seen:
                        seen[h] += 1
                        h = f"{h}_{seen[h]}"
                    else:
                        seen[h] = 0
                    cleaned_headers.append(h)
                
                records = []
                for row in all_values[1:]:
                    record = {}
                    for i, header in enumerate(cleaned_headers):
                        if i < len(row):
                            record[header] = row[i]
                        else:
                            record[header] = ""
                    records.append(record)
                return records
            except Exception as e:
                print(f"ERROR: Failed to get records from {worksheet_name}: {e}")
                return []
        return []

    def find_cell(self, worksheet_name: str, value: str, column: int):
        ws = self.get_worksheet(worksheet_name)
        if ws:
            try:
                cell = ws.find(value, in_column=column)
                return cell
            except gspread.exceptions.CellNotFound:
                return None
            except Exception as e:
                print(f"ERROR: Failed to find cell in {worksheet_name}: {e}")
                return None
        return None

    def update_cell(self, worksheet_name: str, row: int, col: int, value):
        ws = self.get_worksheet(worksheet_name)
        if ws:
            try:
                ws.update_cell(row, col, value)
            except Exception as e:
                print(f"ERROR: Failed to update cell in {worksheet_name}: {e}")
                raise e

    def update_range(self, worksheet_name: str, range_name: str, values: List[List]):
        """Updates a range of cells, e.g., 'E2:F2' with [[points, revenue]]."""
        ws = self.get_worksheet(worksheet_name)
        if ws:
            try:
                # In gspread 6.x, 'values' is the first positional argument
                ws.update(values, range_name)
                print(f"Successfully updated range {range_name} in {worksheet_name}")
            except Exception as e:
                print(f"ERROR: Failed to update range {range_name} in {worksheet_name}: {e}")
                raise e

    def log_audit(self, action: str, message: str, status: str = "SUCCESS"):
        """Logs an action to the 'Admin Audit' sheet."""
        try:
            from datetime import datetime
            row = [datetime.now().isoformat(), action, message, status]
            self.append_row("Admin Audit", row)
        except Exception as e:
            print(f"FAILED TO LOG AUDIT: {e}")

    @staticmethod
    def get_case_insensitive_val(record: dict, *keys: str, default=None):
        """Robustly retrieves a value from a gspread record using case-insensitive/variant keys."""
        normalized_record = {str(k).strip().lower(): v for k, v in record.items()}
        for key in keys:
            norm_key = str(key).strip().lower()
            if norm_key in normalized_record:
                return normalized_record[norm_key]
        return default

def safe_float(v):
    """Robust conversion of sheet values (strings/None/numbers) to float."""
    if v is None:
        return 0.0
    if isinstance(v, (int, float)):
        return float(v)
    
    # Clean string: remove currency symbols, commas, and whitespace
    clean_v = str(v).replace("NGN", "").replace("\u20a6", "").replace(",", "").replace("$", "").replace("N", "").strip()

    if not clean_v:
        return 0.0
    try:
        return float(clean_v)
    except (ValueError, TypeError):
        return 0.0

sheets_client = GoogleSheetsClient()
