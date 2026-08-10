import json
import pyaudiowpatch as pyaudio

cfg_path = r'C:\Users\voffk\Documents\РХ_ПалочкиPRO_V6.5\RollHelper\tools\call_listener\assistant_config.json'
try:
    with open(cfg_path, 'r', encoding='utf-8') as f:
        cfg = json.load(f)
except Exception:
    cfg = {}

p = pyaudio.PyAudio()
try:
    dev = p.get_device_info_by_index(29)
    name = f'[{29}] {dev["name"]}'
    cfg["client_device"] = name
    with open(cfg_path, 'w', encoding='utf-8') as f:
        json.dump(cfg, f, ensure_ascii=False)
    print('Updated config to:', name)
except Exception as e:
    print('Error:', e)
p.terminate()
