from pathlib import Path
import unittest


ENGINE_PATH = Path(__file__).resolve().parents[1] / "engine_rollclub.ahk"


class RollClubZoneVerificationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = ENGINE_PATH.read_text(encoding="utf-8-sig")

    def test_pult_schedules_address_zone_detection(self):
        self.assertIn("SetTimer, RcCheckZone, -450", self.source)

    def test_apply_calls_point_verification_not_zone_detection(self):
        start = self.source.index("ApplyRollclub:")
        end = self.source.index("; ==== DEBUG: лог запису ====", start)
        apply_section = self.source[start:end]

        self.assertIn("SetTimer, RcVerifyPoint, Off", apply_section)
        self.assertIn("GoSub, RcVerifyPoint", apply_section)
        self.assertNotIn("GoSub, RcCheckZone", apply_section)

    def test_point_verification_compares_kml_kitchen_with_iiko_point(self):
        start = self.source.index("\nRcVerifyPoint:")
        end = self.source.index("\nRcPickupVerifyPoint:", start)
        verify_section = self.source[start:end]

        self.assertIn('/api/iiko/diagnose_point_prepare', verify_section)
        self.assertIn("RcKitchenFromKmlZone(RcLastZone)", verify_section)
        self.assertIn("RcKitchenFromIikoPoint(iikoPoint)", verify_section)
        self.assertIn("DELIVERY_IDENTITY", verify_section)

    def test_zone_module_contains_operator_data(self):
        data_dir = ENGINE_PATH.parent / "modules" / "rollclub-zones" / "data"
        for file_name in ("zones.kml", "zones_map.ini", "RkKitchens.ini"):
            self.assertTrue((data_dir / file_name).is_file(), file_name)


if __name__ == "__main__":
    unittest.main()
