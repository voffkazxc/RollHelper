#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%
DetectHiddenWindows, On
SetTitleMatchMode, 2

#Include %A_ScriptDir%\lib\UIA_Interface.ahk

uia := UIA_Interface()
iikoWin := WinExist("ahk_exe iikoCard5.Pos.Host.exe")

logFile := "C:\Users\voffk\Documents\РХ_ПалочкиPRO_V6.5\RollHelper\grid_result.txt"
FileDelete, %logFile%

if (!iikoWin) {
    FileAppend, ERROR: Window handle is 0`n, %logFile%, UTF-8
    ExitApp
}

iikoEl := uia.ElementFromHandle(iikoWin)
if (!iikoEl) {
    FileAppend, ERROR: ElementFromHandle returned empty`n, %logFile%, UTF-8
    ExitApp
}

treeEl := iikoEl.FindFirstBy("AutomationId=treeListItems")
if (!treeEl) {
    FileAppend, ERROR: treeListItems element not found`n, %logFile%, UTF-8
    ExitApp
}

allChildren := treeEl.FindAllBy("TrueCondition")
outStr := "Total children count: " . allChildren.MaxIndex() . "`n`n"

Loop, % allChildren.MaxIndex() {
    child := allChildren[A_Index]
    try {
        name := child.CurrentName
        ctrlType := child.CurrentControlType
        aid := child.CurrentAutomationId
        
        val := ""
        try {
            val := child.CurrentValuePattern.Value
        } catch {
            val := "<NoVal>"
        }
        
        outStr .= "[" . A_Index . "] Name: '" . name . "' | Val: '" . val . "' | Aid: '" . aid . "' | Type: " . ctrlType . "`n"
    } catch e {
        outStr .= "[" . A_Index . "] Exception`n"
    }
}

FileAppend, %outStr%, %logFile%, UTF-8
