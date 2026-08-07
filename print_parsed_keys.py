import sqlite3
import os
import json
from inspect_nodes_running import unflatten_safe

db_path = os.path.expanduser("~/.n8n/database.sqlite")
conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute("SELECT data FROM execution_data WHERE executionId = 70")
row = cur.fetchone()
if row:
    raw_data = json.loads(row[0])
    parsed = unflatten_safe(raw_data)
    print("Parsed type:", type(parsed))
    if isinstance(parsed, dict):
        for k, v in parsed.items():
            print(f"- Key: {k}, Type: {type(v)}, Sample/Value: {str(v)[:200]}")
else:
    print("No row")
conn.close()
