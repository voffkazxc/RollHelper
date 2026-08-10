#Include %A_ScriptDir%\lib\UIA_Interface.ahk

global RcUiaInstance := ""
global RcUiaIikoWindow := ""

RcLog(msg) {
    FileAppend, % "[" . A_Now . "] " . msg . "`n", %A_ScriptDir%\rc_uia.log
}

RcInitUia() {
    global RcUiaInstance
    if (!RcUiaInstance) {
        try {
            RcUiaInstance := UIA_Interface()
        } catch {
            RcLog("UIA_ERROR: Failed to initialize UIA_Interface.")
            return false
        }
    }
    return true
}

RcGetIikoUiaWindow() {
    global RcUiaInstance, RcUiaIikoWindow
    
    if (!RcInitUia())
        return ""
        
    ; Quick check if cache is valid
    if (RcUiaIikoWindow) {
        try {
            if (RcUiaIikoWindow.CurrentProcessId)
                return RcUiaIikoWindow
        }
    }
    
    ; Find the iiko window handle
    hwnd := WinExist("ahk_exe iikoCard5.Pos.Host.exe")
    if (!hwnd)
        hwnd := WinActive("A")
        
    if (hwnd) {
        try {
            RcUiaIikoWindow := RcUiaInstance.ElementFromHandle(hwnd)
            return RcUiaIikoWindow
        } catch e {
            RcLog("UIA_ERROR: Could not get ElementFromHandle. " . e.Message)
        }
    }
    return ""
}

; Нативный UIA-клик с фолбеком на Python
RcNativeUiaClick(AutomationId, Type := "Invoke") {
    startTime := A_TickCount
    iikoWin := RcGetIikoUiaWindow()
    
    if (!iikoWin) {
        RcLog("UIA_FALLBACK: Window not found for AutoId=" . AutomationId)
        return RcUiaFallbackClick(AutomationId)
    }
    
    try {
        ; Поиск элемента по AutomationId. Depth 8 должно хватать для карточки доставки.
        btn := iikoWin.FindFirstBy("AutomationId=" . AutomationId)
        
        if (btn) {
            btn.Click()
            elapsed := A_TickCount - startTime
            RcLog("UIA_SUCCESS: Clicked " . AutomationId . " natively in " . elapsed . "ms")
            return true
        } else {
            RcLog("UIA_FALLBACK: Button not found natively: " . AutomationId)
            return RcUiaFallbackClick(AutomationId)
        }
    } catch e {
        RcLog("UIA_FALLBACK: Exception during UIA native click: " . e.Message)
        return RcUiaFallbackClick(AutomationId)
    }
}

RcUiaFallbackClick(AutomationId) {
    RcLog("UIA: Calling Python fallback for " . AutomationId)
    ; Временно закомментировано, так как мы только тестируем
    ; res := RhPost("/api/iiko/invoke/" . AutomationId, "{}")
    ; return res.ok
    return false
}
