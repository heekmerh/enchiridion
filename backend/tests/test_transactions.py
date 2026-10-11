import asyncio

import psycopg
import pytest
from psycopg.rows import dict_row

from app.rewards import credit
from tests.conftest import create_user


@pytest.mark.asyncio
async def test_concurrent_reward_deliveries_only_credit_once(db_url):
    partner_id = create_user(db_url, "concurrent@example.com", referral_code="concurrent")

    async def deliver():
        async with await psycopg.AsyncConnection.connect(db_url, row_factory=dict_row) as db:
            await db.execute("SET search_path = enchiridion_web, public")
            return await credit(db, partner_id, "concurrent-buyer@example.com", "book_purchase", 5)

    results = await asyncio.gather(deliver(), deliver(), deliver())
    assert results.count(True) == 1
    async with await psycopg.AsyncConnection.connect(db_url, row_factory=dict_row) as db:
        row = await (await db.execute(
            "SELECT points FROM enchiridion_web.partners WHERE id = %s", (partner_id,),
        )).fetchone()
        assert row["points"] == 5
