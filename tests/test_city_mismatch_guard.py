import unittest
import re

def rc_geocode_response_has_city(resp, city):
    if not resp or not city:
        return False
    # 1. First, check structured address fields if present
    m = re.search(r'"(?:city|town|village|municipality)"\s*:\s*"([^"]+)"', resp)
    if m:
        actual_city = m.group(1).lower().strip()
        expected = city.lower().strip()
        aliases = [expected]
        if expected in ('киев', 'київ'):
            aliases = ['киев', 'київ']
        elif expected in ('біла церква', 'белая церковь'):
            aliases = ['біла церква', 'белая церковь']
        elif expected in ('днепр', 'дніпро'):
            aliases = ['днепр', 'дніпро']
        elif expected in ('харьков', 'харків'):
            aliases = ['харьков', 'харків']
        elif expected in ('одесса', 'одеса'):
            aliases = ['одесса', 'одеса']
        elif expected in ('львов', 'львів'):
            aliases = ['львов', 'львів']
        elif expected in ('винница', 'вінниця'):
            aliases = ['винница', 'вінниця']
        elif expected in ('ровно', 'рівне'):
            aliases = ['ровно', 'рівне']
        elif expected in ('ивано-франковск', 'івано-франківськ', 'франківськ'):
            aliases = ['ивано-франковск', 'івано-франківськ', 'франківськ', 'іф']
        for a in aliases:
            if a == actual_city or a in actual_city:
                return True
        return False

    # 2. Check display_name, stripping oblast / rayon / hromada
    haystack = resp.lower()
    haystack = re.sub(r'[а-яіїєґё\w\-]+(?:ська|цька|зька|ская|цкая|зкая)\s+(?:область|обл|район|р\-н|громада)\b', ' ', haystack)
    haystack = re.sub(r'[а-яіїєґё\w\-]+\s+(?:область|обл|район|р\-н|громада)\b', ' ', haystack)
    
    expected = city.lower().strip()
    aliases = [expected]
    if expected in ('киев', 'київ'):
        aliases = ['киев', 'київ']
    elif expected in ('біла церква', 'белая церковь'):
        aliases = ['біла церква', 'белая церковь']
    elif expected in ('днепр', 'дніпро'):
        aliases = ['днепр', 'дніпро']
    elif expected in ('харьков', 'харків'):
        aliases = ['харьков', 'харків']
    elif expected in ('одесса', 'одеса'):
        aliases = ['одесса', 'одеса']
    elif expected in ('львов', 'львів'):
        aliases = ['львов', 'львів']
    elif expected in ('винница', 'вінниця'):
        aliases = ['винница', 'вінниця']
    elif expected in ('ровно', 'рівне'):
        aliases = ['ровно', 'рівне']
    elif expected in ('ивано-франковск', 'івано-франківськ', 'франківськ'):
        aliases = ['ивано-франковск', 'івано-франківськ', 'франківськ', 'іф']

    for a in aliases:
        pattern = r'(?<![а-яіїєґё\w\-])' + re.escape(a) + r'(?![а-яіїєґё\w\-])'
        if re.search(pattern, haystack):
            return True
    return False


def validate_zone_city(detected_city, kitchen_city):
    if not detected_city or not kitchen_city:
        return True
    return detected_city.strip().lower() == kitchen_city.strip().lower()


class CityMismatchGuardTests(unittest.TestCase):
    def test_bila_tserkva_rejected_when_detected_city_is_kyiv(self):
        # Even if coordinates match Bila Tserkva zone, city validation must fail
        self.assertFalse(validate_zone_city("Київ", "Біла Церква"))

    def test_kyiv_kitchen_accepted_for_kyiv(self):
        self.assertTrue(validate_zone_city("Київ", "Київ"))

    def test_phonetic_variation_simirenka(self):
        addr = "вулиця Симеренка, 13"
        addr_var = re.sub(r'([а-яіїєґ])е([а-яіїєґ])', r'\1и\2', addr)
        self.assertEqual(addr_var, "вулиця Симиренка, 13")

    def test_geocode_response_has_city_rejects_kyivska_oblast(self):
        resp = '{"display_name":"13, вул. Сімеренка, Біла Церква, Київська область"}'
        self.assertFalse(rc_geocode_response_has_city(resp, "Київ"))


if __name__ == '__main__':
    unittest.main()
