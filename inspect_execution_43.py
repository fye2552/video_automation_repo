import sqlite3
import os
import json

db_path = os.path.expanduser("~/.n8n/database.sqlite")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Get execution data for ID 43
cur.execute("SELECT data FROM execution_data WHERE executionId = 43")
row = cur.fetchone()
if row:
    raw_data = json.loads(row[0])
    indices = [5, 7, 14, 16, 17, 18, 19, 20]
    for idx in indices:
        if idx < len(raw_data):
            print(f"Index {idx}: {raw_data[idx]}")
else:
    print("Execution ID 43 data not found.")

conn.close()
