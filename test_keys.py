import urllib.request
import json

keys = {
    "OPENAI_API_KEY": "sk-1ks925FOA3Zzr249DAFpOoqexX0XpHHFUvhFvyfWwIpIqLA3",
    "OMINI_API_KEY (MOYIN_API_KEY)": "sk-Cz2XXQbs7xaiUOgN9Ps8oPhkJaB6Hd24yyIZdojsbtoxTxWh"
}

url = "https://api.aiyxgaw.com/v1/chat/completions"
model = "gemini-pro-agent"

payload = {
    "model": model,
    "messages": [
        {"role": "user", "content": "Hi"}
    ],
    "max_tokens": 5
}

for name, key in keys.items():
    print(f"\n--- Testing Key: {name} ---")
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            print(f"Result: SUCCESS (HTTP {res.getcode()})")
            print("Response:")
            print(res.read().decode("utf-8"))
    except Exception as e:
        print(f"Result: FAILED ({e})")
