import os
import json

jobs_dir = r"E:\n8n-video-gemini\video_jobs"
# Get directories in jobs_dir
subdirs = [os.path.join(jobs_dir, d) for d in os.listdir(jobs_dir) if os.path.isdir(os.path.join(jobs_dir, d)) and d != "inbox" and d != "_manual_run"]
# Sort by modification time to find the newest one
subdirs.sort(key=os.path.getmtime, reverse=True)

if subdirs:
    latest_job_dir = subdirs[0]
    print(f"Latest Job Directory: {latest_job_dir}")
    job_json_path = os.path.join(latest_job_dir, "job.json")
    if os.path.exists(job_json_path):
        with open(job_json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        print(f"Job ID: {data.get('job_id')}")
        print(f"Product ID: {data.get('product_id')}")
        print(f"Active Skill: {data.get('active_skill')}")
        
        # Look at the scenes and prompts
        for scene in data.get("scenes", []):
            print(f"\nScene ID: {scene.get('scene_id')}")
            print(f"Prompt Image: {scene.get('promptImage')}")
            print(f"Prompt Text: {scene.get('promptText')[:100]}...")
            # Check how many images are sent in raw request (if we have request body logged)
    else:
        print("job.json not found in latest folder.")
else:
    print("No job folders found.")
