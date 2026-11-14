"""Minimized Office reads must not use the foreground window or screen geometry."""
import unittest

from test_rollclub_duty_cache import Bridge, Control, MODULE


class BackgroundDutyTests(unittest.TestCase):
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
