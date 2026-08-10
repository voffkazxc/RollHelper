import sys
import time
import math
import argparse
import threading
import numpy as np
try:
    import pyaudiowpatch as pyaudio
except ImportError:
    print("PyAudioWPatch is required. Please install it.")
    sys.exit(1)

def get_target_devices(p, wasapi_info):
    devices = []
    for i in range(p.get_device_count()):
        dev = p.get_device_info_by_index(i)
        if dev["hostApi"] == wasapi_info["index"]:
            if dev["maxInputChannels"] > 0:
                name = dev["name"]
                if "Sonar" in name or "SteelSeries" in name:
                    devices.append(dev)
    return devices

def rms_to_db(rms):
    return 20 * math.log10(rms) if rms > 1e-7 else -100.0

def test_device_auto(p, dev_info, scan_duration=2.5):
    idx = dev_info["index"]
    channels = max(1, int(dev_info["maxInputChannels"]))
    rate = int(dev_info["defaultSampleRate"])
    
    # Try different formats if float32 is not supported
    fmt = pyaudio.paFloat32
    supported = False
    for test_fmt in [pyaudio.paFloat32, pyaudio.paInt16, pyaudio.paInt32]:
        try:
            if p.is_format_supported(rate, input_device=idx, input_channels=channels, input_format=test_fmt):
                fmt = test_fmt
                supported = True
                break
        except Exception:
            pass
            
    if not supported:
        return None

    stats_per_channel = [{"rms_max": 0.0} for _ in range(channels)]
    lock = threading.Lock()

    def cb(in_data, frame_count, time_info, status):
        if len(in_data) > 0:
            if fmt == pyaudio.paFloat32:
                audio = np.frombuffer(in_data, dtype=np.float32)
            elif fmt == pyaudio.paInt16:
                audio = np.frombuffer(in_data, dtype=np.int16).astype(np.float32) / 32768.0
            elif fmt == pyaudio.paInt32:
                audio = np.frombuffer(in_data, dtype=np.int32).astype(np.float32) / 2147483648.0
                
            if channels > 1:
                n = len(audio) // channels
                if n > 0:
                    audio = audio[:n * channels].reshape(n, channels)
                    for c in range(channels):
                        ch_audio = audio[:, c]
                        rms = float(np.sqrt(np.mean(ch_audio**2))) if len(ch_audio) > 0 else 0.0
                        with lock:
                            if rms > stats_per_channel[c]["rms_max"]:
                                stats_per_channel[c]["rms_max"] = rms
            else:
                rms = float(np.sqrt(np.mean(audio**2))) if len(audio) > 0 else 0.0
                with lock:
                    if rms > stats_per_channel[0]["rms_max"]:
                        stats_per_channel[0]["rms_max"] = rms
                        
        return (in_data, pyaudio.paContinue)

    try:
        stream = p.open(
            format=fmt,
            channels=channels,
            rate=rate,
            input=True,
            input_device_index=idx,
            frames_per_buffer=0,
            stream_callback=cb
        )
    except Exception:
        return None

    time.sleep(scan_duration)
    
    with lock:
        res = [ch["rms_max"] for ch in stats_per_channel]
        
    stream.stop_stream()
    stream.close()
    return res

def auto_scan(p, devices):
    print("\n=== STARTING SONAR/STEELSERIES AUTO-SCAN ===")
    print("Please PLAY YOUTUBE with sound right now.\n")
    
    found_signal = False
    
    for dev in devices:
        idx = dev["index"]
        name = dev["name"]
        print(f"Scanning [{idx}] {name[:60]}... ", end="", flush=True)
        
        max_rms_list = test_device_auto(p, dev)
        
        if max_rms_list is None:
            print("FAILED TO OPEN OR UNSUPPORTED")
            continue
            
        db_strs = []
        is_signal = False
        for c, rms in enumerate(max_rms_list):
            db = rms_to_db(rms)
            if db > -50.0:
                is_signal = True
            db_strs.append(f"CH{c+1}={db:+.0f}dB")
            
        print(" ".join(db_strs) + ("  <-- SIGNAL!" if is_signal else ""))
        
        if is_signal:
            print(f"    SUCCESS! Found active audio on this device.")
            for c, rms in enumerate(max_rms_list):
                db = rms_to_db(rms)
                if db > -50.0:
                    print(f"      Channel {c+1}: {db:+.1f} dB (RMS={rms:.5f})")
            found_signal = True
            
    if not found_signal:
        print("\nFinished scan. NO SIGNAL FOUND on any Sonar/SteelSeries device above -50 dB.")

def main():
    p = pyaudio.PyAudio()
    try:
        wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)
    except OSError:
        print("WASAPI host API not found!")
        p.terminate()
        sys.exit(1)

    devices = get_target_devices(p, wasapi_info)
    auto_scan(p, devices)
    p.terminate()

if __name__ == "__main__":
    main()
