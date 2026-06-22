"""
diagnose_iiko.py — повна діагностика UIA-дерева iiko
Запуск: python diagnose_iiko.py
Результат: diagnose_out.txt поруч зі скриптом
"""

import time, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import uiautomation as auto
except ImportError:
    print("ERROR: pip install uiautomation --break-system-packages")
    input()
    sys.exit(1)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'diagnose_out.txt')

lines = []
def log(s=''):
    print(s)
    lines.append(s)

def save():
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    log(f'\n=== Збережено: {OUT} ===')

# ──────────────────────────────────────────────
# 1. Знайти головне вікно iiko
# ──────────────────────────────────────────────
log('=== DIAGNOSE IIKO UIA ===')
log(f'Час: {time.strftime("%H:%M:%S")}')
log()

root = auto.GetRootControl()
iiko_wins = []
for w in root.GetChildren():
    cn = w.ClassName or ''
    if 'WindowsForms10' in cn:
        iiko_wins.append(w)
        log(f'WinForms вікно: "{w.Name}" [{cn[:40]}]')

if not iiko_wins:
    log('ПОМИЛКА: WindowsForms10 вікна не знайдено. Відкрий iiko!')
    save(); input(); sys.exit(1)

log()

# ──────────────────────────────────────────────
# 2. Знайти DeliveryOrderEditControl
# ──────────────────────────────────────────────
def find_by_id(el, aid, depth=10):
    if depth <= 0: return None
    try:
        if (el.AutomationId or '') == aid:
            return el
        for c in el.GetChildren():
            r = find_by_id(c, aid, depth-1)
            if r: return r
    except: pass
    return None

form = None
for w in iiko_wins:
    form = find_by_id(w, 'DeliveryOrderEditControl', 10)
    if form:
        log(f'DeliveryOrderEditControl знайдено в "{w.Name}"')
        break

if not form:
    log('ПОМИЛКА: DeliveryOrderEditControl НЕ знайдено!')
    log('Відкрий будь-яке замовлення доставки в iiko і запусти знову.')
    save(); input(); sys.exit(1)

log()

# ──────────────────────────────────────────────
# 3. Дамп всіх дочірніх контролів (до глибини 8)
# ──────────────────────────────────────────────
IMPORTANT_IDS = {
    'lookUpEditCustomerPhone', 'memoEditDeliveryComment',
    'memoEditCustomerComment', 'textEditCustomerCardNumber',
    'memoEditDeliveryAddressComment', 'gridLookUpEditStreetAddress',
    'textEditDeliveryHouse', 'timeEditDeliveryTime',
    'textEditName', 'labelOrderSum',
    'treeListItems', 'gridControlItems',
    'gridViewItems', 'treeList1',
}

found_important = {}

def dump(el, depth=0, max_depth=8):
    if depth > max_depth: return
    try:
        aid  = el.AutomationId or ''
        name = (el.Name or '')[:50]
        cls  = (el.ClassName or '')[:40]
        ct   = str(el.ControlType)[:20]
        val  = ''
        try:
            vp = el.GetValuePattern()
            val = (vp.Value or '')[:40] if vp else ''
        except: pass
        hwnd = el.NativeWindowHandle or 0

        prefix = '  ' * depth
        important = '*' if aid in IMPORTANT_IDS else ''
        log(f'{prefix}{important}[{aid or "?"}] Name="{name}" Cls="{cls}" Val="{val}" hwnd={hwnd}')

        if aid in IMPORTANT_IDS:
            found_important[aid] = {
                'name': name, 'val': val, 'hwnd': hwnd, 'cls': cls, 'el': el
            }

        for child in el.GetChildren():
            dump(child, depth+1, max_depth)
    except Exception as ex:
        log('  ' * depth + f'[EX: {ex}]')

log('=== ДЕРЕВО КОНТРОЛІВ (глибина 8) ===')
dump(form)
log()

# ──────────────────────────────────────────────
# 4. Звіт про знайдені важливі поля
# ──────────────────────────────────────────────
log('=== ЗНАЙДЕНІ ВАЖЛИВІ ПОЛЯ ===')
for aid in IMPORTANT_IDS:
    if aid in found_important:
        d = found_important[aid]
        log(f'  FOUND  {aid}: val="{d["val"]}" hwnd={d["hwnd"]}')
    else:
        log(f'  MISSING {aid}')
log()

# ──────────────────────────────────────────────
# 5. Пошук treeListItems / таблиці страв
# ──────────────────────────────────────────────
log('=== ПОШУК ТАБЛИЦІ СТРАВ (будь-яка treeList/gridControl) ===')
def find_dishes_table(el, depth=0, max_depth=10):
    if depth > max_depth: return []
    results = []
    try:
        aid = el.AutomationId or ''
        cls = el.ClassName or ''
        if any(k in aid.lower() for k in ['tree', 'grid', 'item', 'dish', 'list']):
            if any(k in cls.lower() for k in ['tree', 'grid', 'list']):
                hwnd = el.NativeWindowHandle or 0
                results.append({'aid': aid, 'cls': cls, 'hwnd': hwnd, 'el': el})
        for c in el.GetChildren():
            results.extend(find_dishes_table(c, depth+1, max_depth))
    except: pass
    return results

dishes = find_dishes_table(form)
for d in dishes[:20]:
    log(f'  [{d["aid"]}] Cls={d["cls"]} hwnd={d["hwnd"]}')

if not dishes:
    log('  (нічого не знайдено)')
log()

# ──────────────────────────────────────────────
# 6. Тест читання вулиці
# ──────────────────────────────────────────────
log('=== ТЕСТ ЧИТАННЯ ВУЛИЦІ ===')
if 'gridLookUpEditStreetAddress' in found_important:
    st_el = found_important['gridLookUpEditStreetAddress']['el']
    log(f'  AutomId: {st_el.AutomationId}')
    log(f'  Name: "{st_el.Name}"')
    try:
        vp = st_el.GetValuePattern()
        log(f'  ValuePattern.Value: "{vp.Value if vp else "NO VP"}"')
    except Exception as ex:
        log(f'  ValuePattern ERROR: {ex}')
    try:
        log(f'  LegacyIAccessible.Value: "{st_el.GetLegacyIAccessiblePattern().Value}"')
    except: pass
    log('  -- Дочірні контроли вулиці:')
    try:
        for c in st_el.GetChildren():
            cv = ''
            try:
                vp2 = c.GetValuePattern()
                cv = vp2.Value if vp2 else ''
            except: pass
            log(f'    [{c.AutomationId or "?"}] Name="{(c.Name or "")[:30]}" Val="{(cv or "")[:30]}"')
    except Exception as ex:
        log(f'    ERROR: {ex}')
else:
    log('  gridLookUpEditStreetAddress не знайдено')
log()

# ──────────────────────────────────────────────
# 7. Тест читання часу
# ──────────────────────────────────────────────
log('=== ТЕСТ ЧИТАННЯ ЧАСУ ===')
if 'timeEditDeliveryTime' in found_important:
    t_el = found_important['timeEditDeliveryTime']['el']
    log(f'  Name: "{t_el.Name}"')
    log(f'  Cls: "{t_el.ClassName}"')
    try:
        vp = t_el.GetValuePattern()
        log(f'  ValuePattern.Value: "{vp.Value if vp else "NO VP"}"')
    except Exception as ex:
        log(f'  ValuePattern ERROR: {ex}')
    log('  -- Дочірні:')
    try:
        for c in t_el.GetChildren():
            cv = ''
            try:
                vp2 = c.GetValuePattern()
                cv = vp2.Value if vp2 else ''
            except: pass
            log(f'    [{c.AutomationId or "?"}] Cls="{(c.ClassName or "")[:30]}" Name="{(c.Name or "")[:30]}" Val="{cv[:30]}"')
    except Exception as ex:
        log(f'    ERROR: {ex}')
log()

save()
print(f'\nВідкрий файл: {OUT}')
input('Натисни Enter...')
