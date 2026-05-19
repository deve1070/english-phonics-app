"""
app/api/v1/endpoints/tts.py
===========================
TTS endpoints:
  POST /tts/synthesize          → plain text → audio bytes
  POST /tts/phoneme-with-visemes → IPA → audio bytes + viseme sequence

The viseme endpoint is what the Flutter mouth animation uses.
Azure Speech SDK VisemeReceived events fire during synthesis with:
  - viseme_id: int (0-21, Microsoft's 22-shape system)
  - audio_offset: int (100-nanosecond ticks from start of audio)

We collect these during synthesis on the backend and return them
alongside the audio as a JSON response.
"""

import asyncio
import base64
import io
from functools import partial
from typing import List

import azure.cognitiveservices.speech as speechsdk
from app.core.config import settings
from app.utils.tts_synthesizer import (
    PHONEME_IPA_MAP,
    generate_phoneme_sound_ssml,
    generate_ssml,
)
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pathlib import Path
from app.api.deps import get_db
from app.models.phoneme import Phoneme

router = APIRouter(prefix="/tts", tags=["tts"])


# ── Request/Response models ───────────────────────────────────────
class TTSRequest(BaseModel):
    text: str


class VisemeEvent(BaseModel):
    viseme_id: int
    # offset in milliseconds from audio start
    offset_ms: float


class PhonemeAudioWithVisemes(BaseModel):
    # base64-encoded MP3 audio
    audio_b64: str
    visemes: List[VisemeEvent]


def _resolve_audio_file_path(audio_url: str) -> Path | None:
    url_path = audio_url.lstrip("/")
    candidate = Path("uploads") / url_path
    if candidate.exists():
        return candidate
    return None


# ── Plain TTS ─────────────────────────────────────────────────────
@router.post("/synthesize")
async def synthesize(body: TTSRequest):
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


# ── Phoneme audio + visemes ───────────────────────────────────────
@router.post("/phoneme-with-visemes", response_model=PhonemeAudioWithVisemes)
async def phoneme_with_visemes(body: TTSRequest, db: AsyncSession = Depends(get_db)):
    """
    Synthesize a phoneme symbol (e.g. "a", "ʃ (sh)") to audio
    and return both the MP3 bytes AND the viseme sequence.
    
    Now updated to serve pre-recorded human audio if available in the database,
    returning mock generic visemes so the UI still animates.
    """
    # 1. Try to fetch pre-recorded audio from the database
    result = await db.execute(select(Phoneme).filter(Phoneme.symbol == body.text))
    phoneme = result.scalars().first()
    
    if phoneme and phoneme.audio_url:
        file_path = _resolve_audio_file_path(phoneme.audio_url)
        if file_path:
            with open(file_path, "rb") as f:
                audio_bytes = f.read()
            
            # Create a mock open/close mouth animation for human audio
            # 0 = closed, 1 = wide open, 0 = closed
            viseme_events = [
                VisemeEvent(viseme_id=0, offset_ms=0),
                VisemeEvent(viseme_id=1, offset_ms=100),
                VisemeEvent(viseme_id=0, offset_ms=500),
            ]
            
            return PhonemeAudioWithVisemes(
                audio_b64=base64.b64encode(audio_bytes).decode(),
                visemes=viseme_events,
            )

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=(
            "No pre-recorded phoneme audio found. "
            "Phoneme TTS endpoint is configured to use pre-recorded audio only."
        ),
    )


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


def _synthesize_with_visemes(ssml: str):
    """
    Synthesize SSML and collect VisemeReceived events.
    Returns (audio_bytes, [VisemeEvent, ...]).

    Azure fires VisemeReceived events synchronously before returning
    the synthesis result, so we collect them in a list.
    """
    cfg = speechsdk.SpeechConfig(
        subscription=settings.AZURE_SPEECH_KEY,
        region=settings.AZURE_SPEECH_REGION,
    )
    cfg.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Audio24Khz160KBitRateMonoMp3
    )
    synth = speechsdk.SpeechSynthesizer(speech_config=cfg, audio_config=None)

    viseme_events: list[VisemeEvent] = []

    def on_viseme(evt: speechsdk.SpeechSynthesisVisemeEventArgs):
        # audio_offset is in 100-nanosecond ticks → convert to ms
        offset_ms = evt.audio_offset / 10_000
        viseme_events.append(VisemeEvent(viseme_id=evt.viseme_id, offset_ms=offset_ms))

    synth.viseme_received.connect(on_viseme)
    result = synth.speak_ssml_async(ssml).get()

    if result.reason != speechsdk.ResultReason.SynthesizingAudioCompleted:
        cancellation = speechsdk.CancellationDetails(result)
        raise ValueError(
            f"TTS failed: {cancellation.error_code} — {cancellation.error_details}"
        )

    return result.audio_data, viseme_events
