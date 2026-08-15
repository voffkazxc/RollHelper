import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "brands" / "rollclub" / "server" / "rollclub_point_dialogs.py"
SPEC = importlib.util.spec_from_file_location("rollclub_point_dialogs", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FakePattern:
    def __init__(self, value=""):
        self.Value = value


class FakeControl:
    def __init__(self, name="", value="", children=None):
        self.Name = name
        self._value = value
        self._children = children or []

    def GetChildren(self):
        return self._children

    def GetValuePattern(self):
        return FakePattern(self._value)

    def GetLegacyIAccessiblePattern(self):
        return FakePattern("")


class RollClubPointDialogTests(unittest.TestCase):
    def test_recognizes_russian_city_price_warning(self):
        dialog = FakeControl(
            "Сообщение",
            children=[FakeControl("Для этого города действуют другие цены. Обратите внимание.")],
        )
        self.assertTrue(MODULE.is_known_find_point_dialog(dialog))

    def test_recognizes_ukrainian_city_price_warning(self):
        dialog = FakeControl(
            "Повідомлення",
            children=[FakeControl("Для цього міста діють інші ціни. Зверніть увагу.")],
        )
        self.assertTrue(MODULE.is_known_find_point_dialog(dialog))

    def test_keeps_existing_known_dialogs(self):
        self.assertTrue(MODULE.is_known_find_point_dialog(FakeControl("Внимание")))
        self.assertTrue(MODULE.is_known_find_point_dialog(FakeControl("Сумма заказа")))

    def test_does_not_close_unrelated_dialog(self):
        dialog = FakeControl("Подтверждение", children=[FakeControl("Удалить заказ?")])
        self.assertFalse(MODULE.is_known_find_point_dialog(dialog))

    def test_build_includes_and_installs_handler(self):
        build_script = (ROOT / "packaging" / "build-rollclub-mvp.ps1").read_text(encoding="utf-8-sig")
        self.assertIn("rollclub_point_dialogs.py", build_script)
        self.assertIn("is_known_find_point_dialog(p)", build_script)


if __name__ == "__main__":
    unittest.main()
