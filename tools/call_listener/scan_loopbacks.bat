@echo off
cd /d "%~dp0..\.."
python "tools\call_listener\scan_loopbacks.py" --seconds 3
pause
