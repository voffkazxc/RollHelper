; Default is a read-only preflight. --execute requires operator authorization.
; No HTTP, order reading, filtering, opening, saving or booking is performed.
#Requires AutoHotkey v1.1
#NoEnv
#NoTrayIcon
#SingleInstance Off
#Include %A_ScriptDir%\..\lib\UIA_Interface.ahk
#Include %A_ScriptDir%\..\lib\RollClubDutyBackground.ahk

try {
    hwnd := RcDutyBgHwnd()
    if (hwnd <= 0)
        throw Exception("Expected one Syrve Office window")
    WinGet, beforeState, MinMax, ahk_id %hwnd%
    uia := UIA_Interface()
    window := uia.ElementFromHandle(hwnd)
    workspace := window.FindFirstBy("AutomationId=tabControlMain")
    beforePage := RcDutyBgTabSnapshot(workspace)
    FileAppend, % "PREFLIGHT hwnd=" . hwnd . " state=" . beforeState . " page=" . beforePage . "`n", *
    if (A_Args[1] != "--execute")
        ExitApp, 0
    if (beforeState != -1)
        throw Exception("Minimize Syrve first; no navigation was attempted")
    if (beforePage != "Доставки|")
        throw Exception("Open Deliveries first; no navigation was attempted")
    if IsObject(workspace.FindFirstBy("AutomationId=DeliveryOrderEditControl"))
        throw Exception("An order card is open; no navigation was attempted")
    popup := DllCall("GetLastActivePopup", "Ptr", hwnd, "Ptr")
    if (popup != hwnd && DllCall("IsWindowVisible", "Ptr", popup))
        throw Exception("A modal window is open; no navigation was attempted")
    grid := workspace.FindFirstBy("AutomationId=gridDeliveries")
    if (!IsObject(grid) || !RcDutyBgGridIsActive({grid: grid, workspace: workspace}))
        throw Exception("Delivery grid is not active; no navigation was attempted")
    foreground := WinActive("A")
    dutyOn := 1, kcStop := 0, rhPunchBusy := 0, _inDutyTake := 0
    RcDutyBgGeneration := 1, RcDutyBgRunGeneration := 1
    RcDutyBgWasMinimized := (beforeState = -1)
    RcDutyBgRefresh(hwnd, workspace)
    afterPage := RcDutyBgTabSnapshot(workspace)
    WinGet, afterState, MinMax, ahk_id %hwnd%
    FileAppend, % "NAVIGATION_RESULT original=" . beforePage . " final=" . afterPage . " state_before=" . beforeState . " state_after=" . afterState . " foreground_unchanged=" . (foreground = WinActive("A")) . "`n", *
    ExitApp, 0
} catch error {
    FileAppend, % "CHECK_STOPPED " . error.Message . "`n", *
    ExitApp, 1
}

IikoDriver_InitEngine() {
    return false
}
