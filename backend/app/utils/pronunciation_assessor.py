import azure.cognitiveservices.speech as speechsdk
from app.core.config import AZURE_SPEECH_KEY, AZURE_SPEECH_REGION
import json

speech_config = speechsdk.SpeechConfig(
    subscription=AZURE_SPEECH_KEY, region=AZURE_SPEECH_REGION
)

speech_config.set_property(
    speechsdk.PropertyId.SpeechServiceResponse_JsonResult, "true"
)


async def assess_pronunciation(local_audio_path: str, reference_text: str) -> dict:
    audio_config = speechsdk.AudioConfig(filename=local_audio_path)

    pron_config = speechsdk.PronunciationAssessmentConfig(
        reference_text=reference_text.strip(),
        grading_system=speechsdk.PronunciationAssessmentGradingSystem.HundredMark,
        granularity=speechsdk.PronunciationAssessmentGranularity.Phoneme,
        enable_miscue=True,
    )
    pron_config.phoneme_alphabet = "IPA"
    pron_config.enable_prosody_assessment()
