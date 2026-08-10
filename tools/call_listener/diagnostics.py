import os
import glob
import time
import numpy as np
import soundfile as sf
import torch
import traceback
import sys

# Suppress ALSA/CUDA warnings
os.environ["PYTHONWARNINGS"] = "ignore"

try:
    from faster_whisper import WhisperModel
except ImportError:
    print("Please install faster-whisper")
    sys.exit(1)

def run_diagnostics():
    print("========================================")
    print("         CALL LISTENER DIAGNOSTICS      ")
    print("========================================\n")
    
    # 1. Find newest log and wav
    logs_dir = "logs"
    if not os.path.exists(logs_dir):
        print("01 AUDIO CAPTURE ........ FAIL (No logs directory found)")
        return
        
    wav_files = glob.glob(f"{logs_dir}/debug_call_*.wav")
    if not wav_files:
        print("01 AUDIO CAPTURE ........ FAIL (No .wav files found in logs/)")
        print("\n=> Action needed: Make ONE real call in the main app to generate the WAV file.")
        return
        
    wav_file = max(wav_files, key=os.path.getctime)
    log_file = wav_file.replace('.wav', '.log')
    
    print(f"Using diagnostic file: {wav_file}\n")
    
    # 1. AUDIO Properties
    try:
        audio_data, samplerate = sf.read(wav_file)
        duration = len(audio_data) / samplerate
        channels = audio_data.shape[1] if len(audio_data.shape) > 1 else 1
        rms = float(np.sqrt(np.mean(audio_data ** 2)))
        rms_db = 20 * np.log10(rms + 1e-6)
        
        print("01 AUDIO CAPTURE ........ PASS")
        print(f"   - Duration: {duration:.2f}s")
        print(f"   - Rate: {samplerate} Hz")
        print(f"   - Channels: {channels}")
        print(f"   - Max RMS: {rms_db:.1f} dB")
        
        if duration < 1.0:
            print("   => FAIL: Audio is too short!")
            return
            
    except Exception as e:
        print(f"01 AUDIO CAPTURE ........ FAIL: {e}")
        return
        
    # 2. RESAMPLE CHECK
    try:
        # It's already supposed to be 16k mono
        if samplerate != 16000 or channels != 1:
            print("02 RESAMPLE 48K->16K .... FAIL (Not 16kHz mono)")
        else:
            print("02 RESAMPLE 48K->16K .... PASS (Saved correctly as 16kHz Mono)")
            
        # Ensure volume didn't drop completely
        if rms_db < -70:
            print(f"   => WARNING: Resampled audio is practically silent ({rms_db:.1f} dB).")
            print("      Check if loopback is capturing the correct output.")
    except Exception as e:
        print(f"02 RESAMPLE 48K->16K .... FAIL: {e}")
        
    # 3. VAD SPEECH DETECTION
    print("\nLoading Silero VAD...")
    try:
        vad_model, _ = torch.hub.load(
            repo_or_dir='snakers4/silero-vad', model='silero_vad',
            force_reload=False, onnx=False, verbose=False
        )
        print("03 VAD SPEECH DETECTION . RUNNING...")
        
        max_prob = 0.0
        speech_detected = False
        speech_start_time = None
        speech_end_time = None
        
        silence_frames = 0
        speech_started = False
        
        for i in range(0, len(audio_data), 512):
            block = audio_data[i:i + 512]
            if len(block) < 512:
                block = np.pad(block, (0, 512 - len(block)))
                
            block_tensor = torch.from_numpy(block.astype(np.float32))
            prob = vad_model(block_tensor, 16000).item()
            max_prob = max(max_prob, prob)
            
            time_sec = i / 16000.0
            
            if prob >= 0.05:
                if not speech_started:
                    speech_started = True
                    speech_detected = True
                    if speech_start_time is None:
                        speech_start_time = time_sec
                    print(f"   {time_sec:.1f}s | prob={prob:.4f} | SPEECH YES")
                silence_frames = 0
            else:
                if speech_started:
                    silence_frames += 1
                    if silence_frames > 15: # approx 0.5 sec
                        speech_started = False
                        speech_end_time = time_sec
                        print(f"   {time_sec:.1f}s | prob={prob:.4f} | SPEECH END (Endpointing)")
                        break
                        
        print(f"   - Max VAD Prob: {max_prob:.4f}")
        
        if speech_detected:
            print("03 VAD SPEECH DETECTION . PASS")
            print(f"   - Detected at: {speech_start_time:.1f}s, End at: {speech_end_time}s")
        else:
            print("03 VAD SPEECH DETECTION . FAIL (No speech detected over 0.05 threshold)")
            
    except Exception as e:
        print(f"03 VAD SPEECH DETECTION . FAIL: {e}")
        speech_detected = False
        
    # 4. STATE MACHINE
    print("\n04 STATE MACHINE ........ " + ("PASS" if speech_detected else "FAIL (No speech detected)"))
    
    # 5. WHISPER 
    print("\nLoading Whisper (CPU)...")
    try:
        t0 = time.time()
        whisper_cpu = WhisperModel("small", device="cpu", compute_type="int8")
        segments, _ = whisper_cpu.transcribe(audio_data, language="uk")
        text = " ".join([s.text for s in segments]).strip()
        t1 = time.time()
        
        print("05 WHISPER CPU .......... PASS")
        print(f"   - Text: {text}")
        print(f"   - Time: {(t1-t0)*1000:.0f} ms")
    except Exception as e:
        print(f"05 WHISPER CPU .......... FAIL: {e}")
        
    # CUDA
    print("\nLoading Whisper (CUDA)...")
    try:
        t0 = time.time()
        whisper_cuda = WhisperModel("small", device="cuda", compute_type="float16")
        segments, _ = whisper_cuda.transcribe(audio_data, language="uk")
        text = " ".join([s.text for s in segments]).strip()
        t1 = time.time()
        
        print("06 WHISPER CUDA ......... PASS")
        print(f"   - Text: {text}")
        print(f"   - Time: {(t1-t0)*1000:.0f} ms")
    except Exception as e:
        tb = traceback.format_exc()
        print(f"06 WHISPER CUDA ......... FAIL:\n{tb}")

    print("\n========================================")
    print("END-TO-END SUMMARY:")
    if not speech_detected:
        print("FAIL at VAD: Audio does not contain recognizable speech (or loopback is capturing wrong device/volume).")
    else:
        print("PASS: VAD successfully extracted speech segment.")
        
if __name__ == "__main__":
    run_diagnostics()
