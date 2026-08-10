@echo off
cd /d "%~dp0..\.."
set /p DEV=Device index: 
python "tools\call_listener\call_listen.py" --seconds 8 --device %DEV%
pause
