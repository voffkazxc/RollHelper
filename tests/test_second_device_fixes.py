import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ENGINE_PATH = REPO_ROOT / "engine_rollclub.ahk"
IIKO_DRIVER_PATH = REPO_ROOT / "lib" / "IikoDriver.ahk"

class SecondDeviceFixesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine_source = ENGINE_PATH.read_text(encoding="utf-8-sig", errors="replace")
        cls.driver_source = IIKO_DRIVER_PATH.read_text(encoding="utf-8-sig", errors="replace")

    def test_iiko_driver_has_get_element_value(self):
        self.assertIn("IikoDriver_GetElementValue(automationId)", self.driver_source)

    def test_engine_has_rc_uia_get_text(self):
        self.assertIn("RcUiaGetText(role, defaultAid := \"\")", self.engine_source)

    def test_trigger_main_extracts_street_and_house_from_server(self):
        self.assertIn('"street"', self.engine_source)
        self.assertIn('"house"', self.engine_source)
        self.assertIn("rawAddress := _srvStreet . (_srvHouse != \"\" ? (\" \" . _srvHouse) : \"\")", self.engine_source)

    def test_trigger_main_has_native_uia_fallback(self):
        self.assertIn('RcUiaGetText("Вулиця", "gridLookUpEditStreetAddress")', self.engine_source)
        self.assertIn('RcUiaGetText("Будинок", "textEditDeliveryHouse")', self.engine_source)
        self.assertIn('RcUiaGetText("Коментар", "memoEditDeliveryComment")', self.engine_source)

    def test_rc_check_zone_handles_empty_address_and_pickup(self):
        self.assertIn("Адресу не знайдено", self.engine_source)
        self.assertIn("GuiControl, Roll:, MapSearch, Адресу не знайдено", self.engine_source)

    def test_apply_rollclub_guards_point_verification_with_last_zone(self):
        self.assertIn("if (!hasPickup && CHECK_POINT_ENABLED && RcLastZone != \"\" && naitiX != 0 && tochkaX != 0)", self.engine_source)
        self.assertIn("RcLastZone = \"\"", self.engine_source)

    def test_apply_rollclub_uses_uia_focus_before_coordinates(self):
        self.assertIn('RcUiaFind("Коментар", "memoEditDeliveryComment")', self.engine_source)
        self.assertIn('RcUiaFind("Картка", "textEditCustomerCardNumber")', self.engine_source)
        self.assertIn('RcUiaFind("Примітка до адреси", "memoEditDeliveryAddressComment")', self.engine_source)

    def test_pickup_detects_samovynos_and_samovyvoz(self):
        pattern = r"i\)\(\*UCP\)\(\?<!\[\\wа-яА-ЯіїєґІЇЄҐёЁ\]\)\(Самовивіз\|Самовывоз\|Самовынос\)\(\?!\[\\wа-яА-ЯіїєґІЇЄҐёЁ\]\)"
        self.assertTrue(re.search(pattern, self.engine_source))

        # Test simulated regex on texts
        py_pattern = re.compile(r"(?<![\wа-яА-ЯіїєґІЇЄҐёЁ])(Самовивіз|Самовывоз|Самовынос)(?![\wа-яА-ЯіїєґІЇЄҐёЁ])", re.IGNORECASE)
        self.assertTrue(py_pattern.search("Самовынос: Новые Дома"))
        self.assertTrue(py_pattern.search("Самовывоз НД"))
        self.assertTrue(py_pattern.search("Самовивіз: Садовий"))

if __name__ == "__main__":
    unittest.main()
