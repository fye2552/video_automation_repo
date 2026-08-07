import sqlite3
import os
import json

db_path = os.path.expanduser("~/.n8n/database.sqlite")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

cur.execute("SELECT status, startedAt FROM execution_entity WHERE id = 70")
row = cur.fetchone()
if row:
    status, started = row
    print(f"Execution 70 Status: {status}, Started: {started}")
    cur.execute("SELECT data FROM execution_data WHERE executionId = 70")
    data_row = cur.fetchone()
    if data_row:
        data_str = data_row[0]
    if data_str:
        try:
            data = json.loads(data_str)
            print("Successfully parsed execution data.")
            # n8n execution data usually has executionData -> nodeExecutionOrder, resultData, etc.
            result_data = data.get('resultData', {})
            run_data = result_data.get('runData', {})
            print("Executed nodes:")
            for node_name, runs in run_data.items():
                print(f"- Node '{node_name}': run count={len(runs)}")
                for i, run in enumerate(runs):
                    # Check if there is an error
                    error = run.get('error')
                    if error:
                        print(f"  Run {i} failed: {error}")
        except Exception as e:
            print("Could not parse data JSON:", e)
            # Try to print start of string
            print("Data preview:", data_str[:500])
    else:
        print("No execution data found in row (it might still be buffered in memory because it's running).")
else:
    print("Execution 70 not found in database.")

conn.close()
