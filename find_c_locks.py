import os

base_dir = r"C:\\"
for entry in os.listdir(base_dir):
    full_path = os.path.join(base_dir, entry)
    if os.path.isdir(full_path):
        if entry.lower() in ["windows", "program files", "program files (x86)", "system volume information", "$recycle.bin"]:
            continue
        try:
            for root, dirs, files in os.walk(full_path):
                if any(x in root.lower() for x in ["node_modules", ".git", "appdata\\local\\microsoft"]):
                    continue
                if "run.lock" in files:
                    path = os.path.join(root, "run.lock")
                    print(f"Found lock file at: {path}")
        except Exception as e:
            pass
