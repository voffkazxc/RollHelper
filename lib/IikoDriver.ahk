; ==============================================================================
; FILE: RollHelper/lib/IikoDriver.ahk
; ARCHITECTURE LAYER: UI Automation Low-Level Driver (Production-Grade)
; RESPONSIBILITY: Process handle management, UIA initialization, robust clicks,
;                 logging, and coordinate fallback execution.
; ==============================================================================

#Include %A_ScriptDir%\lib\UIA_Interface.ahk

global IikoDriver_UiaInstance := ""
global IikoDriver_WindowCache := ""
global IikoDriver_TargetProcess := "iikoCard5.Pos.Host.exe"
global IikoDriver_LogPath := A_ScriptDir . "\iiko_ui_driver.log"

IikoDriver_GetIikoHwnd() {
    global IikoDriver_TargetProcess
    SetTitleMatchMode, 2
    hwnd := WinExist("ahk_exe " . IikoDriver_TargetProcess)
    if (!hwnd)
        hwnd := WinExist("Syrve")
    if (!hwnd)
        hwnd := WinExist("Office")
    if (!hwnd)
        hwnd := WinActive("A")
    return hwnd
}

IikoDriver_ClickScreen(x, y, clickCount := 1) {
    prevMode := A_CoordModeMouse
    CoordMode, Mouse, Screen
    if (clickCount > 1)
        Click, %x%, %y%, %clickCount%
    else
        Click, %x%, %y%
    CoordMode, Mouse, %prevMode%
}
; Write structured driver log
IikoDriver_Log(msg, level := "INFO") {
    global IikoDriver_LogPath
    FormatTime, timeStamp,, yyyy-MM-dd HH:mm:ss
    FileAppend, % "[" . timeStamp . "] [" . level . "] " . msg . "`n", %IikoDriver_LogPath%, UTF-8
}

; Initialize UIA COM Engine once (Singleton)
IikoDriver_InitEngine() {
    global IikoDriver_UiaInstance
    if (!IikoDriver_UiaInstance) {
        try {
            IikoDriver_UiaInstance := UIA_Interface()
            IikoDriver_Log("UIA Engine initialized successfully.")
        } catch e {
            IikoDriver_Log("FAILED to initialize UIA_Interface: " . e.Message, "ERROR")
            return false
        }
    }
    return true
}

; Retrieve & cache iiko main window element handle
IikoDriver_GetWindow() {
    global IikoDriver_UiaInstance, IikoDriver_WindowCache, IikoDriver_TargetProcess
    SetTitleMatchMode, 2
    
    if (!IikoDriver_InitEngine())
        return ""
        
    ; Validate cached element
    if (IikoDriver_WindowCache) {
        try {
            if (IikoDriver_WindowCache.CurrentProcessId)
                return IikoDriver_WindowCache
        } catch {
            IikoDriver_WindowCache := ""
        }
    }
    
    ; Find iiko / Syrve Office window handle
    hwnd := IikoDriver_GetIikoHwnd()
        
    if (hwnd) {
        try {
            IikoDriver_WindowCache := IikoDriver_UiaInstance.ElementFromHandle(hwnd)
            IikoDriver_Log("Attached to iiko window HWND=" . Format("0x{:X}", hwnd))
            return IikoDriver_WindowCache
        } catch e {
            IikoDriver_Log("Exception attaching to HWND=" . Format("0x{:X}", hwnd) . ": " . e.Message, "ERROR")
        }
    }
    
    IikoDriver_Log("iiko process window not found.", "WARN")
    return ""
}

; Core Execution Method: Clicks UI element by AutomationId with Graceful Fallback
IikoDriver_ClickElement(automationId, fallbackX := 0, fallbackY := 0) {
    startTime := A_TickCount
    iikoWin := IikoDriver_GetWindow()
    
    if (iikoWin) {
        try {
            ; Fast first-depth search
            btn := iikoWin.FindFirstBy("AutomationId=" . automationId)
            if (btn) {
                btn.Click()
                elapsed := A_TickCount - startTime
                IikoDriver_Log("NATIVE_SUCCESS: Clicked '" . automationId . "' in " . elapsed . "ms")
                return true
            } else {
                IikoDriver_Log("Element '" . automationId . "' not found in UIA tree.", "WARN")
            }
        } catch e {
            IikoDriver_Log("Exception clicking '" . automationId . "': " . e.Message, "ERROR")
        }
    }
    
    ; Graceful Fallback to Coordinates if provided
    if (fallbackX > 0 && fallbackY > 0) {
        IikoDriver_Log("FALLBACK: Using coordinate click (" . fallbackX . ", " . fallbackY . ") for '" . automationId . "'", "WARN")
        MouseGetPos, currentX, currentY
        IikoDriver_ClickScreen(fallbackX, fallbackY)
        Sleep, 150
        MouseMove, %currentX%, %currentY%, 0
        return true
    }
    
    IikoDriver_Log("FAIL: Could not click '" . automationId . "' (No UIA, No Coordinates)", "ERROR")
    return false
}

; Direct Native UIA Sub-Tree Extraction (No Mouse, No Keyboard, Screen-Independent)
IikoDriver_GetTreeItemsTextDirect(automationId := "treeListItems") {
    iikoWin := IikoDriver_GetWindow()
    if (!iikoWin)
        return ""
        
    treeEl := IikoDriver_FindElement(automationId)
    if (!treeEl)
        return ""
        
    items := treeEl.FindAllBy("TrueCondition", 4)
    if (!items || items.MaxIndex() = 0)
        return ""
        
    resText := ""
    prevStr := ""
    Loop, % items.MaxIndex() {
        item := items[A_Index]
        aid := Trim(item.CurrentAutomationId)
        name := Trim(item.CurrentName)
        
        ; 1. Прямая проверка ячейки 'Блюдо row X'
        if (RegExMatch(aid, "^Блюдо row\s*\d+")) {
            val := ""
            try {
                val := Trim(item.CurrentValuePattern.Value)
            } catch {
            }
            if (val = "") {
                try {
                    val := Trim(item.CurrentLegacyIAccessible.Value)
                } catch {
                }
            }
            if (val = "") {
                try {
                    val := Trim(item.CurrentLegacyIAccessible.Name)
                } catch {
                }
            }
            if (val != "" && val != aid && !RegExMatch(val, "i)^(Блюдо|Заказ|Количество|Цена|Сумма)") && val != prevStr) {
                resText .= val . "`n"
                prevStr := val
                continue
            }
        }
        
        ; 2. Если имя элемента "Узел0", "Узел1"..., ищем реальный текст блюда внутри его дочерних объектов (scope=4)
        if (RegExMatch(name, "^Узел\d+")) {
            try {
                subItems := item.FindAllBy("TrueCondition", 4)
                Loop, % subItems.MaxIndex() {
                    subName := Trim(subItems[A_Index].CurrentName)
                    if (subName = "") {
                        try {
                            subName := Trim(subItems[A_Index].GetCurrentPropertyValue(10045))
                        } catch {
                            subName := ""
                        }
                    }
                    if (subName != "" && !RegExMatch(subName, "^Узел") && !RegExMatch(subName, "i)^(Заказ|Панель|Блюдо|Количество|Цена|Сумма)") && !RegExMatch(subName, "^[\d\s,.]+(\s*грн)?$")) {
                        name := subName
                        break
                    }
                }
            } catch {
            }
        }
        
        if (name = "" || RegExMatch(name, "^Узел\d+")) {
            try {
                name := Trim(item.GetCurrentPropertyValue(10045))
            } catch {
                name := ""
            }
        }
        
        if (name != "" && name != prevStr 
            && !RegExMatch(name, "^Узел\d+") 
            && !RegExMatch(name, "^Панель") 
            && !RegExMatch(name, "^Блюдо row")
            && !RegExMatch(name, "i)^(Заказ|Блюдо|Количество|Комментарий|Цена|Сумма|Кол-во персон|Разбить заказ)")
            && !RegExMatch(name, "^[\d\s,.]+(\s*грн)?$")) {
            resText .= name . "`n"
            prevStr := name
        }
    }
    
    return resText
}


IikoDriver_GetHwndText(hwnd) {
    VarSetCapacity(text, 4096, 0)
    DllCall("GetWindowText", "Ptr", hwnd, "Str", text, "Int", 2048)
    if (text != "")
        return text
    VarSetCapacity(text2, 4096, 0)
    SendMessage, 0x000D, 2048, &text2,, ahk_id %hwnd%
    return StrGet(&text2)
}

IikoDriver_GetHwndClass(hwnd) {
    VarSetCapacity(cls, 512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Str", cls, "Int", 256)
    return cls
}

IikoDriver_FormatHwndInfo(hwnd) {
    if (!hwnd)
        return "hwnd=<none>"
    cls := IikoDriver_GetHwndClass(hwnd)
    text := IikoDriver_GetHwndText(hwnd)
    WinGet, proc, ProcessName, ahk_id %hwnd%
    return "hwnd=" . Format("0x{:X}", hwnd) . " class='" . cls . "' text='" . text . "' proc='" . proc . "'"
}

IikoDriver_WindowFromScreenPoint(x, y) {
    point := (x & 0xFFFFFFFF) | (y << 32)
    return DllCall("WindowFromPoint", "Int64", point, "Ptr")
}

IikoDriver_RectIntersects(ax, ay, aw, ah, bx, by, bw, bh) {
    return (ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by)
}

IikoDriver_DumpWinApiItemsDiag(automationId := "treeListItems") {
    rootHwnd := IikoDriver_GetIikoHwnd()
    if (!rootHwnd)
        return "ERROR: iiko HWND not found"

    out := "ROOT: " . IikoDriver_FormatHwndInfo(rootHwnd) . "`r`n"
    treeEl := IikoDriver_FindElement(automationId)
    if (!treeEl)
        return out . "ERROR: UIA tree element not found: " . automationId

    try {
        rect := treeEl.CurrentBoundingRectangle
        treeLeft := rect.l, treeTop := rect.t, treeRight := rect.r, treeBottom := rect.b
    } catch {
        return out . "ERROR: tree rect unavailable"
    }

    treeW := treeRight - treeLeft
    treeH := treeBottom - treeTop
    out .= "TREE RECT: l=" . treeLeft . " t=" . treeTop . " w=" . treeW . " h=" . treeH . "`r`n`r`n"

    out .= "=== WindowFromPoint samples ===`r`n"
    colNames := ["dish", "qty", "comment", "price", "sum"]
    colXs := [treeLeft + 80, treeLeft + 350, treeLeft + 470, treeLeft + 720, treeLeft + 850]
    rowTop := treeTop + 21
    Loop, 12 {
        rowIdx := A_Index - 1
        sampleY := rowTop + (rowIdx * 19) + 9
        if (sampleY > treeBottom)
            break
        out .= "row " . rowIdx . " y=" . sampleY . "`r`n"
        Loop, % colXs.MaxIndex() {
            sampleX := colXs[A_Index]
            hitHwnd := IikoDriver_WindowFromScreenPoint(sampleX, sampleY)
            out .= "  " . colNames[A_Index] . " @ " . sampleX . "," . sampleY . " -> " . IikoDriver_FormatHwndInfo(hitHwnd) . "`r`n"
        }
    }

    out .= "`r`n=== Child HWNDs intersecting tree rect ===`r`n"
    WinGet, childList, ControlListHwnd, ahk_id %rootHwnd%
    seen := "|"
    shown := 0
    Loop, Parse, childList, `n
    {
        childHwnd := A_LoopField
        if (childHwnd = "" || InStr(seen, "|" . childHwnd . "|"))
            continue
        seen .= childHwnd . "|"
        VarSetCapacity(childRect, 16, 0)
        if (!DllCall("GetWindowRect", "Ptr", childHwnd, "Ptr", &childRect))
            continue
        cx := NumGet(childRect, 0, "Int")
        cy := NumGet(childRect, 4, "Int")
        cw := NumGet(childRect, 8, "Int") - cx
        ch := NumGet(childRect, 12, "Int") - cy
        if (!IikoDriver_RectIntersects(cx, cy, cw, ch, treeLeft, treeTop, treeW, treeH))
            continue
        shown++
        out .= "[" . shown . "] " . IikoDriver_FormatHwndInfo(childHwnd) . " rect=" . cx . "," . cy . " " . cw . "x" . ch . "`r`n"
    }
    if (shown = 0)
        out .= "(no child HWND intersects tree rect)`r`n"
    return out
}


IikoDriver_CopyTreeItemsClipboardDiag(automationId := "treeListItems") {
    rootHwnd := IikoDriver_GetIikoHwnd()
    if (!rootHwnd)
        return "ERROR: iiko HWND not found"

    treeEl := IikoDriver_FindElement(automationId)
    if (!treeEl)
        return "ERROR: UIA tree element not found: " . automationId

    try {
        rect := treeEl.CurrentBoundingRectangle
        x := rect.l + 80
        y := rect.t + 30
    } catch {
        return "ERROR: tree rect unavailable"
    }

    savedClip := ClipboardAll
    Clipboard := ""
    WinActivate, ahk_id %rootHwnd%
    Sleep, 80
    IikoDriver_ClickScreen(x, y)
    Sleep, 80
    SendInput, ^a
    Sleep, 120
    SendInput, ^c
    ClipWait, 1
    copied := Clipboard
    Clipboard := savedClip
    if (copied = "")
        return "CLIPBOARD EMPTY after tree Ctrl+A/C"
    return copied
}


IikoDriver_DumpTreeItemsDiag(automationId := "treeListItems", maxRows := 160) {
    iikoWin := IikoDriver_GetWindow()
    if (!iikoWin)
        return "ERROR: iiko window/UIA root not found"

    treeEl := IikoDriver_FindElement(automationId)
    if (!treeEl)
        return "ERROR: element not found: " . automationId

    out := "treeListItems FOUND`r`n"
    try {
        rect := treeEl.CurrentBoundingRectangle
        out .= "TREE RECT: l=" . rect.l . " t=" . rect.t . " r=" . rect.r . " b=" . rect.b . " w=" . (rect.r-rect.l) . " h=" . (rect.b-rect.t) . "`r`n"
    } catch {
        out .= "TREE RECT: <error>`r`n"
    }

    items := ""
    try {
        items := treeEl.FindAllBy("TrueCondition", 4)
    } catch {
        items := ""
    }
    if (!items || items.MaxIndex() = 0) {
        try {
            items := treeEl.FindAllBy("TrueCondition")
        } catch {
            items := ""
        }
    }
    if (!items || items.MaxIndex() = 0)
        return out . "CHILDREN: 0"

    count := items.MaxIndex()
    out .= "CHILDREN: " . count . " (showing up to " . maxRows . ")`r`n`r`n"
    Loop, % count {
        if (A_Index > maxRows) {
            out .= "... truncated ...`r`n"
            break
        }
        item := items[A_Index]
        name := "", aid := "", val := "", legacyName := "", legacyValue := "", ctrl := "", cls := "", rectText := ""
        try {
            name := Trim(item.CurrentName)
        } catch {
            name := "<err>"
        }
        try {
            aid := Trim(item.CurrentAutomationId)
        } catch {
            aid := "<err>"
        }
        try {
            ctrl := item.CurrentControlType
        } catch {
            ctrl := "<err>"
        }
        try {
            cls := Trim(item.CurrentClassName)
        } catch {
            cls := ""
        }
        try {
            val := Trim(item.CurrentValuePattern.Value)
        } catch {
            val := ""
        }
        try {
            legacyName := Trim(item.CurrentLegacyIAccessible.Name)
        } catch {
            legacyName := ""
        }
        try {
            legacyValue := Trim(item.CurrentLegacyIAccessible.Value)
        } catch {
            legacyValue := ""
        }
        try {
            rect := item.CurrentBoundingRectangle
            rectText := "l=" . rect.l . " t=" . rect.t . " w=" . (rect.r-rect.l) . " h=" . (rect.b-rect.t)
        } catch {
            rectText := "rect=<err>"
        }
        out .= "[" . A_Index . "] ct=" . ctrl . " class=" . cls . " aid='" . aid . "' name='" . name . "' val='" . val . "' legacyName='" . legacyName . "' legacyVal='" . legacyValue . "' " . rectText . "`r`n"
    }
    return out
}
; Find visible element by AutomationId (ignores hidden background tabs)
IikoDriver_FindElement(automationId) {
    iikoWin := IikoDriver_GetWindow()
    if (!iikoWin)
        return ""
        
    elements := iikoWin.FindAllBy("AutomationId=" . automationId)
    if (!elements || elements.MaxIndex() = 0)
        return ""
        
    ; Возвращаем элемент с физическими видимыми экранными габаритами (активная вкладка)
    Loop, % elements.MaxIndex() {
        elem := elements[A_Index]
        try {
            rect := elem.CurrentBoundingRectangle
            w := rect.r - rect.l
            h := rect.b - rect.t
            if (w > 100 && h > 100 && rect.l >= 0 && rect.t >= 0)
                return elem
        } catch {
            continue
        }
    }
    
    return elements[1]
}

; Focus element by AutomationId
IikoDriver_FocusElement(automationId, fallbackX := 0, fallbackY := 0) {
    elem := IikoDriver_FindElement(automationId)
    if (elem) {
        try {
            elem.SetFocus()
            IikoDriver_Log("UIA_FOCUS_SUCCESS: Focused '" . automationId . "'")
            return true
        } catch e {
            IikoDriver_Log("Exception focusing '" . automationId . "': " . e.Message, "WARN")
        }
    }
    
    if (fallbackX > 0 && fallbackY > 0) {
        IikoDriver_ClickScreen(fallbackX, fallbackY)
        IikoDriver_Log("FALLBACK: Using coordinate focus (" . fallbackX . ", " . fallbackY . ") for '" . automationId . "'", "WARN")
        return true
    }
    
    return false
}

; Set Value of UI Element by AutomationId
IikoDriver_SetElementValue(automationId, valueText, fallbackX := 0, fallbackY := 0) {
    iikoWin := IikoDriver_GetWindow()
    if (iikoWin) {
        try {
            elem := iikoWin.FindFirstBy("AutomationId=" . automationId)
            if (elem) {
                elem.SetFocus()
                try {
                    elem.Value := valueText
                    IikoDriver_Log("UIA_SETVALUE_SUCCESS: Set value for '" . automationId . "'")
                    return true
                } catch {
                    SendInput, %valueText%
                    return true
                }
            }
        } catch e {
            IikoDriver_Log("Exception setting value for '" . automationId . "': " . e.Message, "WARN")
        }
    }
    
    if (fallbackX > 0 && fallbackY > 0) {
        IikoDriver_ClickScreen(fallbackX, fallbackY)
        Sleep, 100
        SendInput, %valueText%
        return true
    }
    return false
}

; Read all text/items from a Tree/Grid control (e.g. treeListItems)
IikoDriver_GetTreeItemsText(automationId) {
    iikoWin := IikoDriver_GetWindow()
    if (iikoWin) {
        try {
            treeElem := iikoWin.FindFirstBy("AutomationId=" . automationId)
            if (treeElem) {
                ; FindAllBy("TrueCondition") gets all descendants at any depth
                children := treeElem.FindAllBy("TrueCondition")
                resultText := ""
                Loop, % children.MaxIndex() {
                    item := children[A_Index]
                    name := Trim(item.CurrentName)
                    
                    ; Filter out technical containers and column titles
                    if (name = "" || InStr(name, "Панель") || name = "Блюдо" || name = "Количество" || name = "Комментарий" || name = "Цена" || name = "Сумма" || name = "Заказ")
                        continue
                    if (RegExMatch(name, "i)^(Блюдо|Количество|Комментарий|Цена|Сумма)\s+row\s+\d+$"))
                        continue
                    if (RegExMatch(name, "i)^row\s+\d+$") || RegExMatch(name, "i)^Узел\d*$"))
                        continue
                        
                    if (!InStr(resultText, name)) {
                        resultText .= name . "`n"
                    }
                }
                IikoDriver_Log("UIA_GETITEMS_SUCCESS: Read items from '" . automationId . "'")
                return resultText
            }
        } catch e {
            IikoDriver_Log("Exception reading tree items '" . automationId . "': " . e.Message, "WARN")
        }
    }
    return ""
}

; Backward compatibility helpers
RcLog(msg) {
    IikoDriver_Log(msg)
}

RcNativeUiaClick(automationId, type := "Click") {
    return IikoDriver_ClickElement(automationId)
}




