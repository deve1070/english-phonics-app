import re

import azure.cognitiveservices.speech as speechsdk
from app.core.config import settings
from phonemizer import phonemize

tts_config = speechsdk.SpeechConfig(
    subscription=settings.AZURE_SPEECH_KEY, region=settings.AZURE_SPEECH_REGION
)
tts_config.set_speech_synthesis_output_format(
    speechsdk.SpeechSynthesisOutputFormat.Audio24Khz160KBitRateMonoMp3
)

VOICE_NAME = "en-US-JennyNeural"
STYLE = "cheerful"
NOMAL_RATE = "medium"
BLENDING_RATE = "slow"
PAUSE_MS = "800MS"


def clean_ipa(ipa_str: str) -> str:
    """Remove stress (' ,), kepp clean phonemes"""
    return re.sub(r"[' ,]", "", ipa_str).strip()


def get_phonemes(text: str) -> list[str]:
    """User Phonemizer for en-us IPA"""
    raw_ipa = phonemize(
        text, language="en-us", backend="espeak", strip=True, with_stress=True
    )
    cleaned = clean_ipa(raw_ipa)
    return cleaned.split()


def generate_ssml(text: str, blending: bool = False) -> str:
    if blending:
        phonemes = get_phonemes(text)
        parts = []
        for ph in phonemes:
            parts.append(f'<phoneme alphabet="ipa" ph="{ph}">{ph}</phoneme>')
            parts.append(f'<break time="{PAUSE_MS}"/>')
        blending_ssml = (
            "".join(parts) + f'<break time="1s"/> Now blend it together: {text}!'
        )

        return f"""
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
            <voice name="{VOICE_NAME}">
                <prosody rate="{BLENDING_RATE}" pitch="medium">
                    <s><prosody style="{STYLE}">
                        Let's sound it out!
                        {blending_ssml}
                    </prosody></s>
                </prosody>
            </voice>
        </speak>
        """
    else:
        return f"""
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
            <voice name="{VOICE_NAME}">
                <prosody rate="slow" pitch="medium">
                    <s><prosody style="{STYLE}">{text}</prosody></s>
                </prosody>
            </voice>
        </speak>
        """


async def synthesize_tts(text: str) -> bytes:
    audio_config = speechsdk.audio.AudioOutputConfig(use_default_speaker=True)
    synthesizer = speechsdk.SpeechSynthesizer(
        speech_config=tts_config, audio_config=audio_config
    )

    ssml = generate_ssml(text)
    result = synthesizer.speak_ssml_async(ssml).get()

    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        return result.audio_data
    else:
        raise ValueError(f"TTS error: {result.reason}")
