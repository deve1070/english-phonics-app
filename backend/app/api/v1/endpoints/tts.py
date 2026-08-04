"""
app/api/v1/endpoints/tts.py
===========================
TTS endpoints:
  POST /tts/synthesize → plain text → audio bytes

There was a POST /tts/phoneme-with-visemes here, serving a phoneme's
recorded audio alongside a hardcoded open-shut-open sequence for the app
to draw a mouth from. Both ends of that are gone. The mouth it drew was
wrong for all but one sound in the curriculum, and the sequence it drew
from was the same three numbers for every sound in the language, which no
amount of finishing would have made teachable. The child's own recording
of a sound reaches the app through /phonemes; nothing needed this.
"""

import asyncio
import io
from functools import partial

import azure.cognitiveservices.speech as speechsdk
from app.core.config import settings
from app.core.security import get_current_active_user
from app.models.user import User
from app.utils.tts_synthesizer import generate_ssml
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

router = APIRouter(prefix="/tts", tags=["tts"])


# ── Request/Response models ───────────────────────────────────────
class TTSRequest(BaseModel):
    text: str


# ── Plain TTS ─────────────────────────────────────────────────────
@router.post("/synthesize")
async def synthesize(
    body: TTSRequest,
    _: User = Depends(get_current_active_user),
):
    """
    Synthesize plain text to speech.
    Returns audio/mpeg stream.
    Used by Spelling Bee to read words aloud.
    """
    loop = asyncio.get_event_loop()
    audio_bytes = await loop.run_in_executor(
        None, partial(_synthesize_plain, body.text)
    )
    return StreamingResponse(io.BytesIO(audio_bytes), media_type="audio/mpeg")


# ── Blocking helpers (run in thread pool) ────────────────────────
def _synthesize_plain(text: str) -> bytes:
    cfg = speechsdk.SpeechConfig(
        subscription=settings.AZURE_SPEECH_KEY,
        region=settings.AZURE_SPEECH_REGION,
    )
    cfg.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Audio24Khz160KBitRateMonoMp3
    )
    synth = speechsdk.SpeechSynthesizer(speech_config=cfg, audio_config=None)
    ssml = generate_ssml(text, blending=False)
    result = synth.speak_ssml_async(ssml).get()

    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        return result.audio_data
    raise ValueError("TTS synthesis failed")
