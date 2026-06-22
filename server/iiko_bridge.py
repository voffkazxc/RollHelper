"""
iiko_bridge.py
"""

import re
import time
import os
from datetime import datetime

try:
    import uiautomation as auto
except ImportError:
    auto = None

LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'bridge.log')


def _com_init():
    """COM потребує ініціалізації на кожному новому потоці (Flask threaded=True)."""
    try:
        import ctypes
        # COINIT_APARTMENTTHREADED = 0x2  (найбезпечніше для UIA)
        ctypes.windll.ole32.CoInitializeEx(None, 0x2)
    except Exception:
        try:
            ctypes.windll.ole32.CoInitialize(None)
        except Exception:
            pass


def _log(msg):
    ts = datetime.now().strftime('%H:%M:%S.%f')[:-3]
    line = f'[{ts}] {msg}'
    print(line)
    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(line + '\n')
    except Exception:
        pass


_form_cache = None
_form_cache_ts = 0
_win_cache = None      # батьківське вікно iiko — перевіряємо першим
FORM_CACHE_TTL = 4     # 4 секунди — форма змінюється при переході між замовленнями


def _collect_ids(el, target_ids, found, depth):
    if depth <= 0 or not target_ids:
        return
    try:
        aid = el.AutomationId or ''
        if aid in target_ids:
            found[aid] = el
            target_ids = target_ids - {aid}
        for child in el.GetChildren():
            _collect_ids(child, target_ids, found, depth - 1)
            if not target_ids:
                return
    except Exception:
        pass


def _find_by_id(el, auto_id, max_depth=12):
    try:
        found = el.FindControl(searchDepth=max_depth, AutomationId=auto_id)
        if found and (found.AutomationId or '') == auto_id:
            return found
    except Exception:
        pass
    try:
        if (el.AutomationId or '') == auto_id:
            return el
        for child in el.GetChildren():
            r = _find_by_id(child, auto_id, max_depth - 1)
            if r:
                return r
    except Exception:
        pass
    return None


def _get_foreground_win():
    try:
        import ctypes
        hwnd = ctypes.windll.user32.GetForegroundWindow()
        if hwnd:
            return auto.ControlFromHandle(hwnd)
    except Exception:
        pass
    return None


def _search_for_form_in(win):
    if win is None:
        return None
    try:
        cls   = win.ClassName or ''
        title = (win.Name or '')
        if 'WindowsForms10' not in cls:
            return None
        _log(f'  checking: cls="{cls[:50]}" title="{title[:40]}"')
        result = _find_by_id(win, 'DeliveryOrderEditControl', 15)
        if result:
            _log(f'  DeliveryOrderEditControl FOUND')
        else:
            _log(f'  DeliveryOrderEditControl NOT found in this window')
        return result
    except Exception as ex:
        _log(f'  _search_for_form_in exception: {ex}')
        return None


def get_delivery_form():
    global _form_cache, _form_cache_ts, _win_cache
    if auto is None:
        _log('ERROR: uiautomation not installed')
        return None
    now = time.time()
    if _form_cache is not None and (now - _form_cache_ts) < FORM_CACHE_TTL:
        try:
            _ = _form_cache.AutomationId
            return _form_cache
        except Exception:
            _log('form cache invalid')
            _form_cache = None

    t0 = time.time()

    def _cache_and_return(ctrl, label):
        global _form_cache, _form_cache_ts, _win_cache
        _form_cache = ctrl
        _form_cache_ts = now
        _log(f'found ({label}) in {time.time()-t0:.2f}s')
        return ctrl

    # 1. Спробувати foreground (швидкий шлях)
    fg = _get_foreground_win()
    ctrl = _search_for_form_in(fg)
    if ctrl:
        _win_cache = fg
        return _cache_and_return(ctrl, 'foreground')

    # 2. Спробувати кешоване батьківське вікно iiko (якщо є)
    if _win_cache is not None:
        try:
            _ = _win_cache.Name  # перевірка що вікно ще живе
            ctrl = _search_for_form_in(_win_cache)
            if ctrl:
                return _cache_and_return(ctrl, 'win_cache')
        except Exception:
            _win_cache = None

    # 3. Повне сканування — WindowsForms10 вікна та вікна iiko/Syrve за назвою
    _log(f'foreground+cache miss ({time.time()-t0:.2f}s), scanning all top-level windows...')
    root = auto.GetRootControl()
    wins_checked = 0
    for win in root.GetChildren():
        cls   = win.ClassName or ''
        title = (win.Name or '').lower()
        is_winforms = 'WindowsForms10' in cls
        is_iiko     = 'iiko' in title or 'syrve' in title or 'office' in title or 'back' in title
        if not is_winforms and not is_iiko:
            continue
        wins_checked += 1
        ctrl = _search_for_form_in(win)
        if ctrl:
            _win_cache = win
            return _cache_and_return(ctrl, f'scan win#{wins_checked} cls={cls[:30]}')
    _log(f'NOT FOUND (checked {wins_checked} windows in {time.time()-t0:.2f}s)')
    return None


def _read_el_value(el):
    try:
        vp = el.GetValuePattern()
        if vp:
            v = vp.Value
            if v is not None:
                return v
    except Exception:
        pass
    name = (el.Name or '')
    if name:
        return name
    try:
        for child in el.GetChildren():
            try:
                vp2 = child.GetValuePattern()
                if vp2:
                    v2 = vp2.Value
                    if v2:
                        return v2
            except Exception:
                pass
            cn = (child.Name or '')
            if cn:
                return cn
    except Exception:
        pass
    return ''


def _debug_el(el, label):
    try:
        name = el.Name or ''
        aid  = el.AutomationId or ''
        cls  = el.ClassName or ''
        vp_val = ''
        try:
            vp = el.GetValuePattern()
            vp_val = vp.Value if vp else ''
        except Exception:
            pass
        children_info = []
        try:
            for c in el.GetChildren():
                cn = (c.Name or '')[:30]
                cv = ''
                try:
                    vp2 = c.GetValuePattern()
                    cv = (vp2.Value or '')[:30] if vp2 else ''
                except Exception:
                    pass
                children_info.append(f'[{c.AutomationId or "?"} name="{cn}" val="{cv}"]')
        except Exception:
            pass
        _log(f'DEBUG {label}: Name="{name[:40]}" AutomId="{aid}" Cls="{cls[:30]}" Val="{vp_val[:40]}"')
        for ci in children_info[:5]:
            _log(f'  child: {ci}')
    except Exception as ex:
        _log(f'DEBUG {label} EXCEPTION: {ex}')


FORM_SEARCH_TIMEOUT_S = 8   # якщо пошук форми зайняв >8 с — це timeout

def read_fields():
    global _form_cache, _form_cache_ts
    _com_init()
    t0 = time.time()
    _log('read_fields() called')
    form = get_delivery_form()
    if not form:
        elapsed = time.time() - t0
        # P7: 3 різних типи iiko-помилок
        if elapsed >= FORM_SEARCH_TIMEOUT_S:
            _log(f'read_fields: TIMEOUT ({elapsed:.1f}s)')
            return {
                'ok': False,
                'error_code': 'IIKO_TIMEOUT',
                'error': f'iiko не відповідає (пошук тривав {elapsed:.1f}с).',
            }
        _log(f'read_fields: form not found ({elapsed:.1f}s)')
        return {
            'ok': False,
            'error_code': 'IIKO_FORM_NOT_FOUND',
            'error': 'Форма доставки iiko не знайдена. Відкрийте замовлення в iiko.',
        }

    TARGET_IDS = {
        'lookUpEditCustomerPhone',
        'memoEditDeliveryComment',
        'memoEditCustomerComment',
        'textEditCustomerCardNumber',
        'memoEditDeliveryAddressComment',
        'gridLookUpEditStreetAddress',
        'textEditDeliveryHouse',
        'timeEditDeliveryTime',
        'textEditName',
        'labelOrderSum',
    }
    found_els = {}
    _collect_ids(form, set(TARGET_IDS), found_els, 12)
    _log(f'tree walk done in {time.time()-t0:.2f}s, found {len(found_els)}/{len(TARGET_IDS)} fields')

    # Якщо phone-поле взагалі не знайдено в дереві — форма, швидше за все, стала/хибна.
    # Скидаємо кеш і повертаємо порожній результат одразу (не чекаємо читання решти)
    if 'lookUpEditCustomerPhone' not in found_els:
        _form_cache = None
        _form_cache_ts = 0
        _log('lookUpEditCustomerPhone not in tree → cache invalidated, returning early')
        return {
            'ok': True, 'phone': '', 'comment': '', 'customer_comment': '',
            'card': '', 'address_comment': '', 'street': '', 'house': '',
            'time': '', 'name': '', 'sum': 0,
        }

    if 'gridLookUpEditStreetAddress' in found_els:
        _debug_el(found_els['gridLookUpEditStreetAddress'], 'street')

    def val(aid):
        el = found_els.get(aid)
        return _read_el_value(el) if el else ''

    sum_raw = val('labelOrderSum')
    m = re.search(r'(\d[\d\s]*[,.]?\d*)', sum_raw.replace('\xa0', ''))
    try:
        order_sum = int(float(m.group(1).replace(',', '.').replace(' ', ''))) if m else 0
    except Exception:
        order_sum = 0

    result = {
        'ok':               True,
        'phone':            val('lookUpEditCustomerPhone'),
        'comment':          val('memoEditDeliveryComment'),
        'customer_comment': val('memoEditCustomerComment'),
        'card':             val('textEditCustomerCardNumber'),
        'address_comment':  val('memoEditDeliveryAddressComment'),
        'street':           val('gridLookUpEditStreetAddress'),
        'house':            val('textEditDeliveryHouse'),
        'time':             val('timeEditDeliveryTime'),
        'name':             val('textEditName'),
        'sum':              order_sum,
    }
    _log(f'read_fields OK in {time.time()-t0:.2f}s: phone="{result["phone"][:15]}" sum={result["sum"]}')

    # Якщо телефон порожній — скидаємо кеш форми,
    # щоб наступний виклик (retry з AHK) точно робив свіжий скан
    if not result['phone']:
        _form_cache = None
        _form_cache_ts = 0
        _log('phone empty → cache invalidated for next call')

    return result


def write_fields(data):
    _com_init()
    _log(f'write_fields() called: {list(data.keys())}')
    t0 = time.time()
    form = get_delivery_form()
    if not form:
        elapsed = time.time() - t0
        code = 'IIKO_TIMEOUT' if elapsed >= FORM_SEARCH_TIMEOUT_S else 'IIKO_FORM_NOT_FOUND'
        return {'ok': False, 'error_code': code, 'error': 'Форма доставки iiko не знайдена.'}

    results = {}
    field_map = {
        'comment':          'memoEditDeliveryComment',
        'customer_comment': 'memoEditCustomerComment',
        'address_comment':  'memoEditDeliveryAddressComment',
    }
    for key, auto_id in field_map.items():
        if key in data and data[key] not in (None, ''):
            ok = _find_and_set(form, auto_id, data[key])
            results[key] = ok
            _log(f'  set {auto_id} = {ok}')

    return {'ok': True, 'results': results}


def _find_and_set(form, auto_id, value):
    el = _find_by_id(form, auto_id)
    if not el:
        return False
    try:
        vp = el.GetValuePattern()
        if vp:
            vp.SetValue(str(value))
            return True
    except Exception:
        pass
    return False


def focus_field(auto_id):
    _com_init()
    _log(f'focus_field({auto_id})')
    t0 = time.time()
    form = get_delivery_form()
    if not form:
        elapsed = time.time() - t0
        code = 'IIKO_TIMEOUT' if elapsed >= FORM_SEARCH_TIMEOUT_S else 'IIKO_FORM_NOT_FOUND'
        return {'ok': False, 'hwnd': 0, 'error_code': code, 'error': 'Форма доставки iiko не знайдена.'}
    el = _find_by_id(form, auto_id)
    if not el:
        return {'ok': False, 'hwnd': 0, 'error_code': 'IIKO_FORM_NOT_FOUND',
                'error': f'Елемент iiko не знайдено: {auto_id}.'}
    try:
        el.SetFocus()
        time.sleep(0.08)
        hwnd = 0
        try:
            for child in el.GetChildren():
                cn = child.ClassName or ''
                if 'EDIT' in cn.upper() and 'WindowsForms10' in cn:
                    h = child.NativeWindowHandle
                    if h:
                        hwnd = h
                        break
        except Exception:
            pass
        if not hwnd:
            hwnd = el.NativeWindowHandle or 0
        _log(f'focus_field({auto_id}) OK: hwnd={hwnd}')
        return {'ok': True, 'hwnd': hwnd}
    except Exception as ex:
        _log(f'focus_field({auto_id}) EXCEPTION: {ex}')
        return {'ok': False, 'hwnd': 0, 'error': str(ex)}


def focus_items_tree():
    return focus_field('treeListItems')


def invoke_button(auto_id):
    _log(f'invoke_button({auto_id})')
    form = get_delivery_form()
    if not form:
        return {'ok': False, 'error': 'no_form'}
    el = _find_by_id(form, auto_id)
    if not el:
        return {'ok': False, 'error': f'not_found:{auto_id}'}
    try:
        ip = el.GetInvokePattern()
        if ip:
            ip.Invoke()
            _log(f'invoke_button({auto_id}) OK via InvokePattern')
            return {'ok': True, 'method': 'invoke'}
    except Exception:
        pass
    try:
        el.SetFocus()
        time.sleep(0.05)
        import ctypes
        hwnd = el.NativeWindowHandle or 0
        if hwnd:
            VK_SPACE = 0x20
            ctypes.windll.user32.PostMessage(hwnd, 0x0100, VK_SPACE, 0)
            ctypes.windll.user32.PostMessage(hwnd, 0x0101, VK_SPACE, 0)
            _log(f'invoke_button({auto_id}) OK via Space key')
            return {'ok': True, 'method': 'space'}
    except Exception as ex:
        _log(f'invoke_button({auto_id}) FAILED: {ex}')
    return {'ok': False, 'error': 'no_invoke_pattern'}


def dump_children(auto_id, max_depth=4):
    _com_init()
    _log(f'dump_children({auto_id})')
    form = get_delivery_form()
    if not form:
        return {'ok': False, 'error': 'no_form', 'elements': []}

    root_el = form if auto_id.upper() == 'ROOT' else _find_by_id(form, auto_id)
    if not root_el:
        return {'ok': False, 'error': f'not_found:{auto_id}', 'elements': []}

    elements = []

    def _walk(el, depth, path):
        if depth <= 0:
            return
        try:
            aid  = el.AutomationId or ''
            name = (el.Name or '')[:60]
            cls  = (el.ClassName or '')[:40]
            ctrl = el.ControlTypeName or ''
            vp_val = ''
            try:
                vp = el.GetValuePattern()
                if vp:
                    vp_val = (vp.Value or '')[:60]
            except Exception:
                pass
            enabled = True
            try:
                enabled = el.IsEnabled
            except Exception:
                pass
            elements.append({
                'depth': depth, 'path': path,
                'aid': aid, 'name': name, 'cls': cls,
                'ctrl': ctrl, 'val': vp_val, 'en': enabled,
            })
            _log(f'  [{depth}] aid="{aid}" ctrl={ctrl} name="{name[:30]}" val="{vp_val[:30]}" en={enabled}')
            for child in el.GetChildren():
                _walk(child, depth - 1, path + '/' + (aid or cls or ctrl or '?'))
        except Exception as ex:
            _log(f'  dump walk ex: {ex}')

    _walk(root_el, max_depth, auto_id)
    return {'ok': True, 'root': auto_id, 'count': len(elements), 'elements': elements}


def read_phone():
    form = get_delivery_form()
    if not form:
        return ''
    el = _find_by_id(form, 'lookUpEditCustomerPhone')
    return _read_el_value(el) if el else ''
