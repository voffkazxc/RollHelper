"""
Raw WASAPI Loopback test without GUI.
Prints RMS/Peak/dBFS every 0.5s for 20 seconds.
"""
import pyaudiowpatch as pyaudio
import numpy as np
import time
import math

p = pyaudio.PyAudio()

print("=== Listing WASAPI Loopback devices ===")
wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)
loopback_devices = []
for i in range(p.get_device_count()):
    dev = p.get_device_info_by_index(i)
    if dev["hostApi"] == wasapi_info["index"]:
        lb = dev.get("isLoopbackDevice", False)
        print(f"  [{i}] name={dev['name']!r}  loopback={lb}  maxIn={dev['maxInputChannels']}  maxOut={dev['maxOutputChannels']}  rate={dev['defaultSampleRate']}")
        if lb:
            loopback_devices.append(i)

if not loopback_devices:
    print("ERROR: No loopback devices found!")
    p.terminate()
    exit(1)

# Find SteelSeries or use first loopback
target_idx = None
for i in loopback_devices:
    dev = p.get_device_info_by_index(i)
    if "Gaming" in dev["name"] or "SteelSeries" in dev["name"] or "Sonar" in dev["name"]:
        target_idx = i
        break

if target_idx is None:
    target_idx = loopback_devices[0]

dev_info = p.get_device_info_by_index(target_idx)
rate = int(dev_info["defaultSampleRate"])
channels = dev_info["maxInputChannels"]
if channels < 1:
    channels = 1

print(f"\n=== Opening device [{target_idx}] '{dev_info['name']}' ===")
print(f"  isLoopback: {dev_info.get('isLoopbackDevice', False)}")
print(f"  maxInputChannels: {dev_info['maxInputChannels']}")
print(f"  maxOutputChannels: {dev_info['maxOutputChannels']}")
print(f"  defaultSampleRate: {rate}")
print(f"  hostApi: {dev_info['hostApi']}")
print(f"  Opening with channels={channels}, rate={rate}")
print()

CHUNK_SIZE = 2048

try:
    stream = p.open(
        format=pyaudio.paFloat32,
        channels=channels,
        rate=rate,
        input=True,
        input_device_index=target_idx,
        frames_per_buffer=CHUNK_SIZE
    )
    print(f"Stream opened OK. Chunk size: {CHUNK_SIZE} frames")
    print("=== Reading for 20 seconds. Play YouTube now! ===")
    print()

    start = time.time()
    while time.time() - start < 20:
        data = stream.read(CHUNK_SIZE, exception_on_overflow=False)
        audio = np.frombuffer(data, dtype=np.float32)
        
        # Mix channels to mono if stereo
        if channels > 1:
            audio = audio.reshape(-1, channels).mean(axis=1)
        
        rms = np.sqrt(np.mean(audio**2)) if len(audio) > 0 else 0
        peak = np.max(np.abs(audio)) if len(audio) > 0 else 0
        db = 20 * math.log10(rms) if rms > 1e-7 else -80.0
        bar = int(min(50, rms * 300))
        bar_str = "#" * bar + "-" * (50 - bar)
        print(f"  RMS={rms:.5f}  Peak={peak:.4f}  dBFS={db:+.1f}  [{bar_str}]  chunk={len(data)}b")

    stream.stop_stream()
    stream.close()
    print("Done.")

except Exception as e:
    print(f"ERROR opening stream: {e}")

p.terminate()
