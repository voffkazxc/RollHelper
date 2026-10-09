import unittest
import re

def compute_ready_time(cur_hour: int, cur_min: int, add_minutes: int):
    total = cur_hour * 60 + cur_min + add_minutes
    hh = (total // 60) % 24
    mm = total % 60
    return f"{hh:02d}", f"{mm:02d}"

def format_time_parts(h_val, m_val):
    if h_val is None or str(h_val).strip() == "":
        r_h = ""
    else:
        r_h = f"{int(str(h_val).strip()):02d}"
        
    if m_val is None or str(m_val).strip() == "":
        r_m = ""
    else:
        r_m = f"{int(str(m_val).strip()):02d}"
        
    return r_h, r_m

def build_time_send_sequence(r_h: str, r_m: str):
    if not r_h or not r_m:
        return []
    return [
        "{Home}",
        "{Del 3}",
        r_h,
        "{Right}",
        r_m,
        "{Tab}"
    ]

class TestRollclubTimeEntry(unittest.TestCase):
    def test_time_calculation_standard(self):
        # 14:15 + 40 min -> 14:55
        h, m = compute_ready_time(14, 15, 40)
        self.assertEqual(h, "14")
        self.assertEqual(m, "55")

    def test_time_calculation_hour_rollover(self):
        # 14:45 + 40 min -> 15:25
        h, m = compute_ready_time(14, 45, 40)
        self.assertEqual(h, "15")
        self.assertEqual(m, "25")

    def test_time_calculation_midnight_rollover(self):
        # 23:40 + 50 min -> 00:30
        h, m = compute_ready_time(23, 40, 50)
        self.assertEqual(h, "00")
        self.assertEqual(m, "30")

    def test_format_single_digits(self):
        # "9" and "5" should become "09" and "05"
        h, m = format_time_parts("9", "5")
        self.assertEqual(h, "09")
        self.assertEqual(m, "05")

    def test_send_sequence_structure(self):
        seq = build_time_send_sequence("18", "45")
        self.assertEqual(seq[0], "{Home}")
        self.assertIn("18", seq)
        self.assertIn("{Right}", seq)
        self.assertIn("45", seq)
        self.assertEqual(seq[-1], "{Tab}")

    def test_ahk_process_time_calc_isolated(self):
        # Verify that in engine_rollclub.ahk ProcessTimeCalc ends with return and does not fall into HFinishOrder
        with open(r"C:\Users\voffk\Documents\РХ_ПалочкиPRO_V6.5\RollHelper\engine_rollclub.ahk", "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        match = re.search(r"ProcessTimeCalc:\s*\n([\s\S]*?)\nHFinishOrder:", content)
        self.assertIsNotNone(match, "ProcessTimeCalc must be followed by HFinishOrder")
        block = match.group(1)
        self.assertIn("RcSetReadyByMinutes", block)
        self.assertIn("return", block)
        self.assertNotIn("HFinishOrder", block)

if __name__ == "__main__":
    unittest.main()
