@echo off
cd /d "%~dp0..\.."
python tools\call_listener\benchmark_local_asr.py --skip-whisper --limit 10 --include-sherpa --sherpa-model tools\call_listener\models\sherpa-onnx-nemo-ctc-giga-am-v2-russian-2025-04-19 --sherpa-threads 2 %*
pause
