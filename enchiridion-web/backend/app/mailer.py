"""SMTP delivery for transactional and consented marketing email."""

import logging
import os

from fastapi_mail import ConnectionConfig, FastMail, MessageSchema, MessageType

logger = logging.getLogger(__name__)


def frontend_url():
    return os.getenv("FRONTEND_URL", "http://localhost:3000").rstrip("/")


def is_configured():
    return bool(os.getenv("MAIL_USERNAME") and os.getenv("MAIL_PASSWORD"))


async def send_email(email: str, subject: str, body: str, headers: dict | None = None) -> bool:
    if not is_configured():
        logger.warning("Email delivery is not configured")
        return False
    config = ConnectionConfig(
        MAIL_USERNAME=os.environ["MAIL_USERNAME"], MAIL_PASSWORD=os.environ["MAIL_PASSWORD"],
        MAIL_FROM=os.getenv("MAIL_FROM", os.environ["MAIL_USERNAME"]),
        MAIL_PORT=int(os.getenv("MAIL_PORT", "587")),
        MAIL_SERVER=os.getenv("MAIL_SERVER", "smtp.gmail.com"),
        MAIL_FROM_NAME=os.getenv("MAIL_FROM_NAME", "Enchiridion"),
        MAIL_STARTTLS=True, MAIL_SSL_TLS=False, USE_CREDENTIALS=True, VALIDATE_CERTS=True,
        TIMEOUT=10,
    )
    try:
        await FastMail(config).send_message(MessageSchema(
            subject=subject, recipients=[email], body=body, subtype=MessageType.html, headers=headers or {},
        ))
        return True
    except Exception:
        logger.exception("Email delivery failed")
        return False
