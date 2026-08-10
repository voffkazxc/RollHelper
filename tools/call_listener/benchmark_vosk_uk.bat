@echo off
cd /d "%~dp0..\.."
python tools\call_listener\benchmark_local_asr.py --skip-whisper --limit 10 --include-vosk --include-vosk-grammar --vosk-model tools\call_listener\models\vosk-model-small-uk-v3-nano %*
pause
