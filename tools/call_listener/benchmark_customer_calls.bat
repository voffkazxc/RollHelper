@echo off
cd /d "%~dp0..\.."
python "tools\call_listener\benchmark_local_asr.py" "data\call_listener\customer_calls" --models base --languages ru,uk,auto --beam-size 1 --include-sherpa --sherpa-model "tools\call_listener\models\sherpa-onnx-nemo-ctc-giga-am-v2-russian-2025-04-19" --sherpa-threads 2 --limit 60
pause
