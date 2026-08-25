import os
import json
import time
import urllib.request
from pydub import AudioSegment
from pydub.effects import normalize
from pydub.silence import detect_leading_silence

# Map of standard MP3 filenames inside backend/uploads/audio_standardized
# to their exact Wikimedia Commons File names.
COMMONS_FILE_MAP = {
    # Short vowels
    "phoneme_a_short.mp3": "Near-open_front_unrounded_vowel.ogg",
    "phoneme_e_short.mp3": "Open-mid_front_unrounded_vowel.ogg",
    "phoneme_i_short.mp3": "Near-close_near-front_unrounded_vowel.ogg",
    "phoneme_o_short.mp3": "Open_back_rounded_vowel.ogg",
    "phoneme_u_short.mp3": "Open-mid_back_unrounded_vowel.ogg",
    
    # Consonants
    "phoneme_b.mp3": "Voiced_bilabial_plosive.ogg",
    "phoneme_d.mp3": "Voiced_alveolar_plosive.ogg",
    "phoneme_f.mp3": "Voiceless_labiodental_fricative.ogg",
    "phoneme_g.mp3": "Voiced_velar_plosive.ogg",
    "phoneme_h.mp3": "Voiceless_glottal_fricative.ogg",
    "phoneme_j.mp3": "Palatal_approximant.ogg",
    "phoneme_k.mp3": "Voiceless_velar_plosive.ogg",
    "phoneme_l.mp3": "Alveolar_lateral_approximant.ogg",
    "phoneme_m.mp3": "Bilabial_nasal.ogg",
    "phoneme_n.mp3": "Alveolar_nasal.ogg",
    "phoneme_p.mp3": "Voiceless_bilabial_plosive.ogg",
    "phoneme_r.mp3": "Alveolar_approximant.ogg",
    "phoneme_s.mp3": "Voiceless_alveolar_sibilant.ogg",
    "phoneme_t.mp3": "Voiceless_alveolar_plosive.ogg",
    "phoneme_v.mp3": "Voiced_labiodental_fricative.ogg",
    "phoneme_w.mp3": "Voiced_labio-velar_approximant.ogg",
    "phoneme_z.mp3": "Voiced_alveolar_sibilant.ogg",

    # Digraphs
    "phoneme_sh.mp3": "Voiceless_palato-alveolar_sibilant.ogg",
    "phoneme_ch.mp3": "Voiceless_palato-alveolar_affricate.ogg",
    "phoneme_th.mp3": "Voiceless_dental_fricative.ogg",
    "phoneme_thh.mp3": "Voiced_dental_fricative.ogg",
    "phoneme_ng.mp3": "Velar_nasal.ogg"
}

# The target directory relative to backend
TARGET_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "uploads", "audio_standardized"))
USER_AGENT = "EnglishPhonicsApp/1.0 (https://englishphonicsapp.example.com; contact: developer@englishphonicsapp.example.com) Python-urllib"

def get_direct_wikimedia_url(file_name):
    """
    Query the MediaWiki API to get the absolute direct URL to the OGG file.
    This bypasses MD5 hash directory calculations completely.
    """
    api_url = f"https://commons.wikimedia.org/w/api.php?action=query&titles=File:{file_name}&prop=imageinfo&iiprop=url&format=json"
    headers = {"User-Agent": USER_AGENT}
    
    try:
        req = urllib.request.Request(api_url, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            
        pages = data.get("query", {}).get("pages", {})
        for page_id, page_info in pages.items():
            image_info = page_info.get("imageinfo", [])
            if image_info:
                return image_info[0].get("url")
    except Exception as e:
        print(f"Error querying API for {file_name}: {e}")
        
    return None

def download_and_process():
    os.makedirs(TARGET_DIR, exist_ok=True)
    print(f"Target Directory: {TARGET_DIR}")
    
    temp_ogg_path = os.path.join(TARGET_DIR, "temp_download.ogg")
    headers = {"User-Agent": USER_AGENT}

    for filename, commons_file in COMMONS_FILE_MAP.items():
        print("\n" + "="*50)
        print(f"Processing target: {filename}")
        print(f"Resolving MediaWiki direct URL for: {commons_file}")
        
        direct_url = get_direct_wikimedia_url(commons_file)
        if not direct_url:
            print(f"Could not resolve URL for: {commons_file}")
            continue
            
        print(f"Found URL: {direct_url}")
        
        # Be extremely polite to Wikimedia to avoid HTTP 429
        time.sleep(1.5)
        
        try:
            # Download OGG file
            print("Downloading...")
            req = urllib.request.Request(direct_url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as response:
                content = response.read()
                
            with open(temp_ogg_path, "wb") as f:
                f.write(content)
                
            # Load OGG using PyDub
            audio = AudioSegment.from_ogg(temp_ogg_path)
            
            # 1. Standardize sampling rate and channels (Mono, 24kHz)
            audio = audio.set_frame_rate(24000).set_channels(1)
            
            # 2. Trim silence (threshold at -45 dBFS)
            # This makes sure the sound plays immediately upon tap
            start_trim = detect_leading_silence(audio, silence_threshold=-45)
            end_trim = detect_leading_silence(audio.reverse(), silence_threshold=-45)
            
            duration = len(audio)
            if start_trim < duration and end_trim < duration:
                audio = audio[start_trim:duration - end_trim]
            
            # 3. Normalize to uniform maximum volume
            normalized = normalize(audio)
            
            # 4. Save to target location as high-quality MP3 (192kbps)
            dest_path = os.path.join(TARGET_DIR, filename)
            normalized.export(dest_path, format="mp3", bitrate="192k")
            print(f"Converted and saved to {dest_path}")
            
        except Exception as e:
            print(f"Error processing {filename}: {e}")
            
    # Clean up temp file
    if os.path.exists(temp_ogg_path):
        os.remove(temp_ogg_path)
        
    print("\n" + "="*50)
    print("Audio processing complete!")

if __name__ == "__main__":
    download_and_process()
