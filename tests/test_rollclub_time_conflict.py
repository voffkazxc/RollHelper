import unittest
import re
import sys
import os

# Function that mimics AHK time conflict evaluation
def evaluate_ahk_time(now_h, now_m, comment_time, kitchen_min, is_pickup=False, is_future_date=False):
    if is_future_date:
        return {
            "extracted_time": "",
            "is_conflict": False,
            "conflict_plaque": "",
            "call_alert": ""
        }

    now_mins = now_h * 60 + now_m
    standard_min = 40 if is_pickup else 90
    min_needed = kitchen_min if (kitchen_min and kitchen_min > 0) else standard_min

    def format_time(mins):
        h = (mins // 60) % 24
        m = mins % 60
        return f"{h:02d}:{m:02d}"

    has_comment_time = bool(comment_time)
    
    if has_comment_time:
        parts = comment_time.split(":")
        req_h, req_m = int(parts[0]), int(parts[1])
        req_mins = req_h * 60 + req_m
        diff_mins = req_mins - now_mins
        if diff_mins < -720:
            diff_mins += 1440
        elif diff_mins > 720:
            diff_mins -= 1440

        if diff_mins < 0:
            # Past time
            target = format_time(now_mins + min_needed)
            return {
                "extracted_time": target,
                "is_conflict": True,
                "conflict_plaque": f"⚠ ЧАС КЛІЄНТА ({comment_time}) МЕНШИЙ ЗА ПОТОЧНИЙ! ВИСТАВЛЕНО {target} (+{min_needed} хв) — УЗГОДИТИ!",
                "call_alert": f"⚠ УЗГОДИТИ ЧАС ({comment_time} ➔ {target}) — ЗАТЕЛЕФОНУВАТИ!"
            }
        elif diff_mins < min_needed:
            # Less than kitchen minimum
            target = format_time(now_mins + min_needed)
            return {
                "extracted_time": target,
                "is_conflict": True,
                "conflict_plaque": f"⚠ ЧАС КЛІЄНТА ({comment_time}) МЕНШИЙ ЗА КУХНЮ ({min_needed} хв)! ВИСТАВЛЕНО {target} — УЗГОДИТИ!",
                "call_alert": f"⚠ УЗГОДИТИ ЧАС ({comment_time} ➔ {target}) — ЗАТЕЛЕФОНУВАТИ!"
            }
        else:
            # Sufficient time
            if min_needed > standard_min:
                return {
                    "extracted_time": comment_time,
                    "is_conflict": True,
                    "conflict_plaque": f"⚠ ЗБІЛЬШЕНИЙ ЧАС КУХНІ ({min_needed} хв) — ПОПЕРЕДИТИ КЛІЄНТА!",
                    "call_alert": f"⚠ ЗБІЛЬШЕНИЙ ЧАС ({min_needed} хв) — ЗАТЕЛЕФОНУВАТИ!"
                }
            else:
                return {
                    "extracted_time": comment_time,
                    "is_conflict": False,
                    "conflict_plaque": "",
                    "call_alert": ""
                }
    else:
        # Nearest time
        target = format_time(now_mins + min_needed)
        if min_needed > standard_min:
            return {
                "extracted_time": target,
                "is_conflict": True,
                "conflict_plaque": f"⚠ ЗБІЛЬШЕНИЙ ЧАС КУХНІ ({min_needed} хв)! ВИСТАВЛЕНО {target} — УЗГОДИТИ!",
                "call_alert": f"⚠ ЗБІЛЬШЕНИЙ ЧАС ({min_needed} хв) — ЗАТЕЛЕФОНУВАТИ!"
            }
        else:
            return {
                "extracted_time": target,
                "is_conflict": False,
                "conflict_plaque": "",
                "call_alert": ""
            }

class TestRollClubTimeConflict(unittest.TestCase):
    def test_past_time_in_comment(self):
        # Current time 20:00, comment 19:30, kitchen 120 min
        res = evaluate_ahk_time(20, 0, "19:30", 120)
        self.assertTrue(res["is_conflict"])
        self.assertEqual(res["extracted_time"], "22:00")
        self.assertIn("МЕНШИЙ ЗА ПОТОЧНИЙ", res["conflict_plaque"])
        self.assertIn("19:30 ➔ 22:00", res["call_alert"])

    def test_less_than_kitchen_load(self):
        # Current time 19:35, comment 21:15 (100 min), kitchen 120 min (needs 21:35)
        res = evaluate_ahk_time(19, 35, "21:15", 120)
        self.assertTrue(res["is_conflict"])
        self.assertEqual(res["extracted_time"], "21:35")
        self.assertIn("МЕНШИЙ ЗА КУХНЮ (120 хв)", res["conflict_plaque"])
        self.assertIn("21:15 ➔ 21:35", res["call_alert"])

    def test_increased_kitchen_load_no_comment_time(self):
        # Current time 19:59, comment nearest time, kitchen 120 min
        res = evaluate_ahk_time(19, 59, "", 120)
        self.assertTrue(res["is_conflict"])
        self.assertEqual(res["extracted_time"], "21:59")
        self.assertIn("ЗБІЛЬШЕНИЙ ЧАС КУХНІ (120 хв)", res["conflict_plaque"])
        self.assertIn("ЗАТЕЛЕФОНУВАТИ", res["call_alert"])

    def test_pickup_increased_load(self):
        # Current time 19:59, pickup, kitchen pickup 60 min (standard is 40)
        res = evaluate_ahk_time(19, 59, "", 60, is_pickup=True)
        self.assertTrue(res["is_conflict"])
        self.assertEqual(res["extracted_time"], "20:59")
        self.assertIn("ЗБІЛЬШЕНИЙ ЧАС КУХНІ (60 хв)", res["conflict_plaque"])

    def test_standard_order(self):
        # Current time 20:00, standard delivery (90 min)
        res = evaluate_ahk_time(20, 0, "", 90)
        self.assertFalse(res["is_conflict"])
        self.assertEqual(res["extracted_time"], "21:30")
        self.assertEqual(res["conflict_plaque"], "")

if __name__ == "__main__":
    unittest.main()
