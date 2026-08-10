import sys
import numpy as np
import soundfile as sf
import torch
import scipy.signal

def process_audio(wav_path):
    print(f"Loading {wav_path}...")
    data, rate = sf.read(wav_path)
    if len(data.shape) > 1:
        data = data.mean(axis=1) # downmix to mono
        
    print(f"Original rate: {rate}, Samples: {len(data)}, Duration: {len(data)/rate:.2f}s")
    
    # 1. CONTINUOUS RESAMPLING
    # We replace scipy.signal.resample (which uses FFT and corrupts chunk boundaries)
    # with a streaming-safe decimation or integer slicing.
    
    audio_16k = None
    if rate == 48000:
        print("Using integer decimation [::3] for perfect streaming boundary continuity.")
        audio_16k = data[::3]
    elif rate != 16000:
        print("Using scipy.signal.resample for offline file (not streaming safe).")
        num_samples = int(len(data) * 16000 / rate)
        audio_16k = scipy.signal.resample(data, num_samples)
    else:
        audio_16k = data
        
    audio_16k = audio_16k.astype(np.float32)
    
    # 2. SILERO VAD WITH PROPER STATE
    print("\nLoading Silero VAD...")
    model, utils = torch.hub.load(repo_or_dir='snakers4/silero-vad', model='silero_vad', force_reload=False, verbose=False)
    
    window_size = 512 # 16000 Hz, so 512 samples = 32ms
    
    speech_detected = False
    model.reset_states()
    
    # We feed the model exactly 512 samples per step, keeping internal RNN state intact!
    for i in range(0, len(audio_16k) - window_size, window_size):
        chunk = audio_16k[i:i + window_size]
        
        tensor = torch.from_numpy(chunk).unsqueeze(0)
        prob = model(tensor, 16000).item()
        
        time_sec = i / 16000.0
        if prob > 0.1:
            speech_detected = True
            print(f"[{time_sec:.2f}s] SPEECH PROB: {prob:.4f}")
            
    if not speech_detected:
        print("\nNo speech detected (prob never exceeded 0.1).")
    else:
        print("\nSUCCESS: Speech was confidently detected!")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        process_audio(sys.argv[1])
    else:
        print("Usage: python vad_offline_test.py <wav_file>")
