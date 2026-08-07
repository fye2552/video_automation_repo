import json

filepath = r"E:\n8n-video-gemini\workflows\main_generate_video.workflow.json"
with open(filepath, "r", encoding="utf-8") as f:
    data = json.load(f)

print("Workflow nodes:")
for node in data.get("nodes", []):
    print(f"- {node.get('name')} (type: {node.get('type')})")
