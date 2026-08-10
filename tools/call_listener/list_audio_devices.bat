@echo off
cd /d "%~dp0..\.."
python "tools\call_listener\list_audio_devices.py"
pause
