import time
import numpy as np
import pyaudiowpatch as pyaudio
import torch
import json
import os

with open('../../config.json', 'r') as f:
    config = json.load(f)
client_device = config.get("client_device", "")

wanted_idx = -1
if client_device:
    try:
        wanted_idx = int(client_device.split("]")[0].strip("["))
    except:
        pass

p = pyaudio.PyAudio()
if wanted_idx == -1:
    print("Invalid device index.")
    exit(1)

dev_info = p.get_device_info_by_index(wanted_idx)
channels = int(dev_info["maxInputChannels"])
samplerate = int(dev_info["defaultSampleRate"])

print(f"Testing capture on: {client_device}")
print(f"Device properties: channels={channels}, rate={samplerate}")

if samplerate != 48000:
    print(f"WARNING: Device is not 48000 Hz! It is {samplerate} Hz.")
    exit(1)

# Load Silero
print("Loading Silero VAD...")
model, utils = torch.hub.load(repo_or_dir='snakers4/silero-vad', model='silero_vad', force_reload=False, verbose=False)
model.reset_states()
window_size = 512

audio_queue = []

def cb(in_data, frame_count, time_info, status_flags):
    audio = np.frombuffer(in_data, dtype=np.float32)
    audio_queue.append(audio)
    return (in_data, pyaudio.paContinue)

print("\nCapturing 10 seconds. PLEASE ENSURE SPEECH IS PLAYING (e.g., YouTube)...")
stream = p.open(
    format=pyaudio.paFloat32,
    channels=channels,
    rate=samplerate,
    input=True,
    input_device_index=wanted_idx,
    frames_per_buffer=0,
    stream_callback=cb
)
stream.start_stream()
time.sleep(10.0)
stream.stop_stream()
stream.close()
p.terminate()

print("\nProcessing via production path: 48k stereo -> mono -> [::3] -> FIFO 512 -> Silero")

# 1. Concatenate all captured chunks
if not audio_queue:
    print("No audio captured.")
    exit(1)
    
raw_audio = np.concatenate(audio_queue)

# 2. Downmix to mono
if channels > 1:
    n = len(raw_audio) // channels
    raw_audio = raw_audio[:n * channels].reshape(n, channels).mean(axis=1)
mono_48k = raw_audio.flatten()

# 3. Decimate [::3]
audio_16k = mono_48k[::3]

# 4. FIFO 512 -> Silero
max_prob = 0.0
speech_detected = False

for i in range(0, len(audio_16k) - window_size, window_size):
    chunk = audio_16k[i:i + window_size]
    tensor = torch.from_numpy(chunk).unsqueeze(0)
    
    prob = model(tensor, 16000).item()
    max_prob = max(max_prob, prob)
    
    time_sec = i / 16000.0
    if prob > 0.5:
        speech_detected = True
        print(f"[{time_sec:.2f}s] SPEECH PROB: {prob:.4f}  <-- SPEECH!")
    elif prob > 0.1:
        print(f"[{time_sec:.2f}s] SPEECH PROB: {prob:.4f}")

print(f"\nMAX VAD PROB: {max_prob:.4f}")
if speech_detected:
    print("TEST PASS! Pipeline is solid.")
else:
    print("TEST FAIL! No speech > 0.5 detected (or YouTube was silent).")
