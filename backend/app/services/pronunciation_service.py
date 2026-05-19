import io

from app import models
from app.crud.crud_progress import crud_progress
from app.crud.crud_pronunciation_score import crud_pronunciation_score
from app.schemas.pronunciation_score import PronunciationScoreCreate
from app.utils.pronunciation_assessor import assess_pronunciation
from fastapi import HTTPException
from pydub import AudioSegment
from sqlalchemy.ext.asyncio import AsyncSession

# async def assess_student_pronunciation(
#     db: AsyncSession,
#     exercise: models.Exercise,
#     audio_content: bytes,  # Raw bytes from upload
#     user_id: int,
# ) -> dict:
#     # Reference text (no separate Word model; use exercise.content)
#     if exercise.type == models.ExerciseType.PHONEME and exercise.phonemes:
#         reference_text = exercise.phonemes[0].symbol
#     else:
#         reference_text = exercise.content or "say something"

#     # Temp file (privacy: delete after)
#     with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
#         temp_file.write(audio_content)
#         temp_path = temp_70file.name

#     try:
#         assessment = await assess_pronunciation(temp_path, reference_text)
#     finally:
#         if os.path.exists(temp_path):
#             os.remove(temp_path)

#     # Save score
#     score_in = schemas.pronunciation_score.PronunciationScoreCreate(
#         exercise_id=exercise.id, user_id=user_id, score=assessment["score"]
#     )
#     score = await crud.pronunciation_score.create(db, obj_in=score_in)

#     # Update progress
#     progress = await crud.progress.get_by_user_and_exercise(
#         db, user_id=user_id, exercise_id=exercise.id
#     )
#     if progress:
#         progress.score = max(progress.score or 0, assessment["score"])
#         progress.completed = assessment["score"] >= 80
#         progress.attempts += 1
#         await db.commit()

#     return {
#         "score_id": score.id,
#         "score": assessment["score"],
#         "accuracy": assessment.get("accuracy", 0),
#         "fluency": assessment.get("fluency", 0),
#         "feedback": assessment["feedback"],
#         "your_speech": assessment["transcription"],
#     }


async def assess_student_pronunciation(
    db: AsyncSession,
    exercise: models.Exercise,
    audio_content: bytes,
    user_id: int,
) -> dict:
    # Reference text
    if exercise.type == models.ExerciseType.PHONEME and exercise.phonemes:
        reference_text = exercise.phonemes[0].symbol
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

    # Save score
    # score_in = schemas.pronunciation_score.PronunciationScoreCreate(
    #     exercise_id=exercise.id, user_id=user_id, score=assessment["score"]
    # )
    # score_in = PronunciationScoreCreate(
    #     exercise_id=exercise.id, user_id=user_id, score=assessment["score"]
    # )
    score_in = PronunciationScoreCreate(
        exercise_id=exercise.id,
        user_id=user_id,
        score=assessment["score"],
        audio_url=None,
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
