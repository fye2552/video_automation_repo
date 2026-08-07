import sqlite3
import os
import json

db_path = os.path.expanduser("~/.n8n/database.sqlite")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Get execution data for ID 48
cur.execute("SELECT data FROM execution_data WHERE executionId = 48")
row = cur.fetchone()
if row:
    data = json.loads(row[0])
    print("Execution 50 data loaded.")
    
    # We want to find the input to the Moyin Create Video node
    # Let's search for the node that executes just before Moyin Create Video, which is "Split Scenes" or "Build Moyin Jobs"
    for i, item in enumerate(data):
        if isinstance(item, dict) and item.get('name') == 'Build Moyin Jobs':
            print(f"Build Moyin Jobs node found at index {i}")
            # print its output structure
            for k, v in item.items():
                try:
                    v_idx = int(v)
                    if v_idx < len(data) and isinstance(data[v_idx], list):
                        # print first item structure
                        if data[v_idx]:
                            first_item = data[v_idx][0]
                            # Dereference first_item if it is an index
                            try:
                                first_item = data[int(first_item)]
                            except (ValueError, TypeError):
                                pass
                            print("Output structure sample:")
                            print(json.dumps(first_item, indent=2))
                except ValueError:
                    pass
else:
    print("Execution data not found.")

conn.close()
