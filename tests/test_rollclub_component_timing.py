"""Run the real installed tab component, isolated from the Syrve application."""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
OFFICE = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Syrve/SyrveRMS/Office"
AHK = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "AutoHotkey/v1.1.37.02/AutoHotkeyU64.exe"
CSC = Path(os.environ.get("WINDIR", "C:/Windows")) / "Microsoft.NET/Framework64/v4.0.30319/csc.exe"
REFERENCES = ("GuiCommon.dll", "DevExpress.XtraEditors.v16.2.dll", "DevExpress.Utils.v16.2.dll", "DevExpress.Data.v16.2.dll")


class SyrveComponentTimingTest(unittest.TestCase):
    def test_real_tab_control_with_production_key_settings(self):
        if not (AHK.is_file() and CSC.is_file() and all((OFFICE / n).is_file() for n in REFERENCES)):
            self.skipTest("installed Syrve component, .NET Framework compiler and AHK v1 required")
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            executable = directory / "SyrveTabFixture.exe"
            state = directory / "state.txt"
            args = [str(CSC), "/nologo", "/target:exe", "/platform:x64", "/out:" + str(executable), "/r:System.Windows.Forms.dll", "/r:System.Drawing.dll"]
            args += ["/r:" + str(OFFICE / n) for n in REFERENCES]
            args += [str(ROOT / "tests/SyrveTabFixture.cs")]
            compiled = subprocess.run(args, capture_output=True, timeout=30)
            self.assertEqual(compiled.returncode, 0, compiled.stdout.decode("utf-8", "replace"))
            fixture = subprocess.Popen([str(executable), str(OFFICE), str(state)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                end = time.monotonic() + 10
                while not state.exists() and fixture.poll() is None and time.monotonic() < end:
                    time.sleep(0.05)
                self.assertTrue(state.exists(), "fixture did not initialize")
                initial = list(map(int, state.read_text().split(",")))
                window, tab = initial[:2]
                harness = f'''#Requires AutoHotkey v1.1
#NoEnv
#NoTrayIcon
#SingleInstance Off
#Include {ROOT / 'lib/RollClubDutyBackground.ahk'}
SendMode, Input
SetBatchLines, -1
SetKeyDelay, -1, -1
SetControlDelay, -1
hwnd := {window}
tabHwnd := {tab}
foreground := WinActive("A")
physicalCtrl := DllCall("GetAsyncKeyState", "Int", 0x11, "Short") & 0x8000
dutyOn := 1, kcStop := 0, rhPunchBusy := 0, _inDutyTake := 0
RcDutyBgGeneration := 1, RcDutyBgRunGeneration := 1, RcDutyBgWasMinimized := true
try {{
    RcDutyBgCtrlTab(tabHwnd)
    Sleep, 120
    FileRead, middleState, {state}
    if (StrSplit(middleState, ",")[3] != "1")
        throw Exception("actual component did not switch to the other tab")
    RcDutyBgCtrlTab(tabHwnd)
    Sleep, 120
    FileRead, endState, {state}
    if (StrSplit(endState, ",")[3] != "0")
        throw Exception("actual component did not return to its original tab")
    if (A_KeyDelay != -1 || A_KeyDuration != -1)
        throw Exception("production key settings were not restored")
    rejected := false
    try RcDutyBgCtrlTab(0)
    catch error
        rejected := true
    if (!rejected || A_KeyDelay != -1 || A_KeyDuration != -1)
        throw Exception("failed delivery did not restore caller key settings")
    WinGet, stateAfter, MinMax, ahk_id %hwnd%
    if (stateAfter != -1 || WinActive("A") != foreground)
        throw Exception("window state or foreground changed")
    if ((DllCall("GetAsyncKeyState", "Int", 0x11, "Short") & 0x8000) != physicalCtrl)
        throw Exception("physical Ctrl state changed")
    FileAppend, PASS: actual Syrve component refreshed under production timing`n, *
    ExitApp, 0
}} catch error {{
    FileAppend, % "FAIL: " . error.Message . "`n", *
    ExitApp, 1
}}
IikoDriver_InitEngine() {{
    return false
}}
'''
                script = directory / "refresh.ahk"
                script.write_text(harness, encoding="utf-8-sig")
                for _ in range(3):
                    result = subprocess.run([str(AHK), "/ErrorStdOut", str(script)], capture_output=True, timeout=20)
                    self.assertEqual(result.returncode, 0, result.stdout.decode("utf-8", "replace"))
                    self.assertIn(b"PASS: actual Syrve component", result.stdout)
                final = list(map(int, state.read_text().split(",")))
                self.assertEqual(final[2], initial[2], "original page restored")
                self.assertEqual(final[4] - initial[4], 6, "six actual page transitions")
                self.assertEqual(final[5], 1, "fixture remains minimized")
                self.assertEqual(final[6], 0, "tab control has no focus")
            finally:
                if fixture.poll() is None:
                    fixture.terminate()
                fixture.communicate(timeout=5)


if __name__ == "__main__":
    unittest.main()
