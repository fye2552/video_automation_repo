import json
import os
import subprocess

workflows = [
    {'Source': r'E:\n8n-video-gemini\workflows\main_generate_video.workflow.json', 'Id': 'hqj0P1dbvqyPEh18'},
]

os.makedirs(r'E:\n8n-video-gemini\test_logs', exist_ok=True)

for spec in workflows:
    with open(spec['Source'], 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    data['id'] = spec['Id']
    data['active'] = True
    
    import_path = rf'E:\n8n-video-gemini\test_logs\{spec["Id"]}.import.json'
    with open(import_path, 'w', encoding='utf-8') as f:
        json.dump(data, f)
    
    print(f"Importing {spec['Source']}...")
    subprocess.run(['n8n.cmd', 'import:workflow', f'--input={import_path}'], shell=True)
    print(f"Publishing {spec['Id']}...")
    subprocess.run(['n8n.cmd', 'publish:workflow', f'--id={spec["Id"]}'], shell=True)

print('Done!')
