from typing import List, Optional

from app import crud, models, schemas
from app.api.deps import get_db
from app.core.security import get_current_admin
from app.utils.audio import save_audio_file
from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Path,
    UploadFile,
    status,
)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Lesson

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
    """Create a new phoneme with pre-recoreded human audio(pure sound)."""

    # Ensure lesson exists
    result = await db.execute(select(Lesson).where(Lesson.id == lesson_id))
    if result.scalar_one_or_none() is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Lesson with id {lesson_id} not found. Create a lesson first (e.g. run seed_lessons.py).",
        )

    # Upload and get URL
    audio_url = await save_audio_file(audio_file)
    phoneme_in = schemas.PhonemeCreate(
        symbol=symbol,
        description=description,
        type=type,
        audio_url=audio_url,
        lesson_id=lesson_id,
    )
    phoneme = await crud.phoneme.create(db=db, obj_in=phoneme_in)
    return phoneme


@router.get("/", response_model=List[schemas.Phoneme])
async def get_phonemes(
    db: AsyncSession = Depends(get_db),
    skip: int = 0,
    limit: int = 100,
):
    """List all phonemes(public or student access ok)."""
    phonemes = await crud.phoneme.get_multi(db=db, skip=skip, limit=limit)
    return phonemes


@router.get("/{phoneme_id}", response_model=schemas.Phoneme)
async def get_phoneme(phoneme_id: int = Path(...), db: AsyncSession = Depends(get_db)):
    """Get a specific phoneme by ID (public or student access ok)."""
    phoneme = await crud.phoneme.get(db=db, id=phoneme_id)
    if not phoneme:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Phoneme not found"
        )
    return phoneme


@router.put("/{phoneme_id}", response_model=schemas.Phoneme)
async def update_phoneme(
    phoneme_id: int = Path(...),
    symbol: Optional[str] = Form(...),
    description: Optional[str] = Form(...),
    type: Optional[models.PhonemeType] = Form(...),
    audio_file: Optional[UploadFile] = File(None),
    lesson_id: Optional[int] = Form(...),
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_admin),
):
    """Update phoneme (audio optional-replace if unloaded)"""
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
                detail=f"Lesson with id {lesson_id} not found.",
            )
        update_data["lesson_id"] = lesson_id
    if audio_file is not None:
        audio_url = await save_audio_file(audio_file)
        update_data["audio_url"] = audio_url
    phoneme_in = schemas.PhonemeUpdate(**update_data)
    updated_phoneme = await crud.phoneme.update(
        db=db, db_obj=phoneme, obj_in=phoneme_in
    )
    return updated_phoneme


@router.delete("/{phoneme_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_phoneme(
    phoneme_id: int = Path(...),
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_admin),
):
    """Delete a phoneme by ID."""
    phoneme = await crud.phoneme.get(db=db, id=phoneme_id)
    if not phoneme:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Phoneme not found"
        )
    await crud.phoneme.remove(db=db, id=phoneme_id)
    return None
