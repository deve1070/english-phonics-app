import io
import os
import tempfile

from app import models
from app.crud.crud_progress import crud_progress
from app.crud.crud_pronunciation_score import crud_pronunciation_score
from app.schemas.pronunciation_score import PronunciationScoreCreate
from app.utils.pronunciation_assessor import assess_pronunciation
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
#         temp_path = temp_file.name

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
        audio_segment = AudioSegment.from_file(io.BytesIO(audio_content))
        audio_segment = (
            audio_segment.set_frame_rate(16000)  # 16kHz — required by Azure SDK
            .set_channels(1)  # mono
            .set_sample_width(2)  # 16-bit PCM
        )
    except Exception:
        return {
            "score": 0,
            "accuracy": 0,
            "fluency": 0,
            "feedback": "Could not read audio file. Please try recording again.",
            "your_speech": "",
        }

    # Write converted WAV to temp file
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
        audio_segment.export(temp_file, format="wav")
        temp_path = temp_file.name

    try:
        assessment = await assess_pronunciation(temp_path, reference_text)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

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
    progress = await crud_progress.get_by_user_and_exercise(
        db, user_id=user_id, exercise_id=exercise.id
    )
    if progress:
        db.add(progress)  # ← required before commit
        progress.score = max(progress.score or 0, assessment["score"])
        progress.completed = assessment["score"] >= 80
        progress.attempts += 1
        await db.commit()

    return {
        "score_id": score.id,
        "score": assessment["score"],
        "accuracy": assessment.get("accuracy", 0),
        "fluency": assessment.get("fluency", 0),
        "feedback": assessment["feedback"],
        "your_speech": assessment["transcription"],
    }
