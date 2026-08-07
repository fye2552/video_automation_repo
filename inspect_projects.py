import sqlite3
import os

db_path = os.path.expanduser("~/.n8n/database.sqlite")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Get tables list
cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [t[0] for t in cur.fetchall()]

for t in ["project", "project_membership", "project_relation"]:
    if t in tables:
        print(f"\n=== Table: {t} ===")
        cur.execute(f"PRAGMA table_info({t})")
        print("Columns:", [c[1] for c in cur.fetchall()])
        cur.execute(f"SELECT * FROM {t}")
        for row in cur.fetchall():
            print(row)

conn.close()
