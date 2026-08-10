@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { `$_.Name -like 'AutoHotkey*.exe' -and `$_.CommandLine -like '*RollHouseLite.ahk*' } | ForEach-Object { Stop-Process -Id `$_.ProcessId -Force }"
