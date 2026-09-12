import importlib.util
from pathlib import Path
import re
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

    def test_duty_uses_ctrl_f4_and_plain_f4_is_free(self):
        engine_path = MODULE_PATH.parents[3] / "engine_rollclub.ahk"
        source = engine_path.read_text(encoding="utf-8-sig")

        self.assertRegex(source, r"(?m)^\^F4::\s*$")
        self.assertIsNone(re.search(r"(?m)^F4::\s*$", source))

    def test_operator_conflict_check_ignores_unrelated_windows_dialogs(self):
        engine_path = MODULE_PATH.parents[3] / "engine_rollclub.ahk"
        source = engine_path.read_text(encoding="utf-8-sig")
        start = source.index("RcFindOperatorConflictDialog()")
        monitor = source[start : source.index("#IfWinActive Rollclub PRO", start)]

        self.assertIn("dialogProcess = \"BackOffice.exe\"", monitor)
        self.assertIn("DUTY_OPERATOR_CONFLICT", monitor)
        self.assertNotIn('if (!_busy && WinExist("ahk_class #32770"))', monitor)

    def test_ukrainian_syrve_localization_is_supported(self):
        bridge = Bridge()
        ua_cells = [
            Control("№ row 1", value="741899"),
            Control("Коментар row 1", value="Пост-15 Доставка кур'єром"),
            Control("Оператор row 1", value=""),
            Control("Статус row 1", value="Не підтверджена"),
        ]
        bridge.panel = Control("Панель даних", children=[Control("Рядок 1", children=ua_cells)])
        bridge.grid = Control("gridDeliveries", children=[bridge.panel])

        result = MODULE.read_kc_list(bridge)

        self.assertTrue(result["ok"])
        self.assertEqual(result["take_no"], 741899)
    def test_all_rows_counted_for_search_filter_verification(self):
        bridge = Bridge()
        row1_cells = [
            Control("№ row 1", value="741899"),
            Control("Коментар row 1", value="пост-15 Доставка"),
            Control("Оператор row 1", value=""),
            Control("Статус row 1", value="Не підтверджена"),
        ]
        row2_cells = [
            Control("№ row 2", value="741900"),
            Control("Коментар row 2", value="Інше замовлення"),
            Control("Оператор row 2", value="Оператор 1"),
            Control("Статус row 2", value="В дорозі"),
        ]
        bridge.panel = Control("Панель даних", children=[
            Control("Рядок 1", children=row1_cells),
            Control("Рядок 2", children=row2_cells),
        ])
        bridge.grid = Control("gridDeliveries", children=[bridge.panel])

        result = MODULE.read_kc_list(bridge)
        self.assertTrue(result["ok"])
        self.assertEqual(result["take_no"], 741899)
        self.assertEqual(result["count"], 1)  # early break stops on first eligible order

    def test_filter_and_row_coordinates_calculated_from_no_cell(self):
        class MockRect:
            def __init__(self, left, top, right, bottom):
                self.left = left
                self.top = top
                self.right = right
                self.bottom = bottom
            def width(self):
                return self.right - self.left
            def height(self):
                return self.bottom - self.top
            def xcenter(self):
                return (self.left + self.right) // 2
            def ycenter(self):
                return (self.top + self.bottom) // 2

        bridge = Bridge()
        no_cell = Control("№ row 1", value="741899")
        no_cell.BoundingRectangle = MockRect(50, 200, 150, 240)
        row_cells = [
            no_cell,
            Control("Коментар row 1", value="Пост Доставка"),
            Control("Оператор row 1", value=""),
            Control("Статус row 1", value="Не підтверджена"),
        ]
        target_row = Control("Рядок 1", children=row_cells)
        target_row.BoundingRectangle = MockRect(0, 200, 800, 240)
        bridge.panel = Control("Панель даних", children=[target_row])
        bridge.grid = Control("gridDeliveries", children=[bridge.panel])

        result = MODULE.read_kc_list(bridge)

        self.assertTrue(result["ok"])
        self.assertEqual(result["take_no"], 741899)
        self.assertEqual(result["first_row_x"], 100)
        self.assertEqual(result["first_row_y"], 220)
        self.assertEqual(result["filter_x"], 100)
        self.assertEqual(result["filter_y"], 180)
        self.assertEqual(result["take"]["click_x"], 100)
        self.assertEqual(result["take"]["click_y"], 220)

    def test_dnipro_and_kyiv_orders_are_taken(self):
        bridge = Bridge()
        row_cells = [
            Control("№ row 1", value="857847"),
            Control("Коментар row 1", value="Дніпро Доставка кур'єром"),
            Control("Оператор row 1", value=""),
            Control("Статус row 1", value="Не підтверджена"),
        ]
        target_row = Control("Рядок 1", children=row_cells)
        bridge.panel = Control("Панель даних", children=[target_row])
        bridge.grid = Control("gridDeliveries", children=[bridge.panel])

        result = MODULE.read_kc_list(bridge)
        self.assertTrue(result["ok"])
        self.assertEqual(result["take_no"], 857847)

    def test_lowercase_and_arbitrary_row_names_recognized(self):
        bridge = Bridge()
        row_cells = [
            Control("№ row 1", value="796776"),
            Control("Коментар row 1", value="Київ Доставка"),
            Control("Оператор row 1", value=""),
            Control("Статус row 1", value="Не підтверджена"),
        ]
        # DevExpress might name row in lowercase, by order number, or empty
        target_row = Control("рядок 1", children=row_cells)
        bridge.panel = Control("панель даних", children=[target_row])
        bridge.grid = Control("gridDeliveries", children=[bridge.panel])
        result = MODULE.read_kc_list(bridge)
        self.assertTrue(result["ok"])
        self.assertEqual(result["take_no"], 796776)

    def test_order_number_with_prefix_and_nomer_column(self):
        bridge = Bridge()
        row_cells = [
            Control("Номер row 1", value="№ 857847"),
            Control("Коментар row 1", value="Дніпро самовивіз"),
            Control("Оператор row 1", value=""),
            Control("Статус row 1", value="Не підтверджена"),
        ]
        target_row = Control("рядок 1", children=row_cells)
        bridge.panel = Control("панель даних", children=[target_row])
        bridge.grid = Control("gridDeliveries", children=[bridge.panel])

        result = MODULE.read_kc_list(bridge)
        self.assertTrue(result["ok"])
        self.assertEqual(result["take_no"], 857847)


if __name__ == "__main__":
    unittest.main()


