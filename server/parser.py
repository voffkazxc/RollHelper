"""
parser.py — Roll House EML comment parser
Навчено на 4425 реальних замовленнях (Берестин, Чугуїв, Мерефа)

Вхід: рядок тексту (з AHK або email)
Вихід: dict з полями для iiko
"""
import re
from datetime import datetime, timedelta


def parse_comment(text: str) -> dict:
    result = {
        'DeliveryDate':  '',
        'DeliveryTime':  '',
        'isPickup':      0,
        'isFastDelivery': 0,
        'FilaClub':      0,
        'Allergy':       0,
        'Birthday':      0,
        'SticksNorm':    0,
        'SticksEdu':     0,
        'Utensils':      0,
        'RestChange':    '',
        'CardPayment':   '',
        'addrNote':      '',
        'kitchenNote':   '',
        'infoText':      '',
        'isFutureDate':  0,
        'warnReason':    '',
        'isPost':        0,
        'postNum':       '',
        'needCall':      0,
    }

    if not text:
        return result

    t = text  # working copy

    # ══════════════════════════════════════════════════
    # 1. VIP FilaClub
    # ══════════════════════════════════════════════════
    if re.search(r'(?i)(filaclub|филаклаб|філаклаб)', t):
        result['FilaClub'] = 1

    # ══════════════════════════════════════════════════
    # 2. Алергія
    # ══════════════════════════════════════════════════
    if re.search(r'(?i)(алерг|аллерг)', t):
        result['Allergy'] = 1

    # ══════════════════════════════════════════════════
    # 3. День народження
    #    "дн", "д.н", "д.р", "день народження", "іменинник"
    # ══════════════════════════════════════════════════
    if re.search(r'(?i)(д\.?\s*[нр]\.?\b|день\s+народ|день\s+рожд|іменин|именин)', t):
        result['Birthday'] = 1

    # ══════════════════════════════════════════════════
    # 4. Самовивіз
    # ══════════════════════════════════════════════════
    if re.search(r'(?i)(самовивіз|самовывоз|заберу\s+сам|забираю\s+сам)', t):
        result['isPickup'] = 1

    # ══════════════════════════════════════════════════
    # 5. Якомога швидше / найближчим часом
    # ══════════════════════════════════════════════════
    if re.search(r'(?i)(якомога\s*швидше|найближчим|ближайш|побыстрее|якнайшвидше|asap)', t):
        result['isFastDelivery'] = 1

    # ══════════════════════════════════════════════════
    # 6. Палички
    #    Реальні приклади: "2 пари паличок", "3 палочки", "на 4 персони"
    #    "замовлення на 10 осіб" → 10 пар паличок
    # ══════════════════════════════════════════════════

    # Учбові / дитячі
    m = re.search(
        r'(?i)(\d+)\s*(?:пар[иаі]?|набор|шт|комп)?[^0-9]{0,15}'
        r'(?:учбов|учеб|навчальн|дитяч|детск|обучающ)',
        t
    )
    if not m:
        m = re.search(
            r'(?i)(?:учбов|учеб|навчальн|дитяч|детск)[^0-9]{0,15}(\d+)',
            t
        )
    if m:
        result['SticksEdu'] = int(m.group(1))

    # Звичайні палички (тільки якщо в тому ж контексті не фігурують учбові)
    m_norm = re.search(
        r'(?i)(\d+)\s*(?:пар[иаі]?|набор|шт|персон|компл)?[^0-9]{0,12}'
        r'(?:палоч|палич|звичай|бамбук)',
        t
    )
    if not m_norm:
        m_norm = re.search(
            r'(?i)(?:палоч|палич|звичай|бамбук)[^0-9]{0,12}(\d+)',
            t
        )
    if m_norm:
        # Перевіряємо що це не учбові (якщо в тому ж шматку є слово учбов*)
        ctx_start = max(0, m_norm.start() - 20)
        ctx_end = min(len(t), m_norm.end() + 20)
        ctx = t[ctx_start:ctx_end]
        if not re.search(r'(?i)(учбов|учеб|навчальн|дитяч|детск)', ctx):
            result['SticksNorm'] = int(m_norm.group(1))

    # "на X осіб/людей/персон" → палички (якщо не знайшли явно)
    # Також: "на три людини", "на п'ять персон" (слова-числа)
    _word_nums = {'один': 1, 'одну': 1, 'два': 2, 'дві': 2, 'три': 3,
                  'чотири': 4, 'п\'ять': 5, 'п\'яти': 5, 'шість': 6,
                  'сім': 7, 'вісім': 8, 'дев\'ять': 9, 'десять': 10}
    if not result['SticksNorm']:
        m = re.search(
            r'(?i)(?:на|для)\s+(\d+)\s*(?:осіб|людин|персон|чоловік|чол\.)',
            t
        )
        if m:
            result['SticksNorm'] = int(m.group(1))
        else:
            m2 = re.search(
                r'(?i)(?:на|для)\s+([а-яіїєґ\']+)\s*(?:осіб|людин|персон|чоловік)',
                t
            )
            if m2:
                result['SticksNorm'] = _word_nums.get(m2.group(1).lower(), 0)

    # ══════════════════════════════════════════════════
    # 7. Прибори (виделки)
    # ══════════════════════════════════════════════════
    m = re.search(r'(?i)(?:Кількість приборів|прибор|виделк)\D{0,10}(\d+)', t)
    if not m:
        m = re.search(r'(?i)(\d+)\D{0,10}(?:прибор|виделк)', t)
    if m:
        result['Utensils'] = int(m.group(1))

    # ══════════════════════════════════════════════════
    # 8. Готівка / решта
    # ══════════════════════════════════════════════════

    # Решта з суми: "решта з 500", "сдача з 1000", "готівка 500"
    m = re.search(
        r'(?i)(?:решт[аиу]|сдач[аиу])\s*(?:з|с|із|from)?\s*(\d{3,5})',
        t
    )
    if m:
        result['RestChange'] = m.group(1)

    # Без решти / точна сума
    if re.search(
        r'(?i)(без\s*решт|без\s*сдач|підготую\s*точно|готую\s*точно|рівно|точна\s*сума)',
        t
    ):
        result['RestChange'] = '0'  # сигнал: без решти

    # ══════════════════════════════════════════════════
    # 9. Оплата карткою онлайн / у закладі
    # ══════════════════════════════════════════════════
    if re.search(r'(?i)(карткою\s+онлайн|картой\s+онлайн|оплачено онлайн|УСПІШНО)', t):
        result['CardPayment'] = 'online'
    elif re.search(r'(?i)(карткою\s+у\s+закладі|картой\s+в\s+заведении)', t):
        result['CardPayment'] = 'inplace'

    # ══════════════════════════════════════════════════
    # 10. Потрібно зателефонувати
    #     "подзвонити", "набрати", "зателефонуйте", "перезвоніть"
    # ══════════════════════════════════════════════════
    if re.search(
        r'(?i)(передзвон|перезвон|подзвон|зателефон|набрати|набрать|'
        r'звʼяж|зв\'яж|зв.яж|позвон|ring\s*me)',
        t
    ):
        result['needCall'] = 1

    # ══════════════════════════════════════════════════
    # 11. Тиха доставка
    # ══════════════════════════════════════════════════
    if re.search(
        r'(?i)(не\s*дзвон|не\s*звон|сплять|спят|тих[аи]\s*доставк|'
        r'під\s*двер|под\s*двер|без\s*дзвінк|тихо\s*принес)',
        t
    ):
        result['addrNote'] = _append(result['addrNote'], '🛑 ТИХА ДОСТАВКА')

    # ══════════════════════════════════════════════════
    # 12. Адресні підказки: код домофону, під'їзд, поверх, орієнтири
    # ══════════════════════════════════════════════════
    addr_parts = []

    # Код від під'їзду / домофону — шукаємо цифри/коди після слів
    m = re.search(r'(?i)(?:код|домофон)\D{0,8}([0-9][0-9a-zA-Zа-яіїєґ#\*]{0,8})', t)
    if m:
        addr_parts.append(f"код {m.group(1)}")
    # "Код від підїзда - 46" → просто "код 46"
    if not m:
        m = re.search(r'(?i)(?:код\s+від\s+\w+|код\s+на\s+\w+)[^0-9]*([0-9]{2,6})', t)
        if m:
            addr_parts.append(f"код {m.group(1)}")

    # Під'їзд
    m = re.search(r'(?i)(?:під\'їзд|подъезд|п-д|п\.д)[^0-9а-яіїєґ]{0,3}(\d+|(?:[a-яіїєґ]+\s+)?(?:сторон|зі?\s*сторон)\w*)', t)
    if m:
        addr_parts.append(f"під'їзд {m.group(1)}")

    # Поверх
    m = re.search(r'(?i)(?:поверх|этаж|пов-х)[^0-9]{0,3}(\d+)', t)
    if m:
        addr_parts.append(f'поверх {m.group(1)}')

    # Квартира
    m = re.search(r'(?i)(?:квартира|кв\.?)[^0-9]{0,3}(\d+)', t)
    if m:
        addr_parts.append(f'кв {m.group(1)}')

    # Орієнтир / навпроти / заїзд
    m = re.search(r'(?i)((?:навпроти|напроти|орієнтир|заїзд|вхід\s+з)[^,\n\.]{5,40})', t)
    if m:
        addr_parts.append(m.group(1).strip())

    if addr_parts:
        result['addrNote'] = _append(result['addrNote'], ' | '.join(addr_parts))

    # ══════════════════════════════════════════════════
    # 13. Кухня / побажання (без чогось, окреме пакування тощо)
    # ══════════════════════════════════════════════════
    kitchen_parts = []

    # "без X" де X — інгредієнт
    for m in re.finditer(r'(?i)(без\s+(?:[а-яіїєґa-z]+\s+){0,2}(?:[а-яіїєґa-z]+))', t):
        val = m.group(1).strip()
        # Відфільтровуємо "без решти", "без дзвінка" тощо
        if not re.search(r'(?i)(решт|сдач|дзвін|звонк|оплат)', val):
            kitchen_parts.append(val)

    # Алергічні побажання
    if result['Allergy']:
        kitchen_parts.insert(0, '🚨 АЛЕРГІЯ — окремий бокс!')

    # "не гостре", "окремо", "порізати", "навпіл"
    for pat, label in [
        (r'(?i)(не\s+гостр\w+)', None),
        (r'(?i)(гостр\w+)', None),
        (r'(?i)(окремо\s+\w+|пакуват\w+\s+окремо)', None),
        (r'(?i)(навпіл|пополам|порізати|порізайт)', None),
        (r'(?i)(веган\w*|вегетар\w*)', None),
    ]:
        m = re.search(pat, t)
        if m:
            kitchen_parts.append(m.group(1).strip())

    if kitchen_parts:
        result['kitchenNote'] = ' | '.join(dict.fromkeys(kitchen_parts))  # без дублів
        result['infoText'] = result['kitchenNote']

    # ══════════════════════════════════════════════════
    # 14. Час доставки
    #     "на 18:30", "до 19:00", "о 17.30", "доставка на 20:30"
    # ══════════════════════════════════════════════════
    # Час: шукаємо "на 18:30", "о 20.00" — але НЕ плутаємо з датою "21.03"
    # Дата має формат DD.MM (день 1-31, місяць 1-12), час — HH:MM (8-23:00-59)
    time_match = re.search(
        r'(?i)(?:на|до|о|к|готовність[:\s]|з\s)\s*'
        r'(\d{1,2})[:\.-](\d{2})(?!\d)',
        t
    )
    if not time_match:
        # Шукаємо HH:MM через двокрапку (найнадійніший формат)
        time_match = re.search(r'(?<!\d)(\d{1,2}):(\d{2})(?!\d)', t)
        if time_match:
            # Якщо знайшли — зберігаємо як HH:MM
            hh2, mm2 = int(time_match.group(1)), int(time_match.group(2))
            if not (8 <= hh2 <= 23 and 0 <= mm2 <= 59):
                time_match = None

    if time_match:
        groups = time_match.groups()
        hh = int(groups[0])
        mm = int(groups[1])
        # Додаткова перевірка: не хочемо "21.03" → DeliveryTime 21:03
        # Дата виглядає як DD.MM: день 1-31 + точка + місяць 1-12
        # Час виглядає як HH:MM: година 8-23
        if 8 <= hh <= 23 and 0 <= mm <= 59:
            # Перевіряємо чи це не частина дати (dd.mm) — якщо розділювач крапка
            sep_char = time_match.group(0)[len(str(hh)):len(str(hh))+1] if hasattr(time_match, 'group') else ':'
            raw_match = time_match.group(0) if hasattr(time_match, 'group') else ''
            # Якщо розділювач крапка і mm виглядає як місяць (1-12), і є слово з датою поруч — пропускаємо
            is_date_context = ('.' in raw_match and 1 <= mm <= 12 and
                               re.search(r'(?i)(замовлення\s+на|на\s+\d{1,2}\.\d{1,2}|суботу|неділю|понеділок)', t))
            if not is_date_context:
                result['DeliveryTime'] = f'{hh:02d}:{mm:02d}'

    # ══════════════════════════════════════════════════
    # 15. Дата доставки (майбутня)
    #     "замовлення на 21.03", "на суботу", "завтра"
    # ══════════════════════════════════════════════════
    today = datetime.now()

    # Завтра / послязавтра
    if re.search(r'(?i)(завтра|tomorrow)', t):
        d = today + timedelta(days=1)
        result['DeliveryDate'] = d.strftime('%d.%m.%Y')
        result['isFutureDate'] = 1
        result['warnReason'] = 'ЗАВТРА'
    elif re.search(r'(?i)(послезавтра|після\s*завтра)', t):
        d = today + timedelta(days=2)
        result['DeliveryDate'] = d.strftime('%d.%m.%Y')
        result['isFutureDate'] = 1
        result['warnReason'] = 'ПІСЛЯ ЗАВТРА'

    # Конкретна дата: "21.03", "21.03.2026"
    m = re.search(r'(?<!\d)(\d{1,2})[\.\/](\d{1,2})(?:[\.\/](\d{4}|\d{2}))?(?!\d)', t)
    if m and not result['isFutureDate']:
        day, mon = int(m.group(1)), int(m.group(2))
        year = int(m.group(3)) if m.group(3) else today.year
        if year < 100:
            year += 2000
        try:
            order_date = datetime(year, mon, day)
            if order_date.date() > today.date():
                result['DeliveryDate'] = order_date.strftime('%d.%m.%Y')
                result['isFutureDate'] = 1
                result['warnReason'] = order_date.strftime('%d.%m.%Y')
        except ValueError:
            pass

    # Системна дата (із поля Час: 2026-06-19)
    m = re.search(r'(\d{4})-(\d{2})-(\d{2})', t)
    if m and not result['isFutureDate']:
        year, mon, day = int(m.group(1)), int(m.group(2)), int(m.group(3))
        try:
            order_date = datetime(year, mon, day)
            if order_date.date() > today.date():
                result['DeliveryDate'] = order_date.strftime('%d.%m.%Y')
                result['isFutureDate'] = 1
                result['warnReason'] = order_date.strftime('%d.%m.%Y')
        except ValueError:
            pass

    # ══════════════════════════════════════════════════
    # 16. Нова пошта / відділення
    # ══════════════════════════════════════════════════
    m = re.search(r'(?i)(?:нова\s*пошт|нп\b|новой\s*почт)[^0-9]{0,10}(\d+)', t)
    if m:
        result['isPost'] = 1
        result['postNum'] = m.group(1)

    return result


def _append(existing: str, new_part: str) -> str:
    """Додати частину до рядка через ' | '"""
    if existing:
        return existing + ' | ' + new_part
    return new_part


# ══════════════════════════════════════════════════════════
# Тест
# ══════════════════════════════════════════════════════════
if __name__ == '__main__':
    import json

    tests = [
        # З реальних замовлень
        "Подзвонити біля підʼїзду",
        "Код від підїзда - 46",
        "замовлення на 10 осіб",
        "Доставка на 20:30",
        "можна на 14:00",
        "Нехай курьер зі мною звʼяжеться , скажу де заберу замовлення",
        "1 подъезд со стороны дороги.",
        "Доброго дня,а можно зробити мое замолвлен на 18.00?",
        "В подарунок запечений рол",
        "На три людини",
        "Замовлення на 21.03 (субота) готовність: 11.00",
        # З AHK (Android-формат)
        ", Android v.1.4, Час: 2026-06-19 16:02 (Якомога швидше), Адреса: м. Чугуїв, вул. Харківська вулиця, дім 122, Під-д: 5, Пов-х: 9, Кв: 176, Оплата: Картою онлайн (УСПІШНО), Коментар: 3 соуса 2 васаби 2 имбиря и 3 палочек.",
        "Готівка Решта з 500 | Доставка Мерефа - 100 грн",
        "FilaClub, без цибулі, алергія на горіхи, 2 пари учбових паличок",
    ]

    for test in tests:
        r = parse_comment(test)
        interesting = {k: v for k, v in r.items() if v not in ('', 0)}
        print(f"\n INPUT: {test[:80]}")
        print(f"OUTPUT: {json.dumps(interesting, ensure_ascii=False)}")
