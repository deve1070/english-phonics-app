import io
from pathlib import Path

from app import models
from app.utils.tts_synthesizer import synthesize_tts
from fastapi import HTTPException
from fastapi.responses import StreamingResponse


async def get_reference_audio_stream(
    exercise: models.Exercise, blending: bool = False
) -> StreamingResponse:
    if (
        exercise.type == models.ExerciseType.PHONEME
        and exercise.phonemes
        and not blending
    ):
        phoneme = exercise.phonemes[0]
        if not phoneme.audio_url:
            raise HTTPException(404, "No pre-recorded audio")

        file_path = Path("uploads/audio") / Path(phoneme.audio_url).name
        if not file_path.exists():
            raise HTTPException(500, "Audio file missing")

        def iterfile():
            with open(file_path, "rb") as f:
                yield from f

        return StreamingResponse(iterfile(), media_type="audio/mpeg")

    # TTS: use exercise content (no separate Word model)
    text = exercise.content or "Practice this!"
    if not text.strip():
        raise HTTPException(400, "No text for audio")

    audio_bytes = await synthesize_tts(text, blending=blending)
    return StreamingResponse(io.BytesIO(audio_bytes), media_type="audio/mpeg")
