@echo off
set CSC="C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist %CSC% (
    echo ОШИБКА: Компилятор csc.exe не найден!
    pause
    exit /b 1
)

echo Компиляция RollhouseAddon.cs...
%CSC% /nologo /t:exe /out:RollhouseAddon.exe /r:C:\Windows\Microsoft.NET\Framework64\v4.0.30319\WPF\UIAutomationClient.dll /r:C:\Windows\Microsoft.NET\Framework64\v4.0.30319\WPF\UIAutomationTypes.dll /r:C:\Windows\Microsoft.NET\Framework64\v4.0.30319\WPF\WindowsBase.dll /r:System.Windows.Forms.dll /r:System.Web.Extensions.dll RollhouseAddon.cs

if %ERRORLEVEL% EQU 0 (
    echo УСПЕХ! Файл RollhouseAddon.exe успешно создан.
) else (
    echo ОШИБКА при компиляции.
)
pause
