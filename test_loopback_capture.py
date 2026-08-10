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

def get_loopback_devices(p, wasapi_info):
    devices = []
    for i in range(p.get_device_count()):
        dev = p.get_device_info_by_index(i)
        if dev["hostApi"] == wasapi_info["index"] and dev.get("isLoopbackDevice"):
            devices.append(dev)
    return devices

def print_devices(devices):
    print("\n=== WASAPI Loopback Devices ===")
    for dev in devices:
        idx = dev["index"]
        name = dev["name"]
        ch = dev["maxInputChannels"]
        rate = int(dev["defaultSampleRate"])
        print(f"[{idx}] {name} (Channels: {ch}, Rate: {rate})")
    print("===============================\n")

def test_device(p, dev_info):
    idx = dev_info["index"]
    name = dev_info["name"]
    channels = max(1, int(dev_info["maxInputChannels"]))
    rate = int(dev_info["defaultSampleRate"])
    
    print(f"\nTrying to open device [{idx}] {name}")
    print(f"Parameters: rate={rate}, channels={channels}, format=Float32")
    
    # Check if supported
    try:
        supported = p.is_format_supported(
            rate,
            input_device=idx,
            input_channels=channels,
            input_format=pyaudio.paFloat32
        )
        print(f"is_format_supported: {supported}")
    except Exception as e:
        print(f"is_format_supported returned error: {e}")

    stats = {"frames_received": 0, "rms": 0.0, "peak": 0.0}
    lock = threading.Lock()

    def cb(in_data, frame_count, time_info, status):
        with lock:
            stats["frames_received"] += frame_count
        
        if len(in_data) > 0:
            audio = np.frombuffer(in_data, dtype=np.float32)
            if channels > 1:
                n = len(audio) // channels
                if n > 0:
                    audio = audio[:n * channels].reshape(n, channels).mean(axis=1)
            
            rms = float(np.sqrt(np.mean(audio**2))) if len(audio) > 0 else 0.0
            peak = float(np.max(np.abs(audio))) if len(audio) > 0 else 0.0
            
            with lock:
                stats["rms"] = rms
                stats["peak"] = peak
                
        return (in_data, pyaudio.paContinue)

    try:
        stream = p.open(
            format=pyaudio.paFloat32,
            channels=channels,
            rate=rate,
            input=True,
            input_device_index=idx,
            frames_per_buffer=0, # Let Host decide
            stream_callback=cb
        )
        print(f"Stream opened successfully. Active: {stream.is_active()}\n")
    except Exception as e:
        print(f"FAILED TO OPEN STREAM: {type(e).__name__}: {e}")
        return

    print("Listening for 15 seconds. PLAY YOUTUBE NOW!\n")
    
    t_end = time.time() + 15
    while time.time() < t_end:
        time.sleep(0.5)
        with lock:
            frames = stats["frames_received"]
            rms = stats["rms"]
            peak = stats["peak"]
            
        db = 20 * math.log10(rms) if rms > 1e-7 else -80.0
        bar = "#" * int(min(40, rms * 400))
        print(f"frames={frames:8d} | rms={rms:.5f} | peak={peak:.5f} | db={db:+.1f} | {bar}")

    stream.stop_stream()
    stream.close()
    print("Stream closed.")

def main():
    parser = argparse.ArgumentParser(description="Test WASAPI Loopback Capture")
    parser.add_argument("device_index", nargs="?", type=int, help="Index of the device to test")
    args = parser.parse_args()

    p = pyaudio.PyAudio()
    try:
        wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)
    except OSError:
        print("WASAPI host API not found!")
        p.terminate()
        sys.exit(1)

    devices = get_loopback_devices(p, wasapi_info)
    
    if args.device_index is None:
        print_devices(devices)
        print("Run again with the device index as an argument to test it.")
        print("Example: python test_loopback_capture.py 33")
    else:
        target_dev = next((d for d in devices if d["index"] == args.device_index), None)
        if target_dev is None:
            print(f"Error: Device {args.device_index} is not a WASAPI loopback device.")
            print_devices(devices)
        else:
            test_device(p, target_dev)

    p.terminate()

if __name__ == "__main__":
    main()
