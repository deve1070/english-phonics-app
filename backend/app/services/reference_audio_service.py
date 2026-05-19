import io
from pathlib import Path

from app import models
from app.utils.tts_synthesizer import synthesize_tts
from fastapi import HTTPException
from fastapi.responses import StreamingResponse


def _resolve_audio_file_path(audio_url: str) -> Path | None:
    url_path = audio_url.lstrip("/")
    candidate = Path("uploads") / url_path
    if candidate.exists():
        return candidate
    return None


async def get_reference_audio_stream(
    exercise: models.Exercise, blending: bool = False
) -> StreamingResponse:
    if (
        exercise.type == models.ExerciseType.PHONEME
        and exercise.phonemes
        and not blending
    ):
        phoneme = exercise.phonemes[0]
        if phoneme.audio_url:
            file_path = _resolve_audio_file_path(phoneme.audio_url)
            if file_path:
                def iterfile():
                    with open(file_path, "rb") as f:
                        yield from f

                return StreamingResponse(iterfile(), media_type="audio/mpeg")
        raise HTTPException(
            404,
            "No pre-recorded audio found for this phoneme. "
            "Phoneme reference audio uses pre-recorded sounds only.",
        )

    # TTS: use exercise content (no separate Word model)
    text = exercise.content or "Practice this!"
    if not text.strip():
        raise HTTPException(400, "No text for audio")

    audio_bytes = await synthesize_tts(text, blending=blending)
    return StreamingResponse(io.BytesIO(audio_bytes), media_type="audio/mpeg")
