import gspread
from google.oauth2.service_account import Credentials
from typing import List, Optional
import os
from dotenv import load_dotenv

load_dotenv()

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
            return None
        return self.sheet.worksheet(name)

    def append_row(self, worksheet_name: str, row: List):
        ws = self.get_worksheet(worksheet_name)
        if ws:
            ws.append_row(row)

    def get_all_records(self, worksheet_name: str):
        ws = self.get_worksheet(worksheet_name)
        if ws:
            return ws.get_all_records()
        return []

    def find_cell(self, worksheet_name: str, value: str, column: int):
        ws = self.get_worksheet(worksheet_name)
        if ws:
            try:
                cell = ws.find(value, in_column=column)
                return cell
            except gspread.exceptions.CellNotFound:
                return None
        return None

    def update_cell(self, worksheet_name: str, row: int, col: int, value):
        ws = self.get_worksheet(worksheet_name)
        if ws:
            ws.update_cell(row, col, value)

sheets_client = GoogleSheetsClient()
