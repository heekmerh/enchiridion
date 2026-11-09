"""Idempotent ledger of provider notifications, including rejected deliveries and failed processing."""

import logging
import uuid
from collections.abc import Awaitable, Callable

from fastapi import HTTPException
from psycopg.types.json import Jsonb

logger = logging.getLogger(__name__)

MAX_ATTEMPTS = 5
FINISHED_STATUSES = frozenset({"processed", "ignored"})


class UnmatchedEvent(Exception):
    """Raised when a verified event cannot yet be tied to a subscription; it stays retryable."""


async def record_rejected(db, provider: str, event_type: str = ""):
    await db.execute(
        """INSERT INTO billing.payment_events(provider, event_id, event_type, authentication, processing_status)
           VALUES (%s, %s, %s, 'rejected', 'ignored')""",
        (provider, "rejected:" + uuid.uuid4().hex, event_type),
    )


async def record_verified(db, provider: str, event_id: str, event_type: str, payload: dict) -> dict:
    return await (await db.execute(
        """INSERT INTO billing.payment_events(provider, event_id, event_type, authentication, payload)
           VALUES (%s, %s, %s, 'verified', %s)
           ON CONFLICT (provider, event_id) DO UPDATE SET event_type = billing.payment_events.event_type
           RETURNING *""",
        (provider, event_id, event_type, Jsonb(payload)),
    )).fetchone()


async def finish(db, event_id, status: str, error: str | None = None):
    await db.execute(
        """UPDATE billing.payment_events
           SET processing_status = %s, last_error = %s, attempts = attempts + 1,
               processed_at = CASE WHEN %s IN ('processed', 'ignored') THEN now() ELSE processed_at END
           WHERE id = %s""",
        (status, error, status, event_id),
    )


async def process(db, event: dict, handler: Callable[[], Awaitable[str]]) -> tuple[int, dict]:
    if event["processing_status"] in FINISHED_STATUSES:
        return 200, {"status": "duplicate"}
    try:
        async with db.transaction():
            outcome = await handler()
    except UnmatchedEvent as exc:
        await finish(db, event["id"], "failed", str(exc))
        return 200, {"status": "unmatched"}
    except HTTPException as exc:
        await finish(db, event["id"], "failed", str(exc.detail))
        if exc.status_code >= 500:
            return 503, {"status": "retry"}
        return 200, {"status": "rejected", "detail": exc.detail}
    except Exception as exc:
        logger.exception("Payment event %s failed", event["event_id"])
        await finish(db, event["id"], "failed", type(exc).__name__)
        return 503, {"status": "retry"}
    await finish(db, event["id"], "ignored" if outcome == "ignored" else "processed")
    return 200, {"status": outcome}
