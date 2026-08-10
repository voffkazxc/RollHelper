import time, math, random, sys
eq_levels = [0.0] * 25
chars = [' ', ' ', '▂', '▃', '▄', '▅', '▆', '▇', '█']

def render(rms):
    amp = min(1.0, rms * 3.0)
    for i in range(25):
        if amp > 0.01:
            target = amp * random.uniform(0.2, 1.0)
            dist = abs(i - 12) / 12.0
            target *= (1.0 - 0.4 * dist)
        else:
            target = 0.0
        if target > eq_levels[i]:
            eq_levels[i] = target
        else:
            eq_levels[i] = max(0.0, eq_levels[i] - 0.1)
        idx = max(0, min(8, int(eq_levels[i] * 8)))
        sys.stdout.write(chars[idx])
    
    db = 20 * math.log10(rms) if rms > 1e-4 else -80.0
    sys.stdout.write(f'  {db:+.1f} dB\n')
    
for val in [0.0, 0.05, 0.1, 0.2, 0.3, 0.1, 0.0, 0.0, 0.0]:
    render(val)
