#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%

itemX := 0
itemY := 0

#Include %A_ScriptDir%\lib\IikoUI.ahk

res := IikoUI_GetOrderItems()
if (res = "")
    res := "[EMPTY OR ERROR]"

logFile := A_ScriptDir . "\order_items_result.txt"
FileDelete, %logFile%
FileAppend, %res%, %logFile%, UTF-8
