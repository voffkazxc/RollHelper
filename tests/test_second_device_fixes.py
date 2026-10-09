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
        self.assertIn('RcUiaFocusOrClick("Коментар", "memoEditDeliveryComment"', self.engine_source)
        self.assertIn('RcUiaFocusOrClick("Картка", "textEditCustomerCardNumber"', self.engine_source)
        self.assertIn('RcUiaFocusOrClick("Примітка до адреси", "memoEditDeliveryAddressComment"', self.engine_source)

    def test_pickup_detects_samovynos_and_samovyvoz(self):
        pattern = r"i\)\(\*UCP\)\(\?<!\[\\wа-яА-ЯіїєґІЇЄҐёЁ\]\)\(Самовивіз\|Самовывоз\|Самовынос\)\(\?!\[\\wа-яА-ЯіїєґІЇЄҐёЁ\]\)"
        self.assertTrue(re.search(pattern, self.engine_source))

        # Test simulated regex on texts
        py_pattern = re.compile(r"(?<![\wа-яА-ЯіїєґІЇЄҐёЁ])(Самовивіз|Самовывоз|Самовынос)(?![\wа-яА-ЯіїєґІЇЄҐёЁ])", re.IGNORECASE)
        self.assertTrue(py_pattern.search("Самовынос: Новые Дома"))
        self.assertTrue(py_pattern.search("Самовывоз НД"))
        self.assertTrue(py_pattern.search("Самовивіз: Садовий"))

    def test_settings_has_clean_four_tabs_and_coord_formatter(self):
        self.assertIn("RcFormatCoordBtn(title, x, y)", self.engine_source)
        self.assertIn("Tab3, x10 y10 w460 h595 vSettingsTab, Клавіші та Опції|Координати|PLU коди|Діагностика", self.engine_source)
        self.assertIn("vBtnComm", self.engine_source)
        self.assertIn("vBtnCard", self.engine_source)
        self.assertIn("vBtnAddr", self.engine_source)

    def test_hkfinish_is_dynamically_bound(self):
        self.assertIn("if (hkFinish != \"\") {", self.engine_source)
        self.assertIn("try Hotkey, %hkFinish%, FinishOrder, On", self.engine_source)

    def test_hotkey_normalization_logic(self):
        self.assertIn("RcNormalizeHotkey(hk, defaultHk := \"\")", self.engine_source)
        self.assertIn('if InStr(clean, "Тильда") || InStr(clean, "~")', self.engine_source)
        self.assertIn('return "vkC0"', self.engine_source)
        self.assertIn('if InStr(clean, "Ctrl+Shift+Enter")', self.engine_source)
        self.assertIn('return "^+Enter"', self.engine_source)
        self.assertIn('if InStr(clean, "Ctrl+Enter")', self.engine_source)
        self.assertIn('return "^Enter"', self.engine_source)

    def test_save_settings_releases_mutex_before_reload(self):
        self.assertIn('DllCall("CloseHandle", "Ptr", RhSingleInstanceMutex)', self.engine_source)
        self.assertIn("Reload", self.engine_source)

    def test_rh_kill_duplicate_instances_waits_for_process_and_retries_mutex(self):
        self.assertIn("Process, WaitClose, %pid%, 2", self.engine_source)
        self.assertIn("Loop, 15 {", self.engine_source)
        self.assertIn('RhSingleInstanceMutex := DllCall("CreateMutex"', self.engine_source)

    def test_siv_vis_apply_activates_syrve_window(self):
        siv_block = re.search(r"SivVisApply:.*?(?=\n\S|\Z)", self.engine_source, re.DOTALL)
        self.assertIsNotNone(siv_block)
        block_text = siv_block.group(0)
        self.assertIn("IikoDriver_GetIikoHwnd()", block_text)
        self.assertIn("WinActivate, ahk_id %iikoHwnd%", block_text)
        self.assertIn("WinWaitActive, ahk_id %iikoHwnd%", block_text)

    def test_rc_punch_plu_series_activates_syrve_window(self):
        punch_series_block = re.search(r"RcPunchPluSeries\(jobs\)\s*\{.*?(?=\n\})", self.engine_source, re.DOTALL)
        self.assertIsNotNone(punch_series_block)
        block_text = punch_series_block.group(0)
        self.assertIn("IikoDriver_GetIikoHwnd()", block_text)
        self.assertIn("WinActivate, ahk_id %iikoHwnd%", block_text)

    def test_rc_click_first_order_row_clicks_bounding_rectangle(self):
        click_row_block = re.search(r"RcClickFirstOrderRowUIA\(\)\s*\{.*?(?=\n\})", self.engine_source, re.DOTALL)
        self.assertIsNotNone(click_row_block)
        block_text = click_row_block.group(0)
        self.assertIn("CurrentBoundingRectangle", block_text)
        self.assertIn("IikoDriver_ClickScreen", block_text)

    def test_rc_punch_plu_in_open_editor_uses_reliable_key_delay(self):
        punch_editor_block = re.search(r"RcPunchPluInOpenEditor\(pluCode, qty\)\s*\{.*?(?=\n\})", self.engine_source, re.DOTALL)
        self.assertIsNotNone(punch_editor_block)
        block_text = punch_editor_block.group(0)
        self.assertIn("SetKeyDelay, 45, 25", block_text)
        self.assertIn("SendEvent, %pluCode%", block_text)
        self.assertIn("SendEvent, %qty%", block_text)

if __name__ == "__main__":
    unittest.main()
