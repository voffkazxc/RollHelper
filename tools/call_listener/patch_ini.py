import os
import re

ini_path = r'C:\Users\voffk\AppData\Roaming\MicroSIP\microsip.ini'
if os.path.exists(ini_path):
    with open(ini_path, 'r', encoding='utf-16') as f:
        content = f.read()

    trigger_py = r'C:\Users\voffk\Documents\РХ_ПалочкиPRO_V6.5\RollHelper\tools\call_listener\udp_trigger.py'
    
    cmd_start = f'python "{trigger_py}" CALL_START'.replace('\\', '\\\\')
    cmd_end = f'python "{trigger_py}" CALL_END'.replace('\\', '\\\\')

    content = re.sub(r'^cmdCallStart=.*', f'cmdCallStart={cmd_start}', content, flags=re.MULTILINE)
    content = re.sub(r'^cmdCallEnd=.*', f'cmdCallEnd={cmd_end}', content, flags=re.MULTILINE)

    with open(ini_path, 'w', encoding='utf-16') as f:
        f.write(content)
    print('microsip.ini patched successfully!')
else:
    print('microsip.ini not found')
