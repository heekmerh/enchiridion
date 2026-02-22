import sys
import os
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from app.sheets import sheets_client

def repair_misaligned_data():
    print("--- Repairing Misaligned Registration Data ---")
    ws = sheets_client.get_worksheet("Partners")
    all_values = ws.get_all_values()
    
    # We'll check each row. If Column A is empty but Column V or later has an email, we shift it back.
    for i in range(1, len(all_values)): # Skip header
        row = all_values[i]
        if not row: continue
        
        # Scenario 1: Row has email in V but A-U are empty
        if len(row) > 21 and not str(row[0]).strip() and "@" in str(row[21]):
            email = row[21]
            print(f"Found misaligned user on Row {i+1} at Col V: {email}")
            # The data starts at index 21 (Col V) and is length 18
            new_data = row[21:21+18]
            # Pad or trim to 18 items if needed
            while len(new_data) < 18: new_data.append("")
            
            print(f"  Shifting {email} to Column A...")
            # Update columns A-R
            sheets_client.update_range("Partners", f"A{i+1}:R{i+1}", [new_data])
            # Clear columns V-AM (the old shifted data)
            clear_row = [""] * 20 # Clear a large chunk
            sheets_client.update_range("Partners", f"V{i+1}:AO{i+1}", [clear_row])
            
        # Scenario 2: Row has email in AJ (36) - like our simulation
        elif len(row) > 35 and not str(row[0]).strip() and "@" in str(row[35]):
             email = row[35]
             print(f"Found misaligned user on Row {i+1} at Col AJ: {email}")
             new_data = row[35:35+18]
             while len(new_data) < 18: new_data.append("")
             
             print(f"  Shifting {email} to Column A...")
             sheets_client.update_range("Partners", f"A{i+1}:R{i+1}", [new_data])
             # Clear the old data carefully without exceeding column 53
             sheets_client.update_range("Partners", f"AJ{i+1}:BA{i+1}", [[""] * 18])

if __name__ == "__main__":
    repair_misaligned_data()
