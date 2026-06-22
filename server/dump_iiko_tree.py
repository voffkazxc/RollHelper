"""
Дамп UI-дерева вікна iiko для пошуку AutomationId полів.
Запуск: python dump_iiko_tree.py
Відкрий замовлення в iiko перед запуском!
"""
import sys
import os

try:
    import uiautomation as auto
except ImportError:
    print("Встановлюю uiautomation...")
    os.system("pip install uiautomation -q")
    import uiautomation as auto

OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'iiko_tree.txt')

def dump_element(el, depth=0, out=None, max_depth=6):
    if depth > max_depth:
        return
    try:
        ctrl_type  = el.ControlTypeName or ''
        name       = (el.Name or '')[:80]
        auto_id    = el.AutomationId or ''
        class_name = el.ClassName or ''

        value = ''
        try:
            vp = el.GetValuePattern()
            if vp:
                value = (vp.Value or '')[:60]
        except Exception:
            pass

        line = (
            '  ' * depth
            + f'[{ctrl_type}]'
            + (f' Name="{name}"'        if name       else '')
            + (f' AutoId="{auto_id}"'   if auto_id    else '')
            + (f' Class="{class_name}"' if class_name else '')
            + (f' Value="{value}"'      if value      else '')
        )
        out.write(line + '\n')
        print(line)
    except Exception as e:
        out.write('  ' * depth + f'<error: {e}>\n')
        return

    try:
        for child in el.GetChildren():
            dump_element(child, depth + 1, out, max_depth)
    except Exception:
        pass


def find_iiko_window():
    """Шукає головне вікно iiko серед усіх відкритих вікон."""
    root = auto.GetRootControl()
    candidates = []
    for win in root.GetChildren():
        title = (win.Name or '').lower()
        cls   = (win.ClassName or '').lower()
        if any(k in title for k in ('доставка', 'syrve', 'iiko', 'delivery', 'заказ')):
            candidates.append(win)
        elif 'hwndwrapper' in cls or 'wpf' in cls:
            candidates.append(win)

    if not candidates:
        print("❌ Вікно iiko не знайдено. Відкрий замовлення і запусти знову.")
        sys.exit(1)

    # Повертаємо перше підходяще
    print(f"✅ Знайдено {len(candidates)} вікон. Беремо перше: '{candidates[0].Name}'")
    return candidates[0]


def find_by_auto_id(root_el, auto_id, max_depth=15):
    """Рекурсивно шукає елемент за AutomationId."""
    if max_depth <= 0:
        return None
    try:
        if (root_el.AutomationId or '') == auto_id:
            return root_el
        for child in root_el.GetChildren():
            result = find_by_auto_id(child, auto_id, max_depth - 1)
            if result:
                return result
    except Exception:
        pass
    return None


if __name__ == '__main__':
    print("🔍 Шукаємо вікно iiko...")
    root = auto.GetRootControl()
    iiko_win = None
    for win in root.GetChildren():
        if 'WindowsForms10' in (win.ClassName or ''):
            iiko_win = win
            break

    if not iiko_win:
        print("❌ Вікно iiko не знайдено.")
        input("Enter...")
        sys.exit(1)

    print(f"✅ Знайдено: '{iiko_win.Name}'")
    print("🔍 Шукаємо DeliveryOrderEditControl...")

    delivery_ctrl = find_by_auto_id(iiko_win, 'DeliveryOrderEditControl', max_depth=10)
    if not delivery_ctrl:
        print("❌ DeliveryOrderEditControl не знайдено. Відкрий форму замовлення!")
        input("Enter...")
        sys.exit(1)

    print("✅ Знайдено! Дампимо поля форми (глибина 15)...")

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write("DeliveryOrderEditControl — повний дамп\n")
        f.write("=" * 60 + "\n\n")
        dump_element(delivery_ctrl, 0, f, max_depth=15)

    print(f"\n✅ Готово! Файл: {OUTPUT_FILE}")
    input("\nНатисни Enter щоб закрити...")
