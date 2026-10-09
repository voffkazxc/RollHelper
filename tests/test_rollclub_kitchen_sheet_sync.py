import unittest
import re
import math

def parse_kitchen_minutes(text: str, default_min: int):
    t = (text or "").strip().lower()
    if not t or "стандарт" in t:
        return default_min

    if t in ("стоп", "св стоп") or "повний стоп" in t or "кухня стоп" in t:
        return "стоп"

    t = t.replace("–", "-").replace("—", "-").replace(",", ".")

    m_range = re.search(r"(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)", t)
    if m_range:
        return value_to_minutes(float(m_range.group(2)))

    m_single = re.search(r"(\d+(?:\.\d+)?)", t)
    if m_single:
        return value_to_minutes(float(m_single.group(1)))

    if "стоп" in t:
        if re.search(r"запечен|рол|сет|піц|бургер", t):
            return default_min
        return "стоп"

    return default_min

def value_to_minutes(n: float) -> int:
    if n <= 0:
        return 0
    if n <= 8:
        return round(n * 60)
    return round(n)

class TestKitchenSheetSync(unittest.TestCase):
    def test_parse_range_hours(self):
        # 1.5–2 hours -> 2 hours -> 120 minutes
        self.assertEqual(parse_kitchen_minutes("1.5–2", 90), 120)
        # 2–2.5 hours -> 2.5 hours -> 150 minutes
        self.assertEqual(parse_kitchen_minutes("2–2.5", 90), 150)

    def test_parse_exact_minutes(self):
        # 60 min
        self.assertEqual(parse_kitchen_minutes("60", 40), 60)
        # 90 min
        self.assertEqual(parse_kitchen_minutes("90", 40), 90)

    def test_parse_with_dish_stop(self):
        # "60, Запечене СТОП" -> pickup is 60 minutes
        self.assertEqual(parse_kitchen_minutes("60, Запечене СТОП", 40), 60)
        # "Запечене СТОП" without numbers -> delivery remains standard (90 min)
        self.assertEqual(parse_kitchen_minutes("Запечене СТОП", 90), 90)

    def test_parse_kitchen_stops(self):
        self.assertEqual(parse_kitchen_minutes("Стоп", 90), "стоп")
        self.assertEqual(parse_kitchen_minutes("СВ Стоп", 40), "стоп")
        self.assertEqual(parse_kitchen_minutes("🛑 ПОВНИЙ СТОП", 90), "стоп")

    def test_parse_standard_and_empty(self):
        self.assertEqual(parse_kitchen_minutes("Стандарт", 90), 90)
        self.assertEqual(parse_kitchen_minutes("", 40), 40)
        self.assertEqual(parse_kitchen_minutes("—", 90), 90)
        self.assertEqual(parse_kitchen_minutes("По узгодженню", 90), 90)

    def test_pickup_concept_resolution(self):
        def pickup_concept(pt: str) -> str:
            pt_l = pt.lower()
            if "драгоманова" in pt_l: return "Київ Драгоманова"
            if "антонова" in pt_l or "солом'янськ" in pt_l or "соломянськ" in pt_l: return "Київ Антонова"
            if "стрільців" in pt_l or "стрильц" in pt_l or "лук'янівка" in pt_l or "лукьяновка" in pt_l: return "Київ Стрільців"
            if "лаврухіна" in pt_l or "лаврухина" in pt_l or "троєщина" in pt_l or "троещина" in pt_l: return "Київ Лаврухіна"
            if "конституції" in pt_l or "конституции" in pt_l or "ресторан" in pt_l: return "РК Харків Конституції Доставка"
            if any(k in pt_l for k in ["садовий", "садовый", "нові", "нови", "новые", "новы", "нд"]): return "Харків Нові Дома"
            if "липа" in pt_l: return "Львов Липа"
            if any(k in pt_l for k in ["мудрого", "авіаторськ", "ярослава"]): return "Дніпро Мудрого"
            if any(k in pt_l for k in ["вернадського", "вернадского", "біла церква", "белая церковь", "бц"]): return "Біла Церква"
            if any(k in pt_l for k in ["незалежності", "независимости", "приморська", "приморская", "котовського"]): return "Приморська"
            if any(k in pt_l for k in ["фудотека", "промприлад", "перемоги", "франківськ", "іф"]): return "Франківськ Фудотека"
            if any(k in pt_l for k in ["кулика", "екватор", "экватор", "рівне", "ровно"]): return "Рівне"
            if any(k in pt_l for k in ["600", "мегамолл", "вінниц", "винниц"]): return "Вінниця"
            return ""

        concept_to_kitchen = {
            "Київ Драгоманова": "Драгоманова",
            "Київ Антонова": "Антонова",
            "Київ Стрільців": "Лук'янівка",
            "Київ Лаврухіна": "Троєщина",
            "РК Харків Конституції Доставка": "РЕСТОРАН",
            "Харків Нові Дома": "НД",
            "Львов Липа": "Крива Липа",
            "Дніпро Мудрого": "Мудрого",
            "Біла Церква": "БЦ",
            "Приморська": "Приморська",
            "Франківськ Фудотека": "Фудотека",
            "Рівне": "ТРЦ Екватор",
            "Вінниця": "Мегамолл",
        }

        # Нові Дома: перевірка обох назв (вулиця та назва точки)
        self.assertEqual(concept_to_kitchen[pickup_concept("Харків — Садовий проїзд")], "НД")
        self.assertEqual(concept_to_kitchen[pickup_concept("Харків — Нові Доми")], "НД")
        self.assertEqual(concept_to_kitchen[pickup_concept("Харьков — Новые Дома")], "НД")
        self.assertEqual(concept_to_kitchen[pickup_concept("Садовый")], "НД")

        # Інші критичні точки
        self.assertEqual(concept_to_kitchen[pickup_concept("Київ — Миколи Лаврухіна")], "Троєщина")
        self.assertEqual(concept_to_kitchen[pickup_concept("Одеса — вул.Незалежності")], "Приморська")
        self.assertEqual(concept_to_kitchen[pickup_concept("Рівне — Кулика і Гудачека")], "ТРЦ Екватор")

if __name__ == '__main__':
    unittest.main()
