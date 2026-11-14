#Requires AutoHotkey v1.1
#NoEnv
#NoTrayIcon
#SingleInstance Off
#Include %A_ScriptDir%\..\lib\RollClubDutyBackground.ahk

mouseMessages := [], keyboardMessages := [], fixtureTabState := 0, fixtureAcceptTabs := true
nativeProc := RegisterCallback("NativeWindowProc", "", 4)
nativeClass := "RollHelperNativeTest" . A_Pid
VarSetCapacity(wc, 80, 0)
NumPut(80, wc, 0, "UInt"), NumPut(8, wc, 4, "UInt")
NumPut(nativeProc, wc, 8, "Ptr")
NumPut(DllCall("GetModuleHandle", "Ptr", 0, "Ptr"), wc, 24, "Ptr")
NumPut(&nativeClass, wc, 64, "Ptr")
if (!DllCall("RegisterClassExW", "Ptr", &wc, "UShort"))
    ExitApp, 2
testWindow := DllCall("CreateWindowExW", "UInt", 0x80, "WStr", nativeClass, "WStr", "Native test", "UInt", 0x00CF0000, "Int", 0, "Int", 0, "Int", 280, "Int", 180, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
testGrid := DllCall("CreateWindowExW", "UInt", 0, "WStr", nativeClass, "WStr", "grid", "UInt", 0x50000000, "Int", 20, "Int", 20, "Int", 200, "Int", 100, "Ptr", testWindow, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
DllCall("ShowWindow", "Ptr", testWindow, "Int", 7)
try {
    foreground := WinActive("A")
    ctrlBefore := DllCall("GetAsyncKeyState", "Int", 0x11, "Short") & 0x8000
    dutyOn := 1, kcStop := 0, rhPunchBusy := 0, _inDutyTake := 0
    RcDutyBgGeneration := 1, RcDutyBgRunGeneration := 1, RcDutyBgWasMinimized := true
    previousDpi := DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    VarSetCapacity(rect, 16)
    DllCall("GetWindowRect", "Ptr", testGrid, "Ptr", &rect)
    element := {CurrentBoundingRectangle: {l: NumGet(rect, 0, "Int"), t: NumGet(rect, 4, "Int"), r: NumGet(rect, 8, "Int"), b: NumGet(rect, 12, "Int")}}
    DllCall("SetThreadDpiAwarenessContext", "Ptr", previousDpi, "Ptr")
    point := RcDutyBgClientPoint(element, testGrid)
    NativeAssert(point.x = 100 && point.y = 50, "physical UIA rectangle maps to control client center")
    RcDutyBgMouseMessage(testGrid, point, true)
    Sleep, 100
    NativeAssert(mouseMessages.MaxIndex() = 4, "four addressed mouse messages")
    expected := [0x201, 0x202, 0x203, 0x202]
    for index, message in expected {
        entry := mouseMessages[index]
        NativeAssert(entry.msg = message && entry.hwnd = testGrid, "message order and target")
        NativeAssert(entry.point = point.packed, "all messages use validated client point")
    }
    rejected := false
    try RcDutyBgCtrlTab(testGrid)
    catch error
        rejected := true
    NativeAssert(rejected, "WinForms command rejected for a generic Win32 control")
    NativeAssert(!keyboardMessages.MaxIndex(), "no keys sent to an unsupported control")
    testEditor := DllCall("CreateWindowExW", "UInt", 0, "WStr", "Edit", "WStr", "", "UInt", 0x50000000, "Int", 40, "Int", 40, "Int", 100, "Int", 25, "Ptr", testGrid, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
    NativeAssert(RcDutyBgEditorContains(testEditor, testGrid, point), "editor contains filter point")
    NativeAssert(!RcDutyBgEditorContains(testEditor, testGrid, {x: 5, y: 5}), "unrelated editor is rejected")
    filterCell := {CurrentName: "№ filter row", CurrentBoundingRectangle: element.CurrentBoundingRectangle}
    fixtureRow := new NativeFixtureChildren([filterCell])
    fixtureRow.CurrentName := "Фильтр строк"
    fixturePanel := new NativeFixtureChildren([fixtureRow])
    fixtureGrid := new NativeFixtureChildren([{CurrentNativeWindowHandle: testEditor, CurrentIsEnabled: true}])
    fixtureGrid.CurrentNativeWindowHandle := testGrid
    fixtureContext := {grid: fixtureGrid, panel: fixturePanel}
    RcDutyBgFilter(testWindow, fixtureContext, "741877")
    ControlGetText, filterValue,, ahk_id %testEditor%
    NativeAssert(filterValue = "741877", "filter text entered in the native editor")
    RcDutyBgFilter(testWindow, fixtureContext, "")
    ControlGetText, filterValue,, ahk_id %testEditor%
    NativeAssert(filterValue = "", "native filter cleanup")
    WinGet, stateAfter, MinMax, ahk_id %testWindow%
    NativeAssert(stateAfter = -1, "target remains minimized")
    NativeAssert(WinActive("A") = foreground, "foreground window unchanged")
    ctrlAfter := DllCall("GetAsyncKeyState", "Int", 0x11, "Short") & 0x8000
    NativeAssert(ctrlAfter = ctrlBefore, "physical Ctrl state unchanged")
    FileAppend, PASS: native mouse/filter/cleanup; unsupported refresh rejected; foreground unchanged`n, *
    DllCall("DestroyWindow", "Ptr", testWindow)
    ExitApp, 0
} catch error {
    FileAppend, % "FAIL: " . error.Message . "`n", *
    DllCall("DestroyWindow", "Ptr", testWindow)
    ExitApp, 1
}

NativeWindowProc(hwnd, msg, wParam, lParam) {
    global mouseMessages, keyboardMessages, fixtureTabState, fixtureAcceptTabs
    if (msg = 0x201 || msg = 0x202 || msg = 0x203)
        mouseMessages.Push({msg: msg, point: lParam, hwnd: hwnd})
    if (msg = 0x100 || msg = 0x101)
        keyboardMessages.Push({key: wParam, msg: msg, hwnd: hwnd, ctrl: DllCall("GetKeyState", "Int", 0x11, "Short") & 0x8000})
    if (fixtureAcceptTabs && msg = 0x100 && wParam = 9 && (DllCall("GetKeyState", "Int", 0x11, "Short") & 0x8000))
        fixtureTabState := !fixtureTabState
    return DllCall("DefWindowProcW", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}
NativeAssert(condition, message) {
    if (!condition)
        throw Exception(message)
}
IikoDriver_InitEngine() {
    return false
}

class NativeFixtureChildren {
    __New(children) {
        this.children := children
    }
    FindAllBy(query, scope := 4) {
        return this.children
    }
}

class NativeFixtureWorkspace {
    __New(hwnd) {
        this.CurrentNativeWindowHandle := hwnd
    }
    FindAllBy(query, scope := 2) {
        global fixtureTabState
        return [{CurrentNativeWindowHandle: 100 + fixtureTabState, CurrentName: "Tab" . fixtureTabState}]
    }
}
