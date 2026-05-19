import os
import sys
import time
from pydub import AudioSegment
from pydub.effects import normalize
from pydub.silence import detect_leading_silence

# Force python path to include app
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import azure.cognitiveservices.speech as speechsdk
from app.core.config import settings

AZURE_KEY = settings.AZURE_SPEECH_KEY
AZURE_REGION = settings.AZURE_SPEECH_REGION
TARGET_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "uploads", "audio_standardized"))

# List of curriculum assets to generate using highly-optimized Azure neural voice SSML.
# Each maps the target filename to the specific IPA phonetic representation
# and the text representation of the isolated sound.
AZURE_PHONEME_MAP = {
    # 1. Long Vowels and Diphthong spellings
    "phoneme_a_long.mp3": ("eɪ", "a_e"),
    "phoneme_ie.mp3": ("aɪ", "i_e"),
    "phoneme_o_long.mp3": ("oʊ", "o_e"),
    "phoneme_u_long.mp3": ("uː", "u_e"),
    "phoneme_ai.mp3": ("eɪ", "ai"),
    "phoneme_ee.mp3": ("iː", "ee"),

    # 2. Consonant Blends (saying both consonant sounds blended cleanly in sequence)
    "phoneme_bl.mp3": ("bl", "bl"),
    "phoneme_cl.mp3": ("kl", "cl"),
    "phoneme_br.mp3": ("br", "br"),
    "phoneme_cr.mp3": ("kr", "cr"),
    "phoneme_fl.mp3": ("fl", "fl"),
    "phoneme_gl.mp3": ("ɡl", "gl"),
    "phoneme_fr.mp3": ("fr", "fr"),
    "phoneme_gr.mp3": ("ɡr", "gr"),
    "phoneme_pl.mp3": ("pl", "pl"),
    "phoneme_sl.mp3": ("sl", "sl"),
    "phoneme_dr.mp3": ("dr", "dr"),
    "phoneme_tr.mp3": ("tr", "tr"),
    "phoneme_sm.mp3": ("sm", "sm"),
    "phoneme_sn.mp3": ("sn", "sn"),
    "phoneme_sp.mp3": ("sp", "sp"),
    "phoneme_sw.mp3": ("sw", "sw"),
    "phoneme_st.mp3": ("st", "st"),
    "phoneme_sk.mp3": ("sk", "sk"),
    "phoneme_sc.mp3": ("sk", "sc"),
    "phoneme_spr.mp3": ("spr", "spr"),
    "phoneme_str.mp3": ("str", "str"),
    "phoneme_spl.mp3": ("spl", "spl"),
    "phoneme_squ.mp3": ("skw", "squ"),

    # 3. R-Controlled Vowels and Diphthongs
    "phoneme_ar.mp3": ("ɑːr", "ar"),
    "phoneme_er.mp3": ("ɜːr", "er"),
    "phoneme_or.mp3": ("ɔːr", "or"),
    "phoneme_ou.mp3": ("aʊ", "ou"),
    "phoneme_oi.mp3": ("ɔɪ", "oi"),
    "phoneme_oo.mp3": ("ʊ", "oo"),
    "phoneme_au.mp3": ("ɔː", "au"),

    # 4. Suffixes
    "phoneme_ck.mp3": ("k", "ck"),
    "phoneme_qu.mp3": ("kw", "qu"),
}

VOICE_NAME = "en-US-JennyNeural"

def generate_ssml(ipa: str, text: str) -> str:
    """
    Generate optimized SSML wrapping the phonetic translation around the grapheme
    to force Azure Neural to say the exact isolated phonics sound.
    """
    return f"""<speak version="1.0"
    xmlns="http://www.w3.org/2001/10/synthesis"
    xmlns:mstts="http://www.w3.org/2001/mstts"
    xml:lang="en-US">
    <voice name="{VOICE_NAME}">
        <mstts:express-as style="cheerful">
            <prosody rate="x-slow" pitch="medium">
                <phoneme alphabet="ipa" ph="{ipa}">{text}</phoneme>
            </prosody>
        </mstts:express-as>
    </voice>
</speak>"""

def synthesize_and_process():
    if not AZURE_KEY or not AZURE_REGION:
        print("❌ Error: AZURE_SPEECH_KEY and AZURE_SPEECH_REGION must be configured in .env")
        return

    print("Starting Azure synthesis for remaining phoneme assets...")
    
    cfg = speechsdk.SpeechConfig(subscription=AZURE_KEY, region=AZURE_REGION)
    # Output high quality 24kHz MP3
    cfg.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Audio24Khz160KBitRateMonoMp3
    )
    
    synth = speechsdk.SpeechSynthesizer(speech_config=cfg, audio_config=None)
    temp_mp3_path = os.path.join(TARGET_DIR, "temp_azure.mp3")

    for filename, (ipa, text) in AZURE_PHONEME_MAP.items():
        print("\n" + "="*50)
        print(f"Generating remaining asset: {filename} -> Phoneme: /{ipa}/ ({text})")
        
        ssml = generate_ssml(ipa, text)
        
        try:
            result = synth.speak_ssml_async(ssml).get()
            if result.reason != speechsdk.ResultReason.SynthesizingAudioCompleted:
                cancellation = speechsdk.CancellationDetails(result)
                print(f"❌ Azure synthesis failed: {cancellation.error_code} - {cancellation.error_details}")
                continue
                
            with open(temp_mp3_path, "wb") as f:
                f.write(result.audio_data)
                
            # Load into PyDub to trim silence and normalize
            audio = AudioSegment.from_file(temp_mp3_path)
            
            # Standardize: Mono, 24kHz
            audio = audio.set_frame_rate(24000).set_channels(1)
            
            # Trim silences (threshold: -45 dBFS)
            start_trim = detect_leading_silence(audio, silence_threshold=-45)
            end_trim = detect_leading_silence(audio.reverse(), silence_threshold=-45)
            
            duration = len(audio)
            if start_trim < duration and end_trim < duration:
                audio = audio[start_trim:duration - end_trim]
                
            # Normalize peak gain
            normalized = normalize(audio)
            
            # Export to standard path
            dest_path = os.path.join(TARGET_DIR, filename)
            normalized.export(dest_path, format="mp3", bitrate="192k")
            print(f"✅ Successfully generated and saved to: {dest_path}")
            
        except Exception as e:
            print(f"❌ Error processing {filename}: {e}")
            
        time.sleep(0.5) # Short throttle

    if os.path.exists(temp_mp3_path):
        os.remove(temp_mp3_path)
        
    print("\n" + "="*50)
    print("Azure dynamic synthesis complete!")

if __name__ == "__main__":
    synthesize_and_process()
