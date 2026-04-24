import asyncio
import re
from functools import partial

import azure.cognitiveservices.speech as speechsdk
from app.core.config import settings
from phonemizer import phonemize

# NOTE: tts_config is intentionally NOT created at module level.
# Creating it here causes SPXERR_INVALID_ARG when keys are loaded
# after import. Config is created fresh inside _synthesize_blocking.

VOICE_NAME = "en-US-JennyNeural"
STYLE = "cheerful"
BLENDING_RATE = "slow"
PAUSE_MS = "800ms"

PHONEME_IPA_MAP = {
    # Short vowels
    "a": "æ",
    "e": "ɛ",
    "ɪ": "ɪ",
    "ɒ/ɔ": "ɒ",
    "ʌ/ə": "ʌ",
    # Long vowels
    "eɪ (a_e)": "eɪ",
    "eɪ (ai)": "eɪ",
    "eɪ (ay)": "eɪ",
    "aɪ (i_e)": "aɪ",
    "oʊ (o_e)": "oʊ",
    "uː (u_e)": "uː",
    "iː (ee/ea)": "iː",
    # Consonants
    "b": "b",
    "k": "k",
    "d": "d",
    "f": "f",
    "g": "ɡ",
    "h": "h",
    "l": "l",
    "m": "m",
    "n": "n",
    "p": "p",
    "r": "r",
    "s": "s",
    "t": "t",
    "v": "v",
    "w": "w",
    "j": "j",
    "z": "z",
    "ks": "ks",
    "kw": "kw",
    "dʒ": "dʒ",
    "kʰ": "k",
    # Digraphs
    "ʃ (sh)": "ʃ",
    "tʃ (ch)": "tʃ",
    "f (ph)": "f",
    "w (wh)": "w",
    "ð (voiced th)": "ð",
    "θ (unvoiced th)": "θ",
    "ck": "k",
    "qu": "kw",
    "ŋ (ng)": "ŋ",
    "nk": "ŋk",
    "nd": "nd",
    "nt": "nt",
    "lt": "lt",
    "mp": "mp",
    "s (voiced)": "z",
    # Consonant blends
    "bl": "bl",
    "cl": "kl",
    "br": "br",
    "cr": "kr",
    "fl": "fl",
    "gl": "ɡl",
    "fr": "fr",
    "gr": "ɡr",
    "pl": "pl",
    "sl": "sl",
    "dr": "dr",
    "tr": "tr",
    "sm": "sm",
    "sn": "sn",
    "sp": "sp",
    "sw": "sw",
    "st": "st",
    "sk": "sk",
    "sc": "sk",
    "spr": "spr",
    "str": "str",
    "spl": "spl",
    "skw (squ)": "skw",
    # R-controlled vowels
    "ar": "ɑːr",
    "ɜːr (ir/ur)": "ɜːr",
    "ər (er/or)": "ər",
    "ɔː (or/oar)": "ɔːr",
    # Diphthongs
    "aʊ (ou/ow)": "aʊ",
    "ɔɪ (oi/oy)": "ɔɪ",
    # Special
    "ʊ/ʌ (oo/u)": "ʊ",
    "ɔː (au/aw)": "ɔː",
    "ə (schwa)": "ə",
    # Silent letters
    "kn- (silent k)": "n",
    "wr- (silent w)": "r",
    "mb (silent b)": "m",
    "rh- (silent h)": "r",
    "st (silent t in some words)": "s",
    # Suffixes
    "tʃər (ture)": "tʃər",
    "ʒər (sure)": "ʒər",
    "ʃən (tion/sion)": "ʃən",
    "əs (ous)": "əs",
    "fəl (ful)": "fəl",
}


def clean_ipa(ipa_str: str) -> str:
    return re.sub(r"[' ,]", "", ipa_str).strip()


def get_phonemes(text: str) -> list[str]:
    raw_ipa = phonemize(
        text, language="en-us", backend="espeak", strip=True, with_stress=True
    )
    return clean_ipa(raw_ipa).split()


def generate_phoneme_sound_ssml(ipa: str, repeat: int = 3) -> str:
    """
    SSML that produces ONLY the isolated phoneme sound.
    Repeats `repeat` times with a pause so kids can hear it clearly.
    The display word 'sound' is ignored — Azure speaks the IPA directly.
    """
    parts = []
    for _ in range(repeat):
        parts.append(f'<phoneme alphabet="ipa" ph="{ipa}">sound</phoneme>')
        parts.append('<break time="600ms"/>')

    return f"""<speak version="1.0"
    xmlns="http://www.w3.org/2001/10/synthesis"
    xmlns:mstts="http://www.w3.org/2001/mstts"
    xml:lang="en-US">
    <voice name="{VOICE_NAME}">
        <mstts:express-as style="cheerful">
            <prosody rate="x-slow" pitch="medium">
                {"".join(parts)}
            </prosody>
        </mstts:express-as>
    </voice>
</speak>"""


def generate_ssml(text: str, blending: bool = False) -> str:
    """SSML for exercise content (words / sentences)."""
    if blending:
        phonemes = get_phonemes(text)
        parts = []
        for ph in phonemes:
            parts.append(f'<phoneme alphabet="ipa" ph="{ph}">{ph}</phoneme>')
            parts.append(f'<break time="{PAUSE_MS}"/>')
        body = "".join(parts) + f'<break time="1s"/> Now blend it together: {text}!'
        return f"""<speak version="1.0"
    xmlns="http://www.w3.org/2001/10/synthesis"
    xmlns:mstts="http://www.w3.org/2001/mstts"
    xml:lang="en-US">
    <voice name="{VOICE_NAME}">
        <mstts:express-as style="{STYLE}">
            <prosody rate="{BLENDING_RATE}" pitch="medium">
                Let's sound it out! {body}
            </prosody>
        </mstts:express-as>
    </voice>
</speak>"""
    else:
        return f"""<speak version="1.0"
    xmlns="http://www.w3.org/2001/10/synthesis"
    xmlns:mstts="http://www.w3.org/2001/mstts"
    xml:lang="en-US">
    <voice name="{VOICE_NAME}">
        <mstts:express-as style="{STYLE}">
            <prosody rate="slow" pitch="medium">{text}</prosody>
        </mstts:express-as>
    </voice>
</speak>"""


def _synthesize_blocking(
    text: str,
    blending: bool = False,
    ssml_override: str | None = None,
) -> bytes:
    """
    Blocking TTS call — always run via run_in_executor, never directly
    from async code. Creates a fresh SpeechConfig each call so settings
    are always read at runtime (avoids SPXERR_INVALID_ARG).
    """
    cfg = speechsdk.SpeechConfig(
        subscription=settings.AZURE_SPEECH_KEY,
        region=settings.AZURE_SPEECH_REGION,
    )
    cfg.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Audio24Khz160KBitRateMonoMp3
    )
    synthesizer = speechsdk.SpeechSynthesizer(speech_config=cfg, audio_config=None)

    ssml = ssml_override if ssml_override else generate_ssml(text, blending=blending)
    result = synthesizer.speak_ssml_async(ssml).get()

    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        return result.audio_data

    cancellation = speechsdk.CancellationDetails(result)
    raise ValueError(
        f"TTS failed — Code: {cancellation.error_code} — "
        f"Details: {cancellation.error_details}"
    )


async def synthesize_tts(
    text: str,
    blending: bool = False,
    ssml_override: str | None = None,
) -> bytes:
    """Async wrapper. Runs blocking SDK in a thread pool."""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None,
        partial(_synthesize_blocking, text, blending, ssml_override),
    )
