@echo off
cd /d "%~dp0..\.."
python "tools\call_listener\call_listen.py" --seconds 8
pause
