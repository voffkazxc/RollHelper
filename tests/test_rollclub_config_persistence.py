from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
ENGINE_PATH = ROOT / "engine_rollclub.ahk"
BUILD_PATH = ROOT / "packaging" / "build-rollclub-mvp.ps1"


class RollClubConfigPersistenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = ENGINE_PATH.read_text(encoding="utf-8-sig")
        cls.builder = BUILD_PATH.read_text(encoding="utf-8-sig")

    def test_main_config_is_stored_in_user_data(self):
        self.assertIn(
            "ConfigPath := RcPrepareMainConfig(PackageConfigPath)", self.engine
        )
        self.assertIn('RcUserDataDir() . "\\RkConfig.ini"', self.engine)

    def test_settings_never_write_to_relative_config(self):
        self.assertIsNone(
            re.search(r"Ini(?:Write|Delete),[^\n]*,\s*RkConfig\.ini,", self.engine)
        )

    def test_legacy_coordinates_and_uia_are_migrated(self):
        self.assertIn("RcFindBestMainConfig", self.engine)
        self.assertIn("LegacyImported", self.engine)
        self.assertIn(
            r'\*\RollHelper\brands\rollclub\RkConfig.ini', self.engine
        )

    def test_builder_copies_committed_config_as_raw_bytes(self):
        self.assertIn("StandardOutput.BaseStream.CopyTo", self.builder)
        self.assertNotIn("$cleanConfig | Set-Content", self.builder)


if __name__ == "__main__":
    unittest.main()
