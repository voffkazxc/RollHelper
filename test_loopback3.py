"""
WASAPI Loopback test using CALLBACK mode (non-blocking).
Callback mode is required for loopback - blocking read() hangs.
"""
import pyaudiowpatch as pyaudio
import numpy as np
import math
import sys
import time
import threading

print("Starting callback-mode loopback test...", flush=True)
p = pyaudio.PyAudio()

wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)

# Find SteelSeries Sonar Gaming Loopback [33]
target_idx = None
for i in range(p.get_device_count()):
    dev = p.get_device_info_by_index(i)
    if dev["hostApi"] == wasapi_info["index"] and dev.get("isLoopbackDevice"):
        if "Gaming" in dev["name"]:
            target_idx = i
            print(f"Found Gaming Loopback: [{i}] '{dev['name']}'  ch={dev['maxInputChannels']}  rate={int(dev['defaultSampleRate'])}", flush=True)
            break

if target_idx is None:
    # Fallback: first loopback
    for i in range(p.get_device_count()):
        dev = p.get_device_info_by_index(i)
        if dev["hostApi"] == wasapi_info["index"] and dev.get("isLoopbackDevice"):
            target_idx = i
            print(f"Using first loopback: [{i}] '{dev['name']}'", flush=True)
            break

if target_idx is None:
    print("ERROR: No loopback device found!", flush=True)
    p.terminate()
    sys.exit(1)

dev_info = p.get_device_info_by_index(target_idx)
rate = int(dev_info["defaultSampleRate"])
channels = max(1, dev_info["maxInputChannels"])

print(f"Opening: idx={target_idx}  rate={rate}  channels={channels}", flush=True)

rms_values = []
lock = threading.Lock()

def audio_callback(in_data, frame_count, time_info, status):
    audio = np.frombuffer(in_data, dtype=np.float32)
    if channels > 1:
        audio = audio.reshape(-1, channels).mean(axis=1)
    rms = float(np.sqrt(np.mean(audio**2))) if len(audio) > 0 else 0.0
    with lock:
        rms_values.append(rms)
    return (in_data, pyaudio.paContinue)

try:
    stream = p.open(
        format=pyaudio.paFloat32,
        channels=channels,
        rate=rate,
        input=True,
        input_device_index=target_idx,
        frames_per_buffer=1024,
        stream_callback=audio_callback
    )
    print(f"Stream opened OK in callback mode!", flush=True)
    print(f"Reading for 15 seconds. PLAY YOUTUBE NOW!", flush=True)
    print(flush=True)

    t_end = time.time() + 15
    while time.time() < t_end:
        time.sleep(0.3)
        with lock:
            if rms_values:
                rms = rms_values[-1]
                peak_rms = max(rms_values[-20:]) if len(rms_values) >= 20 else max(rms_values)
                rms_values.clear()
            else:
                rms = 0.0
                peak_rms = 0.0

        db = 20 * math.log10(rms) if rms > 1e-7 else -80.0
        bar = "#" * int(min(40, rms * 400))
        print(f"RMS={rms:.5f}  peak={peak_rms:.5f}  dBFS={db:+.1f}  [{bar:<40}]", flush=True)

    stream.stop_stream()
    stream.close()
    print("\nDone.", flush=True)

except Exception as e:
    print(f"ERROR: {type(e).__name__}: {e}", flush=True)

p.terminate()
