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

    def test_boundary_addresses_are_marked_uncertain(self):
        self.assertIn("RcDistanceToZoneBoundaryMeters", self.source)
        self.assertIn("RcZoneBoundaryWarnMeters := 100", self.source)
        self.assertIn("⚠ Межа зон", self.source)
        self.assertIn("ПЕРЕВІРТЕ ТОЧКУ В SYRVE", self.source)

    def test_overlapping_kml_polygons_are_not_silently_accepted(self):
        self.assertIn("RcFindOverlappingZone", self.source)
        self.assertIn("⚠ Перетин зон", self.source)
        self.assertIn("ZONE_UNCERTAIN", self.source)

    def test_uncertain_zone_does_not_change_ready_time_automatically(self):
        self.assertIn(
            "if (extractedTimeAuto && !hasPickup && !RcLastZoneUncertain)",
            self.source,
        )

    def test_street_only_geocoder_fallback_is_not_treated_as_exact(self):
        self.assertIn("RcLastGeocodeApprox := 1", self.source)
        self.assertIn("⚠ Адрес без точного дома", self.source)

    def test_geocoder_never_accepts_another_city(self):
        self.assertIn("RcTryGeocodeResponse(resp, detectedCity, lat, lng)", self.source)
        self.assertIn("RcGeocodeResponseHasCity(resp, expectedCity)", self.source)
        self.assertIn(
            'fallbackQuery := (detectedCity != "") ? (detectedCity . ", " . addr) : addr',
            self.source,
        )

    def test_new_address_clears_previous_zone_before_lookup(self):
        start = self.source.index("\nRcCheckZone:")
        end = self.source.index("\n    if (!RcRefreshZonesModuleState())", start)
        reset_section = self.source[start:end]
        self.assertIn('RcLastZone := ""', reset_section)
        self.assertIn('RcCurrentKitchen := ""', reset_section)
        self.assertIn('lastZoneName := ""', reset_section)


if __name__ == "__main__":
    unittest.main()
