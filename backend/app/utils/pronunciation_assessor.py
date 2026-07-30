import asyncio
import tempfile
from pathlib import Path

import azure.cognitiveservices.speech as speechsdk
from app.core.config import settings


def create_speech_config():
    if not settings.AZURE_SPEECH_KEY:
        raise ValueError("AZURE_SPEECH_KEY missing")

    if not settings.AZURE_SPEECH_REGION:
        raise ValueError("AZURE_SPEECH_REGION missing")

    speech_config = speechsdk.SpeechConfig(
        subscription=settings.AZURE_SPEECH_KEY,
        region=settings.AZURE_SPEECH_REGION,
    )

    speech_config.set_property(
        speechsdk.PropertyId.SpeechServiceResponse_JsonResult,
        "true",
    )

    return speech_config


async def assess_pronunciation(audio_wav_bytes: bytes, reference_text: str) -> dict:
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
        temp_path = Path(temp_file.name)
        temp_file.write(audio_wav_bytes)

    try:
        audio_config = speechsdk.AudioConfig(filename=str(temp_path))

        pron_config = speechsdk.PronunciationAssessmentConfig(
            reference_text=reference_text.strip(),
            grading_system=speechsdk.PronunciationAssessmentGradingSystem.HundredMark,
            granularity=speechsdk.PronunciationAssessmentGranularity.Phoneme,
            enable_miscue=True,
        )
        pron_config.phoneme_alphabet = "IPA"
        pron_config.nbest_phonemes_count = 5
        pron_config.enable_prosody_assessment()

        recognizer = speechsdk.SpeechRecognizer(
            speech_config=create_speech_config(), audio_config=audio_config
        )
        pron_config.apply_to(recognizer)

        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(None, recognizer.recognize_once)
    finally:
        temp_path.unlink(missing_ok=True)

    if result.reason == speechsdk.ResultReason.RecognizedSpeech:
        pron_result = speechsdk.PronunciationAssessmentResult(result)
        # NOTE: use an explicit None check, not `or` — a legitimate score of 0
        # would otherwise be silently replaced by accuracy_score.
        raw_score = (
            pron_result.pronunciation_score
            if pron_result.pronunciation_score is not None
            else pron_result.accuracy_score
        )
        overall_score = round(raw_score)

        if overall_score >= 90:
            feedback = "Amazing! You're a phonics superstar! 🌟"
        elif overall_score >= 80:
            feedback = "Great job! Keep it up! 👏"
        elif overall_score >= 60:
            feedback = "Good try — let's practice once more."
        else:
            feedback = "Nice try! Let's practice this one more. 👍"

        return {
            "score": overall_score,
            "accuracy": round(pron_result.accuracy_score),
            "fluency": round(pron_result.fluency_score, 0),
            "feedback": feedback,
            "transcription": result.text.strip(),
        }
    elif result.reason == speechsdk.ResultReason.NoMatch:
        return {
            "score": 0,
            "feedback": "No speech heard — try recording louder!",
            "transcription": "",
        }
    else:
        return {"score": 0, "feedback": "Error - try again!", "transcription": ""}
