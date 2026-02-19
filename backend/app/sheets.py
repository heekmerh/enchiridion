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
        # In a real app, you'd use a service account key file path from env
        self.creds_file = os.getenv("GOOGLE_SHEETS_CREDS_FILE")
        self.spreadsheet_id = os.getenv("GOOGLE_SHEETS_ID")
        
        if self.creds_file and os.path.exists(self.creds_file):
            try:
                self.creds = Credentials.from_service_account_file(self.creds_file, scopes=self.scopes)
                self.client = gspread.authorize(self.creds)
                self.sheet = self.client.open_by_key(self.spreadsheet_id)
            except Exception as e:
                print(f"CRITICAL ERROR: Failed to load Google Sheets credentials: {e}")
                if "client_email" in str(e):
                    print("TIP: It looks like you're using an OAuth Client ID JSON instead of a Service Account Key JSON.")
                    print("Please create a Service Account in Google Cloud Console and use its JSON key.")
                self.client = None
                self.sheet = None
        else:
            print("WARNING: Google Sheets credentials not found. Using mock client.")
            self.client = None
            self.sheet = None

    def get_worksheet(self, name: str):
        if not self.sheet:
            print(f"ERROR: Google Sheets not initialized. Cannot access worksheet '{name}'.")
            return None
        try:
            return self.sheet.worksheet(name)
        except Exception as e:
            print(f"ERROR: Could not find worksheet '{name}' in sheet {self.spreadsheet_id}: {e}")
            import traceback
            traceback.print_exc()
            return None


    def append_row(self, worksheet_name: str, row: List):
        ws = self.get_worksheet(worksheet_name)
        if ws:
            try:
                ws.append_row(row)
                print(f"Successfully appended row to {worksheet_name}")
            except Exception as e:
                print(f"ERROR: Failed to append row to {worksheet_name}: {e}")
                raise e # Re-raise to let the caller know it failed

    def get_all_records(self, worksheet_name: str):
        print(f"DEBUG: Fetching all records from {worksheet_name}...")
        ws = self.get_worksheet(worksheet_name)
        if ws:
            try:
                records = ws.get_all_records()
                # print(f"DEBUG: Successfully fetched {len(records)} records from {worksheet_name}")
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
                ws.update(values, range_name)
                print(f"Successfully updated range {range_name} in {worksheet_name}")
            except Exception as e:
                print(f"ERROR: Failed to update range {range_name} in {worksheet_name}: {e}")
                raise e

sheets_client = GoogleSheetsClient()
