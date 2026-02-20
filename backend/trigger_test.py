import requests
import json

def trigger_test():
    url = "http://127.0.0.1:8002/auth/forgot-password"
    email = "heekmerh@gmail.com"
    print(f"Triggering forgot-password for: {email}")
    try:
        response = requests.post(url, json={"email": email}, headers={"Content-Type": "application/json"})
        print(f"Status: {response.status_code}")
        print(f"Body: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    trigger_test()
