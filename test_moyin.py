import urllib.request
import urllib.error
import json
import os

env_path = r'E:\n8n-video-gemini\.env'
with open(env_path, 'r', encoding='utf-8') as f:
    for line in f:
        if line.startswith('MOYIN_API_KEY='):
            token = line.strip().split('=', 1)[1].strip('"\'')
            break

task_id = 'task_1782805464676_8ht8zbcf_video_generation'
url = f'https://demo.moyinai.com/api/v1/videos/{task_id}'

req = urllib.request.Request(url, headers={
    'Authorization': f'Bearer {token}',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode('utf-8'))
        print(json.dumps(data, indent=2, ensure_ascii=False))
except Exception as e:
    print('Error:', e)
