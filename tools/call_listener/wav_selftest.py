import time
import numpy as np
import pyaudiowpatch as pyaudio
import scipy.signal
import soundfile as sf
import os
import json
import traceback

with open('../../config.json', 'r') as f:
    config = json.load(f)
client_device = config.get("client_device", "")

print(f"Testing capture on: {client_device}")
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

print(f"Device properties: channels={channels}, rate={samplerate}")

audio_queue = []

def cb(in_data, frame_count, time_info, status_flags):
    audio = np.frombuffer(in_data, dtype=np.float32)
    audio_queue.append(audio.astype(np.float32))
    return (in_data, pyaudio.paContinue)

print("Capturing 5 seconds...")
try:
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
    time.sleep(5.0)
    stream.stop_stream()
    stream.close()
except Exception as e:
    print(f"Error opening stream: {e}")

print("Processing...")
current_debug_wav_frames = []

for audio_data in audio_queue:
    if channels > 1:
        n = len(audio_data) // channels
        if n > 0:
            audio_data = audio_data[:n * channels].reshape(n, channels).mean(axis=1)
            
    mono = audio_data.flatten()
        
    num_samples = int(len(mono) * 16000 / samplerate)
    audio_16k = scipy.signal.resample(mono, num_samples) if samplerate != 16000 else mono
    current_debug_wav_frames.append(audio_16k.astype(np.float32))

print("Saving WAV...")
if current_debug_wav_frames:
    audio_data = np.concatenate(current_debug_wav_frames)
    os.makedirs('logs', exist_ok=True)
    path = 'logs/debug_call_selftest.wav'
    sf.write(path, audio_data, 16000, subtype='PCM_16')

    # Check properties
    data, rate = sf.read(path)
    duration = len(data) / rate
    ch = data.shape[1] if len(data.shape) > 1 else 1
    rms = float(np.sqrt(np.mean(data ** 2)))
    rms_db = 20 * np.log10(rms + 1e-6)

    print(f"duration: {duration:.2f} (expected ~5.0)")
    print(f"rate: {rate} (expected 16000)")
    print(f"channels: {ch} (expected 1)")
    print(f"RMS: {rms_db:.2f} dB (expected not -100)")

    if duration >= 4.5 and rate == 16000 and ch == 1:
        print("\nDIAGNOSTIC WAV SELF-TEST: PASS")
    else:
        print("\nDIAGNOSTIC WAV SELF-TEST: FAIL")
else:
    print("No audio captured.")
