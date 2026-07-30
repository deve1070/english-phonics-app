"""
app/services/biometric_service.py
==================================
Shared biometric-token issuance logic, used by both /auth/register and
/parents/register (and anywhere else that needs to hand a device a
"stay signed in" token after creating an account or logging in).

Previously this lived only in auth.py; moved here once parents.py also
needed it, rather than importing a private (underscore-prefixed)
function across endpoint modules.
"""

import hashlib
import hmac
import secrets
from typing import Optional

from app.core.config import settings
from app.models.auth_models import BiometricToken
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession


def hash_biometric_token(raw: str) -> str:
    return hmac.new(
        settings.SECRET_KEY.encode(), raw.encode(), hashlib.sha256
    ).hexdigest()


async def deactivate_biometric_tokens(db: AsyncSession, user_id: int) -> None:
    await db.execute(
        update(BiometricToken)
        .where(BiometricToken.user_id == user_id)
        .values(is_active=False)
    )


async def issue_biometric_token(
    db: AsyncSession, user_id: int, device_id: Optional[str] = None
) -> str:
    """
    Deactivates any existing biometric tokens for this user (single
    active device at a time) and issues + stores a new one, returning
    the raw (unhashed) token to send back to the client. The client
    must store this - only the hash is kept server-side.
    """
    await deactivate_biometric_tokens(db, user_id)
    raw = secrets.token_urlsafe(32)
    db.add(
        BiometricToken(
            user_id=user_id,
            token_hash=hash_biometric_token(raw),
            device_id=(device_id or "")[:200],
            is_active=True,
        )
    )
    await db.flush()
    return raw
