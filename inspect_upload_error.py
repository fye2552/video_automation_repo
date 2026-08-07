import sqlite3
import os
import json

db_path = os.path.expanduser("~/.n8n/database.sqlite")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Get the latest failed execution of the upload workflow
cur.execute("""
    SELECT e.id, d.data
    FROM execution_entity e
    JOIN execution_data d ON e.id = d.executionId
    WHERE e.workflowId = 'z7E11UeH17wunGMJ' AND e.status = 'error'
    ORDER BY e.id DESC LIMIT 1
""")
row = cur.fetchone()
if row:
    exec_id, data_str = row
    print(f"Failed Execution ID: {exec_id}")
    data = json.loads(data_str)
    
    # Let's inspect the flatted structure
    if isinstance(data, list):
        # Scan for dict containing error info
        for i, item in enumerate(data):
            if isinstance(item, dict):
                if 'error' in item or 'message' in item or 'lastNodeExecuted' in item:
                    print(f"Index {i}: {item}")
                    
        # Let's print index 5, 7, 14, 16, 17, 18 if they are pointers
        indices = [5, 7, 14, 16, 17, 18]
        for idx in indices:
            if idx < len(data):
                print(f"Pointers - Index {idx}: {data[idx]}")
else:
    print("No failed executions found for upload workflow.")

conn.close()
