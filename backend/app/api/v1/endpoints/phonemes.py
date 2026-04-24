import io
from pathlib import Path
from typing import List, Optional

from app import crud, models, schemas
from app.api.deps import get_db
from app.core.security import get_current_active_user, get_current_admin
from app.models.lesson import Lesson
from app.models.phoneme import Phoneme
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
)
from fastapi import Path as FastAPIPath
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

router = APIRouter(prefix="/phonemes", tags=["phonemes"])


@router.post("/", response_model=schemas.Phoneme, status_code=status.HTTP_201_CREATED)
async def create_phoneme(
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
    return await crud.phoneme.create(db=db, obj_in=phoneme_in)


@router.get("/", response_model=List[schemas.Phoneme])
async def get_phonemes(
    db: AsyncSession = Depends(get_db),
    skip: int = 0,
    limit: int = 100,
):
    return await crud.phoneme.get_multi(db=db, skip=skip, limit=limit)


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
        filename = Path(phoneme.audio_url).name
        local_path = Path("uploads/audio") / filename
        if local_path.exists():

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

    # Priority 2: IPA isolated sound
    ipa = PHONEME_IPA_MAP.get(phoneme.symbol)
    if ipa:
        ssml = generate_phoneme_sound_ssml(ipa, repeat=3)
    else:
        # Priority 3: clean description fallback
        import re

        clean = re.sub(r"/[^/]+/", "", phoneme.description or "")
        clean = re.sub(r"\s+", " ", clean).strip()
        ssml = generate_ssml(clean or phoneme.symbol, blending=False)

    try:
        audio_bytes = await synthesize_tts(text="", ssml_override=ssml)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"TTS generation failed: {exc}",
        )

    return StreamingResponse(
        io.BytesIO(audio_bytes),
        media_type="audio/mpeg",
        headers={"Cache-Control": "no-store"},
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
