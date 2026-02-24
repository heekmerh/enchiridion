import requests
import json

def test_share():
    url = "http://127.0.0.1:3000/api/referral/record-share?platform=proxy_test_python"
    payload = {
        "refCode": "HA8543",
        "ip": "127.0.0.1",
        "userAgent": "python_test"
    }
    headers = {"Content-Type": "application/json"}
    
    print(f"Sending POST to {url}...")
    try:
        response = requests.post(url, json=payload, headers=headers)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

def test_visit():
    url = "http://127.0.0.1:3000/api/referral/record-visit"
    payload = {
        "refCode": "HA8543",
        "ip": "127.0.0.2", # Different IP to avoid "already tracked" or self-referral
        "userAgent": "python_test_visit"
    }
    headers = {"Content-Type": "application/json"}
    
    print(f"Sending POST to {url}...")
    try:
        response = requests.post(url, json=payload, headers=headers)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_share()
    test_visit()
