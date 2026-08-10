import numpy as np
import scipy.signal

mono = np.random.randn(1440).astype(np.float32) # 30ms of noise at 48k
samplerate = 48000

# Bad way (current)
num_samples = int(len(mono) * 16000 / samplerate)
bad_16k = scipy.signal.resample(mono, num_samples)

# Good way 1: simple decimation
simple_16k = mono[::3]

# Good way 2: sosfilt decimation
sos = scipy.signal.cheby1(8, 0.05, 0.8, output='sos')
zi = scipy.signal.sosfilt_zi(sos)
filtered, zi_out = scipy.signal.sosfilt(sos, mono, zi=zi)
good_16k = filtered[::3]

print(f"Bad shape: {bad_16k.shape}")
print(f"Simple shape: {simple_16k.shape}")
print(f"Good shape: {good_16k.shape}")
