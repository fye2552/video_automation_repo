import os
import time

jobs_dir = r"E:\n8n-video-gemini\openai_jobs"
if os.path.exists(jobs_dir):
    subdirs = [os.path.join(jobs_dir, d) for d in os.listdir(jobs_dir) if os.path.isdir(os.path.join(jobs_dir, d))]
    subdirs.sort(key=os.path.getmtime, reverse=True)
    if subdirs:
        latest_dir = subdirs[0]
        print(f"Latest OpenAI Job Directory: {latest_dir}")
        print(f"Created: {time.ctime(os.path.getmtime(latest_dir))}")
        
        log_path = os.path.join(latest_dir, "openai.log")
        if os.path.exists(log_path):
            print("\n=== Content of openai.log ===")
            with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
                print(f.read())
        else:
            print("openai.log does not exist in this directory.")
    else:
        print("No job directories found inside openai_jobs.")
else:
    print("openai_jobs directory does not exist.")
