import importlib.util
from pathlib import Path
import unittest


MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "brands"
    / "rollclub"
    / "server"
    / "rollclub_kc_legacy.py"
)
SPEC = importlib.util.spec_from_file_location("rollclub_kc_legacy", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class Control:
    def __init__(self, name="", class_name="", children=None, value=""):
        self.Name = name
        self.ClassName = class_name
        self._children = list(children or [])
        self._value = value

    def GetChildren(self):
        return self._children

    def GetValuePattern(self):
        return Pattern(self._value)

    def GetLegacyIAccessiblePattern(self):
        return Pattern(self._value)


class Pattern:
    def __init__(self, value):
        self.Value = value


class Auto:
    def __init__(self, root):
        self._root = root

    def GetRootControl(self):
        return self._root


class Bridge:
    def __init__(self):
        cells = [
            Control("№ row 1", value="741877"),
            Control("Комментарий row 1", value="Пост-13 Mob QR code"),
            Control("Оператор row 1", value=""),
            Control("Статус row 1", value="Не подтверждена"),
        ]
        self.panel = Control("Панель данных", children=[Control("Строка 1", children=cells)])
        self.grid = Control("gridDeliveries", children=[self.panel])
        self.window = Control("Syrve Office", "WindowsForms", [])
        self.root = Control(children=[self.window])
        self.auto = Auto(self.root)
        self._kc_panel_cache = None
        self.grid_searches = 0
        self.logs = []

    def _com_init(self):
        pass

    def _get_foreground_win(self):
        return self.window

    def _find_by_id(self, control, automation_id, max_depth=0):
        if automation_id == "DeliveryOrderEditControl":
            return None
        if automation_id == "gridDeliveries":
            self.grid_searches += 1
            return self.grid
        return None

    def _log(self, message):
        self.logs.append(message)


class RollClubDutyCacheTests(unittest.TestCase):
    def test_second_scan_reuses_original_panel_cache(self):
        bridge = Bridge()

        first = MODULE.read_kc_list(bridge)
        second = MODULE.read_kc_list(bridge)

        self.assertEqual(first["take_no"], 741877)
        self.assertEqual(second["take_no"], 741877)
        self.assertEqual(bridge.grid_searches, 1)
        self.assertIn("cached=0", bridge.logs[0])
        self.assertIn("cached=1", bridge.logs[1])

    def test_reader_does_not_require_removed_bridge_cell_helper(self):
        bridge = Bridge()

        self.assertFalse(hasattr(bridge, "_kc_cell"))
        result = MODULE.read_kc_list(bridge)

        self.assertEqual(result["take_no"], 741877)
        self.assertEqual(result["take"]["operator"], "")
        self.assertEqual(result["take"]["status"], "Не подтверждена")

    def test_engine_keeps_original_after_take_action_chain(self):
        engine_path = MODULE_PATH.parents[3] / "engine_rollclub.ahk"
        source = engine_path.read_text(encoding="utf-8-sig")
        markers = [
            "dutyOn := 0",
            "_inDutyTake := 1",
            "GoSub, TriggerMain",
            "GoSub, ApplyRollclub",
            "_inDutyTake := 0",
            "GoSub, SoundOk",
            "kcTook := 1",
        ]

        positions = [source.index(marker, source.index("; opened -> read")) for marker in markers]
        self.assertEqual(positions, sorted(positions))


if __name__ == "__main__":
    unittest.main()
