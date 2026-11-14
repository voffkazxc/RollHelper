import configparser
import csv
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("kitchen_sync", ROOT / "brands/rollclub/server/sync_rollclub_kitchens.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

HEADER = ["МІСТО", "АДМІН", "ПРИМІТКА", "СТОП", "ЦЕНТР", "СВ", "Дальня зона", "СТОП ЦЕХА", "ТЕРМИНАЛ", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22"]
ROW = ["[Драгоманова] Драгоманова 38", "Адмін", "Генератор\nІнтервал: ±30 хв", "Пепсі 0,33 блек", "Работаем по предзаказам", "Стандарт", "Работаем по предзаказам", "СТОП: ТЕМПУРА", "ЕСТЬ", "⚪", "⚪", "⚪", "🔴", "⚪", "🔴", "🔴", "🔴", "🔴", "🟡", "🟢"]


def sheet(header=HEADER, row=ROW):
    output = io.StringIO(newline="")
    writer = csv.writer(output)
    city = [""] * len(header)
    city[header.index("МІСТО")] = "КИЇВ"
    writer.writerows([header, city, row])
    return output.getvalue()


class KitchenAvailabilityTests(unittest.TestCase):
    def parse(self, header=HEADER, row=ROW):
        return sync.parse_sheet_rows(sheet(header, row), {"Драгоманова": "CUSTOM-KML"})[0]

    def test_independent_stops_and_multiline_note(self):
        k = self.parse()
        self.assertEqual(k["StopList"], "Пепсі 0,33 блек")
        self.assertEqual(k["StopWorkshop"], "СТОП: ТЕМПУРА")
        self.assertIn("Генератор Інтервал", k["Remark"])
        self.assertEqual(k["KmlKey"], "CUSTOM-KML")
        self.assertEqual(k["City"], "Київ")

    def test_only_green_and_yellow_hours(self):
        k = self.parse()
        self.assertEqual(k["PreorderAvailable"], "22:00")
        self.assertEqual(k["PreorderLimited"], "21:00")
        self.assertEqual(k["SlotsLoaded"], "1")
        self.assertEqual(k["DataVersion"], "2")

    def test_header_order_does_not_change_result(self):
        order = list(reversed(range(len(HEADER))))
        k = self.parse([HEADER[i] for i in order], [ROW[i] for i in order])
        expected = self.parse()
        expected.pop("UpdatedUTC")
        k.pop("UpdatedUTC")
        self.assertEqual(k, expected)

    def test_all_unavailable_states_and_ambiguous_markers(self):
        for marker in ("🔴", "⚪", "⚫", "🔘", "", "нет", "сірий", "🟢🔴", "🟢🟡", "🟠"):
            with self.subTest(marker=marker):
                row = ROW[:9] + [marker] * 11
                k = self.parse(row=row)
                self.assertEqual((k["PreorderAvailable"], k["PreorderLimited"]), ("", ""))
                self.assertEqual(k["SlotsLoaded"], "1")

    def test_no_hour_headers_is_unknown(self):
        k = self.parse(HEADER[:9], ROW[:9])
        self.assertEqual(k["SlotsLoaded"], "0")

    def test_missing_stop_header_rejects_sync_instead_of_clearing_cache(self):
        for field in ("СТОП", "СТОП ЦЕХА", "ЦЕНТР", "СВ", "Дальня зона", "МІСТО"):
            header = ["unexpected" if h == field else h for h in HEADER]
            # Build raw CSV because the city helper itself requires МІСТО.
            output = io.StringIO()
            csv.writer(output).writerows([header, ROW])
            with self.subTest(field=field), self.assertRaises(ValueError):
                sync.parse_sheet_rows(output.getvalue(), {})

    def test_duplicate_hour_is_conservative(self):
        for marker, expected in (("🔴", ""), ("🟡", "22:00"), ("🟢", "")):
            k = self.parse(HEADER + ["22:00"], ROW + [marker])
            self.assertEqual(k["PreorderLimited"], "21:00" + (", " + expected if expected else ""))
            self.assertEqual(k["PreorderAvailable"], "22:00" if marker == "🟢" else "")

    def test_standard_stops_are_not_presented_as_stop_items(self):
        row = ROW.copy()
        row[3], row[7] = "Стандарт", "—"
        k = self.parse(row=row)
        self.assertEqual((k["StopList"], k["StopWorkshop"]), ("", ""))

    def test_ini_roundtrip_and_backup_preserves_unicode_and_custom_kml(self):
        k = self.parse()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "RkKitchens.ini"
            path.write_text("[Драгоманова]\nKmlKey=CUSTOM-KML\n", encoding="utf-8-sig")
            before = path.read_bytes()
            sync.write_ini_file(path, [k])
            self.assertEqual(path.with_suffix(".ini.bak_sheet").read_bytes(), before)
            self.assertTrue(path.read_bytes().startswith(b"\xef\xbb\xbf"))
            ini = configparser.ConfigParser(interpolation=None)
            ini.read(path, encoding="utf-8-sig")
            for key in sync.INI_FIELDS:
                self.assertEqual(ini["Драгоманова"][key], k[key])
            self.assertEqual(sync.parse_existing_kml_keys(path)["Драгоманова"], "CUSTOM-KML")

    def test_main_keeps_current_kml_over_older_backup(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "RkKitchens.ini"
            path.write_text("[Драгоманова]\nKmlKey=CURRENT\n", encoding="utf-8-sig")
            path.with_suffix(".ini.bak_sheet").write_text("[Драгоманова]\nKmlKey=OLD\n", encoding="utf-8-sig")
            with patch.object(sync, "kitchens_paths", return_value=[path]), patch.object(sync.sys, "argv", ["sync", "--quiet"]), patch.object(sync.urllib.request, "urlopen", return_value=io.BytesIO(sheet().encode("utf-8"))):
                self.assertEqual(sync.main(), 0)
            self.assertEqual(sync.parse_existing_kml_keys(path)["Драгоманова"], "CURRENT")

    def test_failed_fetch_or_invalid_sheet_keeps_cache_untouched(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "RkKitchens.ini"
            before = b"[custom]\nKmlKey=preserve\n"
            path.write_bytes(before)
            for source in (OSError("offline"), io.BytesIO(b"invalid,headers\nnot,a,kitchen")):
                options = {"side_effect": source} if isinstance(source, Exception) else {"return_value": source}
                with patch.object(sync, "kitchens_paths", return_value=[path]), patch.object(sync.sys, "argv", ["sync", "--quiet"]), patch.object(sync.urllib.request, "urlopen", **options):
                    with self.assertRaises((OSError, ValueError)):
                        sync.main()
                self.assertEqual(path.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
