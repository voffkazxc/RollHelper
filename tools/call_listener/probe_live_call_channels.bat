@echo off
cd /d "%~dp0..\.."
python "tools\call_listener\probe_live_call_channels.py" --seconds 8 --prefer-name Gaming
pause
