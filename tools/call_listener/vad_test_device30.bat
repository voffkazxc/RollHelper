@echo off
cd /d "%~dp0..\.."
python "tools\call_listener\call_listen.py" --device 30 --model small --language auto --beam-size 3 --until-silence --seconds 8 --start-timeout 4 --min-speech-seconds 1.5 --silence-seconds 1.0 --rms-threshold 120
pause
