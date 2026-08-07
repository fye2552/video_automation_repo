import sqlite3
import os

db_path = os.path.expanduser("~/.n8n/database.sqlite")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Get workflows
cur.execute("SELECT id, name, active FROM workflow_entity")
workflows = cur.fetchall()

# Get shares
cur.execute("SELECT workflowId, projectId, role FROM shared_workflow")
shares = {row[0]: (row[1], row[2]) for row in cur.fetchall()}

print("Workflow Permissions Report:")
for wf in workflows:
    wf_id, name, active = wf
    share = shares.get(wf_id)
    if share:
        print(f"- Workflow: {name} (ID: {wf_id}) is owned by Project: {share[0]} (Role: {share[1]})")
    else:
        print(f"- Workflow: {name} (ID: {wf_id}) HAS NO SHARE RELATION (ORPHANED!)")

conn.close()
