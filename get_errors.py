import sqlite3
import os
import json

db_path = os.path.expanduser('~/.n8n/database.sqlite')
conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute('''
    SELECT e.id, e.workflowId, d.data 
    FROM execution_entity e 
    JOIN execution_data d ON e.id = d.executionId 
    ORDER BY e.id DESC LIMIT 5
''')
out_lines = []
for row in cur.fetchall():
    data = json.loads(row[2])
    if isinstance(data, list):
        out_lines.append(f'Execution ID: {row[0]}, Workflow: {row[1]}')
        for item in data:
            if isinstance(item, dict) and item.get('message'):
                out_lines.append(f'Error object: {item}')
            elif isinstance(item, str) and ('error' in item.lower() or 'failed' in item.lower()):
                out_lines.append(f'String element: {item}')
        continue

with open(r'E:\n8n-video-gemini\n8n_errors_out.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out_lines))
