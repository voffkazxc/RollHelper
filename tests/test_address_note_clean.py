import unittest
import re

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

    if re.search(r'(?i)^\s*(?:Фоп|Самовивіз|Знижка)', clean):
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
        if rc_is_street_or_address(p, raw_address):
            continue
        if comment_street and comment_street.lower() in p.lower():
            sub = re.sub(re.escape(comment_street), '', p, flags=re.IGNORECASE).strip()
            if not sub or len(sub) < 3:
                continue
        clean_parts.append(p)

    return " | ".join(clean_parts)

class TestAddressNoteClean(unittest.TestCase):
    def test_strip_trailing_street_from_note(self):
        # Note with real instruction + duplicate street at the end
        note = "Набрать - спущусь к подъезду | Богатирська"
        cleaned = rc_clean_address_note(note, "Богатирська 10, кв. 5", "Богатирська")
        self.assertEqual(cleaned, "Набрать - спущусь к подъезду")

    def test_pure_street_in_note_becomes_empty(self):
        # Only street name was passed after FOP
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

if __name__ == '__main__':
    unittest.main()
