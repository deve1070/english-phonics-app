import json

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


async def assess_pronunciation(local_audio_path: str, reference_text: str) -> dict:
    audio_config = speechsdk.AudioConfig(filename=local_audio_path)

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

    result = recognizer.recognize_once()

    if result.reason == speechsdk.ResultReason.RecognizedSpeech:
        pron_result = speechsdk.PronunciationAssessmentResult(result)
        overall_score = round(
            pron_result.pronunciation_score or pron_result.accuracy_score
        )

        if overall_score >= 90:
            feedback = "Amazing! You're a phonics superstar! 🌟"
        elif overall_score >= 70:
            feedback = "Great effort! You're getting better! 😊"
        else:
            feedback = "Nice try! Let's practice this one more. 👍"

        return {
            "score": overall_score,
            "accuracy": round(pron_result.accuracy_score),
            "fluency": round(pron_result.fluency_score, 0),
            "feedback": feedback,
            "transcription": result.text.strip(),
            "detailed": json.loads(
                result.properties.get_property(
                    speechsdk.PropertyId.SpeechServiceResponse_JsonResult
                )
            ),
        }
    elif result.reason == speechsdk.ResultReason.NoMatch:
        return {
            "score": 0,
            "feedback": "No sppech heard - try recording louder!",
            "transcription": "",
        }
    else:
        return {"score": 0, "feedback": "Error - try again!", "transcription": ""}
