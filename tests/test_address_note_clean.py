import unittest
import re
import sys
import os

# Add server to sys.path so we can import parse_comment directly
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "server")))
try:
    from parser import parse_comment
except ImportError:
    # fallback to local server path if needed
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "server")))
    from parser import parse_comment

def rc_is_street_or_address(text: str, raw_address: str = "") -> bool:
    clean = text.strip()
    if not clean:
        return True

    # If it contains courier instructions, it's NOT just a street name
    courier_kw = r'(?i)(?:домофон|під\'їзд|подъезд|поверх|этаж|квартир|кв\s*\d|парадн|двер|код\b|шлагбаум|зустрін|встрет|вийду|выйду|консьєрж|ресепшн|охорон|заїзд|вхід|вход|корпус|фасад|ворот|хвіртк|паркан|двір\b|двор\b|орієнтир|ориентир|навпроти|напротив|біля|рядом|зателефону|дзвон|звон|набрати|наберіть|наберите|стука|постуч|не\s+дзвон|не\s+звон|сплять|спят|під\s+двер|пам\'?ятник|лікарн|госпітал)'
    if re.search(courier_kw, clean):
        return False

    street_pat = r'(?i)(?:\b(?:вул\.?|вулиця|просп\.?|проспект|пров\.?|провулок|шосе|бульв\.?|бульвар|набережна|узвіз|площа|майдан|тупик|проїзд|алея)\b)'
    if re.search(street_pat, clean):
        return True

    if raw_address:
        words = clean.split()
        if len(words) <= 4:
            for w in words:
                w_clean = re.sub(r'[^\wа-яіїєґА-ЯІЇЄҐёЁ]', '', w)
                if len(w_clean) >= 4 and w_clean.lower() in raw_address.lower():
                    return True

    if re.search(r'(?i)^\s*(?:Фоп|ФОП|FOP|Самовивіз|Знижка)', clean):
        return True

    return False

def rc_clean_address_note(note: str, raw_address: str = "", comment_street: str = "") -> str:
    if not note:
        return ""

    parts = note.split("|")
    clean_parts = []
    for part in parts:
        p = part.strip()
        if not p:
            continue

        # Strip FOP block (e.g. "Фоп Пруднікова О.А. вул." or "ФОП Богатий П.О.")
        p = re.sub(r'(?i)\b(?:Фоп|ФОП|FOP)\b.*?(?=\||$)', '', p).strip()
        # Strip payment / cash change
        p = re.sub(r'(?i)\b(?:підготувати\s+)?решт[ау]\s*(?:з|с)?\s*\d+\b', ' ', p)
        p = re.sub(r'(?i)\bсдач[ау]\s*(?:з|с)?\s*\d+\b', ' ', p)
        p = re.sub(r'(?i)\bбез\s+(?:решт[аи]?|здач[іе]?)\b', ' ', p)
        p = re.sub(r'(?i)\b(?:готівкою|картою|оплачено|qr\s*code)\b(?:\s*№\s*\d+)?', ' ', p)
        # Strip dates and times
        p = re.sub(r'\b\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?\b', ' ', p)
        p = re.sub(r'(?<!\d)\d{1,2}:\d{2}(?!\d)', ' ', p)
        # Strip districts / microdistricts
        districts = r'(?i)\b(?:Тополь|Тополя|Перемога|Победа|Сокіл|Сокол|Парус|Покровський|Комунар|Червоний\s+Камінь|Красный\s+Камень|Лівобережний|Левобережный|Сонячний|Солнечный|Придніпровськ|Приднепровск|Ігрень|Игрень|Північний|Северный|Західний|Западный|12\s*квартал|Мирний|Мирный|Клочко|Калиновський|Калиновский|Діївка|Диевка|Таромське|Таромское|Правий\s+берег|Лівий\s+берег)(?:[\s\-]*\d+)?\b'
        p = re.sub(districts, ' ', p)
        # Strip stray street markers at beginning or end
        p = re.sub(r'(?i)^\s*(?:вул\.?|вулиця|просп\.?|проспект|пров\.?|провулок|буд\.?)\s*', '', p)
        p = re.sub(r'(?i)\s*(?:\bвул\.?|вулиця|\bпросп\.?|проспект|\bпров\.?|провулок|\bбуд\.?)\s*$', '', p)
        p = re.sub(r'\s+', ' ', p)
        p = p.strip(" \t\r\n,.-")

        if not p:
            continue
        if rc_is_street_or_address(p, raw_address):
            continue
        if comment_street and comment_street.lower() in p.lower():
            sub = re.sub(re.escape(comment_street), '', p, flags=re.IGNORECASE).strip()
            if not sub or len(sub) < 3:
                continue

        # Deduplication
        p_low = p.lower()
        is_dup = False
        for idx, exist_p in enumerate(clean_parts):
            ex_low = exist_p.lower()
            if p_low == ex_low or p_low in ex_low:
                is_dup = True
                break
            elif ex_low in p_low:
                clean_parts[idx] = p
                is_dup = True
                break
        if not is_dup:
            clean_parts.append(p)

    return " | ".join(clean_parts)

class TestAddressNoteClean(unittest.TestCase):
    def test_user_reported_comment_parser(self):
        # Exact string reported by the user
        raw = "Пост-11 Mob !!!ПЕРШЕМОБ Передзвонити Готівкою №961278 Коментар до адреси: Корпус 4 під'їзд виходить в сторону дороги Підготувати решту з 2000 2026-10-24 19:30 Тополь 3"
        res = parse_comment(raw)
        self.assertEqual(res.get("addrNote"), "Корпус 4 під'їзд виходить в сторону дороги")
        self.assertEqual(res.get("RestChange"), "2000")
        self.assertEqual(res.get("isPost"), 1)
        self.assertEqual(res.get("postNum"), "11")
        self.assertEqual(res.get("needCall"), 1)
        # Ensure 'реж' was NOT matched as kitchen note
        self.assertEqual(res.get("kitchenNote", ""), "")

    def test_street_naberezhna_not_kitchen_note(self):
        raw = "вул. Набережна Перемоги 5, кв 22"
        res = parse_comment(raw)
        self.assertEqual(res.get("kitchenNote", ""), "")

    def test_comment_oberezhno_not_kitchen_note(self):
        raw = "Коментар до адреси: обережно з дверима, зламана ручка"
        res = parse_comment(raw)
        self.assertEqual(res.get("kitchenNote", ""), "")
        self.assertIn("обережно з дверима", res.get("addrNote", ""))

    def test_actual_cut_instructions_still_work(self):
        raw1 = "порізати на 4 частини"
        self.assertIn("порізати", parse_comment(raw1).get("kitchenNote", ""))

        raw2 = "не різати роли"
        self.assertIn("не різати", parse_comment(raw2).get("kitchenNote", ""))

        raw3 = "наріжте пополам"
        k3 = parse_comment(raw3).get("kitchenNote", "")
        self.assertIn("наріжте", k3)

    def test_deduplication_of_address_note_with_change_and_district(self):
        dup_note = "Корпус 4 під'їзд виходить в сторону дороги Підготувати решту з 2000 2026-10-24 19:30 Тополь 3 | Корпус 4 під'їзд виходить в сторону дороги Підготувати решту з 2000"
        cleaned = rc_clean_address_note(dup_note)
        self.assertEqual(cleaned, "Корпус 4 під'їзд виходить в сторону дороги")

    def test_strip_trailing_street_from_note(self):
        note = "Набрать - спущусь к подъезду | Богатирська"
        cleaned = rc_clean_address_note(note, "Богатирська 10, кв. 5", "Богатирська")
        self.assertEqual(cleaned, "Набрать - спущусь к подъезду")

    def test_pure_street_in_note_becomes_empty(self):
        note = "пр. Петра Калнишевського"
        cleaned = rc_clean_address_note(note, "пр. Петра Калнишевського 15", "Петра Калнишевського")
        self.assertEqual(cleaned, "")

    def test_landmark_and_trailing_street(self):
        note = "Ближайшие станции метро Спортивная и Площадь Восстания | Брянський провулок"
        cleaned = rc_clean_address_note(note, "Брянський провулок 4", "Брянський")
        self.assertEqual(cleaned, "Ближайшие станции метро Спортивная и Площадь Восстания")

    def test_prospect_street_only(self):
        note = "проспект Червоної Калини"
        cleaned = rc_clean_address_note(note, "проспект Червоної Калини 60", "Червоної Калини")
        self.assertEqual(cleaned, "")

    def test_pickup_and_street(self):
        note = "Остановитесь на новой почте, я выйду заберу | шосе Запорізьке"
        cleaned = rc_clean_address_note(note, "шосе Запорізьке 12", "Запорізьке")
        self.assertEqual(cleaned, "Остановитесь на новой почте, я выйду заберу")

    def test_complex_gate_instructions(self):
        note = "Въезд с улицы Старокозацкой, двор закрыт, доставьте к воротам и наберите | вул. Юрія Савченка"
        cleaned = rc_clean_address_note(note, "вул. Юрія Савченка 8", "Юрія Савченка")
        self.assertEqual(cleaned, "Въезд с улицы Старокозацкой, двор закрыт, доставьте к воротам и наберите")

    def test_single_word_street(self):
        note = "Осокорська"
        cleaned = rc_clean_address_note(note, "Осокорська 2а", "Осокорська")
        self.assertEqual(cleaned, "")

    def test_door_code_instructions(self):
        note = "код двору 146, сірі двері праворуч"
        cleaned = rc_clean_address_note(note, "вулиця Пантелеймонівська 22", "Пантелеймонівська")
        self.assertEqual(cleaned, "код двору 146, сірі двері праворуч")

    def test_fop_prudnikova_alone_becomes_empty(self):
        note = "Фоп Пруднікова О.А. вул."
        cleaned = rc_clean_address_note(note, "вул. Шевченка 12", "Шевченка")
        self.assertEqual(cleaned, "")

    def test_fop_prudnikova_with_courier_note(self):
        note = "код 123 Фоп Пруднікова О.А. вул."
        cleaned = rc_clean_address_note(note, "вул. Шевченка 12", "Шевченка")
        self.assertEqual(cleaned, "код 123")

    def test_fop_prudnikova_pipe_separated(self):
        note = "3 поверх | Фоп Пруднікова О.А. вул."
        cleaned = rc_clean_address_note(note, "вул. Шевченка 12", "Шевченка")
        self.assertEqual(cleaned, "3 поверх")

    def test_fop_bogatyi_trailing_street(self):
        note = "Фоп Богатий П.О. Тракторобудівників проспект"
        cleaned = rc_clean_address_note(note, "Тракторобудівників проспект 10", "Тракторобудівників")
        self.assertEqual(cleaned, "")

    def test_fop_velesyk_with_note(self):
        note = "домофон 45, 2 під'їзд | Фоп Велесик Р.О. Біла вулиця"
        cleaned = rc_clean_address_note(note, "Біла вулиця 5", "Біла")
        self.assertEqual(cleaned, "домофон 45, 2 під'їзд")

    def test_fop_initials_only(self):
        note = "ФОП Іванов І.І."
        cleaned = rc_clean_address_note(note, "вул. Миру 1", "Миру")
        self.assertEqual(cleaned, "")

    def test_reshta_bez_not_kitchen_note(self):
        comment = "Пост-24 Сайт Готівкою №861297 Найближчим часом Решта з: Без вул. Філософська"
        res = parse_comment(comment)
        self.assertEqual(res['RestChange'], '0')
        self.assertEqual(res['kitchenNote'], '')
        self.assertEqual(res['infoText'], '')
        self.assertEqual(res['addrNote'], '')

if __name__ == '__main__':
    unittest.main()
