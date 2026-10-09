import unittest
import math

def calculate_payment_with_bonuses(order_sum: int, bonus_sum: int, client_change: str):
    cash_to_pay = max(0, order_sum - bonus_sum)
    try:
        parsed_client_change = int(client_change) if client_change.strip() else None
    except ValueError:
        parsed_client_change = None

    if parsed_client_change is not None and parsed_client_change >= cash_to_pay:
        calc_change = parsed_client_change
    elif cash_to_pay > 0:
        calc_change = math.ceil(cash_to_pay / 200) * 200
    else:
        calc_change = 0

    return cash_to_pay, calc_change

class TestBonusPayment(unittest.TestCase):
    def test_bonus_in_order(self):
        # Order 804 грн, bonuses 100 грн -> cash to pay is 704 грн
        # Round change is 800 грн
        cash_to_pay, calc_change = calculate_payment_with_bonuses(order_sum=804, bonus_sum=100, client_change="")
        self.assertEqual(cash_to_pay, 704)
        self.assertEqual(calc_change, 800)

    def test_bonus_with_client_change_large(self):
        # Order 804 грн, bonuses 100 грн, client asked change from 1000
        cash_to_pay, calc_change = calculate_payment_with_bonuses(order_sum=804, bonus_sum=100, client_change="1000")
        self.assertEqual(cash_to_pay, 704)
        self.assertEqual(calc_change, 1000)

    def test_bonus_with_client_change_too_small(self):
        # Order 804 грн, bonuses 100 грн, cash to pay 704 грн
        # If client comment said "500", but remaining is 704 -> bumps to 800
        cash_to_pay, calc_change = calculate_payment_with_bonuses(order_sum=804, bonus_sum=100, client_change="500")
        self.assertEqual(cash_to_pay, 704)
        self.assertEqual(calc_change, 800)

    def test_no_bonuses(self):
        # Standard order 804 грн without bonuses -> 1000 грн
        cash_to_pay, calc_change = calculate_payment_with_bonuses(order_sum=804, bonus_sum=0, client_change="")
        self.assertEqual(cash_to_pay, 804)
        self.assertEqual(calc_change, 1000)

    def test_full_bonus_payment(self):
        # Order 500 грн, bonuses 500 грн -> cash to pay is 0
        cash_to_pay, calc_change = calculate_payment_with_bonuses(order_sum=500, bonus_sum=500, client_change="")
        self.assertEqual(cash_to_pay, 0)
        self.assertEqual(calc_change, 0)

if __name__ == '__main__':
    unittest.main()
