@echo off
cd /d "%~dp0..\.."
python "tools\call_listener\call_listen.py" --seconds 8 --device 30 --model small --beam-size 3 --compare --compare-languages uk,ru,auto
pause
