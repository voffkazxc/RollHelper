#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%

#Include %A_ScriptDir%\lib\IikoUI.ahk

ToolTip, [LIVE TEST] Считываю состав заказа по UIA...
if (WinExist("ahk_exe iikoCard5.Pos.Host.exe")) {
    WinActivate, ahk_exe iikoCard5.Pos.Host.exe
    Sleep, 200
}

res := IikoUI_GetOrderItems()
ToolTip

if (res != "") {
    MsgBox, 64, Результат считывания (LIVE TEST), % res
} else {
    MsgBox, 48, Ошибка, Не удалось прочитать состав заказа.
}
ExitApp
