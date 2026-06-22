@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

:: ─── Налаштування ───────────────────────────────────────────────
set DB_FILE=rollhouse.db
set BACKUP_DIR=%~dp0backups
set MAX_BACKUPS=30

:: Формат імені: rollhouse_2025-06-13_14-22-05.db
for /f "tokens=1-5 delims=/: " %%a in ("%DATE% %TIME%") do (
    set DT=%%c-%%a-%%b_%%d-%%e
)
:: Прибрати секунди якщо TIME має формат H:M:S.ms
set DT=%DT:~0,19%
:: Видалити можливі пробіли (однозначна година → " 9:..." → "09:...")
set DT=%DT: =0%

set BACKUP_FILE=%BACKUP_DIR%\rollhouse_%DT%.db

:: ─── Створити папку якщо нема ───────────────────────────────────
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:: ─── Перевірка наявності БД ──────────────────────────────────────
if not exist "%DB_FILE%" (
    echo [ERROR] База даних не знайдена: %DB_FILE%
    echo         Запустіть backup.bat з папки server\
    exit /b 1
)

:: ─── Копіювання (sqlite3 WAL-safe: copy + WAL flush) ────────────
echo Створюємо резервну копію...
copy /Y "%DB_FILE%" "%BACKUP_FILE%" >nul
if errorlevel 1 (
    echo [ERROR] Не вдалося скопіювати базу даних.
    exit /b 1
)

:: Розмір файлу
for %%F in ("%BACKUP_FILE%") do set SIZE=%%~zF
set /a SIZE_KB=%SIZE% / 1024

echo [OK] %BACKUP_FILE%
echo      Розмір: %SIZE_KB% KB

:: ─── Видалити старі копії (залишити MAX_BACKUPS) ─────────────────
echo Очищення старих копій (залишаємо %MAX_BACKUPS%)...
set COUNT=0
for /f "delims=" %%F in ('dir /b /o-d /a-d "%BACKUP_DIR%\rollhouse_*.db" 2^>nul') do (
    set /a COUNT+=1
    if !COUNT! GTR %MAX_BACKUPS% (
        del "%BACKUP_DIR%\%%F" >nul
        echo      Видалено: %%F
    )
)

echo.
echo Резервне копіювання завершено.
echo Всього копій: %COUNT%
