import requests
import json

try:
    response = requests.get('http://127.0.0.1:8002/referral/leaderboard', timeout=5)
    print(f"Status: {response.status_code}")
    data = response.json()
    print(f"Count: {len(data)}")
    print(json.dumps(data[:3], indent=2))
except Exception as e:
    print(f"Error: {e}")
