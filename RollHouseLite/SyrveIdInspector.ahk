#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
#Persistent
SetWorkingDir, %A_ScriptDir%
CoordMode, Mouse, Screen
FileEncoding, UTF-8
SetTitleMatchMode, 2

#Include %A_ScriptDir%\..\lib\UIA_Interface.ahk

global UIA := UIA_Interface()
global InspectText := ""
global InspectLog := A_ScriptDir . "\syrve_id_inspector_last.txt"
global InspectHistoryLog := A_ScriptDir . "\syrve_id_inspector_history.txt"

Gui, Insp:+AlwaysOnTop +Resize +MinSize640x420
Gui, Insp:Font, s9, Segoe UI
Gui, Insp:Add, Text, x10 y8 w760 h22, Наведи мышь на кнопку/поле Syrve и нажми F8. F9 — дамп активного окна. F10 — попробовать Invoke/Click выбранного элемента.
Gui, Insp:Font, s9, Consolas
Gui, Insp:Add, Edit, x10 y36 w760 h460 ReadOnly -Wrap HScroll vInspectText
Gui, Insp:Font, s9, Segoe UI
Gui, Insp:Add, Button, x10 y506 w150 h30 gInspectUnderMouse, F8: элемент под мышью
Gui, Insp:Add, Button, x170 y506 w150 h30 gDumpActiveWindow, F9: дамп окна
Gui, Insp:Add, Button, x330 y506 w150 h30 gTryClickLast, F10: invoke/click
Gui, Insp:Add, Button, x490 y506 w130 h30 gCopyInspect, Скопировать
Gui, Insp:Add, Button, x630 y506 w140 h30 gOpenInspectLog, Открыть лог
Gui, Insp:Show, w790 h550, Syrve ID Inspector v2
return

F8::GoSub, InspectUnderMouse
F9::GoSub, DumpActiveWindow
F10::GoSub, TryClickLast

InspectUnderMouse:
    MouseGetPos, mx, my, hwnd
    el := GetSmallestUnderMouse(mx, my)
    if (!el) {
        ShowInspect("No UIA element under mouse")
        return
    }
    act := FindActionable(el, 8)
    txt := "=== ELEMENT UNDER MOUSE v2 ===`r`n"
    txt .= "Mouse: x=" . mx . " y=" . my . " hwnd=" . FormatHwnd(hwnd) . "`r`n`r`n"
    txt .= "--- smallest ---`r`n" . ElementFullInfo(el)
    txt .= "`r`n--- actionable candidate ---`r`n" . (act ? ElementFullInfo(act) : "<none>")
    txt .= "`r`n`r`n=== PARENTS ===`r`n" . ParentsInfo(el, 10)
    ShowInspect(txt)
return

DumpActiveWindow:
    hwnd := WinActive("A")
    if (!hwnd) {
        ShowInspect("No active window")
        return
    }
    try root := UIA.ElementFromHandle(hwnd)
    catch e {
        ShowInspect("ERROR ElementFromHandle: " . e.Message)
        return
    }
    txt := "=== ACTIVE WINDOW DUMP ===`r`n"
    txt .= "HWND: " . FormatHwnd(hwnd) . "`r`n`r`n"
    txt .= ElementLine(root) . "`r`n`r`n"
    txt .= SafeDumpChildren(root, 4, 350)
    ShowInspect(txt)
return

TryClickLast:
    MouseGetPos, mx, my
    el := GetSmallestUnderMouse(mx, my)
    if (!el) {
        ShowInspect("No UIA element under mouse before click")
        return
    }
    act := FindActionable(el, 10)
    if (!act)
        act := el
    info := "=== TRY CLICK ACTIONABLE ELEMENT v2 ===`r`n"
    info .= "--- smallest ---`r`n" . ElementFullInfo(el) . "`r`n"
    info .= "--- clicked candidate ---`r`n" . ElementFullInfo(act) . "`r`n"
    try {
        r := act.Click()
        info .= "RESULT: act.Click() returned " . r
    } catch e {
        info .= "RESULT: act.Click() failed: " . e.Message
    }
    ShowInspect(info)
return

CopyInspect:
    GuiControlGet, t, Insp:, InspectText
    Clipboard := t
    ToolTip, Copied
    SetTimer, TipOff, -900
return

ClearHistoryLog:
    FileDelete, %InspectHistoryLog%
    ToolTip, History cleared
    SetTimer, TipOff, -900
return

OpenInspectLog:
    Run, notepad.exe "%InspectLog%"
return

OpenHistoryLog:
    Run, notepad.exe "%InspectHistoryLog%"
return

TipOff:
    ToolTip
return

InspGuiClose:
InspGuiEscape:
ExitApp

GetSmallestUnderMouse(mx, my) {
    global UIA
    hwnd := WinActive("A")
    root := ""
    if (hwnd) {
        try {
            root := UIA.ElementFromHandle(hwnd)
        } catch {
            root := ""
        }
    }
    try {
        if (root)
            return UIA.SmallestElementFromPoint(mx, my, true, root)
        return UIA.SmallestElementFromPoint(mx, my)
    } catch {
        try {
            return UIA.ElementFromPoint(mx, my)
        } catch {
            return ""
        }
    }
}

IsActionable(el) {
    ids := [30031,30041,30036,30028,30090]
    Loop, % ids.MaxIndex() {
        pid := ids[A_Index]
        try {
            if (el.GetCurrentPropertyValue(pid))
                return 1
        } catch {
        }
    }
    return 0
}

FindActionable(el, maxDepth := 8) {
    global UIA
    if (!el)
        return ""
    if (IsActionable(el))
        return el
    cur := el
    Loop, %maxDepth% {
        try {
            parent := UIA.TreeWalkerTrue.GetParentElement(cur)
        } catch {
            break
        }
        if (!parent)
            break
        if (IsActionable(parent))
            return parent
        cur := parent
    }
    return ""
}

ShowInspect(txt) {
    global InspectText, InspectLog, InspectHistoryLog
    InspectText := txt
    GuiControl, Insp:, InspectText, %txt%
    FileDelete, %InspectLog%
    FileAppend, %txt%, %InspectLog%, UTF-8
    FormatTime, ts,, yyyy-MM-dd HH:mm:ss
    FileAppend, % "`r`n`r`n===== " . ts . " =====`r`n" . txt, %InspectHistoryLog%, UTF-8
}

FormatHwnd(hwnd) {
    if (!hwnd)
        return "<none>"
    WinGetClass, cls, ahk_id %hwnd%
    WinGetTitle, title, ahk_id %hwnd%
    WinGet, proc, ProcessName, ahk_id %hwnd%
    return Format("0x{:X}", hwnd) . " class='" . cls . "' title='" . title . "' proc='" . proc . "'"
}

ElementFullInfo(el) {
    out := ElementLine(el) . "`r`n"
    out .= PatternInfo(el) . "`r`n"
    try {
        out .= "Dump: " . el.Dump() . "`r`n"
    } catch e {
        out .= "Dump: <err " . e.Message . ">`r`n"
    }
    return out
}

ElementLine(el, prefix := "") {
    name := SafeProp(el, "CurrentName")
    aid := SafeProp(el, "CurrentAutomationId")
    cls := SafeProp(el, "CurrentClassName")
    ctype := SafeProp(el, "CurrentControlType")
    ltype := SafeProp(el, "CurrentLocalizedControlType")
    fw := SafeProp(el, "CurrentFrameworkId")
    hwnd := SafeProp(el, "CurrentNativeWindowHandle")
    val := SafeValue(el)
    rect := SafeRect(el)
    return prefix . "ControlType=" . ctype . " LocalType='" . ltype . "' Name='" . name . "' AutomationId='" . aid . "' Class='" . cls . "' Framework='" . fw . "' NativeHwnd='" . hwnd . "' Value='" . val . "' Rect=" . rect
}

SafeProp(el, prop) {
    try return el[prop]
    catch {
        try {
            return el[prop]
        } catch {
            return ""
        }
    }
}

SafeValue(el) {
    try return el.CurrentValue
    catch {
        try {
            return el.GetCurrentPropertyValue(30045)
        } catch {
            return ""
        }
    }
}

SafeRect(el) {
    try {
        r := el.CurrentBoundingRectangle
        return "l=" . r.l . " t=" . r.t . " w=" . (r.r-r.l) . " h=" . (r.b-r.t)
    } catch {
        return "<err>"
    }
}

PatternInfo(el) {
    props := {Invoke:30031, Value:30043, Toggle:30041, SelectionItem:30036, ExpandCollapse:30028, Legacy:30090, Grid:30030, GridItem:30029, Text:30040}
    out := "Patterns: "
    first := 1
    for label, pid in props {
        ok := 0
        try {
            ok := el.GetCurrentPropertyValue(pid)
        } catch {
            ok := 0
        }
        if (ok) {
            out .= (first ? "" : ", ") . label
            first := 0
        }
    }
    if (first)
        out .= "none"
    return out
}

ParentsInfo(el, maxDepth := 8) {
    out := ""
    cur := el
    Loop, %maxDepth% {
        try parent := UIA.TreeWalkerTrue.GetParentElement(cur)
        catch {
            break
        }
        if (!parent)
            break
        out .= ElementLine(parent, "[" . A_Index . "] ") . "`r`n"
        cur := parent
    }
    return out
}

SafeDumpChildren(root, maxDepth := 4, maxLines := 350) {
    out := ""
    count := 0
    DumpNode(root, 0, maxDepth, out, count, maxLines)
    return out
}

DumpNode(el, depth, maxDepth, ByRef out, ByRef count, maxLines) {
    if (count >= maxLines || depth > maxDepth)
        return
    count++
    indent := ""
    Loop, %depth%
        indent .= "  "
    out .= indent . ElementLine(el) . "`r`n"
    if (depth >= maxDepth)
        return
    try children := el.GetChildren()
    catch {
        return
    }
    try max := children.MaxIndex()
    catch {
        max := 0
    }
    Loop, %max% {
        if (count >= maxLines) {
            out .= "... truncated ...`r`n"
            return
        }
        DumpNode(children[A_Index], depth + 1, maxDepth, out, count, maxLines)
    }
}
