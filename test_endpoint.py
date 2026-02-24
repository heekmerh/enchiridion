import os
import sys
import json

# Add backend directory to sys.path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from dotenv import load_dotenv
from app.sheets import GoogleSheetsClient

load_dotenv(dotenv_path="backend/.env")

from app.routers.referral import get_shipping_rates
import asyncio

async def test_endpoint():
    rates = await get_shipping_rates()
    print(json.dumps(rates, indent=2))

if __name__ == "__main__":
    asyncio.run(test_endpoint())
