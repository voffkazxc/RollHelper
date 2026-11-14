"""Minimized Office reads must not use the foreground window or screen geometry."""
import unittest
import os
from pathlib import Path
import re
import subprocess
import tempfile

from test_rollclub_duty_cache import Bridge, Control, MODULE


class BackgroundDutyTests(unittest.TestCase):
    def test_ctrl_f4_never_routes_to_legacy_for_any_window_state(self):
        executable = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "AutoHotkey/v1.1.37.02/AutoHotkeyU64.exe"
        if not executable.exists():
            self.skipTest("AHK v1 runtime required")
        root = Path(__file__).resolve().parents[1]
        source = (root / "engine_rollclub.ahk").read_text(encoding="utf-8-sig")
        start = source.index("    ; Ctrl+F4 always uses UIA.")
        end = source.index("    ; === ПРАВИЛЬНИЙ ПОРЯДОК", start)
        routing = source[start:end]
        # Stub only OS/UI effects. Execute the production routing/return logic.
        routing = re.sub(r"(?m)^\s*WinGet, _bgState,.*$", "    _bgState := testState", routing)
        routing = re.sub(r"(?m)^\s*(ToolTip|Gui|SetTimer),.*$", "    ; OS effect stubbed", routing)
        harness = '''#NoEnv
#SingleInstance Off
for _, testState in [-1, 0, 1, ""] {
    for _, testHwnd in [123, 0, -1] {
        dutyOn := 1, _rcDutyTickBackground := 1, calls := 0, legacy := 0
        GoSub, TestRoute
        if (legacy || calls != (testHwnd > 0 ? 1 : 0))
            ExitApp, 1
    }
}
FileAppend, PASS: 12 production routing cases`n, *
ExitApp, 0
TestRoute:
''' + routing + '''
legacy++
return
ShowDutyContinueBanner:
return
RcDutyBgHwnd() {
    global testHwnd, dutyOn
    dutyOn := 0 ; simulate a stop racing with window discovery
    return testHwnd
}
RcDutyBgCycle(hwnd, ByRef number) {
    global calls
    calls++
    return 0
}
RcDutyBgLog(event, detail) {
}
RcPlaySound(name) {
}
'''
        with tempfile.TemporaryDirectory() as temporary:
            script = Path(temporary) / "routing.ahk"
            script.write_text(harness, encoding="utf-8-sig")
            result = subprocess.run([str(executable), "/ErrorStdOut", str(script)], capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout.decode("utf-8", "replace"))
        self.assertIn(b"PASS: 12", result.stdout)

    def test_idle_poll_does_not_switch_tabs(self):
        source = (Path(__file__).resolve().parents[1] / "lib/RollClubDutyBackground.ahk").read_text(encoding="utf-8-sig")
        self.assertNotIn(".Select()", source)
        self.assertNotIn("SelectionItem", source)

    def bridge(self):
        bridge = Bridge()
        bridge.window.ClassName = "WindowsForms10.Window.8.app"
        bridge.window.ProcessId = 91
        bridge.grid.IsOffscreen = True
        bridge.grid.BoundingRectangle = type("Rect", (), {
            "width": lambda self: 0, "height": lambda self: 0,
        })()
        bridge.auto.ControlFromHandle = lambda hwnd: bridge.window
        bridge._get_foreground_win = lambda: self.fail("must not read foreground")
        bridge.auto.GetRootControl = lambda: self.fail("must not enumerate desktop")
        return bridge

    def test_cold_read_of_minimized_grid_ignores_offscreen_and_zero_bounds(self):
        bridge = self.bridge()
        result = MODULE.read_kc_list_background(bridge, 123)
        self.assertTrue(result["ok"])
        self.assertEqual(result["take_no"], 741877)
        self.assertEqual(result["background_hwnd"], 123)

    def test_background_cache_is_separate_and_reused(self):
        bridge = self.bridge()
        foreground_panel = Control("foreground sentinel")
        bridge._kc_panel_cache = foreground_panel
        MODULE.read_kc_list_background(bridge, 123)
        result = MODULE.read_kc_list_background(bridge, 123)
        self.assertEqual(result["take_no"], 741877)
        self.assertEqual(bridge.grid_searches, 1)
        self.assertIs(bridge._kc_panel_cache, foreground_panel)
        self.assertIn("cached=1", bridge.logs[-1])

    def test_background_never_requests_screen_rectangles(self):
        class NoGeometry(Control):
            @property
            def BoundingRectangle(self):
                raise AssertionError("screen geometry requested while minimized")

        bridge = self.bridge()
        row = bridge.panel._children[0]
        row._children[0] = NoGeometry("№ row 1", value="741877")
        result = MODULE.read_kc_list_background(bridge, 123)
        self.assertEqual(result["take_no"], 741877)
        self.assertEqual(result["first_row_x"], 0)

    def test_recycled_handle_with_new_process_drops_cache(self):
        bridge = self.bridge()
        MODULE.read_kc_list_background(bridge, 123)
        bridge.window.ProcessId = 92
        MODULE.read_kc_list_background(bridge, 123)
        self.assertEqual(bridge.grid_searches, 2)

    def test_browser_window_is_rejected_even_with_matching_title(self):
        bridge = self.bridge()
        bridge.window.ClassName = "Chrome_WidgetWin_1"
        result = MODULE.read_kc_list_background(bridge, 123)
        self.assertFalse(result["ok"])
        self.assertEqual(bridge.grid_searches, 0)

    def test_invalid_or_closed_handle_returns_failure(self):
        bridge = self.bridge()
        self.assertFalse(MODULE.read_kc_list_background(bridge, 0)["ok"])
        bridge.auto.ControlFromHandle = lambda hwnd: None
        result = MODULE.read_kc_list_background(bridge, 123)
        self.assertFalse(result["ok"])
        self.assertEqual(result["background_hwnd"], 123)

    def test_background_still_excludes_orders_taken_by_another_operator(self):
        bridge = self.bridge()
        bridge.panel._children[0]._children[2]._value = "Operator 2"
        result = MODULE.read_kc_list_background(bridge, 123)
        self.assertTrue(result["ok"])
        self.assertEqual(result["take_no"], 0)

    def test_background_still_excludes_callback_orders(self):
        bridge = self.bridge()
        bridge.panel._children[0]._children[1]._value = "Пост-13 передзвонити"
        self.assertEqual(MODULE.read_kc_list_background(bridge, 123)["take_no"], 0)


if __name__ == "__main__":
    unittest.main()
