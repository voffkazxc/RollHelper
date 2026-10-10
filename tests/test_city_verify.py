import unittest
import re
import json

def rc_geocode_response_has_city(resp, city):
    if not resp or not city:
        return False
    # 1. First, check structured address fields if present
    # Looking for "city":"...", "town":"...", "village":"...", "municipality":"..."
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

    # 2. Check display_name, but strip oblast / rayon / hromada so "Київська область" doesn't match "Київ"
    haystack = resp.lower()
    # Strip oblasts
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
        # Match as whole word or bounded
        pattern = r'(?<![а-яіїєґё\w\-])' + re.escape(a) + r'(?![а-яіїєґё\w\-])'
        if re.search(pattern, haystack):
            return True
    return False


class CityVerifyTests(unittest.TestCase):
    def test_bila_tserkva_not_matched_for_kyiv(self):
        resp = '[{"lat":"49.7914777","lon":"30.1178947","address":{"city":"Біла Церква","state":"Київська область"},"display_name":"13, вулиця Левка Сімеренка, Таращанський масив, Біла Церква, Білоцерківська міська громада, Білоцерківський район, Київська область, 09117, Україна"}]'
        self.assertFalse(rc_geocode_response_has_city(resp, "Київ"))
        self.assertTrue(rc_geocode_response_has_city(resp, "Біла Церква"))

    def test_bila_tserkva_without_addressdetails_not_matched_for_kyiv(self):
        resp = '[{"lat":"49.7914777","lon":"30.1178947","display_name":"13, вулиця Левка Сімеренка, Таращанський масив, Біла Церква, Білоцерківська міська громада, Білоцерківський район, Київська область, 09117, Україна"}]'
        self.assertFalse(rc_geocode_response_has_city(resp, "Київ"))
        self.assertTrue(rc_geocode_response_has_city(resp, "Біла Церква"))

    def test_kyiv_matched_for_kyiv(self):
        resp = '[{"lat":"50.4112503","lon":"30.4006233","address":{"city":"Київ"},"display_name":"13, вулиця Симиренка, Гайок, Південна Борщагівка, Святошинський район, Київ, 03182, Україна"}]'
        self.assertTrue(rc_geocode_response_has_city(resp, "Київ"))
        self.assertFalse(rc_geocode_response_has_city(resp, "Біла Церква"))

    def test_dnipro_oblast_town_not_matched_for_dnipro(self):
        resp = '[{"lat":"48.51","lon":"34.61","address":{"city":"Кам\'янське","state":"Дніпропетровська область"},"display_name":"вул. Соборна, Кам\'янське, Дніпропетровська область, Україна"}]'
        self.assertFalse(rc_geocode_response_has_city(resp, "Дніпро"))

if __name__ == '__main__':
    unittest.main()
