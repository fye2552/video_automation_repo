import sqlite3
import os

db_path = os.path.expanduser("~/.n8n/database.sqlite")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Get recent executions of both workflows
cur.execute("""
    SELECT e.id, e.workflowId, e.status, e.startedAt, e.stoppedAt
    FROM execution_entity e
    WHERE e.id >= 40
    ORDER BY e.id DESC
""")
rows = cur.fetchall()
print("Recent Executions (ID >= 40):")
for row in rows:
    name = "Upload" if row[1] == 'z7E11UeH17wunGMJ' else "Main Gen"
    print(f"ID: {row[0]}, Workflow: {name}, Status: {row[2]}, Started: {row[3]}, Stopped: {row[4]}")

conn.close()
