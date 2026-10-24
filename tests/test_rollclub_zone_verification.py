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
        self.assertIn("HARD_CITY_MISMATCH", self.source)
        self.assertIn("RcFindZone(lng, lat, detectedCity)", self.source)

    def test_new_address_clears_previous_zone_before_lookup(self):
        start = self.source.index("\nRcCheckZone:")
        end = self.source.index("\n    if (!RcRefreshZonesModuleState())", start)
        reset_section = self.source[start:end]
        self.assertIn('RcLastZone := ""', reset_section)
        self.assertIn('RcCurrentKitchen := ""', reset_section)
        self.assertIn('lastZoneName := ""', reset_section)

    def test_bundled_zones_enable_module_without_external_package(self):
        self.assertIn('RcZonesModuleEnabled := Module_IsEnabled("zones") || FileExist(kmlPath)', self.source)

    def test_bilingual_city_aliases_and_normalizations(self):
        for city_ru, city_ua in [
            ("Харьков", "Харків"),
            ("Одесса", "Одеса"),
            ("Киев", "Київ"),
            ("Днепр", "Дніпро"),
            ("Львов", "Львів"),
            ("Винница", "Вінниця"),
            ("Ровно", "Рівне"),
            ("Белая Церковь", "Біла Церква"),
        ]:
            self.assertIn(f'"{city_ru}"', self.source)
            self.assertIn(f'detectedCity := "{city_ua}"', self.source)

    def test_bilingual_street_prefix_and_microdistrict_cleaning(self):
        self.assertIn("Тополя-$1", self.source)
        self.assertIn("Перемога-$1", self.source)
        self.assertIn("Сокіл-$1", self.source)
        self.assertIn("Червоний Камінь", self.source)
        self.assertIn("Покровський", self.source)
        self.assertIn("Лівобережний-$1", self.source)
        self.assertIn("Сонячний", self.source)
        self.assertIn("Північний", self.source)
        self.assertIn("шосе|шоссе", self.source)

    def test_build_script_preserves_zone_files(self):
        build_script = (ENGINE_PATH.parent / "packaging" / "build-rollclub-mvp.ps1").read_text(encoding="utf-8")
        self.assertNotIn('"zones.kml"', build_script)
        self.assertNotIn('"zones_map.ini"', build_script)
        self.assertNotIn('"RkPresets.txt"', build_script)
        self.assertIn('"zones_map.BEFORE_NEW_MAPPINGS_20260726_215931.ini"', build_script)


    def test_nova_anglia_kitchen_and_point_mapping(self):
        self.assertIn('return "Київ Нова Англія"', self.source)
        self.assertIn('if (concept = "Київ Нова Англія")', self.source)
        self.assertIn('return "Нова Англія"', self.source)
        self.assertIn('InStr(point, "Нова Англія")', self.source)

    def test_zones_map_contains_updated_kyiv_and_lviv_zones(self):
        data_dir = ENGINE_PATH.parent / "modules" / "rollclub-zones" / "data"
        zones_map_text = (data_dir / "zones_map.ini").read_text(encoding="utf-16")
        self.assertIn("[Нова Англія] Михайла Максимовича 32б (правий берег)", zones_map_text)
        self.assertIn("[Антонова] Авіаконструктора Антонова 43 (правий берег)", zones_map_text)
        self.assertIn("[Драгоманова] Драгоманова 38 (лівий берег)", zones_map_text)
        self.assertIn("Зона підвищеного часу проїзд Крива Липа 8", zones_map_text)

    def test_zone_name_normalization_strips_nbsp_and_newlines(self):
        self.assertIn("RcNormalizeZoneName(name)", self.source)
        self.assertIn(r'RegExReplace(name, "[\s\x{00A0}]+", " ")', self.source)
        self.assertIn("zoneExact := RcNormalizeZoneName(zoneName)", self.source)

    def test_dnipro_far_suburbs_detected_and_mapped_to_mudrogo_far(self):
        self.assertIn("дослідне", self.source)
        self.assertIn("краснопілля", self.source)
        self.assertIn("мирне", self.source)
        self.assertIn("дороге", self.source)

    def test_increased_time_operator_warning_banner_and_tooltip(self):
        self.assertIn('RcLastDeliveryMin > 90 || RcLastDeliveryKind == "FAR"', self.source)
        self.assertIn("ЗБІЛЬШЕНИЙ ЧАС", self.source)
        self.assertIn("ПОПЕРЕДИТИ КЛІЄНТА", self.source)
        self.assertIn("ОБОВ'ЯЗКОВО ЗАТЕЛЕФОНУЙ КЛІЄНТУ", self.source)

    def test_effective_delivery_time_adds_step_for_far_zones(self):
        self.assertIn("outMinFar := centerMins + 30", self.source)
        self.assertIn("if (farMins > centerMins)", self.source)


if __name__ == '__main__':
    unittest.main()
