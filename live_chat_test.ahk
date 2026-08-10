#Requires AutoHotkey v1.1
#NoEnv
SetTitleMatchMode, 2
SetWorkingDir %A_ScriptDir%

#Include %A_ScriptDir%\lib\IikoUI.ahk

; 1. Принудительно выводим окно iiko на передний план
hwnd := WinExist("ahk_exe iikoCard5.Pos.Host.exe")
if (hwnd) {
    DllCall("SetForegroundWindow", "Ptr", hwnd)
    WinActivate, ahk_id %hwnd%
    Sleep, 250
}

; 2. Вызываем продакшн-функцию считывания текущей открытой вкладки
itemsText := IikoUI_GetOrderItems()
if (itemsText = "") {
    itemsText := "[ОШИБКА: Текст блюд пуст или видимая таблица не найдена]"
}

; 3. Сохраняем результат в файл отчета
logFile := A_ScriptDir . "\live_chat_report.txt"
FileDelete, %logFile%
FileAppend, %itemsText%, %logFile%, UTF-8
ExitApp
