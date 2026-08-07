import urllib.request
import json

env_path = r"E:\n8n-video-gemini\.env"
api_key = ""
with open(env_path, "r", encoding="utf-8") as f:
    for line in f:
        if line.startswith("OPENAI_API_KEY="):
            api_key = line.split("=", 1)[1].strip()

url = "https://api.aiyxgaw.com/v1/chat/completions"
model = "gemini-pro-agent"

payload = {
    "model": model,
    "messages": [
        {"role": "user", "content": "Hi, reply with just one word: hello"}
    ],
    "max_tokens": 10
}

print(f"Testing API connection to {url}...")
print(f"Model: {model}")
print(f"Payload: {json.dumps(payload)}")

req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(req, timeout=30) as res:
        print(f"Status: {res.getcode()}")
        print("Response:")
        print(res.read().decode("utf-8"))
except Exception as e:
    print(f"API Call failed: {e}")
