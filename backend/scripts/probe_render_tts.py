import requests

url = "https://english-phonics-app.onrender.com/api/v1/tts/synthesize"
payload = {"text": "cat"}
headers = {"Content-Type": "application/json"}

try:
    print(f"Sending POST to {url} with {payload}...")
    response = requests.post(url, json=payload, headers=headers, timeout=10)
    print(f"Status Code: {response.status_code}")
    print(f"Headers: {response.headers}")
    if response.status_code == 200:
        print(f"Success! Received {len(response.content)} bytes of audio.")
    else:
        print(f"Error Response Body: {response.text}")
except Exception as e:
    print(f"Request failed: {e}")
