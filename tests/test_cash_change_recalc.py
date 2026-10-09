import unittest
import math
import re

def rc_parse_sum_value(str_val: str) -> int:
    if not str_val:
        return 0
    clean = str_val.replace('\xa0', '').replace(' ', '')
    m = re.search(r'(\d+(?:[.,]\d+)?)', clean)
    if m:
        val_str = m.group(1).replace(',', '.')
        try:
            return math.ceil(float(val_str))
        except ValueError:
            return 0
    return 0

def recalc_cash_change(order_sum: int, client_change: str, current_calc_change: int) -> int:
    try:
        parsed_client_change = int(client_change) if client_change.strip() else None
    except ValueError:
        parsed_client_change = None

    if parsed_client_change is not None and parsed_client_change >= order_sum:
        return parsed_client_change
    if order_sum > 0:
        return math.ceil(order_sum / 200) * 200
    return 1000

class TestCashChangeRecalc(unittest.TestCase):
    def test_parse_sum_formats(self):
        self.assertEqual(rc_parse_sum_value("804,00"), 804)
        self.assertEqual(rc_parse_sum_value("804.00 грн"), 804)
        self.assertEqual(rc_parse_sum_value("1 250,00 ₴"), 1250)
        self.assertEqual(rc_parse_sum_value("804.50"), 805)
        self.assertEqual(rc_parse_sum_value("0,00"), 0)
        self.assertEqual(rc_parse_sum_value(""), 0)

    def test_recalc_after_point_assigned(self):
        # Initial sum was 750, calc_change was 800
        # After "Найти точку", sum became 804
        new_change = recalc_cash_change(order_sum=804, client_change="", current_calc_change=800)
        self.assertEqual(new_change, 1000)

    def test_client_change_smaller_than_new_sum(self):
        # Client asked change from 800, but sum became 804
        # Must bump to 1000, never underpay!
        new_change = recalc_cash_change(order_sum=804, client_change="800", current_calc_change=800)
        self.assertEqual(new_change, 1000)

    def test_client_change_greater_than_new_sum(self):
        # Client asked change from 1000, sum became 804 -> keeps 1000
        new_change = recalc_cash_change(order_sum=804, client_change="1000", current_calc_change=1000)
        self.assertEqual(new_change, 1000)

    def test_standard_sum_rounding(self):
        self.assertEqual(recalc_cash_change(650, "", 0), 800)
        self.assertEqual(recalc_cash_change(800, "", 0), 800)
        self.assertEqual(recalc_cash_change(801, "", 0), 1000)
        self.assertEqual(recalc_cash_change(200, "", 0), 200)

if __name__ == '__main__':
    unittest.main()
