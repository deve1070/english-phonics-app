import io
from pathlib import Path
from typing import List, Optional

from app import crud, models, schemas
from app.api.deps import get_db
from app.core.security import get_current_active_user, get_current_admin
from app.db.session import AsyncSessionLocal
from app.models.lesson import Lesson
from app.models.phoneme import Phoneme
from app.models.user import User
from app.services.exercise_generation_service import generate_exercises_for_phoneme
from app.services.pronunciation_service import assess_student_phoneme_pronunciation
from app.utils.audio import save_audio_file
from app.utils.tts_synthesizer import (
    PHONEME_IPA_MAP,
    generate_phoneme_sound_ssml,
    generate_ssml,
    synthesize_tts,
)
from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
    status,
    BackgroundTasks,
)
from fastapi import Path as FastAPIPath
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

router = APIRouter(prefix="/phonemes", tags=["phonemes"])

def _resolve_phoneme_audio_path(audio_url: str) -> Path | None:
    if not audio_url:
        return None

    # Supports:
    # - "/audio_standardized/foo.mp3"  -> uploads/audio_standardized/foo.mp3
    # - "sound_a.mp3"                 -> uploads/audio/sound_a.mp3 (legacy)
    url_path = audio_url.lstrip("/")
    candidate = Path("uploads") / url_path
    if candidate.exists():
        return candidate

    filename = Path(url_path).name
    legacy = Path("uploads/audio") / filename
    if legacy.exists():
        return legacy

    return None


async def _background_generate_exercises_for_new_phoneme(phoneme_id: int):
    async with AsyncSessionLocal() as task_db:
        result = await task_db.execute(select(Phoneme).filter(Phoneme.id == phoneme_id))
        target_phoneme = result.scalar_one_or_none()
        if not target_phoneme:
            return

        allowed_result = await task_db.execute(
            select(Phoneme).filter(
                Phoneme.lesson_id == target_phoneme.lesson_id,
                Phoneme.order <= target_phoneme.order,
            )
        )
        allowed_phonemes = allowed_result.scalars().all()
        try:
            await generate_exercises_for_phoneme(
                task_db,
                target_phoneme=target_phoneme,
                allowed_phonemes=allowed_phonemes,
            )
        except Exception:
            # Keep phoneme creation successful even if generation fails.
            pass


@router.post("/", response_model=schemas.Phoneme, status_code=status.HTTP_201_CREATED)
async def create_phoneme(
    background_tasks: BackgroundTasks,
    symbol: str = Form(...),
    description: str = Form(...),
    type: models.PhonemeType = Form(...),
    audio_file: UploadFile = File(...),
    lesson_id: int = Form(...),
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_admin),
):
    result = await db.execute(select(Lesson).where(Lesson.id == lesson_id))
    if result.scalar_one_or_none() is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Lesson with id {lesson_id} not found.",
        )
    audio_url = await save_audio_file(audio_file)
    phoneme_in = schemas.PhonemeCreate(
        symbol=symbol,
        description=description,
        type=type,
        audio_url=audio_url,
        lesson_id=lesson_id,
    )
    created = await crud.phoneme.create(db=db, obj_in=phoneme_in)
    if background_tasks is not None:
        background_tasks.add_task(
            _background_generate_exercises_for_new_phoneme, created.id
        )
    return created


@router.get("/", response_model=List[schemas.Phoneme])
async def get_phonemes(
    db: AsyncSession = Depends(get_db),
    skip: int = 0,
    limit: int = 100,
):
    return await crud.phoneme.get_multi(db=db, skip=skip, limit=limit)


@router.post("/{phoneme_id}/submit-pronunciation")
async def submit_phoneme_pronunciation(
    phoneme_id: int = FastAPIPath(...),
    audio: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    result = await db.execute(select(Phoneme).where(Phoneme.id == phoneme_id))
    phoneme = result.scalar_one_or_none()
    if not phoneme:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Phoneme not found"
        )

    audio_content = await audio.read()
    if not audio_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Audio file is empty.",
        )

    return await assess_student_phoneme_pronunciation(
        db=db,
        phoneme=phoneme,
        audio_content=audio_content,
        user_id=current_user.id,
    )


# IMPORTANT: /{phoneme_id}/audio MUST come before /{phoneme_id}
@router.get("/{phoneme_id}/audio")
async def get_phoneme_audio(
    phoneme_id: int = FastAPIPath(...),
    db: AsyncSession = Depends(get_db),
    _: models.User = Depends(get_current_active_user),
):
    result = await db.execute(
        select(Phoneme)
        .options(selectinload(Phoneme.exercises))
        .filter(Phoneme.id == phoneme_id)
    )
    phoneme = result.scalar_one_or_none()
    if not phoneme:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Phoneme not found"
        )

    # Priority 1: pre-recorded file
    if phoneme.audio_url:
        local_path = _resolve_phoneme_audio_path(phoneme.audio_url)
        if local_path:
            filename = local_path.name

            def iter_file():
                with open(local_path, "rb") as f:
                    yield from f

            return StreamingResponse(
                iter_file(),
                media_type="audio/mpeg",
                headers={
                    "Content-Disposition": f'inline; filename="{filename}"',
                    "Cache-Control": "public, max-age=86400",
                },
            )

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=(
            "No pre-recorded phoneme audio found. "
            "Phoneme playback is configured to use pre-recorded audio only."
        ),
    )


@router.get("/{phoneme_id}", response_model=schemas.Phoneme)
async def get_phoneme(
    phoneme_id: int = FastAPIPath(...),
    db: AsyncSession = Depends(get_db),
):
    phoneme = await crud.phoneme.get(db=db, id=phoneme_id)
    if not phoneme:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Phoneme not found"
        )
    return phoneme


@router.put("/{phoneme_id}", response_model=schemas.Phoneme)
async def update_phoneme(
    phoneme_id: int = FastAPIPath(...),
    symbol: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    type: Optional[models.PhonemeType] = Form(None),
    audio_file: Optional[UploadFile] = File(None),
    lesson_id: Optional[int] = Form(None),
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_admin),
):
    phoneme = await crud.phoneme.get(db=db, id=phoneme_id)
    if not phoneme:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Phoneme not found"
        )
    update_data = {}
    if symbol is not None:
        update_data["symbol"] = symbol
    if description is not None:
        update_data["description"] = description
    if type is not None:
        update_data["type"] = type
    if lesson_id is not None:
        result = await db.execute(select(Lesson).where(Lesson.id == lesson_id))
        if result.scalar_one_or_none() is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Lesson {lesson_id} not found.",
            )
        update_data["lesson_id"] = lesson_id
    if audio_file is not None:
        update_data["audio_url"] = await save_audio_file(audio_file)

    updated = await crud.phoneme.update(
        db=db, db_obj=phoneme, obj_in=schemas.PhonemeUpdate(**update_data)
    )
    return updated


@router.delete("/{phoneme_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_phoneme(
    phoneme_id: int = FastAPIPath(...),
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_admin),
):
    phoneme = await crud.phoneme.get(db=db, id=phoneme_id)
    if not phoneme:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Phoneme not found"
        )
    await crud.phoneme.remove(db=db, id=phoneme_id)
    return None
