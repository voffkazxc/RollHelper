import pyaudiowpatch as pyaudio
import numpy as np
import math
import sys
import time

print("Starting...", flush=True)
p = pyaudio.PyAudio()
print("PyAudio initialized", flush=True)

try:
    wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)
    print(f"WASAPI hostApi index: {wasapi_info['index']}", flush=True)
except Exception as e:
    print(f"ERROR getting WASAPI: {e}", flush=True)
    p.terminate()
    sys.exit(1)

print("\n=== ALL WASAPI DEVICES ===", flush=True)
loopback_devices = []
for i in range(p.get_device_count()):
    dev = p.get_device_info_by_index(i)
    if dev["hostApi"] == wasapi_info["index"]:
        lb = dev.get("isLoopbackDevice", False)
        line = f"[{i}] '{dev['name']}'  loopback={lb}  maxIn={dev['maxInputChannels']}  maxOut={dev['maxOutputChannels']}  rate={int(dev['defaultSampleRate'])}"
        print(line, flush=True)
        if lb:
            loopback_devices.append(i)

print(f"\nLoopback device indices: {loopback_devices}", flush=True)

if not loopback_devices:
    print("ERROR: No loopback devices!", flush=True)
    p.terminate()
    sys.exit(1)

# Pick target
target_idx = None
for i in loopback_devices:
    dev = p.get_device_info_by_index(i)
    if any(x in dev["name"] for x in ["Gaming", "SteelSeries", "Sonar"]):
        target_idx = i
        break
if target_idx is None:
    target_idx = loopback_devices[0]

dev_info = p.get_device_info_by_index(target_idx)
rate = int(dev_info["defaultSampleRate"])
channels = max(1, dev_info["maxInputChannels"])

print(f"\n=== TARGET: [{target_idx}] '{dev_info['name']}' ===", flush=True)
print(f"  rate={rate}  channels={channels}  loopback={dev_info.get('isLoopbackDevice')}", flush=True)

CHUNK = 1024
print(f"Opening stream: format=Float32, ch={channels}, rate={rate}, chunk={CHUNK}", flush=True)

try:
    stream = p.open(
        format=pyaudio.paFloat32,
        channels=channels,
        rate=rate,
        input=True,
        input_device_index=target_idx,
        frames_per_buffer=CHUNK
    )
    print("Stream opened OK!", flush=True)
    print("Reading 15s of audio. Play YouTube now!", flush=True)
    
    t_end = time.time() + 15
    while time.time() < t_end:
        data = stream.read(CHUNK, exception_on_overflow=False)
        audio = np.frombuffer(data, dtype=np.float32)
        if channels > 1:
            audio = audio.reshape(-1, channels).mean(axis=1)
        rms = float(np.sqrt(np.mean(audio**2))) if len(audio) > 0 else 0.0
        peak = float(np.max(np.abs(audio))) if len(audio) > 0 else 0.0
        db = 20 * math.log10(rms) if rms > 1e-7 else -80.0
        bar = "#" * int(min(40, rms * 200))
        print(f"RMS={rms:.5f}  Peak={peak:.4f}  dBFS={db:+.1f}  [{bar:<40}]", flush=True)

    stream.stop_stream()
    stream.close()
    print("Done.", flush=True)

except Exception as e:
    print(f"ERROR: {e}", flush=True)

p.terminate()
print("Terminated.", flush=True)
