from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
ENGINE_PATH = ROOT / "engine_rollclub.ahk"
BUILD_PATH = ROOT / "packaging" / "build-rollclub-first-order-gunkan-module.ps1"
PUBLISH_PATH = ROOT / "packaging" / "publish-rollclub-mvp-release.ps1"


class RollClubFirstOrderGunkanModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = ENGINE_PATH.read_text(encoding="utf-8-sig")

    def test_module_is_external_and_disabled_without_package(self):
        self.assertIn(
            'ModuleRegistry_RegisterExternal("first_order_gunkan", "rollclub-first-order-gunkan")',
            self.source,
        )

    def test_marker_only_enables_gunkan_when_module_is_enabled(self):
        self.assertIn(
            'if (RcFirstOrderGunkanEnabled && RegExMatch(workComment, "i)!!!ПЕРШЕМОБ"))',
            self.source,
        )

    def test_amount_gifts_stay_separate_from_first_order_promo(self):
        self.assertIn("if (RC_GIFTS_ENABLED && orderSum > 0)", self.source)
        self.assertIn(
            "if (RcFirstOrderGunkanEnabled && autoGunkan && itemX != 0)",
            self.source,
        )

    def test_module_exposes_editable_gunkan_plu(self):
        self.assertIn("vNewGunkan Center Limit10, %pluGunkan%", self.source)
        self.assertIn("IniWrite, %NewGunkan%, %ConfigPath%, PLU, Gunkan", self.source)

    def test_module_builder_exists(self):
        self.assertTrue(BUILD_PATH.is_file())
        builder = BUILD_PATH.read_text(encoding="utf-8-sig")
        self.assertIn('id = "rollclub-first-order-gunkan"', builder)

    def test_release_publisher_uploads_module_asset(self):
        publisher = PUBLISH_PATH.read_text(encoding="utf-8-sig")
        self.assertIn('$assetsToPublish += $gunkanBuild.AssetPath', publisher)
        self.assertIn('$packages += $gunkanPackage', publisher)

    def test_pershemob_routes_to_customer_info_and_never_card_field(self):
        self.assertIn("hasPershemob := 1", self.source)
        self.assertIn('infoText := "ПЕРШЕМОБ"', self.source)
        # Verify cardText is NEVER populated with ПЕРШЕМОБ
        self.assertNotIn('cardText := "ПЕРШЕМОБ"', self.source)
        self.assertNotIn('cardText := "ПЕРШЕМОБ | "', self.source)
        # Verify ApplyRollclub targets Syrve's memoEditCustomerComment
        self.assertIn(
            'RcUiaFocusOrClick("Інформація про клієнта", "memoEditCustomerComment")',
            self.source,
        )
        # Verify RcKnownUiaSelector maps customer comment
        self.assertIn(
            'if (role = "Інформація про клієнта" || role = "Коментар клієнта" || role = "Клієнт")',
            self.source,
        )


if __name__ == "__main__":
    unittest.main()
