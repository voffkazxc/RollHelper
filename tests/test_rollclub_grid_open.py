"""Real installed RestoGrid: cursor-dependent double click vs native Enter."""
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

from test_rollclub_component_timing import ROOT, OFFICE, AHK, CSC, REFERENCES


class SyrveGridOpenTest(unittest.TestCase):
    def test_enter_opens_exact_filtered_row_without_cursor_or_focus(self):
        references = REFERENCES + ("DevExpress.XtraGrid.v16.2.dll",)
        if not (AHK.is_file() and CSC.is_file() and all((OFFICE / n).is_file() for n in references)):
            self.skipTest("installed RestoGrid component, .NET Framework compiler and AHK v1 required")
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            executable, state = directory / "GridFixture.exe", directory / "state.txt"
            args = [str(CSC), "/nologo", "/target:exe", "/platform:x64", "/main:SyrveGridFixture", "/out:" + str(executable), "/r:System.Windows.Forms.dll", "/r:System.Drawing.dll", "/r:System.Data.dll"]
            args += ["/r:" + str(OFFICE / n) for n in references]
            args += [str(ROOT / "tests/SyrveTabFixture.cs"), str(ROOT / "tests/SyrveGridFixture.cs")]
            compiled = subprocess.run(args, capture_output=True, timeout=30)
            self.assertEqual(compiled.returncode, 0, compiled.stdout.decode("utf-8", "replace"))
            fixture = subprocess.Popen([str(executable), str(OFFICE), str(state)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                end = time.monotonic() + 10
                while not state.exists() and fixture.poll() is None and time.monotonic() < end:
                    time.sleep(0.05)
                self.assertTrue(state.exists(), "grid fixture did not initialize")
                initial = state.read_text().split(",")
                self.assertEqual(initial[2], "1", "exactly one dummy order passes the filter")
                hwnd, gridHwnd = initial[:2]
                harness = f'''#Requires AutoHotkey v1.1
#NoEnv
#NoTrayIcon
#Include {ROOT / 'lib/UIA_Interface.ahk'}
#Include {ROOT / 'lib/RollClubDutyBackground.ahk'}
SendMode, Input
SetKeyDelay, -1, -1
SetControlDelay, -1
hwnd := {hwnd}
gridHwnd := {gridHwnd}
foreground := WinActive("A")
MouseGetPos, beforeX, beforeY
dutyOn := 1, kcStop := 0, rhPunchBusy := 0, _inDutyTake := 0
RcDutyBgGeneration := 1, RcDutyBgRunGeneration := 1, RcDutyBgWasMinimized := true
try {{
    uia := UIA_Interface()
    grid := uia.ElementFromHandle(gridHwnd)
    panel := ""
    for _, child in grid.FindAllBy("TrueCondition", 2) {{
        if RegExMatch(child.CurrentName, "i)(данных|даних|data)")
            panel := child
    }}
    if (!IsObject(panel))
        throw Exception("real grid data panel unavailable")
    target := RcDutyBgRow(panel, "741877")
    if (!IsObject(target))
        throw Exception("filtered target row missing")
    point := RcDutyBgClientPoint(target.cell, gridHwnd)
    RcDutyBgMouseMessage(gridHwnd, point, true)
    Sleep, 150
    FileRead, negativeState, {state}
    negative := StrSplit(negativeState, ",")
    if (negative[5] != "0" || negative[6] != "0")
        throw Exception("negative control unexpectedly opened through a double click")
    rejected := false
    try RcDutyBgOpenRow(hwnd, grid, target.cell, "741878")
    catch error
        rejected := true
    if (!rejected)
        throw Exception("mismatched target number was accepted")
    RcDutyBgOpenRow(hwnd, grid, target.cell, "741877")
    Sleep, 150
    FileRead, positiveState, {state}
    positive := StrSplit(positiveState, ",")
    if (positive[5] != "1" || positive[7] != "741877")
        throw Exception("native Enter did not activate the exact filtered order")
    if (A_KeyDelay != -1 || A_KeyDuration != -1)
        throw Exception("key settings changed")
    WinGet, stateAfter, MinMax, ahk_id %hwnd%
    MouseGetPos, afterX, afterY
    if (stateAfter != -1 || WinActive("A") != foreground)
        throw Exception("minimized state or foreground changed")
    ; The real user may move the pointer during this test. What must remain
    ; true is that activation works with the cursor outside this hidden grid.
    VarSetCapacity(cursorPoint, 8, 0)
    NumPut(afterX, cursorPoint, 0, "Int"), NumPut(afterY, cursorPoint, 4, "Int")
    DllCall("ScreenToClient", "Ptr", gridHwnd, "Ptr", &cursorPoint)
    VarSetCapacity(clientRect, 16, 0)
    DllCall("GetClientRect", "Ptr", gridHwnd, "Ptr", &clientRect)
    cursorX := NumGet(cursorPoint, 0, "Int"), cursorY := NumGet(cursorPoint, 4, "Int")
    if (cursorX >= 0 && cursorY >= 0 && cursorX < NumGet(clientRect, 8, "Int") && cursorY < NumGet(clientRect, 12, "Int"))
        throw Exception("test requires the real cursor outside the hidden grid")
    FileAppend, PASS: real RestoGrid Enter activates the filtered row without cursor or focus`n, *
    ExitApp, 0
}} catch error {{
    FileAppend, % "FAIL: " . error.Message . "`n", *
    ExitApp, 1
}}
IikoDriver_InitEngine() {{
    return false
}}
'''
                script = directory / "open.ahk"
                script.write_text(harness, encoding="utf-8-sig")
                result = subprocess.run([str(AHK), "/ErrorStdOut", str(script)], capture_output=True, timeout=20)
                self.assertEqual(result.returncode, 0, result.stdout.decode("utf-8", "replace"))
                self.assertIn(b"PASS: real RestoGrid Enter", result.stdout)
                final = state.read_text().split(",")
                self.assertEqual(final[4:7], ["1", "0", "741877"])
                self.assertEqual(final[7:9], ["1", "0"], "minimized and unfocused")
            finally:
                if fixture.poll() is None:
                    fixture.terminate()
                fixture.communicate(timeout=5)


if __name__ == "__main__":
    unittest.main()
