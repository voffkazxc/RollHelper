"""
Читає номер телефону з відкритого вікна iiko/Syrve через UIA (UI Automation).
Не рухає мишу, не чіпає клавіатуру. Повністю фонова операція.

Запуск: python get_phone.py
Виводить: номер телефону (рядок) або пусто якщо не знайшов
"""

import sys
import re

try:
    import uiautomation as auto
except ImportError:
    # Якщо бібліотека не встановлена — виведемо порожньо, AHK впаде в fallback
    print("")
    sys.exit(0)

def normalize(phone: str) -> str:
    digits = re.sub(r'\D', '', phone)
    if digits.startswith('380'):
        return digits
    elif digits.startswith('80') and len(digits) == 11:
        return '3' + digits
    elif digits.startswith('0') and len(digits) == 10:
        return '38' + digits
    elif len(digits) == 9:
        return '380' + digits
    return digits

def find_phone_in_iiko():
    """
    Шукає поле телефону в вікні iiko через дерево доступності Windows.
    Повертає рядок телефону або порожній рядок.
    """
    # Знаходимо вікно iiko (Syrve)
    iiko_win = None
    for win in auto.GetRootControl().GetChildren():
        title = win.Name or ''
        # iiko відкрита доставка — назва містить "Нова доставка" або "доставка"
        if 'доставка' in title.lower() or 'syrve' in title.lower() or 'iiko' in title.lower():
            iiko_win = win
            break

    if not iiko_win:
        # Fallback: шукаємо по класу
        try:
            iiko_win = auto.WindowControl(searchDepth=1, ClassName='HwndWrapper', foundIndex=1)
        except Exception:
            return ''

    if not iiko_win or not iiko_win.Exists(0):
        return ''

    # Шукаємо текстові поля у вікні та знаходимо телефонний номер
    phone_found = ''
    try:
        # Рекурсивно перебираємо всі Edit-поля
        for ctrl in iiko_win.GetChildren():
            result = _search_phone_in_subtree(ctrl, depth=0, max_depth=8)
            if result:
                phone_found = result
                break
    except Exception:
        pass

    return phone_found

def _search_phone_in_subtree(ctrl, depth, max_depth):
    """Рекурсивно шукає Edit або Text контрол з телефонним номером."""
    if depth > max_depth:
        return ''

    try:
        ctrl_type = ctrl.ControlTypeName
        value = ''

        # Читаємо значення
        if ctrl_type in ('EditControl', 'TextControl', 'ComboBoxControl'):
            try:
                vp = ctrl.GetValuePattern()
                if vp:
                    value = vp.Value or ''
            except Exception:
                pass
            if not value:
                try:
                    value = ctrl.Name or ''
                except Exception:
                    pass

        if value:
            digits = re.sub(r'\D', '', value)
            # Телефонний номер: 9-13 цифр, і починається на 0 або 380 або 38
            if 9 <= len(digits) <= 13:
                if digits.startswith(('380', '38', '0', '80')):
                    norm = normalize(value)
                    if len(norm) >= 9:
                        return norm

        # Рекурсія у дочірні елементи
        for child in ctrl.GetChildren():
            result = _search_phone_in_subtree(child, depth + 1, max_depth)
            if result:
                return result

    except Exception:
        pass

    return ''


if __name__ == '__main__':
    phone = find_phone_in_iiko()
    print(phone, end='')
    sys.exit(0)
