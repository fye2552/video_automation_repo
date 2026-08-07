import json

filepath = r"E:\n8n-video-gemini\workflows\main_generate_video.workflow.json"
with open(filepath, "r", encoding="utf-8") as f:
    data = json.load(f)

for node in data.get("nodes", []):
    if node.get("name") == "Check Uniqueness Select Scripts":
        print("=== Check Uniqueness Select Scripts jsCode ===")
        print(node.get("parameters", {}).get("jsCode", ""))
