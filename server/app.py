"""
RollHouse PRO — локальний сервер
Запуск: python app.py  (або через start.bat)
Порт:   http://localhost:5000
"""

import re
import csv
import io
import json
import os
import time
import threading
import hmac
import hashlib
import base64
import secrets
from flask import Flask, jsonify, request, send_from_directory, Response, redirect
from flask_cors import CORS
import database as db
import telegram as _tg

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False   # кирилиця в JSON без \uXXXX
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static')
CORS(app, supports_credentials=True, origins=['http://localhost:5000', 'http://127.0.0.1:5000'])


# ──────────────────────────────────────────────
# Session token (HMAC-SHA256, HttpOnly cookie)
# ──────────────────────────────────────────────

_SESSION_COOKIE   = 'rh_session'
_SESSION_MAX_AGE  = 8 * 3600          # 8 годин


def _session_secret() -> str:
    """Повертає секрет для підпису токенів. Генерується один раз і зберігається в DB."""
    secret = db.get_setting_value('auth', 'session_secret')
    if not secret:
        secret = secrets.token_hex(32)
        db.set_setting('auth', 'session_secret', secret)
    return secret


def _make_token(role: str = 'operator', user_id: int = 0, login: str = '') -> str:
    """Створює підписаний токен: base64(payload).HMAC"""
    now = int(time.time())
    payload = json.dumps({
        'role': role, 'user_id': user_id, 'login': login,
        'iat': now, 'exp': now + _SESSION_MAX_AGE
    }, separators=(',', ':')).encode()
    payload_b64 = base64.urlsafe_b64encode(payload).decode().rstrip('=')
    sig = hmac.new(_session_secret().encode(), payload_b64.encode(), hashlib.sha256).hexdigest()
    return payload_b64 + '.' + sig


def _verify_token(token: str) -> dict | None:
    """Перевіряє токен. Повертає payload або None якщо недійсний/прострочений."""
    try:
        payload_b64, sig = token.rsplit('.', 1)
        expected = hmac.new(_session_secret().encode(), payload_b64.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(sig, expected):
            return None
        # Відновлюємо padding
        padded = payload_b64 + '=' * (4 - len(payload_b64) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded))
        if payload.get('exp', 0) < time.time():
            return None
        return payload
    except Exception:
        return None


# Маршрути що не вимагають авторизації
_AUTH_EXEMPT_EXACT = {
    '/api/auth/logout',
    '/api/auth/login',
    '/ping',
}
# Префікси що не вимагають авторизації
_AUTH_EXEMPT_PREFIX = (
    '/api/iiko/',        # AHK-скрипт: окрема авторизація пізніше
    '/api/courier/',     # мобільна сторінка кур'єра: авт. по courier_id
)


@app.before_request
def require_session():
    """Перевіряє токен сесії на всіх /api/* маршрутах."""
    path = request.path

    # Статичні HTML сторінки + /login — пропускаємо
    if not path.startswith('/api/'):
        return

    # Звільнені маршрути
    if path in _AUTH_EXEMPT_EXACT:
        return
    if any(path.startswith(p) for p in _AUTH_EXEMPT_PREFIX):
        return

    # Перевіряємо cookie
    token = request.cookies.get(_SESSION_COOKIE)
    if not token:
        return _json_utf8({'ok': False, 'error': 'Не авторизовано.',
                           'error_code': 'UNAUTHORIZED'}, status=401)
    session = _verify_token(token)
    if not session:
        resp = _json_utf8({'ok': False, 'error': 'Сесія закінчилась. Перезайдіть.',
                           'error_code': 'SESSION_EXPIRED'}, status=401)
        resp.delete_cookie(_SESSION_COOKIE, path='/')
        return resp
    # Токени нової системи (user_id > 0) — перевіряємо в БД (revocation check)
    if session.get('user_id'):
        if not db.check_session_active(token):
            resp = _json_utf8({'ok': False, 'error': 'Сесія відкликана. Перезайдіть.',
                               'error_code': 'SESSION_REVOKED'}, status=401)
            resp.delete_cookie(_SESSION_COOKIE, path='/')
            return resp
    # Прикріплюємо сесію до запиту для використання в роутах
    request.session = session


# ──────────────────────────────────────────────
# require_role — декоратор перевірки ролей
# ──────────────────────────────────────────────

def require_role(*roles: str):
    """Декоратор: перевіряє що юзер має одну з дозволених ролей.
    Використовується разом з require_session (встановлює request.session).

    Приклад:
        @app.route('/api/admin/users')
        @require_role('owner', 'admin')
        def list_users(): ...
    """
    def decorator(fn):
        from functools import wraps
        @wraps(fn)
        def wrapper(*args, **kwargs):
            sess = getattr(request, 'session', None)
            if not sess:
                return _json_utf8({'ok': False, 'error': 'Не авторизовано',
                                   'error_code': 'UNAUTHORIZED'}, status=401)
            if roles and sess.get('role') not in roles:
                return _json_utf8({'ok': False, 'error': 'Доступ заборонено',
                                   'error_code': 'ROLE_FORBIDDEN',
                                   'required_roles': list(roles),
                                   'your_role': sess.get('role')}, status=403)
            return fn(*args, **kwargs)
        return wrapper
    return decorator


# ──────────────────────────────────────────────
# CRM Customer card HTML (відкривається в браузері)
# ──────────────────────────────────────────────

@app.route('/login')
def login_page():
    return send_from_directory(STATIC_DIR, 'login.html')


def _html_auth_guard():
    """Для захищених HTML-сторінок: редиректить на /login якщо сесія не активна."""
    token = request.cookies.get(_SESSION_COOKIE)
    if not token:
        return redirect(f'/login?next={request.path}')
    sess = _verify_token(token)
    if not sess:
        resp = redirect(f'/login?next={request.path}')
        resp.delete_cookie(_SESSION_COOKIE, path='/')
        return resp
    # Revocation check для нових сесій
    if sess.get('user_id') and not db.check_session_active(token):
        resp = redirect(f'/login?next={request.path}')
        resp.delete_cookie(_SESSION_COOKIE, path='/')
        return resp
    return None


@app.route('/card')
def customer_card_page():
    r = _html_auth_guard(); return r if r else send_from_directory(STATIC_DIR, 'card.html')


@app.route('/dashboard')
def dashboard_page():
    r = _html_auth_guard(); return r if r else send_from_directory(STATIC_DIR, 'dashboard.html')


# ──────────────────────────────────────────────
# Dashboard API
# ──────────────────────────────────────────────

@app.route('/api/dashboard/orders', methods=['GET'])
def dashboard_orders():
    rows = db.get_orders_filtered(
        status          = request.args.get('status', ''),
        city            = request.args.get('city', ''),
        date_from       = request.args.get('date_from', ''),
        date_to         = request.args.get('date_to', ''),
        search          = request.args.get('search', ''),
        courier_id      = request.args.get('courier_id', ''),
        tag             = request.args.get('tag', ''),
        include_deleted = request.args.get('show_deleted', '0') == '1',
        limit           = int(request.args.get('limit', 200)),
    )
    # P5: сервер — єдиний авторитет. Додаємо allowed_transitions до кожного рядка.
    for r in rows:
        st = r.get('status') or 'new'
        r['allowed_transitions'] = _bl.allowed_transitions(st)
        r['status_label']        = _bl.STATUS_LABELS.get(st, st)
    return _json_utf8(rows)


@app.route('/api/orders/export.csv', methods=['GET'])
def export_orders_csv():
    rows = db.get_orders_filtered(
        status          = request.args.get('status', ''),
        city            = request.args.get('city', ''),
        date_from       = request.args.get('date_from', ''),
        date_to         = request.args.get('date_to', ''),
        search          = request.args.get('search', ''),
        courier_id      = request.args.get('courier_id', ''),
        tag             = request.args.get('tag', ''),
        include_deleted = request.args.get('show_deleted', '0') == '1',
        limit           = 50000,
    )
    fields = ['id', 'order_date', 'status', 'phone', 'customer_name',
              'city', 'delivery_type', 'address', 'items', 'total_amount',
              'courier_name', 'tags', 'comment']
    headers_uk = ['#', 'Дата', 'Статус', 'Телефон', 'Клієнт',
                  'Місто', 'Доставка', 'Адреса', 'Склад', 'Сума',
                  'Кур\'єр', 'Теги', 'Коментар']
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(headers_uk)
    for r in rows:
        w.writerow([r.get(f, '') or '' for f in fields])
    output = '﻿' + buf.getvalue()   # BOM for Excel
    return Response(
        output,
        mimetype='text/csv; charset=utf-8',
        headers={'Content-Disposition': 'attachment; filename="orders.csv"'}
    )


@app.route('/api/dashboard/kpi', methods=['GET'])
def dashboard_kpi():
    return _json_utf8(db.get_kpi_today())


# ──────────────────────────────────────────────
# Couriers
# ──────────────────────────────────────────────

@app.route('/couriers')
def couriers_page():
    r = _html_auth_guard(); return r if r else send_from_directory(STATIC_DIR, 'couriers.html')


@app.route('/courier')
def courier_page():
    # Мобільна сторінка кур'єра — без guard (доступна за прямим посиланням)
    return send_from_directory(STATIC_DIR, 'courier.html')


@app.route('/api/couriers', methods=['GET'])
def get_couriers():
    actor_role = request.args.get('role', 'manager')
    if request.args.get('stats') == '1':
        rows = db.get_couriers_with_stats()
        # P8: кур'єр не бачить суму виручки
        if not _err.check_role(actor_role, 'manage_couriers'):
            for r in rows:
                r.pop('total_revenue', None)
        return _json_utf8(rows)
    active_only = request.args.get('active', '1') != '0'
    return _json_utf8(db.get_couriers(active_only=active_only))


@app.route('/api/couriers', methods=['POST'])
def upsert_courier():
    data = request.get_json(force=True) or {}
    actor_id   = int(data.get('actor_id')   or 0)
    actor_role = str(data.get('actor_role') or 'manager')
    return _json_utf8(db.upsert_courier(data, actor_id=actor_id, actor_role=actor_role))


@app.route('/api/courier/<int:courier_id>/status', methods=['POST'])
def set_courier_status(courier_id):
    data   = request.get_json(force=True) or {}
    status = str(data.get('status', 'offline'))
    return _json_utf8(db.set_courier_status(courier_id, status))


@app.route('/api/courier/<int:courier_id>/notes', methods=['POST'])
def update_courier_notes(courier_id):
    data  = request.get_json(force=True) or {}
    notes = (data.get('notes') or '').strip()
    return _json_utf8(db.update_courier_notes(courier_id, notes))


@app.route('/api/courier/<int:courier_id>/orders', methods=['GET'])
def get_courier_orders(courier_id):
    """P8: кур'єр бачить тільки свої активні доставки, без суми."""
    return _json_utf8({'ok': True, 'items': db.get_courier_orders(courier_id)})


@app.route('/api/order/<int:order_id>/courier', methods=['POST'])
def assign_courier(order_id):
    try:
        data       = request.get_json(force=True) or {}
        courier_id = data.get('courier_id')  # None = зняти кур'єра
        if courier_id is not None:
            courier_id = int(courier_id) if courier_id else None
        actor_id   = int(data.get('actor_id', 0))
        actor_role = data.get('actor_role', 'manager')
        return _json_utf8(db.assign_courier(order_id, courier_id, actor_id, actor_role))
    except Exception as e:
        import traceback; traceback.print_exc()
        return _json_utf8(_err.err('INTERNAL', {'detail': str(e)}))


@app.route('/api/customer/<int:customer_id>/block', methods=['POST'])
def block_customer(customer_id):
    """P2: блокує клієнта. P8: тільки manager."""
    data       = request.get_json(force=True) or {}
    actor_role = data.get('actor_role', 'manager')
    # P8: блокування клієнта — тільки менеджер
    if not _err.check_role(actor_role, 'block_customer'):
        return _json_utf8(_err.err('ROLE_FORBIDDEN'), status=403)
    blocked    = bool(data.get('blocked', True))
    reason     = (data.get('reason') or '').strip()
    actor_id   = int(data.get('actor_id', 0))
    return _json_utf8(db.set_customer_blocked(customer_id, blocked, reason, actor_id, actor_role))


# ──────────────────────────────────────────────
# iiko UIA Bridge — читання і запис полів без миші
# ──────────────────────────────────────────────

import iiko_bridge as _bridge
import business_logic as _bl
import errors as _err


def _tg_cfg():
    """Повертає (token, chat_id) або (None, None) якщо не налаштовано."""
    s = db.get_all_settings().get('telegram', {})
    if s.get('enabled', '0') != '1':
        return None, None
    return s.get('bot_token', ''), s.get('chat_id', '')


def _tg_send(text: str):
    """Відправляє Telegram повідомлення асинхронно (daemon thread).
    Telegram timeout НІКОЛИ не блокує основний request pipeline."""
    token, chat_id = _tg_cfg()
    if token and chat_id:
        def _send():
            try:
                _tg.send(token, chat_id, text)
            except Exception as e:
                print(f'[TG] Помилка відправки: {e}')
        threading.Thread(target=_send, daemon=True).start()


def _json_utf8(data, status: int = 200):
    """jsonify-замінник: ніколи не ескейпить кирилицю."""
    return Response(json.dumps(data, ensure_ascii=False),
                    status=status,
                    mimetype='application/json; charset=utf-8')

import parser as _parser

@app.route('/api/iiko/analyze', methods=['GET', 'POST'])
def analyze_comment():
    """Парсинг комментария (замена гигантских RegEx из AHK)"""
    try:
        text = request.args.get('text', '')
        if request.method == 'POST':
            # Handle both JSON and raw text bodies
            if request.is_json:
                data = request.get_json(silent=True) or {}
                text = data.get('text', text)
            else:
                text = request.get_data(as_text=True)

        result = _parser.parse_comment(text)
        
        # Return plain Key=Value text for AHK
        lines = []
        for k, v in result.items():
            lines.append(f"{k}={v}")
        return Response("\n".join(lines), mimetype='text/plain; charset=utf-8')
    except Exception as e:
        return Response(f"error={str(e)}", mimetype='text/plain; charset=utf-8')

@app.route('/api/iiko/read', methods=['GET'])
def iiko_read():
    """Читає всі поля форми доставки iiko через UIA.
    ?dump=<auto_id>  — замість read: дамп дочірніх UIA-елементів контейнера
    ?depth=N         — глибина дампу (default 4)
    """
    import time as _time
    try:
        dump_id = request.args.get('dump', '')
        if dump_id:
            depth = int(request.args.get('depth', 4))
            return _json_utf8(_bridge.dump_children(dump_id, max_depth=depth))
        t0 = _time.time()
        result = _bridge.read_fields()
        duration_ms = int((_time.time() - t0) * 1000)
        phone = result.get('phone', '') if result.get('ok') else ''
        db.log_iiko_read(
            phone=phone,
            ok=result.get('ok', False),
            duration_ms=duration_ms,
            raw_fields=result if result.get('ok') else None,
            error=result.get('error') if not result.get('ok') else None
        )
        return _json_utf8(result)
    except Exception as e:
        db.log_iiko_read(phone='', ok=False, duration_ms=0, error=str(e))
        return _json_utf8({'ok': False, 'error': str(e)})


@app.route('/api/iiko/write', methods=['POST'])
def iiko_write():
    """Записує поля форми доставки iiko через UIA (без миші)."""
    try:
        data = request.get_json(force=True)
        return jsonify(_bridge.write_fields(data))
    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify(_err.err('IIKO_WRITE_FAILED', {'detail': str(e)}))


@app.route('/api/iiko/focus-items', methods=['POST'])
def iiko_focus_items():
    """Фокусує treeListItems — повертає HWND для прямого ControlSend."""
    try:
        result = _bridge.focus_items_tree()
        return jsonify(result)
    except Exception as e:
        return jsonify({'ok': False, 'hwnd': 0, 'error': str(e)})


@app.route('/api/iiko/invoke/<auto_id>', methods=['POST'])
def iiko_invoke(auto_id):
    """Клік по кнопці через UIA InvokePattern (без координат, без миші)."""
    try:
        result = _bridge.invoke_button(auto_id)
        return _json_utf8(result)
    except Exception as e:
        return _json_utf8({'ok': False, 'error': str(e)})


@app.route('/api/iiko/dump/<auto_id>', methods=['GET', 'POST'])
def iiko_dump(auto_id):
    """Дампить усі дочірні UIA-елементи контейнера — для пошуку AutomationId невідомих полів."""
    try:
        depth = int(request.args.get('depth', 4))
        result = _bridge.dump_children(auto_id, max_depth=depth)
        return _json_utf8(result)
    except Exception as e:
        return _json_utf8({'ok': False, 'error': str(e)})


@app.route('/api/iiko/focus/<auto_id>', methods=['POST'])
def iiko_focus_field(auto_id):
    """
    Фокусує контрол через UIA SetFocus().
    Повертає HWND внутрішнього Edit — AHK робить ControlSend напряму туди.
    """
    try:
        result = _bridge.focus_field(auto_id)
        return jsonify(result)
    except Exception as e:
        return jsonify({'ok': False, 'hwnd': 0, 'error': str(e)})


# ──────────────────────────────────────────────
# Health check
# ──────────────────────────────────────────────

@app.route('/ping')
def ping():
    return jsonify({'ok': True, 'version': '1.0'})


# ──────────────────────────────────────────────
# Auth  (PIN)  — з rate limiting та авто-генерацією PIN
# ──────────────────────────────────────────────

# Rate limiting: {ip: {'fails': int, 'locked_until': float}}
_auth_attempts: dict = {}
_AUTH_MAX_FAILS    = 5       # спроб до блокування
_AUTH_LOCKOUT_SEC  = 900     # 15 хвилин
_AUTH_DELAY_SEC    = 0.3     # затримка на кожен запит (anti-brute-force)


def _get_client_ip() -> str:
    return request.headers.get('X-Forwarded-For', request.remote_addr or '127.0.0.1').split(',')[0].strip()


def _auth_is_locked(ip: str) -> bool:
    rec = _auth_attempts.get(ip)
    if not rec:
        return False
    if rec['locked_until'] and time.time() < rec['locked_until']:
        return True
    if rec['locked_until'] and time.time() >= rec['locked_until']:
        # блокування закінчилось — скидаємо
        _auth_attempts.pop(ip, None)
    return False


def _auth_fail(ip: str):
    rec = _auth_attempts.setdefault(ip, {'fails': 0, 'locked_until': 0.0})
    rec['fails'] += 1
    if rec['fails'] >= _AUTH_MAX_FAILS:
        rec['locked_until'] = time.time() + _AUTH_LOCKOUT_SEC
        print(f'[AUTH] IP {ip} заблоковано на {_AUTH_LOCKOUT_SEC // 60} хв після {rec["fails"]} невдалих спроб')


def _auth_success(ip: str):
    _auth_attempts.pop(ip, None)




@app.route('/api/auth/logout', methods=['POST'])
def auth_logout():
    """Видаляє сесійний cookie + відкликає сесію в БД."""
    token = request.cookies.get(_SESSION_COOKIE)
    if token:
        try:
            db.revoke_session_record(token)
        except Exception:
            pass
    resp = _json_utf8({'ok': True})
    resp.delete_cookie(_SESSION_COOKIE, path='/')
    return resp


# ──────────────────────────────────────────────
# Нова система авторизації: логін + пароль
# ──────────────────────────────────────────────

@app.route('/api/auth/login', methods=['POST'])
def auth_login():
    """Вхід за логіном + паролем. Повертає HttpOnly cookie."""
    ip = _get_client_ip()
    time.sleep(_AUTH_DELAY_SEC)

    if _auth_is_locked(ip):
        remaining = max(0, int(_auth_attempts.get(ip, {}).get('locked_until', 0) - time.time()))
        return _json_utf8(_err.err('AUTH_LOCKED', {'retry_after_sec': remaining}), status=429)

    data     = request.get_json(force=True) or {}
    login    = str(data.get('login', '')).strip()
    password = str(data.get('password', '')).strip()

    if not login or not password:
        return _json_utf8(_err.err('AUTH_FAILED'))

    user = db.authenticate_user(login, password)
    if not user:
        _auth_fail(ip)
        rec = _auth_attempts.get(ip, {})
        attempts_left = max(0, _AUTH_MAX_FAILS - rec.get('fails', 0))
        return _json_utf8(_err.err('AUTH_FAILED', {'attempts_left': attempts_left}))

    _auth_success(ip)
    token = _make_token(role=user['role'], user_id=user['id'], login=user['login'])

    # Зберігаємо сесію в БД для можливості відкликання
    try:
        db.create_session_record(user['id'], token, ip=ip)
    except Exception as e:
        print(f'[AUTH] Помилка запису сесії в БД: {e}')

    resp = _json_utf8({
        'ok': True,
        'user': {
            'id':           user['id'],
            'login':        user['login'],
            'role':         user['role'],
            'display_name': user.get('display_name') or user['login'],
            'location':     user.get('location'),
        }
    })
    resp.set_cookie(
        _SESSION_COOKIE, token,
        httponly=True, samesite='Lax',
        max_age=_SESSION_MAX_AGE, path='/'
    )
    return resp


@app.route('/api/auth/me', methods=['GET'])
def auth_me():
    """Повертає інфо про поточного юзера з активної сесії."""
    sess = getattr(request, 'session', None)
    if not sess:
        return _json_utf8({'ok': False, 'authenticated': False}, status=401)
    user_id = sess.get('user_id', 0)
    if user_id:
        user = db.get_user_by_id(user_id)
        if user:
            user.pop('password_hash', None)
            return _json_utf8({
                'ok': True, 'authenticated': True,
                'user': {
                    'id':           user['id'],
                    'login':        user['login'],
                    'role':         user['role'],
                    'display_name': user.get('display_name') or user['login'],
                    'location':     user.get('location'),
                    'last_login':   user.get('last_login'),
                    'theme':        user.get('theme') or 'light',
                }
            })
    # Legacy PIN сесія
    return _json_utf8({
        'ok': True, 'authenticated': True,
        'role': sess.get('role', 'manager'),
        'legacy_pin': True,
        'theme': 'light',
    })


@app.route('/api/auth/preferences', methods=['PATCH'])
def auth_preferences():
    """Зберегти налаштування профілю (тема тощо)."""
    sess = getattr(request, 'session', None)
    user_id = (sess or {}).get('user_id', 0)
    if not user_id:
        return _json_utf8({'ok': False, 'error': 'Not authenticated'}, status=401)
    data = request.get_json(silent=True) or {}
    allowed = {}
    if 'theme' in data and data['theme'] in ('light', 'dark'):
        allowed['theme'] = data['theme']
    if not allowed:
        return _json_utf8({'ok': False, 'error': 'Нічого оновлювати'}, status=400)
    result = db.update_user(user_id, allowed, actor_id=user_id)
    return _json_utf8(result)


# ──────────────────────────────────────────────
# Settings  (заміна RkConfig.ini)
# ──────────────────────────────────────────────

@app.route('/api/settings', methods=['GET'])
def get_settings():
    return jsonify(db.get_all_settings())


@app.route('/api/settings', methods=['POST'])
@require_role('owner', 'admin')
def update_settings():
    data = request.get_json(force=True)
    sess = getattr(request, 'session', None) or {}
    db.set_settings_bulk(data, actor_id=sess.get('user_id', 0), actor_role=sess.get('role', 'admin'))
    return jsonify({'ok': True})


@app.route('/api/settings/<section>/<key>', methods=['GET'])
def get_one_setting(section, key):
    all_s = db.get_all_settings()
    value = all_s.get(section, {}).get(key)
    return jsonify({'section': section, 'key': key, 'value': value})


@app.route('/api/settings/<section>/<key>', methods=['POST'])
@require_role('owner', 'admin')
def set_one_setting(section, key):
    data  = request.get_json(force=True)
    db.set_setting(section, key, data.get('value', ''), actor_id=0, actor_role='manager')
    return jsonify({'ok': True})


# ──────────────────────────────────────────────
# Operators  CRUD
# ──────────────────────────────────────────────

@app.route('/api/operators', methods=['GET'])
def list_operators():
    include_inactive = request.args.get('all', '0') == '1'
    return _json_utf8({'ok': True, 'items': db.get_operators(include_inactive)})


@app.route('/api/operators', methods=['POST'])
@require_role('owner', 'admin')
def create_operator():
    data = request.get_json(force=True)
    name = (data.get('name') or '').strip()
    pin  = (data.get('pin')  or '').strip()
    role = data.get('role', 'operator')
    if not name:
        return _json_utf8(_err.err('VALIDATION', {'detail': 'Ім\'я обов\'язкове'})), 400
    if not pin or not pin.isdigit() or len(pin) < 4:
        return _json_utf8(_err.err('VALIDATION', {'detail': 'PIN має бути мінімум 4 цифри'})), 400
    if role not in ('operator', 'manager', 'courier'):
        return _json_utf8(_err.err('VALIDATION', {'detail': f'Невідома роль: {role}'})), 400
    try:
        new_id = db.create_operator(name, pin, role)
        return _json_utf8({'ok': True, 'id': new_id})
    except Exception as e:
        return _json_utf8(_err.err('INTERNAL', {'detail': str(e)})), 500


@app.route('/api/operators/<int:op_id>', methods=['GET'])
def get_operator(op_id):
    op = db.get_operator_by_id(op_id)
    if not op:
        return _json_utf8(_err.err('NOT_FOUND')), 404
    return _json_utf8(op)


@app.route('/api/operators/<int:op_id>', methods=['POST'])
@require_role('owner', 'admin')
def update_operator(op_id):
    data   = request.get_json(force=True)
    fields = {}
    if 'name' in data:
        name = data['name'].strip()
        if not name:
            return _json_utf8(_err.err('VALIDATION', {'detail': 'Ім\'я не може бути порожнім'})), 400
        fields['name'] = name
    if 'pin' in data:
        pin = str(data['pin']).strip()
        if not pin.isdigit() or len(pin) < 4:
            return _json_utf8(_err.err('VALIDATION', {'detail': 'PIN має бути мінімум 4 цифри'})), 400
        fields['pin'] = pin
    if 'role' in data:
        role = data['role']
        if role not in ('operator', 'manager', 'courier'):
            return _json_utf8(_err.err('VALIDATION', {'detail': f'Невідома роль: {role}'})), 400
        fields['role'] = role
    if 'active' in data:
        fields['active'] = 1 if data['active'] else 0
    if not fields:
        return _json_utf8(_err.err('VALIDATION', {'detail': 'Немає полів для оновлення'})), 400
    ok = db.update_operator(op_id, fields)
    if not ok:
        return _json_utf8(_err.err('NOT_FOUND')), 404
    return _json_utf8({'ok': True})


@app.route('/api/operators/<int:op_id>/deactivate', methods=['POST'])
@require_role('owner', 'admin')
def deactivate_operator(op_id):
    ok = db.deactivate_operator(op_id)
    if not ok:
        return _json_utf8(_err.err('NOT_FOUND')), 404
    return _json_utf8({'ok': True})


@app.route('/admin')
def admin_page():
    r = _html_auth_guard(); return r if r else send_from_directory(STATIC_DIR, 'admin.html')


@app.route('/api/telegram/test', methods=['POST'])
@require_role('owner', 'admin')
def telegram_test():
    token, chat_id = _tg_cfg()
    if not token or not chat_id:
        return _json_utf8({'ok': False, 'error': 'Telegram не налаштовано або вимкнено. Збережіть налаштування і увімкніть.'})
    import urllib.request, urllib.parse, urllib.error
    url  = f'https://api.telegram.org/bot{token}/sendMessage'
    data = urllib.parse.urlencode({
        'chat_id': chat_id,
        'text':    '✅ RollHouse PRO — Telegram підключено успішно!\n🍣 Нотифікації працюють.',
    }).encode('utf-8')
    try:
        req = urllib.request.Request(url, data=data, method='POST')
        urllib.request.urlopen(req, timeout=8)
        return _json_utf8({'ok': True})
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='replace')
        return _json_utf8({'ok': False, 'error': f'HTTP {e.code}: {body}'}), 502
    except Exception as e:
        return _json_utf8({'ok': False, 'error': str(e)}), 502


# ──────────────────────────────────────────────
# Customers  (CRM)
# ──────────────────────────────────────────────

@app.route('/api/customer/<phone>', methods=['GET'])
def get_customer(phone):
    # Спочатку точний пошук
    customer = db.get_customer_by_phone(phone)
    if customer:
        return jsonify({**customer, 'exists': True})
    # Якщо точного немає — шукаємо дублікат (інший формат того ж номера)
    dup = db.find_duplicate(phone)
    if dup:
        return jsonify({**dup, 'exists': True, 'fuzzy_match': True})
    return jsonify({'exists': False, 'phone': db._normalize_phone(phone)})


@app.route('/api/customer/check-duplicate', methods=['POST'])
def check_duplicate():
    data  = request.get_json(force=True)
    phone = data.get('phone', '')
    dup   = db.find_duplicate(phone)
    if dup:
        return jsonify({'duplicate': True, **dup})
    return jsonify({'duplicate': False})


@app.route('/api/customer', methods=['POST'])
def upsert_customer():
    data   = request.get_json(force=True)
    result = db.upsert_customer(data)
    return jsonify(result)


@app.route('/api/customers/top', methods=['GET'])
def top_customers():
    limit = request.args.get('limit', 10, type=int)
    return jsonify(db.get_top_customers(limit))


@app.route('/api/customers/search', methods=['GET'])
def customers_search():
    q       = request.args.get('q', '').strip()
    vip     = request.args.get('vip', -1, type=int)
    blocked = request.args.get('blocked', -1, type=int)
    sort    = request.args.get('sort', 'total_orders')
    limit   = min(request.args.get('limit', 50, type=int), 200)
    offset  = request.args.get('offset', 0, type=int)
    result  = db.search_customers(q, vip, blocked, sort, limit, offset)
    return _json_utf8({'ok': True, **result})


@app.route('/customers')
def customers_page():
    r = _html_auth_guard(); return r if r else send_from_directory(STATIC_DIR, 'customers.html')


# ──────────────────────────────────────────────
# Orders
# ──────────────────────────────────────────────

@app.route('/api/order', methods=['POST'])
def log_order():
    try:
        data = request.get_json(force=True)

        # UC-02: базова валідація (без customer — ще не резолвлений)
        v = _bl.validate_order(data)
        if not v['valid'] and not v.get('blocked'):
            return _json_utf8(_err.err('VALIDATION_FAILED', {
                'validation_errors': v['errors'], 'detail': '; '.join(v['errors'])
            }))

        # Резолвимо phone → customer_id
        customer = None
        if 'phone' in data and not data.get('customer_id'):
            phone_raw = data.get('phone', '').strip()
            if not phone_raw:
                return _json_utf8(_err.err('PHONE_EMPTY'))
            customer = db.get_customer_by_phone(phone_raw)
            if not customer:
                res = db.upsert_customer({'phone': phone_raw})
                if res.get('ok'):
                    customer = db.get_customer_by_phone(phone_raw)
                    if not customer:
                        customer = db.find_duplicate(phone_raw)
            if not customer:
                return _json_utf8(_err.err('CUSTOMER_RESOLVE_FAILED', {'phone': phone_raw}))
            data['customer_id'] = customer['id']

        # P2: перевірка blocked — після того як знаємо клієнта
        if customer:
            v2 = _bl.validate_order(data, customer=customer)
            if not v2['valid']:
                if v2.get('blocked'):
                    return _json_utf8(_err.err('CUSTOMER_BLOCKED', {
                        'blocked': True, 'validation_errors': v2['errors']
                    }))
                return _json_utf8(_err.err('VALIDATION_FAILED', {
                    'validation_errors': v2['errors'], 'detail': '; '.join(v2['errors'])
                }))

        # UC-01: перевірка на дублікат (попередження, не блокування)
        duplicate_warning = None
        if data.get('customer_id') or data.get('phone'):
            phone_for_dup = data.get('phone', '')
            recent = db.get_orders_by_phone(phone_for_dup) if phone_for_dup else []
            dup = _bl.duplicate_order_check(recent)
            if dup['duplicate']:
                duplicate_warning = dup['warning']

        order_id = db.log_order(data)

        # UC-05: промо-мілстоун
        promo = None
        if data.get('customer_id'):
            cust = db.get_customer_by_phone(data.get('phone', ''))
            if cust:
                promo_check = _bl.suggest_promo(cust.get('total_orders', 0))
                if promo_check['promo']:
                    promo = promo_check['message']

        # UC-04: день народження
        birthday_msg = None
        if data.get('customer_id'):
            cust = cust if 'cust' in dir() else db.get_customer_by_phone(data.get('phone', ''))
            if cust and _bl.check_birthday_today(cust.get('birthday', '')):
                birthday_msg = _bl.birthday_greeting(cust.get('name', ''))

        resp = {'ok': True, 'id': order_id, 'order_id': order_id}
        if duplicate_warning:
            resp['duplicate_warning'] = duplicate_warning
        if promo:
            resp['promo'] = promo
        if birthday_msg:
            resp['birthday'] = birthday_msg

        # Telegram: нове замовлення
        _tg_send(_tg.msg_new_order(
            order_id  = order_id,
            phone     = data.get('phone', ''),
            name      = (cust.get('name', '') if 'cust' in dir() and cust else ''),
            amount    = data.get('amount', 0),
            city      = data.get('city', ''),
            address   = data.get('address', ''),
            items     = data.get('items', ''),
            comment   = data.get('comment', ''),
        ))

        return _json_utf8(resp)
    except Exception as e:
        import traceback; traceback.print_exc()
        return _json_utf8(_err.err('INTERNAL', {'detail': str(e)}))


@app.route('/api/orders', methods=['GET'])
def get_orders():
    phone = request.args.get('phone', '')
    return jsonify(db.get_orders_by_phone(phone))


@app.route('/api/orders/export', methods=['GET'])
def export_orders():
    """CSV-експорт замовлень з тими ж фільтрами що у дашборду."""
    from flask import Response
    import datetime
    status     = request.args.get('status', '')
    city       = request.args.get('city', '')
    date_from  = request.args.get('date_from', '')
    date_to    = request.args.get('date_to', '')
    search     = request.args.get('search', '')
    courier_id = request.args.get('courier_id', '')
    csv_data   = db.export_orders_csv(status, city, date_from, date_to, search, courier_id)
    filename   = f"orders_{datetime.date.today().isoformat()}.csv"
    return Response(
        '﻿' + csv_data,   # BOM для коректного відкриття в Excel
        mimetype='text/csv; charset=utf-8',
        headers={'Content-Disposition': f'attachment; filename="{filename}"'}
    )


@app.route('/api/customers/stats', methods=['GET'])
def customers_stats():
    return _json_utf8(db.get_customers_stats())


@app.route('/api/customers/merge', methods=['POST'])
def customers_merge():
    data     = request.get_json(force=True) or {}
    keep_id  = int(data.get('keep_id')  or 0)
    drop_id  = int(data.get('drop_id')  or 0)
    actor_id = int(data.get('actor_id') or 0)
    actor_role = data.get('actor_role', 'manager')
    if not keep_id or not drop_id:
        return _json_utf8(_err.err('VALIDATION', {'detail': 'keep_id і drop_id обов\'язкові'})), 400
    if not _err.check_role(actor_role, 'manage_couriers'):  # менеджерська операція
        return _json_utf8(_err.err('ROLE_FORBIDDEN')), 403
    result = db.merge_customers(keep_id, drop_id, actor_id, actor_role)
    status = 200 if result.get('ok') else 400
    return _json_utf8(result), status


@app.route('/api/customers/duplicates', methods=['GET'])
def customers_duplicates():
    limit = min(request.args.get('limit', 50, type=int), 200)
    return _json_utf8({'ok': True, 'items': db.find_duplicate_pairs(limit)})


@app.route('/api/customers/import', methods=['POST'])
def customers_import():
    data     = request.get_json(force=True) or {}
    rows     = data.get('rows') or []
    actor_id = int(data.get('actor_id', 0))
    if not isinstance(rows, list):
        return _json_utf8(_err.err('VALIDATION', {'detail': 'rows має бути масивом'})), 400
    result = db.import_customers_csv(rows, actor_id)
    status = 200 if result.get('ok') else 400
    return _json_utf8(result), status


@app.route('/api/order/<int:order_id>', methods=['PUT'])
def edit_order(order_id):
    """Редагує поля замовлення. Записує в action_logs."""
    try:
        data       = request.get_json(force=True) or {}
        actor_id   = int(data.pop('actor_id', 0))
        actor_role = data.pop('actor_role', 'manager')
        result = db.update_order(order_id, data, actor_id, actor_role)
        return _json_utf8(result)
    except Exception as e:
        import traceback; traceback.print_exc()
        return _json_utf8(_err.err('INTERNAL', {'detail': str(e)}))


@app.route('/api/order/<int:order_id>', methods=['GET'])
def get_order(order_id):
    order = db.get_order_by_id(order_id)
    if not order:
        return _json_utf8(_err.err('ORDER_NOT_FOUND'), status=404)
    # Додаємо список дозволених переходів
    order['allowed_transitions'] = _bl.allowed_transitions(order.get('status') or 'new')
    order['status_label'] = _bl.STATUS_LABELS.get(order.get('status') or 'new', '')
    return _json_utf8({'ok': True, 'order': order})


@app.route('/api/order/<int:order_id>/status', methods=['POST'])
def update_order_status(order_id):
    """UC-03: змінює статус замовлення через state machine."""
    try:
        data = request.get_json(force=True) or {}
        new_status = (data.get('status') or '').strip()
        actor_id   = int(data.get('actor_id', 0))
        actor_role = data.get('actor_role', 'operator')

        if not new_status:
            return _json_utf8(_err.err('STATUS_REQUIRED'))

        order = db.get_order_by_id(order_id)
        if not order:
            return _json_utf8(_err.err('ORDER_NOT_FOUND'), status=404)
        if order.get('deleted'):
            return _json_utf8(_err.err('ORDER_DELETED'))

        current_status = order.get('status') or 'new'
        check = _bl.transition_status(current_status, new_status)
        if not check['ok']:
            return _json_utf8(_err.err('STATUS_CONFLICT', {'detail': check['error']}), status=409)

        # BR-1/BR-2: перевірка прав актора на цей конкретний перехід
        actor_check = _bl.check_transition_actor(order, new_status, actor_role, actor_id)
        if not actor_check['ok']:
            return _json_utf8(_err.err(actor_check.get('error_code', 'ROLE_FORBIDDEN'),
                                       {'detail': actor_check['error']}), status=403)

        # BR-6: якщо переходимо в confirmed — перевірити що клієнт не заблокований
        if new_status == 'confirmed' and order.get('customer_id'):
            customer = db.get_customer_by_id(order['customer_id'])
            if customer:
                block_check = _bl.check_confirmed_not_blocked(customer)
                if not block_check['ok']:
                    return _json_utf8(_err.err('CUSTOMER_BLOCKED',
                                               {'detail': block_check['error']}), status=403)

        result = db.update_order_status(order_id, new_status, actor_id, actor_role, before=order)
        if result.get('ok'):
            # P5: повертаємо allowed_transitions для нового статусу
            result['allowed_transitions'] = _bl.allowed_transitions(new_status)
            result['status_label']        = _bl.STATUS_LABELS.get(new_status, new_status)

            # Telegram: зміна статусу (тільки значущі переходи)
            if new_status in ('confirmed', 'on_way', 'delivered', 'cancelled'):
                courier_name = ''
                if new_status == 'on_way' and order.get('courier_id'):
                    cr = db.get_courier_by_id(order['courier_id'])
                    courier_name = cr.get('name', '') if cr else ''
                cust_phone = order.get('phone') or order.get('order_phone') or ''
                cust_name  = ''
                if order.get('customer_id'):
                    c = db.get_customer_by_id(order['customer_id'])
                    cust_name = c.get('name', '') if c else ''
                _tg_send(_tg.msg_status_change(
                    order_id     = order_id,
                    phone        = cust_phone,
                    name         = cust_name,
                    old_status   = current_status,
                    new_status   = new_status,
                    courier_name = courier_name,
                ))

        return _json_utf8(result)
    except Exception as e:
        import traceback; traceback.print_exc()
        return _json_utf8(_err.err('INTERNAL', {'detail': str(e)}))


@app.route('/api/order/<int:order_id>', methods=['DELETE'])
@require_role('owner', 'admin', 'director', 'senior_operator')
def delete_order(order_id):
    try:
        data       = request.get_json(force=True) or {}
        sess       = getattr(request, 'session', None) or {}
        actor_role = sess.get('role', 'admin')
        actor_id   = sess.get('user_id', 0)
        reason = (data.get('reason') or '').strip()
        if not reason:
            return _json_utf8(_err.err('DELETE_REASON_EMPTY'))
        # BR-4: видалення тільки для new/cancelled
        order = db.get_order_by_id(order_id)
        if not order:
            return _json_utf8(_err.err('ORDER_NOT_FOUND'), status=404)
        if order.get('deleted'):
            return _json_utf8(_err.err('ORDER_ALREADY_DELETED'))
        del_check = _bl.check_delete_allowed(order)
        if not del_check['ok']:
            return _json_utf8(_err.err('STATUS_CONFLICT', {'detail': del_check['error']}), status=409)
        result   = db.soft_delete_order(order_id, actor_id, actor_role, reason)
        return _json_utf8(result)
    except Exception as e:
        import traceback; traceback.print_exc()
        return _json_utf8(_err.err('INTERNAL', {'detail': str(e)}))


# ──────────────────────────────────────────────
# Call log
# ──────────────────────────────────────────────

@app.route('/api/call', methods=['POST'])
def log_call():
    data = request.get_json(force=True)
    db.log_call(data)
    return jsonify({'ok': True})


# ──────────────────────────────────────────────
# Analytics
# ──────────────────────────────────────────────

@app.route('/analytics')
def analytics_page():
    r = _html_auth_guard(); return r if r else send_from_directory(STATIC_DIR, 'analytics.html')


def _period_dates(period: str, date_from: str, date_to: str):
    """Обчислює date_from / date_to за period або кастомний діапазон."""
    from datetime import date, timedelta
    today = date.today()
    if period == 'today':
        return str(today), str(today)
    if period == 'week':
        return str(today - timedelta(days=6)), str(today)
    if period == 'month':
        return str(today.replace(day=1)), str(today)
    if period == 'year':
        return str(today.replace(month=1, day=1)), str(today)
    # custom або fallback
    return (date_from or str(today - timedelta(days=29))), (date_to or str(today))


@app.route('/api/analytics/summary', methods=['GET'])
@require_role('owner', 'admin', 'director', 'investor')
def analytics_summary():
    period    = request.args.get('period', 'today')
    date_from = request.args.get('date_from', '')
    date_to   = request.args.get('date_to', '')
    df, dt    = _period_dates(period, date_from, date_to)
    data = db.get_analytics_period(df, dt)
    data['date_from'] = df
    data['date_to']   = dt
    return _json_utf8({'ok': True, **data})


@app.route('/api/analytics/daily', methods=['GET'])
@require_role('owner', 'admin', 'director', 'investor')
def analytics_daily():
    period    = request.args.get('period', 'month')
    date_from = request.args.get('date_from', '')
    date_to   = request.args.get('date_to', '')
    df, dt    = _period_dates(period, date_from, date_to)
    return _json_utf8({'ok': True, 'items': db.get_daily_revenue(df, dt),
                       'date_from': df, 'date_to': dt})


@app.route('/api/analytics/top-customers', methods=['GET'])
@require_role('owner', 'admin', 'director', 'investor')
def analytics_top_customers():
    limit = int(request.args.get('limit', 10))
    return _json_utf8({'ok': True, 'items': db.get_top_customers(limit)})


@app.route('/api/analytics/top-items', methods=['GET'])
@require_role('owner', 'admin', 'director', 'investor')
def analytics_top_items():
    period    = request.args.get('period', 'month')
    date_from = request.args.get('date_from', '')
    date_to   = request.args.get('date_to', '')
    df, dt    = _period_dates(period, date_from, date_to)
    return _json_utf8({'ok': True, 'items': db.get_top_items(df, dt)})


@app.route('/api/analytics/operators', methods=['GET'])
@require_role('owner', 'admin', 'director', 'investor')
def analytics_operators():
    period    = request.args.get('period', 'month')
    date_from = request.args.get('date_from', '')
    date_to   = request.args.get('date_to', '')
    df, dt    = _period_dates(period, date_from, date_to)
    return _json_utf8({'ok': True, 'items': db.get_operators_stats(df, dt)})


@app.route('/api/analytics/reengagement', methods=['GET'])
@require_role('owner', 'admin', 'director', 'investor')
def analytics_reengagement():
    days  = int(request.args.get('days', 30))
    limit = int(request.args.get('limit', 20))
    return _json_utf8({'ok': True, 'items': db.get_reengagement_customers(days, limit)})


@app.route('/api/analytics/vip-candidates', methods=['GET'])
@require_role('owner', 'admin', 'director', 'investor')
def analytics_vip_candidates():
    min_orders = int(request.args.get('min_orders', 5))
    return _json_utf8({'ok': True, 'items': db.get_vip_candidates(min_orders)})


# ──────────────────────────────────────────────
# Phase 5 — Reminders
# ──────────────────────────────────────────────

@app.route('/api/reminders/birthdays', methods=['GET'])
def reminders_birthdays():
    days = int(request.args.get('days', 3))
    return _json_utf8({'ok': True, 'items': db.get_birthday_reminders(days)})


@app.route('/api/reminders', methods=['GET'])
def get_reminders():
    done = request.args.get('done', '0') == '1'
    return _json_utf8({'ok': True, 'items': db.get_reminders(done=done)})


@app.route('/api/reminders', methods=['POST'])
def create_reminder():
    data     = request.get_json(force=True) or {}
    actor_id = int(data.get('actor_id', 0))
    return _json_utf8(db.create_reminder(data, actor_id))


@app.route('/api/reminders/<int:reminder_id>/done', methods=['POST'])
def complete_reminder(reminder_id):
    data     = request.get_json(force=True) or {}
    actor_id = int(data.get('actor_id', 0))
    return _json_utf8(db.complete_reminder(reminder_id, actor_id))


@app.route('/api/reminders/due-count', methods=['GET'])
def reminders_due_count():
    """Кількість нагадувань, які вже настали і ще не виконані."""
    items = db.get_due_reminders()
    return _json_utf8({'ok': True, 'count': len(items), 'items': items})


# ──────────────────────────────────────────────
# Admin
# ──────────────────────────────────────────────

@app.route('/logs')
def logs_page():
    r = _html_auth_guard(); return r if r else send_from_directory(STATIC_DIR, 'logs.html')


@app.route('/api/admin/logs', methods=['GET'])
@require_role('owner', 'admin', 'director')
def admin_logs():
    a = request.args
    data = db.get_action_logs(
        entity_type = a.get('entity_type', ''),
        action      = a.get('action', ''),
        actor_id    = int(a.get('actor_id', 0)),
        date_from   = a.get('date_from', ''),
        date_to     = a.get('date_to', ''),
        limit       = int(a.get('limit', 100)),
        offset      = int(a.get('offset', 0)),
    )
    return _json_utf8({'ok': True, **data})


# ──────────────────────────────────────────────
# AI-парсинг коментаря замовлення
# ──────────────────────────────────────────────

@app.route('/api/parse', methods=['POST'])
def parse_comment():
    data    = request.get_json(force=True)
    comment = data.get('comment', '')
    result  = _parse_order_comment(comment)
    return jsonify(result)


def _parse_order_comment(text: str) -> dict:
    """
    Базовий парсинг.  Пізніше замінимо Claude API.
    """
    result = {}
    t = text.lower()

    # Час  (13:25 або 13.25)
    m = re.search(r'\b(\d{1,2})[:\.](\d{2})\b', text)
    if m:
        result['time'] = f"{m.group(1).zfill(2)}:{m.group(2)}"

    # Готівка — сума
    m = re.search(r'(\d+)\s*грн', t)
    if m:
        result['cash'] = int(m.group(1))

    # Подарунки
    if re.search(r'бруклін|brooklyn|бруклин', t):
        result['gift_brooklyn'] = True
    if re.search(r'пепсі|pepsi|pepsy', t):
        result['gift_pepsi'] = True
    if re.search(r'бургер|burger', t):
        result['gift_burger'] = True

    # VIP / проблема
    if re.search(r'\bvip\b|\bвіп\b', t):
        result['vip'] = True
    if re.search(r'проблем|скарг|complaint', t):
        result['problem'] = True

    return result


# ──────────────────────────────────────────────
# Debug (тимчасово)
# ──────────────────────────────────────────────

@app.route('/api/debug')
def debug_db():
    try:
        conn = db.get_conn()
        cols = [row[1] for row in conn.execute('PRAGMA table_info(orders)').fetchall()]
        orders = [dict(r) for r in conn.execute('SELECT * FROM orders ORDER BY id DESC LIMIT 10').fetchall()]
        custs  = [dict(r) for r in conn.execute('SELECT id,phone,total_orders,total_spent FROM customers ORDER BY id DESC LIMIT 10').fetchall()]
        conn.close()
        return _json_utf8({'columns': cols, 'orders': orders, 'customers': custs})
    except Exception as e:
        return _json_utf8({'error': str(e)})


# ──────────────────────────────────────────────
# Order Tags
# ──────────────────────────────────────────────

@app.route('/api/order/<int:order_id>/tags', methods=['POST'])
def set_order_tags(order_id):
    data       = request.get_json(force=True) or {}
    raw_tags   = data.get('tags') or ''
    # Accept either comma-string "urgent,vip" or list ["urgent","vip"]
    if isinstance(raw_tags, list):
        tags = raw_tags
    else:
        tags = [t.strip() for t in str(raw_tags).split(',') if t.strip()]
    actor_id   = int(data.get('actor_id', 0))
    actor_role = data.get('actor_role', 'operator')
    return _json_utf8(db.set_order_tags(order_id, tags, actor_id, actor_role))


# ──────────────────────────────────────────────
# Bulk Actions
# ──────────────────────────────────────────────

@app.route('/api/orders/bulk/assign-courier', methods=['POST'])
def bulk_assign_courier():
    data       = request.get_json(force=True) or {}
    order_ids  = [int(x) for x in (data.get('order_ids') or [])]
    courier_id = data.get('courier_id')  # None = unassign
    actor_id   = int(data.get('actor_id', 0))
    actor_role = data.get('actor_role', 'manager')
    if not order_ids:
        return _json_utf8({'ok': False, 'error': 'Немає замовлень'}, status=400)
    return _json_utf8(db.bulk_assign_courier(order_ids, courier_id, actor_id, actor_role))


@app.route('/api/orders/bulk/status', methods=['POST'])
def bulk_update_status():
    data       = request.get_json(force=True) or {}
    order_ids  = [int(x) for x in (data.get('order_ids') or [])]
    new_status = (data.get('status') or '').strip()
    actor_id   = int(data.get('actor_id', 0))
    actor_role = data.get('actor_role', 'manager')
    if not order_ids or not new_status:
        return _json_utf8({'ok': False, 'error': 'Немає замовлень або статусу'}, status=400)
    return _json_utf8(db.bulk_update_status(order_ids, new_status, actor_id, actor_role))


# ──────────────────────────────────────────────
# Order Timeline
# ──────────────────────────────────────────────

@app.route('/api/order/<int:order_id>/timeline', methods=['GET'])
def order_timeline(order_id):
    rows = db.get_order_timeline(order_id)
    return _json_utf8({'ok': True, 'items': rows})


# ──────────────────────────────────────────────
# Global Search
# ──────────────────────────────────────────────

@app.route('/api/search', methods=['GET'])
def global_search():
    q     = (request.args.get('q') or '').strip()
    limit = min(int(request.args.get('limit', 5)), 20)
    if not q:
        return _json_utf8({'orders': [], 'customers': [], 'couriers': []})
    return _json_utf8(db.global_search(q, limit))


# ──────────────────────────────────────────────
# Print Receipt
# ──────────────────────────────────────────────

@app.route('/receipt')
def receipt_page():
    return send_from_directory(STATIC_DIR, 'receipt.html')


# ──────────────────────────────────────────────
# Shift Report
# ──────────────────────────────────────────────

@app.route('/report')
def report_page():
    return send_from_directory(STATIC_DIR, 'report.html')


@app.route('/api/report/shift', methods=['GET'])
def shift_report():
    a          = request.args
    date_from  = a.get('date_from', '')
    date_to    = a.get('date_to',   '')
    time_from  = a.get('time_from', '')
    time_to    = a.get('time_to',   '')
    if not date_from or not date_to:
        return _json_utf8({'ok': False, 'error': 'date_from і date_to обов\'язкові'}, status=400)
    data = db.get_shift_report(date_from, date_to, time_from, time_to)
    return _json_utf8({'ok': True, **data})


@app.route('/api/report/shift/telegram', methods=['POST'])
def shift_report_telegram():
    """Надсилає короткий підсумок звіту в Telegram."""
    body = request.get_json(force=True) or {}
    # body: { date_from, date_to, time_from?, time_to? }
    date_from = body.get('date_from', '')
    date_to   = body.get('date_to', '')
    if not date_from or not date_to:
        return _json_utf8({'ok': False, 'error': 'date_from і date_to обов\'язкові'}, status=400)
    data = db.get_shift_report(date_from, date_to,
                               body.get('time_from', ''), body.get('time_to', ''))
    # Build text
    STATUS_UK = {'new': 'Новий', 'confirmed': 'Підтверджено', 'cooking': 'Готується',
                 'on_way': 'В дорозі', 'delivered': 'Доставлено', 'cancelled': 'Скасовано'}
    lines = [
        f'📊 <b>Звіт за зміну</b>',
        f'📅 {date_from}' + (f' → {date_to}' if date_to != date_from else ''),
        '',
        f'📦 Замовлень: <b>{data["total_orders"]}</b>',
        f'💰 Виручка: <b>{data["total_revenue"]:,.0f} грн</b>',
        f'🧾 Середній чек: <b>{data["avg_order"]:,.0f} грн</b>',
        f'👤 Нові клієнти: <b>{data["new_customers"]}</b>',
    ]
    del_info = data['by_status'].get('delivered', {})
    canc_info = data['by_status'].get('cancelled', {})
    if del_info:
        lines.append(f'✅ Доставлено: <b>{del_info["cnt"]}</b> на {del_info["rev"]:,.0f} грн')
    if canc_info:
        lines.append(f'❌ Скасовано: <b>{canc_info["cnt"]}</b>')
    if data['top_items']:
        lines.append('')
        lines.append('🛒 <b>Топ позиції:</b>')
        for item in data['top_items'][:5]:
            lines.append(f'  • {_tg._esc(item["name"])} — {item["qty"]} шт')
    if data['by_courier']:
        lines.append('')
        lines.append('🛵 <b>Кур\'єри:</b>')
        for c in data['by_courier']:
            lines.append(f'  • {_tg._esc(c["name"])} — {c["cnt"]} дост, {c["rev"]:,.0f} грн')
    text = '\n'.join(lines)
    token, chat_id = _tg_cfg()
    if not token or not chat_id:
        return _json_utf8({'ok': False, 'error': 'Telegram не налаштовано'})
    # Sync send для feedback
    import urllib.request, urllib.parse
    url  = f'https://api.telegram.org/bot{token}/sendMessage'
    data_enc = urllib.parse.urlencode({'chat_id': chat_id, 'text': text, 'parse_mode': 'HTML'}).encode()
    try:
        urllib.request.urlopen(urllib.request.Request(url, data_enc, method='POST'), timeout=8)
        return _json_utf8({'ok': True})
    except Exception as e:
        return _json_utf8({'ok': False, 'error': str(e)})


# ──────────────────────────────────────────────
# Courier Salary
# ──────────────────────────────────────────────

@app.route('/salary')
def salary_page():
    return send_from_directory(STATIC_DIR, 'salary.html')


@app.route('/mobile')
def mobile_page():
    return send_from_directory(STATIC_DIR, 'mobile.html')


@app.route('/api/salary/summary', methods=['GET'])
@require_role('owner', 'admin', 'director', 'logistics')
def salary_summary():
    from datetime import date, timedelta
    today = date.today()
    date_from = request.args.get('date_from') or str(today.replace(day=1))
    date_to   = request.args.get('date_to')   or str(today)
    items = db.get_salary_summary(date_from, date_to)
    return _json_utf8({'ok': True, 'date_from': date_from, 'date_to': date_to, 'items': items})


@app.route('/api/salary/courier/<int:courier_id>', methods=['GET'])
@require_role('owner', 'admin', 'director', 'logistics')
def salary_courier(courier_id):
    from datetime import date
    today = date.today()
    date_from = request.args.get('date_from') or str(today.replace(day=1))
    date_to   = request.args.get('date_to')   or str(today)
    data = db.get_courier_salary(courier_id, date_from, date_to)
    data['ok'] = True
    return _json_utf8(data)


@app.route('/api/salary/courier/<int:courier_id>/rate', methods=['POST'])
@require_role('owner', 'admin', 'director', 'logistics')
def set_courier_rate(courier_id):
    body = request.get_json(force=True) or {}
    rate = float(body.get('rate', 0))
    actor_id   = int(body.get('actor_id', 0))
    actor_role = body.get('actor_role', 'manager')
    return _json_utf8(db.set_courier_rate(courier_id, rate, actor_id, actor_role))


@app.route('/api/salary/courier/<int:courier_id>/payout', methods=['POST'])
@require_role('owner', 'admin', 'director', 'logistics')
def courier_payout(courier_id):
    body       = request.get_json(force=True) or {}
    amount     = float(body.get('amount', 0))
    date_from  = body.get('date_from', '')
    date_to    = body.get('date_to', '')
    deliveries = int(body.get('deliveries', 0))
    note       = (body.get('note') or '').strip()
    actor_id   = int(body.get('actor_id', 0))
    actor_role = body.get('actor_role', 'manager')
    if amount <= 0:
        return _json_utf8({'ok': False, 'error': 'Сума має бути > 0'}, status=400)
    return _json_utf8(db.record_payout(courier_id, amount, date_from, date_to,
                                       deliveries, note, actor_id, actor_role))


@app.route('/api/salary/courier/<int:courier_id>/history', methods=['GET'])
@require_role('owner', 'admin', 'director', 'logistics')
def payout_history(courier_id):
    rows = db.get_payout_history(courier_id)
    return _json_utf8({'ok': True, 'items': rows})


# ──────────────────────────────────────────────
# Telegram Bot Webhook
# ──────────────────────────────────────────────
# Команди для оператора через Telegram:
#   /orders          — список активних замовлень
#   /confirm N       — підтвердити замовлення N
#   /cancel N        — скасувати замовлення N
#   /courier N C     — призначити кур'єра C (ім'я або id) на замовлення N
#   /done N          — позначити замовлення N як доставлено

_TG_BOT_HELP = (
    '🍣 <b>RollHouse PRO Bot</b>\n\n'
    '/orders — активні замовлення\n'
    '/confirm N — підтвердити #N\n'
    '/cancel N — скасувати #N\n'
    '/courier N Ім\'я — кур\'єр на #N\n'
    '/done N — доставлено #N\n'
    '/help — це повідомлення'
)


def _tg_reply(token: str, chat_id: str, text: str):
    """Синхронна відповідь боту (потрібна для Webhook)."""
    import urllib.request, urllib.parse
    url  = f'https://api.telegram.org/bot{token}/sendMessage'
    data = urllib.parse.urlencode({
        'chat_id': chat_id, 'text': text, 'parse_mode': 'HTML'
    }).encode()
    try:
        urllib.request.urlopen(
            urllib.request.Request(url, data, method='POST'), timeout=6
        )
    except Exception as e:
        print(f'[TGBot] reply error: {e}')


def _tg_handle_command(token: str, chat_id: str, text: str):
    """Парсить команду та виконує дію."""
    parts = text.strip().split()
    cmd   = parts[0].lower().split('@')[0] if parts else ''
    args  = parts[1:]

    STATUS_UK = {
        'new': 'Новий', 'confirmed': 'Підтверджено', 'cooking': 'Готується',
        'on_way': 'В дорозі', 'delivered': 'Доставлено', 'cancelled': 'Скасовано',
    }

    if cmd in ('/start', '/help'):
        _tg_reply(token, chat_id, _TG_BOT_HELP)
        return

    if cmd == '/orders':
        orders = db.get_orders_filtered(status='', limit=15)
        active = [o for o in orders if o.get('status') not in ('delivered', 'cancelled')]
        if not active:
            _tg_reply(token, chat_id, '✅ Немає активних замовлень')
            return
        lines = ['📋 <b>Активні замовлення:</b>']
        for o in active[:10]:
            st  = STATUS_UK.get(o.get('status',''), o.get('status',''))
            num = '#' + str(o['id'])
            phone = o.get('cust_phone') or o.get('order_phone') or ''
            courier = '🛵 ' + _tg._esc(o['courier_name']) if o.get('courier_name') else '—'
            lines.append(f'{num} {st} | {_tg._esc(phone)} | {courier}')
        _tg_reply(token, chat_id, '\n'.join(lines))
        return

    if cmd in ('/confirm', '/cancel', '/done'):
        if not args or not args[0].isdigit():
            _tg_reply(token, chat_id, '❌ Вкажіть номер замовлення. Приклад: /confirm 42')
            return
        order_id = int(args[0])
        new_status = {'confirm': 'confirmed', '/confirm': 'confirmed',
                      '/cancel': 'cancelled', '/done': 'delivered'}[cmd]
        order = db.get_order_by_id(order_id)
        if not order:
            _tg_reply(token, chat_id, f'❌ Замовлення #{order_id} не знайдено')
            return
        import business_logic as _bl
        allowed = _bl.allowed_transitions(order.get('status', 'new'))
        if new_status not in allowed:
            cur_lbl = STATUS_UK.get(order.get('status',''), order.get('status',''))
            _tg_reply(token, chat_id, f'🚫 Неможливо перевести #{order_id} зі статусу «{cur_lbl}»')
            return
        res = db.update_order_status(order_id, new_status, actor_id=0, actor_role='tg_operator', before=order)
        if res.get('ok'):
            new_lbl = STATUS_UK.get(new_status, new_status)
            _tg_reply(token, chat_id, f'✅ Замовлення #{order_id} → <b>{new_lbl}</b>')
        else:
            _tg_reply(token, chat_id, '❌ Помилка: ' + str(res.get('error','')))
        return

    if cmd == '/courier':
        # /courier 42 Андрій   або   /courier 42 3
        if len(args) < 2:
            _tg_reply(token, chat_id, '❌ Формат: /courier [номер] [ім\'я або id кур\'єра]')
            return
        order_id    = int(args[0]) if args[0].isdigit() else None
        courier_arg = ' '.join(args[1:]).strip()
        if not order_id:
            _tg_reply(token, chat_id, '❌ Вкажіть номер замовлення першим аргументом')
            return
        order = db.get_order_by_id(order_id)
        if not order:
            _tg_reply(token, chat_id, f'❌ Замовлення #{order_id} не знайдено')
            return
        # Знайти кур'єра по id або імені
        couriers = db.get_couriers(active_only=True)
        courier = None
        if courier_arg.isdigit():
            courier = next((c for c in couriers if c['id'] == int(courier_arg)), None)
        else:
            low = courier_arg.lower()
            courier = next((c for c in couriers if low in c['name'].lower()), None)
        if not courier:
            names = ', '.join(c['name'] for c in couriers)
            _tg_reply(token, chat_id, f'❌ Кур\'єра «{_tg._esc(courier_arg)}» не знайдено.\nДоступні: {_tg._esc(names)}')
            return
        res = db.assign_courier(order_id, courier['id'], actor_id=0, actor_role='tg_operator')
        if res.get('ok'):
            _tg_reply(token, chat_id, f'✅ Кур\'єр <b>{_tg._esc(courier["name"])}</b> призначений на #{order_id}')
        else:
            _tg_reply(token, chat_id, '❌ Помилка: ' + str(res.get('error','')))
        return

    # Unknown command
    _tg_reply(token, chat_id, f'❓ Невідома команда <code>{_tg._esc(cmd)}</code>\n/help — список команд')


@app.route('/api/telegram/webhook', methods=['POST'])
def telegram_webhook():
    """
    Telegram Webhook endpoint.
    Налаштуй: POST https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://YOUR_HOST/api/telegram/webhook
    Локально: використовуй ngrok або cloudflared для тунелю.
    """
    try:
        update = request.get_json(force=True) or {}
        msg    = update.get('message') or update.get('edited_message')
        if not msg:
            return jsonify({'ok': True})

        text    = (msg.get('text') or '').strip()
        chat_id = str(msg.get('chat', {}).get('id', ''))
        if not text or not chat_id or not text.startswith('/'):
            return jsonify({'ok': True})

        # Auth: перевіряємо що chat_id відповідає налаштованому
        _, cfg_chat = _tg_cfg()
        if cfg_chat and chat_id != str(cfg_chat):
            print(f'[TGBot] Заборонений chat_id: {chat_id} (очікується {cfg_chat})')
            return jsonify({'ok': True})

        token, _ = _tg_cfg()
        if not token:
            return jsonify({'ok': True})

        # Handle in background thread to return 200 fast
        t = threading.Thread(
            target=_tg_handle_command,
            args=(token, chat_id, text),
            daemon=True
        )
        t.start()

    except Exception as e:
        print(f'[TGBot] Webhook error: {e}')

    return jsonify({'ok': True})


@app.route('/api/telegram/set-webhook', methods=['POST'])
@require_role('owner', 'admin')
def set_telegram_webhook():
    """
    Зручний endpoint для реєстрації webhook.
    POST /api/telegram/set-webhook  { "url": "https://your.domain/api/telegram/webhook" }
    """
    body  = request.get_json(force=True) or {}
    wh_url = body.get('url', '').strip()
    if not wh_url:
        return _json_utf8({'ok': False, 'error': 'url обов\'язковий'}, status=400)
    token, _ = _tg_cfg()
    if not token:
        return _json_utf8({'ok': False, 'error': 'Telegram не налаштовано'})
    import urllib.request, urllib.parse
    api_url = f'https://api.telegram.org/bot{token}/setWebhook'
    data = urllib.parse.urlencode({'url': wh_url}).encode()
    try:
        r = urllib.request.urlopen(
            urllib.request.Request(api_url, data, method='POST'), timeout=8
        )
        result = json.loads(r.read().decode())
        return _json_utf8({'ok': True, 'tg': result})
    except Exception as e:
        return _json_utf8({'ok': False, 'error': str(e)})


# ──────────────────────────────────────────────
# Reminder scheduler (Telegram)
# ──────────────────────────────────────────────

def _reminder_scheduler():
    """
    Фоновий потік — перевіряє нагадування кожні 60 секунд.
    Якщо час настав і TG увімкнений — надсилає повідомлення та ставить tg_sent=1.
    """
    print('[Scheduler] Запущено (перевірка кожні 60 сек)')
    while True:
        try:
            due = db.get_due_reminders()
            if due:
                token, chat_id = _tg_cfg()
                if token and chat_id:
                    for r in due:
                        text = _tg.msg_reminder(
                            r['text'],
                            phone=r.get('phone') or '',
                            name=r.get('customer_name') or '',
                        )
                        # Додаємо дату/час нагадування якщо є
                        parts = []
                        if r.get('due_date'):
                            parts.append(r['due_date'])
                        if r.get('due_time'):
                            parts.append(r['due_time'])
                        if parts:
                            text += f"\n🕐 {' '.join(parts)}"
                        _tg.send(token, chat_id, text)
                        db.mark_reminder_tg_sent(r['id'])
                        print(f"[Scheduler] TG нагадування #{r['id']} надіслано")
                else:
                    # TG не налаштований — все одно позначаємо як sent щоб не накопичувались
                    for r in due:
                        db.mark_reminder_tg_sent(r['id'])
        except Exception as e:
            print(f'[Scheduler] Помилка: {e}')
        time.sleep(60)


# ──────────────────────────────────────────────
# Auto Backup
# ──────────────────────────────────────────────

import shutil, glob

BACKUP_DIR     = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data', 'backups')
BACKUP_KEEP    = 14      # кількість бекапів що зберігаємо
BACKUP_INTERVAL = 6 * 3600  # кожні 6 годин


def _do_backup() -> dict:
    """Копіює DB у backups/ з міткою часу. Повертає {ok, filename, size}."""
    try:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        ts       = time.strftime('%Y%m%d_%H%M%S')
        src      = db.DB_PATH
        dst_name = f'rollhouse_{ts}.db'
        dst      = os.path.join(BACKUP_DIR, dst_name)
        # Використовуємо SQLite backup API через python для цілісності
        import sqlite3
        src_conn = sqlite3.connect(src, timeout=5)
        dst_conn = sqlite3.connect(dst)
        src_conn.backup(dst_conn)
        src_conn.close()
        dst_conn.close()
        size = os.path.getsize(dst)
        # Ротація — видаляємо старі
        backups = sorted(glob.glob(os.path.join(BACKUP_DIR, 'rollhouse_*.db')))
        for old in backups[:-BACKUP_KEEP]:
            try: os.remove(old)
            except: pass
        print(f'[Backup] Збережено: {dst_name} ({size//1024} KB)')
        return {'ok': True, 'filename': dst_name, 'size': size}
    except Exception as e:
        print(f'[Backup] Помилка: {e}')
        return {'ok': False, 'error': str(e)}


def _backup_scheduler():
    """Daemon thread — бекап кожні BACKUP_INTERVAL секунд."""
    # Перший бекап через 30 секунд після старту
    time.sleep(30)
    while True:
        _do_backup()
        time.sleep(BACKUP_INTERVAL)


def _list_backups() -> list:
    """Список бекапів, найновіші першими."""
    os.makedirs(BACKUP_DIR, exist_ok=True)
    files = sorted(glob.glob(os.path.join(BACKUP_DIR, 'rollhouse_*.db')), reverse=True)
    result = []
    for f in files:
        name = os.path.basename(f)
        try:
            stat = os.stat(f)
            result.append({
                'filename':   name,
                'size':       stat.st_size,
                'size_kb':    round(stat.st_size / 1024, 1),
                'created_at': time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(stat.st_mtime)),
            })
        except Exception:
            pass
    return result


@app.route('/api/backup/list', methods=['GET'])
@require_role('owner', 'admin')
def backup_list():
    return _json_utf8({'ok': True, 'items': _list_backups()})


@app.route('/api/backup/now', methods=['POST'])
@require_role('owner', 'admin')
def backup_now():
    result = _do_backup()
    return _json_utf8(result)


@app.route('/api/backup/download/<filename>', methods=['GET'])
@require_role('owner', 'admin')
def backup_download(filename):
    # Sanitize — тільки файли з backups/, тільки .db
    if not filename.startswith('rollhouse_') or not filename.endswith('.db') or '/' in filename or '..' in filename:
        return _json_utf8({'ok': False, 'error': 'Недозволений файл'}, status=400)
    path = os.path.join(BACKUP_DIR, filename)
    if not os.path.exists(path):
        return _json_utf8({'ok': False, 'error': 'Файл не знайдено'}, status=404)
    return send_from_directory(
        os.path.abspath(BACKUP_DIR), filename,
        as_attachment=True,
        download_name=filename,
    )


# ──────────────────────────────────────────────
# Старт
# ──────────────────────────────────────────────

if __name__ == '__main__':
    db.init_db()
    db.ensure_first_owner()    # створює owner/admin якщо users таблиця порожня
    # Планувальник нагадувань
    t = threading.Thread(target=_reminder_scheduler, daemon=True, name='reminder-scheduler')
    t.start()
    # Авто-бекап
    tb = threading.Thread(target=_backup_scheduler, daemon=True, name='backup-scheduler')
    tb.start()
    print("=" * 50)
    print("  RollHouse PRO Server v1.0")
    print("  http://localhost:5000")
    print("=" * 50)
    app.run(host='127.0.0.1', port=5000, debug=False, use_reloader=False, threaded=True)

@app.route('/api/iiko/set_fields', methods=['POST'])
def iiko_set_fields():
    data = request.json
    if not data:
        return jsonify({'ok': False, 'error': 'no_json'})
    import iiko_bridge
    res = iiko_bridge.set_fields(data)
    return jsonify(res)
