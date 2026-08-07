import json

filepath = r"E:\n8n-video-gemini\workflows\main_generate_video.workflow.json"
with open(filepath, "r", encoding="utf-8") as f:
    data = json.load(f)

for node in data.get("nodes", []):
    if node.get("name") in ["Build Local Worker Job", "Write Worker Inbox Job JSON"]:
        print(f"\n=== Node: {node.get('name')} JS Code ===")
        print(node.get("parameters", {}).get("jsCode", ""))
