"""
Test ALL loopback devices simultaneously to find which one has audio.
Run this while YouTube is playing.
"""
import pyaudiowpatch as pyaudio
import numpy as np
import math
import sys
import time
import threading

p = pyaudio.PyAudio()
wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)

# Collect all loopback devices
loopbacks = []
for i in range(p.get_device_count()):
    dev = p.get_device_info_by_index(i)
    if dev["hostApi"] == wasapi_info["index"] and dev.get("isLoopbackDevice"):
        loopbacks.append({
            "idx": i,
            "name": dev["name"],
            "channels": max(1, dev["maxInputChannels"]),
            "rate": int(dev["defaultSampleRate"])
        })

print(f"Found {len(loopbacks)} loopback devices:", flush=True)
for lb in loopbacks:
    print(f"  [{lb['idx']}] '{lb['name']}'  ch={lb['channels']}  rate={lb['rate']}", flush=True)
print(flush=True)

# Open all simultaneously with callbacks
levels = {lb["idx"]: 0.0 for lb in loopbacks}
streams = []

for lb in loopbacks:
    idx = lb["idx"]
    ch = lb["channels"]
    rate = lb["rate"]
    
    def make_cb(device_idx, num_ch):
        def cb(in_data, frame_count, time_info, status):
            audio = np.frombuffer(in_data, dtype=np.float32)
            if len(audio) == 0:
                return (in_data, pyaudio.paContinue)
            if num_ch > 1:
                try:
                    audio = audio.reshape(-1, num_ch).mean(axis=1)
                except:
                    pass
            rms = float(np.sqrt(np.mean(audio**2)))
            levels[device_idx] = rms
            return (in_data, pyaudio.paContinue)
        return cb
    
    try:
        stream = p.open(
            format=pyaudio.paFloat32,
            channels=ch,
            rate=rate,
            input=True,
            input_device_index=idx,
            frames_per_buffer=2048,
            stream_callback=make_cb(idx, ch)
        )
        streams.append(stream)
        print(f"  [{idx}] opened OK", flush=True)
    except Exception as e:
        print(f"  [{idx}] FAILED: {e}", flush=True)

print(flush=True)
print("=== PLAY YOUTUBE NOW. Watching for 20 seconds ===", flush=True)
print(f"{'Device':<65} {'RMS':>10}  {'dBFS':>8}", flush=True)
print("-" * 90, flush=True)

t_end = time.time() + 20
while time.time() < t_end:
    time.sleep(0.5)
    for lb in loopbacks:
        idx = lb["idx"]
        rms = levels[idx]
        db = 20 * math.log10(rms) if rms > 1e-7 else -80.0
        bar = "#" * int(min(30, rms * 600))
        active = " <<< AUDIO!" if rms > 0.001 else ""
        name_short = lb["name"][:60]
        print(f"[{idx:2d}] {name_short:<60} {rms:>10.5f}  {db:>+7.1f} dB  {bar}{active}", flush=True)
    print(flush=True)

for s in streams:
    try:
        s.stop_stream()
        s.close()
    except: pass

p.terminate()
print("Done.", flush=True)
