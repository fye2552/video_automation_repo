import json

filepath = r"E:\n8n-video-gemini\workflows\main_generate_video.workflow.json"
with open(filepath, "r", encoding="utf-8") as f:
    data = json.load(f)

print("Nodes in workflow referencing MOYIN:")
for node in data.get("nodes", []):
    node_str = json.dumps(node, ensure_ascii=False)
    if "MOYIN" in node_str or "moyin" in node_str.lower():
        print(f"- Node Name: {node.get('name')}, Type: {node.get('type')}")
        # Print some parameters
        params = node.get("parameters", {})
        print(f"  Parameters keys: {list(params.keys())}")
        if "url" in params:
            print(f"  URL: {params['url']}")
