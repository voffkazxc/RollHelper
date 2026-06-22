@echo off
echo [!] Ця папка застаріла. Запускаю ПРАВИЛЬНИЙ сервер (..\..\server)...
cd /d "%~dp0..\..\server"
call start.bat
