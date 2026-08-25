from pathlib import Path

import azure.cognitiveservices.speech as speechsdk

# Read key and region straight from .env rather than through Settings, so a
# misconfigured app config cannot mask a working Azure account.
key = ""
region = ""
with open(Path(__file__).resolve().parents[1] / ".env") as f:
    for line in f:
        if line.startswith("AZURE_SPEECH_KEY="):
            key = line.split("=", 1)[1].strip()
        elif line.startswith("AZURE_SPEECH_REGION="):
            region = line.split("=", 1)[1].strip()

print(f"Key: {key[:10]}... (length {len(key)})")
print(f"Region: {region}")

cfg = speechsdk.SpeechConfig(
    subscription=key,
    region=region,
)

synth = speechsdk.SpeechSynthesizer(speech_config=cfg, audio_config=None)
result = synth.speak_text_async("Hello world").get()

if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
    print("Success! Audio synthesized perfectly.")
else:
    cancellation = speechsdk.CancellationDetails(result)
    print(f"Failed! Code: {cancellation.error_code} - Details: {cancellation.error_details}")
