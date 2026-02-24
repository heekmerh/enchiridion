import hmac
import hashlib
import json
import requests
import os
from dotenv import load_dotenv

load_dotenv()

SECRET = os.getenv("PAYSTACK_SECRET_KEY")
URL = "http://localhost:8000/referral/paystack/webhook"

if not SECRET:
    print("Error: PAYSTACK_SECRET_KEY not found in .env")
    exit(1)

payload = {
    "event": "charge.success",
    "data": {
        "status": "success",
        "customer": {
            "email": "heekmerh@gmail.com"
        },
        "metadata": {
            "product": "book"
        },
        "amount": 1000000, # 10,000 NGN in kobo
        "reference": "TEST-WEBHOOK-" + str(os.getpid())
    }
}

body = json.dumps(payload, separators=(',', ':'))
signature = hmac.new(
    SECRET.encode('utf-8'),
    body.encode('utf-8'),
    hashlib.sha512
).hexdigest()

headers = {
    "Content-Type": "application/json",
    "x-paystack-signature": signature
}

print(f"Sending mock Paystack webhook to {URL}...")
print(f"Payload: {body}")
print(f"Signature: {signature}")

try:
    response = requests.post(URL, data=body, headers=headers)
    print(f"Response Status: {response.status_code}")
    print(f"Response Body: {response.text}")
except Exception as e:
    print(f"Error sending request: {e}")
