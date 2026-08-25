import os
import json

def verify_audio():
    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    json_path = os.path.join(backend_dir, "phoneme.json")
    audio_dir = os.path.join(backend_dir, "uploads", "audio_standardized")

    if not os.path.exists(json_path):
        print(f"Error: phoneme.json not found at {json_path}")
        return

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    phonemes = data.get("phonemes", [])
    print("="*60)
    print(f"Loaded {len(phonemes)} phoneme definitions from phoneme.json")
    print(f"Checking physical audio files in: {audio_dir}")
    print("="*60)

    missing_count = 0
    mapped_count = 0
    no_url_count = 0
    
    missing_details = []

    for item in phonemes:
        symbol = item.get("symbol")
        audio_url = item.get("audio_url")
        phoneme_id = item.get("id")

        if not audio_url:
            no_url_count += 1
            missing_details.append((phoneme_id, symbol, "No audio_url defined in JSON"))
            continue

        # Extract filename from audio_url (e.g. /audio_standardized/phoneme_a_short.mp3 -> phoneme_a_short.mp3)
        filename = os.path.basename(audio_url)
        physical_path = os.path.join(audio_dir, filename)

        if os.path.exists(physical_path):
            mapped_count += 1
        else:
            missing_count += 1
            missing_details.append((phoneme_id, symbol, f"File missing on disk: {filename}"))

    print("\nVerification Results Summary:")
    print(f"Verified and present on disk: {mapped_count}")
    print(f"Missing or empty audio_url: {no_url_count}")
    print(f"Missing physical files on disk: {missing_count}")
    print("-" * 60)

    if missing_details:
        print("\nDetail of Issues Found:")
        for pid, sym, err in missing_details:
            print(f"  - [ID {pid}] Symbol: '{sym}' -> {err}")
    else:
        print("\nEvery phoneme in phoneme.json has an audio file on disk.")

    print("="*60)

if __name__ == "__main__":
    verify_audio()
