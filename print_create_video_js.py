import json

filepath = r"E:\n8n-video-gemini\workflows\main_generate_video.workflow.json"
with open(filepath, "r", encoding="utf-8") as f:
    data = json.load(f)

for node in data.get("nodes", []):
    if node.get("name") == "Moyin Create Video":
        print("=== Moyin Create Video Node JS Code ===")
        print(node.get("parameters", {}).get("jsCode", ""))
