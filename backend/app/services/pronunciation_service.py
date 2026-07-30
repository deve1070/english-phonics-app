import io
import re
from typing import Optional

from app import models
from app.crud.crud_progress import crud_progress
from app.crud.crud_pronunciation_score import crud_pronunciation_score
from app.schemas.pronunciation_score import PronunciationScoreCreate
from app.utils.pronunciation_assessor import assess_pronunciation
from fastapi import HTTPException
from pydub import AudioSegment
from sqlalchemy.ext.asyncio import AsyncSession


def split_into_sentences(text: str) -> list[str]:
    """
    Splits on ., !, or ? followed by whitespace or end-of-string, and
    keeps the punctuation attached to each sentence. Deliberately
    simple (no NLP dependency) - the client mirrors this exact logic
    in Dart (see lib/shared/utils/sentence_splitter.dart) so both
    sides always agree on what "sentence index N" refers to for a
    given paragraph. If either side's splitting logic changes, the
    other must change too.
    """
    if not text:
        return []
    parts = re.split(r"(?<=[.!?])\s+", text.strip())
    return [p.strip() for p in parts if p.strip()]


async def assess_student_pronunciation(
    db: AsyncSession,
    exercise: models.Exercise,
    audio_content: bytes,
    user_id: int,
    sentence_index: Optional[int] = None,
) -> dict:
    # Reference text.
    # sentence_index is only meaningful for PARAGRAPH exercises, where
    # a client may submit audio for just one sentence at a time (for
    # real-time-feeling feedback without waiting for the whole
    # paragraph) rather than the full recording. Scoring a single
    # sentence's audio against the *entire* paragraph as reference
    # would produce a nonsense result (everything after that sentence
    # would look "missing"), so when a valid index is given, narrow the
    # reference text down to just that sentence.
    if exercise.type == models.ExerciseType.PHONEME and exercise.phonemes:
        reference_text = exercise.phonemes[0].symbol
    elif exercise.type == models.ExerciseType.PARAGRAPH and sentence_index is not None:
        sentences = split_into_sentences(exercise.content or "")
        if sentence_index < 0 or sentence_index >= len(sentences):
            raise HTTPException(
                status_code=400,
                detail=f"sentence_index {sentence_index} is out of range for this exercise.",
            )
        reference_text = sentences[sentence_index]
    else:
        reference_text = exercise.content or "say something"

    # Convert whatever format we receive → standard WAV (16kHz, mono, 16-bit PCM)
    # Azure Speech SDK requires this exact format
    try:
        # Convert audio
        audio_segment = AudioSegment.from_file(io.BytesIO(audio_content))

        # Reject recordings that are too short or effectively silent.
        # (Kids can tap mic and submit without speaking.)
        if len(audio_segment) < 700:
            raise HTTPException(
                status_code=400, detail="Recording too short. Please try again."
            )
        if audio_segment.dBFS == float("-inf") or audio_segment.dBFS < -40:
            raise HTTPException(
                status_code=400,
                detail="No speech detected. Please speak louder and try again.",
            )

        audio_segment = (
            audio_segment.set_frame_rate(16000)  # 16kHz
            .set_channels(1)  # mono
            .set_sample_width(2)  # 16-bit PCM
        )
        
        wav_buffer = io.BytesIO()
        audio_segment.export(wav_buffer, format="wav")
        assessment = await assess_pronunciation(wav_buffer.getvalue(), reference_text)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Could not process audio: {str(e)}. Please try again.",
        )

    # Save score — include phoneme_id if this exercise targets a specific phoneme
    # so that parents.py _compute_progress_summary can group scores per phoneme.
    phoneme_id: Optional[int] = (
        exercise.phonemes[0].id
        if exercise.phonemes
        else None
    )
    score_in = PronunciationScoreCreate(
        exercise_id=exercise.id,
        user_id=user_id,
        score=assessment["score"],
        audio_url=None,
        phoneme_id=phoneme_id,
    )
    score = await crud_pronunciation_score.create(db, obj_in=score_in)

    # Update progress
    await crud_progress.upsert_after_attempt(
        db,
        user_id=user_id,
        lesson_id=exercise.lesson_id,
        exercise_id=exercise.id,
        score=float(assessment["score"] or 0),
    )

    return {
        "score_id": score.id,
        "score": assessment["score"],
        "accuracy": assessment.get("accuracy", 0),
        "fluency": assessment.get("fluency", 0),
        "feedback": assessment["feedback"],
        "your_speech": assessment["transcription"],
    }


async def assess_student_phoneme_pronunciation(
    db: AsyncSession,
    phoneme: models.Phoneme,
    audio_content: bytes,
    user_id: int,
) -> dict:
    try:
        audio_segment = AudioSegment.from_file(io.BytesIO(audio_content))

        if len(audio_segment) < 700:
            raise HTTPException(
                status_code=400, detail="Recording too short. Please try again."
            )
        if audio_segment.dBFS == float("-inf") or audio_segment.dBFS < -40:
            raise HTTPException(
                status_code=400,
                detail="No speech detected. Please speak louder and try again.",
            )

        audio_segment = (
            audio_segment.set_frame_rate(16000)
            .set_channels(1)
            .set_sample_width(2)
        )

        wav_buffer = io.BytesIO()
        audio_segment.export(wav_buffer, format="wav")
        assessment = await assess_pronunciation(wav_buffer.getvalue(), phoneme.symbol)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Could not process audio: {str(e)}. Please try again.",
        )

    return {
        "score": assessment["score"],
        "accuracy": assessment.get("accuracy", 0),
        "fluency": assessment.get("fluency", 0),
        "feedback": assessment["feedback"],
        "your_speech": assessment["transcription"],
    }
