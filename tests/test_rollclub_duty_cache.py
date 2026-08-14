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
    def __init__(self, name="", class_name="", children=None):
        self.Name = name
        self.ClassName = class_name
        self._children = list(children or [])

    def GetChildren(self):
        return self._children


class Auto:
    def __init__(self, root):
        self._root = root

    def GetRootControl(self):
        return self._root


class Bridge:
    def __init__(self):
        cells = [
            Control("№ row 1"),
            Control("Комментарий row 1"),
            Control("Оператор row 1"),
            Control("Статус row 1"),
        ]
        self.values = {
            "№ row 1": "741877",
            "Комментарий row 1": "Пост-13 Mob QR code",
            "Оператор row 1": "",
            "Статус row 1": "Не подтверждена",
        }
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

    def _kc_cell(self, cell):
        return cell.Name.split(" row ")[0], self.values[cell.Name]

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


if __name__ == "__main__":
    unittest.main()
