import sqlite3
import os
import json
from test_resolve_0 import unflatten_safe

db_path = os.path.expanduser("~/.n8n/database.sqlite")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

print("Fetching Execution 68...")
cur.execute("SELECT data FROM execution_data WHERE executionId = 68")
row = cur.fetchone()
if row:
    raw_data = json.loads(row[0])
    parsed = unflatten_safe(raw_data)
    
    result_data = parsed.get("resultData", {})
    error = result_data.get("error")
    print("\n=== Crash details ===")
    if error:
        print("Error details:")
        print(json.dumps(error, indent=2))
    else:
        print("No error object in resultData. Keys in resultData:", list(result_data.keys()))
        
    print("\nLast executed node:", result_data.get("lastNodeExecuted"))
else:
    print("Execution 68 data not found in DB.")

conn.close()
