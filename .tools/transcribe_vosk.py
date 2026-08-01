import json
import wave
from vosk import Model, KaldiRecognizer

wav_path = r"assets/audio/voice_note.wav"
model_path = r".tools/vosk-model-small-en-us-0.15"

wf = wave.open(wav_path, "rb")
model = Model(model_path)
rec = KaldiRecognizer(model, wf.getframerate())
rec.SetWords(True)

parts = []
while True:
    data = wf.readframes(4000)
    if len(data) == 0:
        break
    if rec.AcceptWaveform(data):
        parts.append(json.loads(rec.Result()).get("text", ""))
parts.append(json.loads(rec.FinalResult()).get("text", ""))

text = " ".join([p for p in parts if p]).strip()
print(text if text else "[NO_SPEECH_DETECTED]")
