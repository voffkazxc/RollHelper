import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ENGINE_PATH = REPO_ROOT / "engine_rollclub.ahk"


class RollClubPointFallbackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine_source = ENGINE_PATH.read_text(encoding="utf-8-sig", errors="replace")

    def test_engine_has_apply_point_fallback_function(self):
        self.assertIn("RcApplyPointFallback(reasonText := \"Адресу не знайдено\")", self.engine_source)

    def test_engine_has_find_kitchen_from_point_or_concept(self):
        self.assertIn("RcFindKitchenFromPointOrConcept(pointVal, conceptVal)", self.engine_source)

    def test_point_fallback_reads_identity_from_server_and_uia(self):
        self.assertIn('/api/iiko/read_identity_fast', self.engine_source)
        self.assertIn('lookUpEditDeliveryTerminal', self.engine_source)
        self.assertIn('restoCompletionConception', self.engine_source)

    def test_point_fallback_sets_warning_and_kitchen_status_text(self):
        self.assertIn('"⚠ ТОЧКА: " . RcCurrentKitchen.Name . " (перевір адресу)"', self.engine_source)
        self.assertIn('GuiControl, Roll:, KitchenStatusText, %kAlertText%', self.engine_source)
        self.assertIn('Натисни «Знайти точку» в Syrve і знову ~ (Тільду)', self.engine_source)

    def test_rc_check_zone_invokes_fallback_on_empty_and_failed_address(self):
        self.assertIn('if (RcApplyPointFallback("Адресу не знайдено"))', self.engine_source)
        self.assertIn('if (RcApplyPointFallback("Точку не знайдено в зонах"))', self.engine_source)

    def test_map_search_has_recheck_click_handler(self):
        self.assertIn("vMapSearch gRcRecheckZoneOrPoint", self.engine_source)
        self.assertIn("RcRecheckZoneOrPoint:", self.engine_source)

    def test_trigger_main_destroys_and_rescans_when_active_in_syrve(self):
        self.assertIn('if WinActive("Rollclub PRO 33.0")', self.engine_source)
        self.assertIn('if WinExist("Rollclub PRO 33.0")', self.engine_source)
        self.assertIn('Gui, Roll:Destroy', self.engine_source)


if __name__ == "__main__":
    unittest.main()
