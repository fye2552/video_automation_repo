import json

workflows = [
    r"E:\n8n-video-gemini\workflows\local_product_upload_to_github.workflow.json",
    r"E:\n8n-video-gemini\workflows\main_generate_video.workflow.json"
]

for wf in workflows:
    print(f"\n=== Workflow: {wf} ===")
    with open(wf, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    # Search nodes
    for node in data.get("nodes", []):
        node_str = json.dumps(node)
        if "raw.githubusercontent.com" in node_str or "githubusercontent" in node_str:
            print(f"Found match in Node: {node.get('name')}")
            # Print parameters containing it
            for k, v in node.get('parameters', {}).items():
                if "githubusercontent" in str(v):
                    print(f"  Param {k}: {v}")
