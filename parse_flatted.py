import sqlite3
import os
import json

def unflatten(data):
    if not isinstance(data, list):
        return data
    
    def resolve(idx):
        if not isinstance(idx, str) or not idx.isdigit():
            return idx
        val = data[int(idx)]
        if isinstance(val, dict):
            return {k: resolve(v) for k, v in val.items()}
        if isinstance(val, list):
            return [resolve(v) for v in val]
        return val
        
    return resolve(data[0])

db_path = os.path.expanduser('~/.n8n/database.sqlite')
conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute('''
    SELECT e.id, e.workflowId, d.data 
    FROM execution_entity e 
    JOIN execution_data d ON e.id = d.executionId 
    ORDER BY e.id DESC LIMIT 5
''')
for row in cur.fetchall():
    data = json.loads(row[2])
    parsed = unflatten(data)
    error = parsed.get('resultData', {}).get('error')
    if error:
        print(f'Execution ID: {row[0]}, Workflow: {row[1]}')
        print(f'Error message: {error.get("message")}')
        print(f'Failed Node: {parsed.get("resultData", {}).get("lastNodeExecuted")}')
        print('-' * 40)
