import os
import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile

UPLOAD_DIR = os.path.join(os.getcwd(), "uploads/audio")
os.makedirs(UPLOAD_DIR, exist_ok=True)
ALLOWED_EXTENSIONS = {".mp3", ".wav", ".ogg", ".webm", ".m4a"}

# A phonics exercise recording is a single word/sentence — a few hundred KB
# at most. 15MB is generous headroom while still capping worst-case memory
# use per request (no request body size limit exists elsewhere in the app).
MAX_AUDIO_UPLOAD_BYTES = 15 * 1024 * 1024


async def read_audio_bounded(file: UploadFile, max_bytes: int = MAX_AUDIO_UPLOAD_BYTES) -> bytes:
    """
    Read an uploaded audio file's contents, aborting early (rather than
    buffering the whole thing into memory first) if it exceeds max_bytes.
    """
    chunks = []
    total = 0
    while True:
        chunk = await file.read(1024 * 1024)  # 1MB at a time
        if not chunk:
            break
        total += len(chunk)
        if total > max_bytes:
            raise HTTPException(
                status_code=413,
                detail=f"Audio file is too large (max {max_bytes // (1024 * 1024)}MB).",
            )
        chunks.append(chunk)
    return b"".join(chunks)


async def save_audio_file(file: UploadFile) -> str:
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Invalid file format.")
    filename = f"{uuid.uuid4()}{ext}"
    file_path = os.path.join(UPLOAD_DIR, filename)

    content = await read_audio_bounded(file)
    with open(file_path, "wb") as buffer:
        buffer.write(content)
    return f"/audio/{filename}"


def resolve_stored_audio(url: str) -> Path | None:
    """The file on disk behind a stored audio url, or None if it is not one.

    Stored urls look like "/audio/<uuid>.mp3" — the value save_audio_file
    returned. Anything that resolves outside the uploads directory is
    treated as not ours: these strings reach here from database columns,
    and a caller that is about to unlink one should never be able to be
    steered at a path somewhere else on the machine.
    """
    if not url:
        return None

    root = Path(UPLOAD_DIR).parent.resolve()
    candidate = (root / url.lstrip("/")).resolve()
    if not candidate.is_relative_to(root):
        return None
    return candidate


def delete_audio_file(url: str) -> bool:
    """Remove a stored recording, reporting whether a file went.

    Never raises. Deleting the file a row no longer points at is
    housekeeping, and housekeeping that can fail a request a parent has
    already been told succeeded is worse than an orphan left on disk.
    """
    path = resolve_stored_audio(url)
    if path is None:
        return False
    try:
        path.unlink()
        return True
    except OSError:
        return False
