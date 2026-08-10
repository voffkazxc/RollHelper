@echo off
cd /d "%~dp0..\.."
python tools\call_listener\benchmark_local_asr.py --models base --languages ru,uk,auto --beam-size 1 %*
pause
