"""
test_iiko.py — діагностика UIA взаємодії з iiko.
Запускай поки iiko відкрите з замовленням доставки.
Результат буде в test_iiko_result.txt поруч з цим файлом.
"""
import sys, os, time, traceback

OUTPUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'test_iiko_result.txt')

lines = []
def log(msg=''):
    print(msg)
    lines.append(str(msg))

def save():
    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    print(f'\n>>> Результат збережено: {OUTPUT}')

# ── 1. Імпорт uiautomation ────────────────────────────────────────────────
log('=== test_iiko.py ===')
log(f'Python: {sys.version}')
log()

try:
    import uiautomation as auto
    log(f'uiautomation: OK (v{getattr(auto, "__version__", "?")})')
except ImportError as e:
    log(f'ПОМИЛКА: uiautomation не встановлено -> {e}')
    log('Запусти:  pip install uiautomation --break-system-packages')
    save(); input('Enter...'); sys.exit(1)

# ── 2. Пошук вікна iiko ──────────────────────────────────────────────────
log()
log('--- Вікна на робочому столі ---')
root = auto.GetRootControl()
iiko_wins = []
for w in root.GetChildren():
    cls = w.ClassName or ''
    nm  = (w.Name or '')[:60]
    log(f'  [{cls[:40]}]  "{nm}"')
    if 'WindowsForms10' in cls:
        iiko_wins.append(w)

log()
log(f'Знайдено WinForms вікон: {len(iiko_wins)}')

if not iiko_wins:
    log('ПОМИЛКА: жодного WinForms вікна не знайдено. Iiko запущено?')
    save(); input('Enter...'); sys.exit(1)

# ── 3. Пошук DeliveryOrderEditControl ────────────────────────────────────
def find_by_id(el, auto_id, max_depth=12):
    if max_depth <= 0: return None
    try:
        if (el.AutomationId or '') == auto_id: return el
        for child in el.GetChildren():
            r = find_by_id(child, auto_id, max_depth - 1)
            if r: return r
    except: pass
    return None

log()
log('--- Пошук DeliveryOrderEditControl ---')
form = None
for win in iiko_wins:
    ctrl = find_by_id(win, 'DeliveryOrderEditControl', 10)
    if ctrl:
        form = ctrl
        log(f'  Знайдено в: "{(win.Name or "")[:60]}"')
        break

if not form:
    log('ПОМИЛКА: DeliveryOrderEditControl не знайдено.')
    log('Переконайся що відкрито форму замовлення доставки (не список), і запусти знову.')
    save(); input('Enter...'); sys.exit(1)

log(f'  AutomationId: {form.AutomationId}')
log(f'  ClassName:    {form.ClassName}')

# ── 4. Читання полів ──────────────────────────────────────────────────────
FIELDS = [
    ('lookUpEditCustomerPhone',    'Телефон'),
    ('memoEditDeliveryComment',    'Коментар замовлення'),
    ('memoEditCustomerComment',    'Коментар клієнта'),
    ('textEditCustomerCardNumber', 'Номер картки'),
    ('memoEditDeliveryAddressComment', 'Адреса (комент)'),
    ('gridLookUpEditStreetAddress','Вулиця'),
    ('timeEditDeliveryTime',       'Час доставки'),
    ('textEditName',               'Ім\'я клієнта'),
    ('labelOrderSum',              'Сума замовлення'),
    ('treeListItems',              'Таблиця страв'),
]

log()
log('--- Читання полів ---')
found_ids = {}
for auto_id, label in FIELDS:
    el = find_by_id(form, auto_id)
    if not el:
        log(f'  {label:<30} NOT FOUND  (AutomationId="{auto_id}")')
        continue

    # Читаємо value
    val = ''
    has_value_pattern = False
    try:
        vp = el.GetValuePattern()
        if vp:
            has_value_pattern = True
            val = vp.Value or ''
    except: pass

    if not val:
        val = el.Name or ''

    hwnd = el.NativeWindowHandle or 0

    # Ищем inner EDIT child
    inner_hwnd = 0
    try:
        for ch in el.GetChildren():
            cn = ch.ClassName or ''
            if 'EDIT' in cn.upper() and 'WindowsForms10' in cn:
                inner_hwnd = ch.NativeWindowHandle or 0
                break
    except: pass

    log(f'  {label:<30} "{val[:50]}"')
    log(f'    AutoId={auto_id}  HWND={hwnd}  InnerEDIT={inner_hwnd}  ValuePattern={has_value_pattern}')
    found_ids[auto_id] = el

# ── 5. Тест SetFocus ──────────────────────────────────────────────────────
log()
log('--- Тест SetFocus (фокусуємо кожне поле) ---')
for auto_id, label in FIELDS[:5]:  # перші 5 полів
    el = found_ids.get(auto_id)
    if not el:
        log(f'  {label:<30} SKIP (not found)')
        continue
    try:
        el.SetFocus()
        time.sleep(0.15)
        log(f'  {label:<30} SetFocus OK')
    except Exception as e:
        log(f'  {label:<30} SetFocus FAIL: {e}')

# ── 6. Тест clipboard read через SetFocus + Ctrl+C ───────────────────────
log()
log('--- Тест читання коментаря через SetFocus + keyboard ---')
try:
    import win32clipboard, win32con, win32api
    HAS_WIN32 = True
    log('  win32clipboard: OK')
except ImportError:
    HAS_WIN32 = False
    log('  win32clipboard: не встановлено (pip install pywin32)')

if HAS_WIN32 and 'memoEditDeliveryComment' in found_ids:
    el = found_ids['memoEditDeliveryComment']
    try:
        # Фокус
        el.SetFocus()
        time.sleep(0.2)

        # Очистити clipboard
        win32clipboard.OpenClipboard()
        win32clipboard.EmptyClipboard()
        win32clipboard.CloseClipboard()

        # Ctrl+A, Ctrl+C через SendInput
        auto.SendKeys('{Ctrl}a', waitTime=0.05)
        auto.SendKeys('{Ctrl}c', waitTime=0.1)
        time.sleep(0.3)

        # Читаємо clipboard
        win32clipboard.OpenClipboard()
        try:
            text = win32clipboard.GetClipboardData(win32con.CF_UNICODETEXT)
        except:
            text = ''
        win32clipboard.CloseClipboard()

        log(f'  Результат clipboard: "{text[:80]}"')
        if text:
            log('  ✅ ЧИТАННЯ ЧЕРЕЗ SendKeys ПРАЦЮЄ!')
        else:
            log('  ❌ Clipboard порожній після SendKeys — SendKeys не дійшли до поля')
    except Exception as e:
        log(f'  ПОМИЛКА: {traceback.format_exc()}')
else:
    log('  SKIP')

# ── 7. Тест SetValue ──────────────────────────────────────────────────────
log()
log('--- Тест SetValue (записуємо "_TEST_" в коментар і одразу стираємо) ---')
if 'memoEditDeliveryComment' in found_ids:
    el = found_ids['memoEditDeliveryComment']
    # Читаємо поточне значення щоб відновити
    original = ''
    try:
        vp = el.GetValuePattern()
        if vp: original = vp.Value or ''
    except: pass

    # Пробуємо SetValue
    try:
        vp = el.GetValuePattern()
        if vp:
            vp.SetValue('_TEST_VALUE_')
            time.sleep(0.2)
            # Перевіряємо чи змінилось
            new_val = vp.Value or ''
            if '_TEST_VALUE_' in new_val:
                log('  ✅ SetValue ПРАЦЮЄ!')
            else:
                log(f'  ❌ SetValue не змінило значення (зараз: "{new_val[:40]}")')
            # Відновлюємо
            vp.SetValue(original)
        else:
            log('  ValuePattern недоступний')
    except Exception as e:
        log(f'  SetValue ПОМИЛКА: {e}')
else:
    log('  SKIP (поле не знайдено)')

# ── 8. Фінал ─────────────────────────────────────────────────────────────
log()
log('=== ГОТОВО ===')
save()
input('Натисни Enter щоб закрити...')
