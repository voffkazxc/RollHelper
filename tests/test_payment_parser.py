import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ENGINE_PATH = REPO_ROOT / "engine_rollclub.ahk"

# Python equivalent of the AHK regexes
PAID_REGEX = re.compile(
    r"(?:---ОПЛАЧЕНО---|(?<![\wа-яА-ЯіїєґІЇЄҐёЁ])(?:ОПЛАЧЕНО|Оплачено|Оплачен|Картою\s+на\s+сайті|Картой\s+на\s+сайте|Картою\s+онлайн|Картой\s+онлайн|Оплата\s+карткою|Оплата\s+картой|LiqPay|WayForPay|Portmone|Apple\s*Pay|Google\s*Pay|MonoPay)(?![\wа-яА-ЯіїєґІЇЄҐёЁ]))",
    re.IGNORECASE,
)
PAID_NUM_REGEX = re.compile(
    r"(?:---ОПЛАЧЕНО---\s*)?(?:Картою[^№\r\n]*|ОПЛАЧЕНО\s*|Оплачен[оа]?\s*(?:онлайн|на сайті|карткою)?\s*)№?\s*(\d+)",
    re.IGNORECASE,
)
QR_REGEX = re.compile(r"QR\s*code[^\d]*(\d+)", re.IGNORECASE)
QR_SIMPLE_REGEX = re.compile(r"(?<![\wа-яА-ЯіїєґІЇЄҐёЁ])QR(?![\wа-яА-ЯіїєґІЇЄҐёЁ])", re.IGNORECASE)
CASH_REGEX = re.compile(r"(?:Готівкою|Наличными|Готівка|Наличные)\s*№?\s*(\d*)", re.IGNORECASE)
RESHTA_DIGITS_REGEX = re.compile(r"(?:[Рр]ешт[уа]|[Сс]дач[ау])\s+з[:\s]+(\d+)", re.IGNORECASE)
RESHTA_WORD_REGEX = re.compile(r"(?:[Рр]ешт[уа]|[Сс]дач[ау])\s+з[:\s]+(ні|нет|без\s+решти|без\s+сдачи|no|0)", re.IGNORECASE)


def simulate_payment_parse(work_comment: str):
    is_paid_order = 0
    payment_method = ""
    payment_num = ""
    auto_cash = 0
    client_change = ""
    calc_change = 0

    if PAID_REGEX.search(work_comment):
        is_paid_order = 1
        payment_method = "Оплачено"
        m_num = PAID_NUM_REGEX.search(work_comment)
        if m_num:
            payment_num = m_num.group(1)
        else:
            m_alt = re.search(r"№\s*(\d{5,})", work_comment)
            if m_alt:
                payment_num = m_alt.group(1)
    elif QR_REGEX.search(work_comment):
        is_paid_order = 1
        payment_method = "QR"
        payment_num = QR_REGEX.search(work_comment).group(1)
    elif QR_SIMPLE_REGEX.search(work_comment):
        is_paid_order = 1
        payment_method = "QR"

    if not is_paid_order:
        m_cash = CASH_REGEX.search(work_comment)
        if m_cash:
            payment_method = "Готівкою"
            payment_num = m_cash.group(1)
            auto_cash = 1

    if is_paid_order:
        auto_cash = 0
        client_change = ""
        calc_change = 0
    else:
        m_reshta_num = RESHTA_DIGITS_REGEX.search(work_comment)
        if m_reshta_num:
            client_change = m_reshta_num.group(1)
            auto_cash = 1
            if not payment_method:
                payment_method = "Готівкою"
        elif RESHTA_WORD_REGEX.search(work_comment):
            client_change = ""
            auto_cash = 1
            if not payment_method:
                payment_method = "Готівкою"

    clean_parts = []
    if payment_method:
        if payment_num:
            clean_parts.append(f"{payment_method} №{payment_num}")
        else:
            clean_parts.append(payment_method)

    return {
        "is_paid_order": is_paid_order,
        "payment_method": payment_method,
        "payment_num": payment_num,
        "auto_cash": auto_cash,
        "client_change": client_change,
        "calc_change": calc_change,
        "clean_payment": " ".join(clean_parts),
    }


class PaymentParserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine_source = ENGINE_PATH.read_text(encoding="utf-8-sig", errors="replace")

    def test_paid_with_card_number_and_reshta_ni_never_sets_autocash(self):
        comment = "Пост-1 Знижка на таксі: -130 Mob !!!ПЕРШЕМОБ ---ОПЛАЧЕНО--- Картою на сайті №860096 Решта з: ні Прибори: Учбові x1"
        res = simulate_payment_parse(comment)
        self.assertEqual(res["is_paid_order"], 1)
        self.assertEqual(res["auto_cash"], 0)
        self.assertEqual(res["payment_method"], "Оплачено")
        self.assertEqual(res["payment_num"], "860096")
        self.assertEqual(res["client_change"], "")
        self.assertEqual(res["calc_change"], 0)
        self.assertEqual(res["clean_payment"], "Оплачено №860096")

    def test_paid_alone_without_number(self):
        comment = "---ОПЛАЧЕНО---"
        res = simulate_payment_parse(comment)
        self.assertEqual(res["is_paid_order"], 1)
        self.assertEqual(res["auto_cash"], 0)
        self.assertEqual(res["payment_method"], "Оплачено")
        self.assertEqual(res["payment_num"], "")
        self.assertEqual(res["clean_payment"], "Оплачено")

    def test_paid_russian_spelling(self):
        comment = "Пост-2 Сайт Оплачено картой онлайн Решта з: без решти 2026-10-10 15:00"
        res = simulate_payment_parse(comment)
        self.assertEqual(res["is_paid_order"], 1)
        self.assertEqual(res["auto_cash"], 0)
        self.assertEqual(res["payment_method"], "Оплачено")

    def test_paid_liqpay_and_wayforpay(self):
        res1 = simulate_payment_parse("Замовлення через LiqPay Решта з: ні")
        self.assertEqual(res1["is_paid_order"], 1)
        self.assertEqual(res1["auto_cash"], 0)

        res2 = simulate_payment_parse("Оплата WayForPay №998877")
        self.assertEqual(res2["is_paid_order"], 1)
        self.assertEqual(res2["auto_cash"], 0)
        self.assertEqual(res2["payment_num"], "998877")

    def test_paid_qr_code(self):
        comment = "Пост-5 Mob QR code №741890 Прибори: 2"
        res = simulate_payment_parse(comment)
        self.assertEqual(res["is_paid_order"], 1)
        self.assertEqual(res["auto_cash"], 0)
        self.assertEqual(res["payment_method"], "QR")
        self.assertEqual(res["payment_num"], "741890")

    def test_cash_order_with_change_amount(self):
        comment = "Сайт Готівкою №729090 Найближчим часом Решта з: 146 вул. Старицького"
        res = simulate_payment_parse(comment)
        self.assertEqual(res["is_paid_order"], 0)
        self.assertEqual(res["auto_cash"], 1)
        self.assertEqual(res["payment_method"], "Готівкою")
        self.assertEqual(res["payment_num"], "729090")
        self.assertEqual(res["client_change"], "146")

    def test_cash_order_with_reshta_ni(self):
        comment = "Пост-3 Mob Готівкою №800578 Решта з: ні Найближчим часом"
        res = simulate_payment_parse(comment)
        self.assertEqual(res["is_paid_order"], 0)
        self.assertEqual(res["auto_cash"], 1)
        self.assertEqual(res["payment_method"], "Готівкою")
        self.assertEqual(res["payment_num"], "800578")
        self.assertEqual(res["client_change"], "")

    def test_neutral_order_without_payment_mentions_does_not_force_cash(self):
        comment = "Пост-4 Mob Передзвонити Найближчим часом вул. Сумська 10"
        res = simulate_payment_parse(comment)
        self.assertEqual(res["is_paid_order"], 0)
        self.assertEqual(res["auto_cash"], 0)
        self.assertEqual(res["payment_method"], "")

    def test_engine_source_contains_strict_guards(self):
        self.assertIn("isPaidOrder", self.engine_source)
        self.assertIn("if (isPaidOrder)", self.engine_source)
        self.assertIn("autoCash := 0", self.engine_source)
        self.assertIn("SKIP_CASH: Syrve already has online payment", self.engine_source)
        self.assertIn("hasOnlinePay", self.engine_source)
        self.assertIn('"✓ " . paymentMethod', self.engine_source)

if __name__ == "__main__":
    unittest.main()
