"""Request-scoped Supabase Postgres transactions for serverless execution."""

import os
from pathlib import Path

from dotenv import load_dotenv
from fastapi import HTTPException
import psycopg
from psycopg.rows import dict_row

load_dotenv(Path(__file__).resolve().parents[1] / ".env")


async def get_db():
    url = os.getenv("SUPABASE_DB_URL", "")
    if not url:
        raise HTTPException(503, "Supabase database is not configured")
    # Supabase's transaction pooler cannot retain prepared statements per client.
    async with await psycopg.AsyncConnection.connect(
        url, row_factory=dict_row, prepare_threshold=None,
        connect_timeout=10, sslmode="require",
    ) as connection:
        async with connection.transaction():
            await connection.execute("SET LOCAL search_path = enchiridion_web, public")
            await connection.execute("SET LOCAL statement_timeout = '15s'")
            yield connection
