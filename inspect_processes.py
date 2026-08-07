import subprocess

try:
    output = subprocess.check_output("tasklist /v", shell=True).decode("gbk", errors="ignore")
    lines = output.splitlines()
    print("Process List:")
    for line in lines:
        if any(x in line.lower() for x in ["git", "ssh", "powershell", "cmd", "node"]):
            print(line)
except Exception as e:
    print("Error listing processes:", e)
