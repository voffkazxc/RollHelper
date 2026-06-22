import sqlite3
import os
import json
import hmac as _hmac
import hashlib
import secrets
from datetime import datetime, timedelta

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data', 'rollhouse.db')


def get_conn():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=10, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def init_db():
    conn = get_conn()
    conn.executescript('''
        CREATE TABLE IF NOT EXISTS iiko_sync_log (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            phone       TEXT,
            ok          INTEGER DEFAULT 0,
            error       TEXT,
            duration_ms INTEGER,
            raw_fields  TEXT,
            read_at     DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS action_logs (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            actor_id    INTEGER DEFAULT 0,
            actor_role  TEXT    DEFAULT 'system',
            entity_type TEXT,
            entity_id   INTEGER,
            action      TEXT,
            before      TEXT,
            after       TEXT,
            created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS settings (
            section TEXT NOT NULL,
            key     TEXT NOT NULL,
            value   TEXT,
            PRIMARY KEY (section, key)
        );

        CREATE TABLE IF NOT EXISTS operators (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT NOT NULL,
            pin        TEXT,
            role       TEXT    DEFAULT 'operator',
            active     INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS customers (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            phone        TEXT UNIQUE NOT NULL,
            name         TEXT,
            notes        TEXT,
            vip          INTEGER DEFAULT 0,
            problem      INTEGER DEFAULT 0,
            birthday     TEXT,
            discount     INTEGER DEFAULT 0,
            total_orders INTEGER DEFAULT 0,
            total_spent  REAL    DEFAULT 0,
            created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS orders (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id  INTEGER REFERENCES customers(id),
            operator_id  INTEGER REFERENCES operators(id),
            order_date   DATETIME DEFAULT CURRENT_TIMESTAMP,
            amount       REAL,
            comment      TEXT,
            address      TEXT,
            ready_time   TEXT,
            payment_type TEXT,
            gift         TEXT,
            status       TEXT DEFAULT 'new',
            phone        TEXT
        );

        CREATE TABLE IF NOT EXISTS call_log (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            phone       TEXT,
            called_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
            answered    INTEGER DEFAULT 0,
            duration    INTEGER DEFAULT 0,
            operator_id INTEGER REFERENCES operators(id)
        );

        CREATE TABLE IF NOT EXISTS couriers (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT NOT NULL,
            phone      TEXT,
            active     INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS reminders (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            type         TEXT NOT NULL DEFAULT 'callback',  -- 'callback' | 'birthday' | 'custom'
            customer_id  INTEGER REFERENCES customers(id),
            phone        TEXT,
            text         TEXT NOT NULL,
            due_date     TEXT,            -- 'YYYY-MM-DD' або NULL = сьогодні
            due_time     TEXT,            -- 'HH:MM' або NULL
            created_by   INTEGER,         -- operator_id
            done         INTEGER DEFAULT 0,
            done_at      DATETIME,
            done_by      INTEGER,
            created_at   DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    ''')
    conn.commit()
    # Міграції — додаємо нові колонки якщо їх ще нема
    orders_cols = [('city', 'TEXT'), ('delivery_type', 'TEXT'), ('items', 'TEXT'),
                   ('phone', 'TEXT'), ('status', "TEXT DEFAULT 'new'"),
                   ('deleted', 'INTEGER DEFAULT 0'), ('deleted_by', 'INTEGER'),
                   ('deleted_at', 'DATETIME'), ('cancel_reason', 'TEXT'),
                   ('courier_id', 'INTEGER'), ('tags', 'TEXT'),
                   ('internal_note', 'TEXT'),
                   ('courier_note', 'TEXT')]
    for col, typ in orders_cols:
        try:
            conn.execute(f'ALTER TABLE orders ADD COLUMN {col} {typ}')
            conn.commit()
        except Exception:
            pass
    # Міграція customers
    cust_cols = [('blocked', 'INTEGER DEFAULT 0'),
                 ('blocked_reason', 'TEXT')]
    for col, typ in cust_cols:
        try:
            conn.execute(f'ALTER TABLE customers ADD COLUMN {col} {typ}')
            conn.commit()
        except Exception:
            pass
    # Міграція couriers — статус онлайн + нотатки
    courier_cols = [('courier_status', "TEXT DEFAULT 'offline'"),
                    ('status_updated_at', 'DATETIME'),
                    ('notes', 'TEXT')]
    for col, typ in courier_cols:
        try:
            conn.execute(f'ALTER TABLE couriers ADD COLUMN {col} {typ}')
            conn.commit()
        except Exception:
            pass
    # Міграція reminders — додаємо колонки для Telegram
    reminder_cols = [('tg_sent', 'INTEGER DEFAULT 0'),
                     ('tg_sent_at', 'DATETIME')]
    for col, typ in reminder_cols:
        try:
            conn.execute(f'ALTER TABLE reminders ADD COLUMN {col} {typ}')
            conn.commit()
        except Exception:
            pass
    # Таблиці авторизації
    conn.executescript('''
        CREATE TABLE IF NOT EXISTS users (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            login         TEXT    NOT NULL UNIQUE COLLATE NOCASE,
            password_hash TEXT    NOT NULL,
            role          TEXT    NOT NULL DEFAULT 'operator',
            display_name  TEXT    NOT NULL DEFAULT '',
            location      TEXT,
            courier_id    INTEGER REFERENCES couriers(id),
            is_active     INTEGER NOT NULL DEFAULT 1,
            created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
            created_by    INTEGER REFERENCES users(id),
            last_login    DATETIME
        );

        CREATE TABLE IF NOT EXISTS sessions (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL REFERENCES users(id),
            token_hash  TEXT    NOT NULL UNIQUE,
            created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
            expires_at  DATETIME NOT NULL,
            revoked     INTEGER  DEFAULT 0,
            ip          TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions(token_hash);
    ''')
    conn.commit()

    # Таблиці зарплати кур'єрів
    conn.executescript('''
        CREATE TABLE IF NOT EXISTS courier_rates (
            courier_id  INTEGER PRIMARY KEY REFERENCES couriers(id),
            rate        REAL    DEFAULT 0,
            updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS courier_payouts (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            courier_id   INTEGER REFERENCES couriers(id),
            amount       REAL    NOT NULL,
            deliveries   INTEGER DEFAULT 0,
            period_from  TEXT,
            period_to    TEXT,
            note         TEXT,
            actor_id     INTEGER DEFAULT 0,
            actor_role   TEXT    DEFAULT 'manager',
            paid_at      DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    ''')
    conn.commit()

    # Міграція: додати theme до users (якщо ще немає)
    try:
        conn.execute("ALTER TABLE users ADD COLUMN theme TEXT NOT NULL DEFAULT 'light'")
        conn.commit()
    except Exception:
        pass  # колонка вже існує

    # Міграція: видалити застарілий PIN з налаштувань
    try:
        conn.execute("DELETE FROM settings WHERE section='auth' AND key='dashboard_pin'")
        conn.commit()
    except Exception:
        pass

    conn.close()


# ---------- Settings ----------

def get_all_settings():
    conn = get_conn()
    rows = conn.execute('SELECT section, key, value FROM settings').fetchall()
    conn.close()
    result = {}
    for row in rows:
        result.setdefault(row['section'], {})[row['key']] = row['value']
    return result


def get_setting_value(section: str, key: str) -> str | None:
    conn = get_conn()
    row = conn.execute('SELECT value FROM settings WHERE section=? AND key=?', (section, key)).fetchone()
    conn.close()
    return row['value'] if row else None


def set_setting(section, key, value, actor_id: int = 0, actor_role: str = 'system'):
    conn = get_conn()
    try:
        old = conn.execute('SELECT value FROM settings WHERE section=? AND key=?',
                           (section, key)).fetchone()
        conn.execute('INSERT OR REPLACE INTO settings (section, key, value) VALUES (?,?,?)',
                     (section, key, str(value)))
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'setting', 0,
             f'set:{section}.{key}',
             json.dumps({'value': old['value'] if old else None}, ensure_ascii=False),
             json.dumps({'value': str(value)}, ensure_ascii=False))
        )
        conn.commit()
    finally:
        conn.close()


def set_settings_bulk(data: dict, actor_id: int = 0, actor_role: str = 'system'):
    """data = {section: {key: value, ...}, ...}"""
    conn = get_conn()
    try:
        for section, keys in data.items():
            for key, value in keys.items():
                old = conn.execute('SELECT value FROM settings WHERE section=? AND key=?',
                                   (section, key)).fetchone()
                conn.execute('INSERT OR REPLACE INTO settings (section, key, value) VALUES (?,?,?)',
                             (section, key, str(value)))
                conn.execute(
                    'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
                    'VALUES (?,?,?,?,?,?,?)',
                    (actor_id, actor_role, 'setting', 0,
                     f'set:{section}.{key}',
                     json.dumps({'value': old['value'] if old else None}, ensure_ascii=False),
                     json.dumps({'value': str(value)}, ensure_ascii=False))
                )
        conn.commit()
    finally:
        conn.close()


# ---------- Operators ----------

def get_operators(include_inactive: bool = False) -> list:
    conn = get_conn()
    if include_inactive:
        rows = conn.execute('SELECT * FROM operators ORDER BY active DESC, name').fetchall()
    else:
        rows = conn.execute('SELECT * FROM operators WHERE active=1 ORDER BY name').fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_operator_by_id(op_id: int):
    conn = get_conn()
    row = conn.execute('SELECT * FROM operators WHERE id=?', (op_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def create_operator(name: str, pin: str, role: str = 'operator',
                    actor_id: int = 0, actor_role: str = 'manager') -> int:
    conn = get_conn()
    try:
        cur = conn.execute(
            'INSERT INTO operators (name, pin, role, active) VALUES (?,?,?,1)',
            (name.strip(), pin.strip(), role)
        )
        new_id = cur.lastrowid
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'operator', new_id, 'create',
             None,
             json.dumps({'name': name, 'role': role}, ensure_ascii=False))
        )
        conn.commit()
        return new_id
    finally:
        conn.close()


def update_operator(op_id: int, fields: dict,
                    actor_id: int = 0, actor_role: str = 'manager'):
    conn = get_conn()
    try:
        old = conn.execute('SELECT * FROM operators WHERE id=?', (op_id,)).fetchone()
        if not old:
            return False
        allowed = {'name', 'pin', 'role', 'active'}
        sets, vals = [], []
        for k, v in fields.items():
            if k in allowed:
                sets.append(f'{k}=?')
                vals.append(v)
        if not sets:
            return False
        vals.append(op_id)
        conn.execute(f'UPDATE operators SET {", ".join(sets)} WHERE id=?', vals)
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'operator', op_id, 'update',
             json.dumps(dict(old), ensure_ascii=False),
             json.dumps(fields, ensure_ascii=False))
        )
        conn.commit()
        return True
    finally:
        conn.close()


def deactivate_operator(op_id: int,
                        actor_id: int = 0, actor_role: str = 'manager'):
    return update_operator(op_id, {'active': 0}, actor_id, actor_role)


# ---------- Customers ----------

def _normalize_phone(phone: str) -> str:
    """
    Канонічний формат: 380XXXXXXXXX (12 цифр, без + та пробілів)
    Приклади:
      +380505831901  → 380505831901
       0505831901    → 380505831901
       380505831901  → 380505831901
       80505831901   → 380505831901
    """
    import re
    digits = re.sub(r'\D', '', phone)          # лишаємо тільки цифри
    if digits.startswith('380'):
        return digits                           # вже повний
    elif digits.startswith('80') and len(digits) == 11:
        return '3' + digits                    # 80... → 380...
    elif digits.startswith('0') and len(digits) == 10:
        return '38' + digits                   # 0... → 380...
    elif len(digits) == 9:
        return '380' + digits                  # без коду країни і оператора
    return digits                              # повертаємо як є (не розпізнано)


def _last10(phone: str) -> str:
    """Останні 10 цифр — унікальний ідентифікатор локального номера."""
    return _normalize_phone(phone)[-10:]


def find_duplicate(phone: str):
    """
    Шукає клієнта з тим же локальним номером (останні 10 цифр).
    Повертає dict клієнта або None.
    """
    local = _last10(phone)
    if len(local) < 9:
        return None
    conn = get_conn()
    # Порівнюємо останні 10 символів поля phone
    row = conn.execute(
        "SELECT * FROM customers WHERE substr(phone, -10) = ? LIMIT 1",
        (local,)
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def get_customer_by_id(customer_id: int):
    conn = get_conn()
    row  = conn.execute('SELECT * FROM customers WHERE id=?', (customer_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_customer_by_phone(phone: str):
    phone = _normalize_phone(phone)
    conn = get_conn()
    row = conn.execute('SELECT * FROM customers WHERE phone = ?', (phone,)).fetchone()
    conn.close()
    return dict(row) if row else None


def upsert_customer(data: dict):
    phone = _normalize_phone(data.get('phone', ''))
    if not phone:
        return {'ok': False, 'error': 'no phone'}

    # Дедуп: шукаємо клієнта з тим же локальним номером
    dup = find_duplicate(phone)
    if dup and dup['phone'] != phone:
        # Існує клієнт з іншим форматом того ж номера
        # Якщо data містить force_merge=True — перезаписуємо phone на канонічний
        if data.get('force_merge'):
            conn = get_conn()
            conn.execute('UPDATE customers SET phone=? WHERE id=?', (phone, dup['id']))
            conn.commit()
            conn.close()
            return {'ok': True, 'id': dup['id'], 'merged': True}
        # Інакше — повертаємо попередження
        return {
            'ok': True,
            'id': dup['id'],
            'duplicate': True,
            'existing_phone': dup['phone'],
            'existing_name':  dup.get('name') or '',
            'total_orders':   dup.get('total_orders', 0),
        }

    conn = get_conn()
    try:
        existing = conn.execute('SELECT * FROM customers WHERE phone = ?', (phone,)).fetchone()
        if existing:
            before = dict(existing)
            conn.execute('''
                UPDATE customers SET
                    name     = COALESCE(?, name),
                    notes    = COALESCE(?, notes),
                    vip      = COALESCE(?, vip),
                    problem  = COALESCE(?, problem),
                    birthday = COALESCE(?, birthday),
                    discount = COALESCE(?, discount),
                    updated_at = CURRENT_TIMESTAMP
                WHERE phone = ?
            ''', (data.get('name'), data.get('notes'), data.get('vip'),
                  data.get('problem'), data.get('birthday'), data.get('discount'), phone))
            customer_id = existing['id']
            action = 'update'
            after = {**before, **{k: data[k] for k in ('name','notes','vip','problem','birthday','discount') if k in data}}
        else:
            before = None
            cur = conn.execute('''
                INSERT INTO customers (phone, name, notes, vip, problem, birthday, discount)
                VALUES (?,?,?,?,?,?,?)
            ''', (phone, data.get('name'), data.get('notes'),
                  data.get('vip', 0), data.get('problem', 0),
                  data.get('birthday'), data.get('discount', 0)))
            customer_id = cur.lastrowid
            action = 'create'
            after = {'id': customer_id, 'phone': phone, 'name': data.get('name')}
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (data.get('operator_id') or 0, data.get('actor_role') or 'operator',
             'customer', customer_id, action,
             json.dumps(before, ensure_ascii=False, default=str) if before else None,
             json.dumps(after,  ensure_ascii=False, default=str))
        )
        conn.commit()
        return {'ok': True, 'id': customer_id}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def merge_customers(keep_id: int, drop_id: int,
                    actor_id: int = 0, actor_role: str = 'manager') -> dict:
    """
    Об'єднує двох клієнтів: keep залишається, drop видаляється.

    Що переноситься з drop → keep:
      - Всі замовлення (orders.customer_id)
      - Reminders (reminders.customer_id)
      - Поля: name, birthday, notes, discount (якщо у keep порожні)
      - total_orders та total_spent — сумуються

    call_log прив'язаний тільки по phone, тому не чіпаємо.
    """
    if keep_id == drop_id:
        return {'ok': False, 'error': 'keep_id == drop_id'}
    conn = get_conn()
    try:
        keep = conn.execute('SELECT * FROM customers WHERE id=?', (keep_id,)).fetchone()
        drop = conn.execute('SELECT * FROM customers WHERE id=?', (drop_id,)).fetchone()
        if not keep:
            return {'ok': False, 'error': f'Клієнт #{keep_id} не знайдений'}
        if not drop:
            return {'ok': False, 'error': f'Клієнт #{drop_id} не знайдений'}
        keep = dict(keep); drop = dict(drop)

        # 1. Перенести замовлення
        conn.execute('UPDATE orders SET customer_id=? WHERE customer_id=?', (keep_id, drop_id))

        # 2. Перенести нагадування
        conn.execute('UPDATE reminders SET customer_id=? WHERE customer_id=?', (keep_id, drop_id))

        # 3. Злити поля (беремо з drop якщо у keep порожньо)
        updates, vals = [], []
        for field in ('name', 'birthday', 'notes'):
            if not (keep.get(field) or '').strip() and (drop.get(field) or '').strip():
                updates.append(f'{field}=?'); vals.append(drop[field])
        if (drop.get('discount') or 0) > (keep.get('discount') or 0):
            updates.append('discount=?'); vals.append(drop['discount'])
        if drop.get('vip') and not keep.get('vip'):
            updates.append('vip=1')

        # 4. Злити статистику
        new_orders = (keep.get('total_orders') or 0) + (drop.get('total_orders') or 0)
        new_spent  = (keep.get('total_spent')  or 0) + (drop.get('total_spent')  or 0)
        updates += ['total_orders=?', 'total_spent=?', 'updated_at=CURRENT_TIMESTAMP']
        vals    += [new_orders, round(new_spent, 2)]

        vals.append(keep_id)
        conn.execute(f'UPDATE customers SET {", ".join(updates)} WHERE id=?', vals)

        # 5. Видалити drop
        conn.execute('DELETE FROM customers WHERE id=?', (drop_id,))

        # 6. ActionLog
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'customer', keep_id, 'merge',
             json.dumps({'keep': keep, 'drop': drop}, ensure_ascii=False, default=str),
             json.dumps({'merged_drop_id': drop_id, 'new_total_orders': new_orders,
                         'new_total_spent': round(new_spent, 2)}, ensure_ascii=False))
        )
        conn.commit()
        return {'ok': True, 'keep_id': keep_id, 'dropped_id': drop_id,
                'total_orders': new_orders, 'total_spent': round(new_spent, 2)}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def find_duplicate_pairs(limit: int = 50) -> list:
    """
    Знаходить пари клієнтів де останні 10 цифр телефону збігаються.
    Повертає список dict з {a, b} — обидва клієнти.
    """
    conn = get_conn()
    rows = conn.execute(
        '''SELECT c1.id id1, c1.phone ph1, c1.name nm1, c1.total_orders to1,
                  c2.id id2, c2.phone ph2, c2.name nm2, c2.total_orders to2
           FROM customers c1
           JOIN customers c2
             ON substr(c1.phone,-10) = substr(c2.phone,-10) AND c1.id < c2.id
           ORDER BY c1.id
           LIMIT ?''', (limit,)
    ).fetchall()
    conn.close()
    return [{'a': {'id': r['id1'], 'phone': r['ph1'], 'name': r['nm1'], 'total_orders': r['to1']},
             'b': {'id': r['id2'], 'phone': r['ph2'], 'name': r['nm2'], 'total_orders': r['to2']}}
            for r in rows]


def set_customer_blocked(customer_id: int, blocked: bool,
                         reason: str = '', actor_id: int = 0, actor_role: str = 'manager') -> dict:
    """Блокує або розблоковує клієнта. Записує в action_logs."""
    conn = get_conn()
    try:
        row = conn.execute('SELECT * FROM customers WHERE id=?', (customer_id,)).fetchone()
        if not row:
            return {'ok': False, 'error': 'Клієнта не знайдено'}
        before = dict(row)
        conn.execute(
            'UPDATE customers SET blocked=?, blocked_reason=?, updated_at=CURRENT_TIMESTAMP WHERE id=?',
            (1 if blocked else 0, reason if blocked else '', customer_id)
        )
        after = {**before, 'blocked': 1 if blocked else 0, 'blocked_reason': reason}
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'customer', customer_id,
             'block' if blocked else 'unblock',
             json.dumps(before, ensure_ascii=False, default=str),
             json.dumps(after, ensure_ascii=False, default=str))
        )
        conn.commit()
        return {'ok': True}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def get_top_customers(limit=10):
    conn = get_conn()
    rows = conn.execute(
        'SELECT phone, name, total_orders, total_spent FROM customers ORDER BY total_orders DESC LIMIT ?',
        (limit,)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def search_customers(q: str = '', vip: int = -1, blocked: int = -1,
                     sort: str = 'total_orders', limit: int = 50, offset: int = 0) -> dict:
    """
    Пошук/фільтрація клієнтів.
    q       — рядок пошуку (phone або name, LIKE)
    vip     — 0/1 або -1 (будь-які)
    blocked — 0/1 або -1 (будь-які)
    sort    — total_orders | total_spent | created_at | name
    """
    conn = get_conn()
    allowed_sorts = {'total_orders', 'total_spent', 'created_at', 'name', 'updated_at'}
    if sort not in allowed_sorts:
        sort = 'total_orders'

    where, params = ['1=1'], []
    if q:
        where.append('(phone LIKE ? OR name LIKE ?)')
        params += [f'%{q}%', f'%{q}%']
    if vip >= 0:
        where.append('vip=?'); params.append(vip)
    if blocked >= 0:
        where.append('blocked=?'); params.append(blocked)

    total = conn.execute(
        f'SELECT COUNT(*) FROM customers WHERE {" AND ".join(where)}', params
    ).fetchone()[0]

    order_dir = 'ASC' if sort == 'name' else 'DESC'
    rows = conn.execute(
        f'''SELECT id, phone, name, vip, blocked, blocked_reason,
                   total_orders, total_spent, discount, birthday, created_at, updated_at
            FROM customers
            WHERE {" AND ".join(where)}
            ORDER BY {sort} {order_dir}
            LIMIT ? OFFSET ?''',
        params + [limit, offset]
    ).fetchall()
    conn.close()
    return {'total': total, 'items': [dict(r) for r in rows]}


# ---------- Orders ----------

def log_order(data: dict):
    conn = get_conn()
    phone_norm = _normalize_phone(data.get('phone', '') or '')
    # P6: orders.phone завжди заповнений.
    # Якщо phone порожній але є customer_id — беремо телефон з customers.
    if not phone_norm and data.get('customer_id'):
        cust_row = conn.execute('SELECT phone FROM customers WHERE id=?',
                                (data['customer_id'],)).fetchone()
        if cust_row and cust_row['phone']:
            phone_norm = cust_row['phone']
    cur = conn.execute('''
        INSERT INTO orders (customer_id, operator_id, amount, comment, address, ready_time, payment_type, gift, city, delivery_type, items, phone)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
    ''', (data.get('customer_id'), data.get('operator_id'), data.get('amount'),
          data.get('comment'), data.get('address'), data.get('ready_time'),
          data.get('payment_type'), data.get('gift'),
          data.get('city'), data.get('delivery_type'), data.get('items'),
          phone_norm))
    order_id = cur.lastrowid
    # BR-5: customer stats оновлюються тільки при → delivered, НЕ при створенні
    # ActionLog: create order
    after_snapshot = {k: data.get(k) for k in
                      ('customer_id', 'operator_id', 'amount', 'comment', 'address',
                       'payment_type', 'city', 'delivery_type', 'items')}
    after_snapshot['phone'] = phone_norm
    after_snapshot['id'] = order_id
    conn.execute(
        'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
        'VALUES (?,?,?,?,?,?,?)',
        (data.get('operator_id') or 0, 'operator', 'order', order_id, 'create',
         None, json.dumps(after_snapshot, ensure_ascii=False, default=str))
    )
    conn.commit()
    conn.close()
    return order_id


def get_orders_filtered(status: str = '', city: str = '', date_from: str = '',
                        date_to: str = '', search: str = '',
                        courier_id: str = '', tag: str = '',
                        include_deleted: bool = False,
                        limit: int = 200) -> list:
    """
    Повертає замовлення з JOIN customers+couriers для дашборду.
    Фільтри: status, city, date_from/date_to (YYYY-MM-DD), search (phone|name), courier_id, tag.
    """
    conn = get_conn()
    q = '''
        SELECT o.id, o.order_date, o.amount, o.status, o.address, o.city,
               o.delivery_type, o.payment_type, o.comment, o.items, o.gift,
               o.phone AS order_phone, o.courier_id, o.deleted, o.cancel_reason,
               o.tags, o.internal_note, o.courier_note, o.ready_time,
               c.id AS customer_id, c.phone AS cust_phone, c.name, c.vip, c.problem,
               cr.name AS courier_name
        FROM orders o
        LEFT JOIN customers c  ON o.customer_id = c.id
        LEFT JOIN couriers  cr ON o.courier_id  = cr.id
        WHERE 1=1
    '''
    params = []
    if not include_deleted:
        q += ' AND (o.deleted IS NULL OR o.deleted = 0)'
    if status:
        q += ' AND o.status = ?'; params.append(status)
    if city:
        q += ' AND o.city = ?'; params.append(city)
    if date_from:
        q += ' AND date(o.order_date) >= ?'; params.append(date_from)
    if date_to:
        q += ' AND date(o.order_date) <= ?'; params.append(date_to)
    if search:
        s = '%' + search.strip() + '%'
        q += ' AND (c.phone LIKE ? OR c.name LIKE ? OR o.phone LIKE ?)'
        params += [s, s, s]
    if courier_id:
        if courier_id == 'none':
            q += ' AND o.courier_id IS NULL'
        else:
            q += ' AND o.courier_id = ?'; params.append(int(courier_id))
    if tag and tag in VALID_TAGS:
        # tags column stores comma-separated values like "urgent,vip"
        q += " AND (',' || COALESCE(o.tags,'') || ',' LIKE ?)"
        params.append('%,' + tag + ',%')
    q += ' ORDER BY o.order_date DESC LIMIT ?'
    params.append(limit)
    rows = conn.execute(q, params).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def export_orders_csv(status: str = '', city: str = '', date_from: str = '',
                      date_to: str = '', search: str = '',
                      courier_id: str = '') -> str:
    """Повертає CSV-рядок замовлень з тими ж фільтрами що get_orders_filtered."""
    import csv, io
    rows = get_orders_filtered(
        status=status, city=city, date_from=date_from, date_to=date_to,
        search=search, courier_id=courier_id, include_deleted=False, limit=10000
    )
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow([
        'ID', 'Дата', 'Статус', 'Клієнт', 'Телефон', 'Сума',
        'Адреса', 'Місто', 'Тип доставки', 'Оплата',
        'Товари', 'Коментар', 'Подарунок', 'Кур\'єр',
    ])
    STATUS_UK = {
        'new': 'Новий', 'confirmed': 'Підтверджено', 'cooking': 'Готується',
        'on_way': 'В дорозі', 'delivered': 'Доставлено', 'cancelled': 'Скасовано',
    }
    for r in rows:
        writer.writerow([
            r.get('id', ''),
            (r.get('order_date') or '')[:19],
            STATUS_UK.get(r.get('status', ''), r.get('status', '')),
            r.get('name') or '',
            r.get('cust_phone') or r.get('order_phone') or '',
            r.get('amount') or '',
            r.get('address') or '',
            r.get('city') or '',
            r.get('delivery_type') or '',
            r.get('payment_type') or '',
            r.get('items') or '',
            r.get('comment') or '',
            r.get('gift') or '',
            r.get('courier_name') or '',
        ])
    return buf.getvalue()


def get_customers_stats() -> dict:
    """Загальна статистика клієнтської бази."""
    conn = get_conn()
    row = conn.execute(
        'SELECT COUNT(*) total, SUM(vip) vip_count, SUM(blocked) blocked_count FROM customers'
    ).fetchone()
    conn.close()
    return {
        'total':   row['total']         or 0,
        'vip':     row['vip_count']     or 0,
        'blocked': row['blocked_count'] or 0,
    }


def get_kpi_today() -> dict:
    """KPI для дашборду: сьогоднішні замовлення, виручка, нові клієнти."""
    conn = get_conn()
    today = datetime.now().strftime('%Y-%m-%d')
    r = conn.execute(
        "SELECT COUNT(*) cnt, COALESCE(SUM(amount),0) rev FROM orders "
        "WHERE date(order_date)=? AND (deleted IS NULL OR deleted=0)", (today,)
    ).fetchone()
    new_clients = conn.execute(
        "SELECT COUNT(*) cnt FROM customers WHERE date(created_at)=?", (today,)
    ).fetchone()['cnt']
    # Статуси сьогодні
    statuses = conn.execute(
        "SELECT status, COUNT(*) cnt FROM orders "
        "WHERE date(order_date)=? AND (deleted IS NULL OR deleted=0) GROUP BY status", (today,)
    ).fetchall()
    conn.close()
    return {
        'today_orders':   r['cnt'],
        'today_revenue':  round(r['rev'], 2),
        'new_clients':    new_clients,
        'by_status':      {row['status'] or 'new': row['cnt'] for row in statuses},
    }


def get_orders_by_phone(phone: str):
    norm = _normalize_phone(phone)
    last10 = norm[-10:]
    conn = get_conn()

    # Знаходимо customer_id через customers (fuzzy по останніх 10 цифрах)
    cust_row = conn.execute(
        "SELECT id FROM customers WHERE substr(phone,-10)=? LIMIT 1", (last10,)
    ).fetchone()
    customer_id = cust_row['id'] if cust_row else None

    # Запит: customer_id АБО phone напряму (на випадок null customer_id)
    # deleted=1 записи завжди виключаються
    if customer_id:
        rows = conn.execute(
            "SELECT id, order_date, amount, comment, address, payment_type, gift, city, delivery_type, items "
            "FROM orders WHERE (customer_id=? OR substr(phone,-10)=?) AND (deleted IS NULL OR deleted=0) "
            "ORDER BY order_date DESC LIMIT 50",
            (customer_id, last10)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT id, order_date, amount, comment, address, payment_type, gift, city, delivery_type, items "
            "FROM orders WHERE substr(phone,-10)=? AND (deleted IS NULL OR deleted=0) "
            "ORDER BY order_date DESC LIMIT 50",
            (last10,)
        ).fetchall()

    conn.close()
    return [dict(r) for r in rows]


def get_order_by_id(order_id: int):
    conn = get_conn()
    row = conn.execute('SELECT * FROM orders WHERE id=?', (order_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def update_order(order_id: int, data: dict, actor_id: int, actor_role: str):
    """
    Оновлює поля замовлення. Дозволені поля: amount, address, comment,
    payment_type, gift, ready_time, city, delivery_type, items.
    Пише в action_logs (before/after).
    """
    ALLOWED = {'amount', 'address', 'comment', 'payment_type',
               'gift', 'ready_time', 'city', 'delivery_type', 'items', 'internal_note', 'courier_note'}
    conn = get_conn()
    try:
        row = conn.execute('SELECT * FROM orders WHERE id=?', (order_id,)).fetchone()
        if not row:
            return {'ok': False, 'error': 'NOT_FOUND'}
        before = dict(row)
        if before.get('deleted'):
            return {'ok': False, 'error': 'Замовлення видалено'}

        updates = {k: v for k, v in data.items() if k in ALLOWED}
        if not updates:
            return {'ok': False, 'error': 'Немає полів для оновлення'}

        set_clause = ', '.join(f'{k}=?' for k in updates)
        values     = list(updates.values()) + [order_id]
        conn.execute(f'UPDATE orders SET {set_clause} WHERE id=?', values)

        after = {**before, **updates}
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'order', order_id, 'edit',
             json.dumps(before, ensure_ascii=False, default=str),
             json.dumps(after,  ensure_ascii=False, default=str))
        )
        conn.commit()
        return {'ok': True}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def soft_delete_order(order_id: int, actor_id: int, actor_role: str, reason: str):
    """
    Soft delete замовлення: встановлює deleted=1 і пише в action_logs.
    Повертає {'ok': True} або {'ok': False, 'error': '...'}.
    """
    conn = get_conn()
    try:
        row = conn.execute('SELECT * FROM orders WHERE id=?', (order_id,)).fetchone()
        if not row:
            return {'ok': False, 'error': 'NOT_FOUND'}
        order = dict(row)

        # Не можна видаляти вже видалені
        if order.get('deleted'):
            return {'ok': False, 'error': 'Замовлення вже видалено'}

        # Soft delete
        conn.execute(
            'UPDATE orders SET deleted=1, deleted_by=?, deleted_at=CURRENT_TIMESTAMP, cancel_reason=? WHERE id=?',
            (actor_id, reason, order_id)
        )

        # Action log (в тій самій транзакції)
        before_json = json.dumps(order, ensure_ascii=False, default=str)
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'order', order_id, 'delete', before_json, None)
        )

        conn.commit()
        return {'ok': True}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def update_order_status(order_id: int, new_status: str, actor_id: int, actor_role: str, before: dict = None):
    """
    Змінює статус замовлення і пише в action_logs.
    before — поточний стан замовлення (dict) для аудиту.
    """
    conn = get_conn()
    try:
        conn.execute(
            'UPDATE orders SET status=? WHERE id=?',
            (new_status, order_id)
        )
        # BR-5: customer stats оновлюються тільки при переході → delivered
        if new_status == 'delivered' and before:
            cust_id = before.get('customer_id')
            amount  = before.get('amount') or 0
            if cust_id and amount:
                conn.execute('''
                    UPDATE customers SET
                        total_orders = total_orders + 1,
                        total_spent  = total_spent + ?,
                        updated_at   = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (amount, cust_id))
                conn.execute(
                    'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
                    'VALUES (?,?,?,?,?,?,?)',
                    (actor_id, actor_role, 'customer', cust_id, 'stats_update',
                     json.dumps({'total_orders': 'prev', 'total_spent': 'prev'}, ensure_ascii=False),
                     json.dumps({'reason': f'order {order_id} delivered', 'delta_orders': 1, 'delta_spent': amount}, ensure_ascii=False))
                )
        before_json = json.dumps(before, ensure_ascii=False, default=str) if before else None
        after_json  = json.dumps({'id': order_id, 'status': new_status}, ensure_ascii=False)
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'order', order_id, f'status→{new_status}', before_json, after_json)
        )
        conn.commit()
        return {'ok': True}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


# ---------- Couriers ----------

def get_couriers_with_stats() -> list:
    """Всі кур'єри з кількістю замовлень (всього / сьогодні / активних)."""
    conn = get_conn()
    today = datetime.now().strftime('%Y-%m-%d')
    rows = conn.execute('''
        SELECT c.*,
               COUNT(o.id)                                          AS total_orders,
               SUM(CASE WHEN date(o.order_date)=? THEN 1 ELSE 0 END) AS today_orders,
               SUM(CASE WHEN o.status NOT IN ('delivered','cancelled')
                        AND o.deleted IS NOT 1 THEN 1 ELSE 0 END)  AS active_orders,
               COALESCE(SUM(o.amount),0)                           AS total_revenue
        FROM couriers c
        LEFT JOIN orders o ON o.courier_id = c.id
                          AND (o.deleted IS NULL OR o.deleted = 0)
        GROUP BY c.id
        ORDER BY c.active DESC, c.name
    ''', (today,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_courier_orders(courier_id: int) -> list:
    """
    Активні замовлення кур'єра для /courier мобільної сторінки.
    Повертає тільки delivery + не deleted + статус в active set.
    P8: не повертає суму (total_revenue).
    """
    conn = get_conn()
    rows = conn.execute('''
        SELECT o.id, o.order_date, o.status, o.delivery_type,
               o.address, o.items, o.comment, o.city, o.courier_note, o.ready_time,
               c.phone AS customer_phone, c.name AS customer_name
        FROM orders o
        LEFT JOIN customers c ON c.id = o.customer_id
        WHERE o.courier_id = ?
          AND o.delivery_type = 'delivery'
          AND (o.deleted IS NULL OR o.deleted = 0)
          AND o.status IN ('confirmed', 'cooking', 'on_way')
        ORDER BY o.order_date
    ''', (courier_id,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_courier_by_id(courier_id: int):
    conn = get_conn()
    row  = conn.execute('SELECT * FROM couriers WHERE id=?', (courier_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_couriers(active_only: bool = True) -> list:
    conn = get_conn()
    q = 'SELECT * FROM couriers'
    if active_only:
        q += ' WHERE active=1'
    q += ' ORDER BY name'
    rows = conn.execute(q).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def upsert_courier(data: dict, actor_id: int = 0, actor_role: str = 'manager') -> dict:
    """Додає або оновлює кур'єра. data: {id?, name, phone?, active?}"""
    conn = get_conn()
    try:
        cid = data.get('id')
        if cid:
            row = conn.execute('SELECT * FROM couriers WHERE id=?', (cid,)).fetchone()
            before = dict(row) if row else None
            conn.execute(
                'UPDATE couriers SET name=COALESCE(?,name), phone=COALESCE(?,phone), active=COALESCE(?,active) WHERE id=?',
                (data.get('name'), data.get('phone'), data.get('active'), cid)
            )
            action = 'update'
            after = {**(before or {}), **{k: data[k] for k in ('name','phone','active') if k in data}}
        else:
            name = (data.get('name') or '').strip()
            if not name:
                return {'ok': False, 'error': 'Ім\'я кур\'єра обов\'язкове'}
            cur = conn.execute(
                'INSERT INTO couriers (name, phone, active) VALUES (?,?,?)',
                (name, data.get('phone', ''), 1)
            )
            cid = cur.lastrowid
            before = None
            action = 'create'
            after = {'id': cid, 'name': name, 'phone': data.get('phone', '')}
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'courier', cid, action,
             json.dumps(before, ensure_ascii=False, default=str) if before else None,
             json.dumps(after,  ensure_ascii=False, default=str))
        )
        conn.commit()
        return {'ok': True, 'id': cid}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def set_courier_status(courier_id: int, status: str) -> dict:
    """Встановлює статус кур'єра: 'online' | 'offline' | 'busy'."""
    VALID = {'online', 'offline', 'busy'}
    if status not in VALID:
        return {'ok': False, 'error': 'Невалідний статус'}
    conn = get_conn()
    try:
        conn.execute(
            "UPDATE couriers SET courier_status=?, status_updated_at=CURRENT_TIMESTAMP WHERE id=?",
            (status, courier_id)
        )
        conn.commit()
        return {'ok': True, 'status': status}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def update_courier_notes(courier_id: int, notes: str) -> dict:
    """Оновлює нотатку кур'єра."""
    conn = get_conn()
    try:
        conn.execute("UPDATE couriers SET notes=? WHERE id=?", (notes, courier_id))
        conn.commit()
        return {'ok': True}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def assign_courier(order_id: int, courier_id: int | None, actor_id: int, actor_role: str) -> dict:
    """Призначає або знімає кур'єра з замовлення. Записує в action_logs."""
    conn = get_conn()
    try:
        row = conn.execute('SELECT * FROM orders WHERE id=?', (order_id,)).fetchone()
        if not row:
            return {'ok': False, 'error': 'NOT_FOUND'}
        before = dict(row)

        if courier_id:
            c = conn.execute('SELECT id, name FROM couriers WHERE id=? AND active=1', (courier_id,)).fetchone()
            if not c:
                return {'ok': False, 'error': 'Кур\'єра не знайдено'}

        conn.execute('UPDATE orders SET courier_id=? WHERE id=?', (courier_id, order_id))
        after_snap = {**before, 'courier_id': courier_id}
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'order', order_id,
             'assign_courier' if courier_id else 'unassign_courier',
             json.dumps(before, ensure_ascii=False, default=str),
             json.dumps(after_snap, ensure_ascii=False, default=str))
        )
        conn.commit()
        return {'ok': True}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def log_iiko_read(phone: str, ok: bool, duration_ms: int, raw_fields: dict = None, error: str = None):
    """Пише кожне UIA-читання в iiko_sync_log. Ротація: видаляємо старші 7 днів."""
    conn = get_conn()
    try:
        conn.execute(
            'INSERT INTO iiko_sync_log (phone, ok, error, duration_ms, raw_fields) VALUES (?,?,?,?,?)',
            (phone, 1 if ok else 0, error,
             duration_ms,
             json.dumps(raw_fields, ensure_ascii=False, default=str) if raw_fields else None)
        )
        # Ротація: видаляємо записи старші 7 днів
        conn.execute("DELETE FROM iiko_sync_log WHERE read_at < datetime('now', '-7 days')")
        conn.commit()
    except Exception:
        pass
    finally:
        conn.close()


def log_action(actor_id: int, actor_role: str, entity_type: str, entity_id: int,
               action: str, before=None, after=None):
    """Записує подію в action_logs."""
    conn = get_conn()
    try:
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, entity_type, entity_id, action,
             json.dumps(before, ensure_ascii=False, default=str) if before is not None else None,
             json.dumps(after, ensure_ascii=False, default=str) if after is not None else None)
        )
        conn.commit()
    except Exception:
        pass
    finally:
        conn.close()


# ---------- Calls ----------

def log_call(data: dict):
    conn = get_conn()
    conn.execute('''
        INSERT INTO call_log (phone, answered, duration, operator_id)
        VALUES (?,?,?,?)
    ''', (data.get('phone'), data.get('answered', 0),
          data.get('duration', 0), data.get('operator_id')))
    conn.commit()
    conn.close()


# ---------- Analytics ----------

def get_analytics_summary():
    conn = get_conn()
    today = datetime.now().strftime('%Y-%m-%d')

    row = conn.execute(
        "SELECT COUNT(*) cnt, COALESCE(SUM(amount),0) total FROM orders WHERE date(order_date)=?",
        (today,)
    ).fetchone()
    today_orders   = row['cnt']
    today_revenue  = row['total']

    row = conn.execute("SELECT COUNT(*) cnt FROM customers").fetchone()
    total_customers = row['cnt']

    row = conn.execute("SELECT COUNT(*) cnt, COALESCE(SUM(answered),0) ans FROM call_log WHERE date(called_at)=?", (today,)).fetchone()
    today_calls    = row['cnt']
    today_answered = row['ans']

    top = get_top_customers(5)

    conn.close()
    return {
        'today_orders':    today_orders,
        'today_revenue':   today_revenue,
        'total_customers': total_customers,
        'today_calls':     today_calls,
        'today_answered':  today_answered,
        'top_customers':   top,
    }


def get_analytics_period(date_from: str, date_to: str) -> dict:
    """
    KPI для довільного діапазону дат.
    date_from, date_to — рядки 'YYYY-MM-DD'.
    """
    conn = get_conn()
    row = conn.execute('''
        SELECT
            COUNT(*)                                               AS total_orders,
            COALESCE(SUM(amount), 0)                              AS revenue,
            COALESCE(AVG(amount), 0)                              AS avg_check,
            SUM(CASE WHEN status='delivered'  THEN 1 ELSE 0 END)  AS delivered,
            SUM(CASE WHEN status='cancelled'  THEN 1 ELSE 0 END)  AS cancelled,
            SUM(CASE WHEN delivery_type='delivery' THEN 1 ELSE 0 END) AS delivery_cnt,
            SUM(CASE WHEN delivery_type='pickup'   THEN 1 ELSE 0 END) AS pickup_cnt
        FROM orders
        WHERE date(order_date) BETWEEN ? AND ?
          AND (deleted IS NULL OR deleted=0)
    ''', (date_from, date_to)).fetchone()
    total = row['total_orders'] or 1  # уникнути ділення на 0
    result = {
        'total_orders':   row['total_orders'],
        'revenue':        round(row['revenue'], 2),
        'avg_check':      round(row['avg_check'], 2),
        'delivered':      row['delivered'],
        'cancelled':      row['cancelled'],
        'delivered_pct':  round(row['delivered'] / total * 100, 1),
        'cancelled_pct':  round(row['cancelled'] / total * 100, 1),
        'delivery_cnt':   row['delivery_cnt'],
        'pickup_cnt':     row['pickup_cnt'],
    }
    conn.close()
    return result


def get_daily_revenue(date_from: str, date_to: str) -> list:
    """Виручка і кількість замовлень по днях для bar chart."""
    conn = get_conn()
    rows = conn.execute('''
        SELECT date(order_date) AS day,
               COUNT(*)                    AS orders,
               COALESCE(SUM(amount), 0)    AS revenue
        FROM orders
        WHERE date(order_date) BETWEEN ? AND ?
          AND (deleted IS NULL OR deleted=0)
        GROUP BY day
        ORDER BY day
    ''', (date_from, date_to)).fetchall()
    conn.close()
    return [{'day': r['day'], 'orders': r['orders'], 'revenue': round(r['revenue'], 2)}
            for r in rows]


def get_top_items(date_from: str, date_to: str, limit: int = 10) -> list:
    """
    Топ позицій меню з items (CSV-рядок типу "Філадельфія x2, Каліфорнія x1").
    Парсимо items в Python — SQLite не має split().
    """
    conn = get_conn()
    rows = conn.execute('''
        SELECT items FROM orders
        WHERE date(order_date) BETWEEN ? AND ?
          AND (deleted IS NULL OR deleted=0)
          AND items IS NOT NULL AND items != ''
    ''', (date_from, date_to)).fetchall()
    conn.close()

    counts: dict[str, int] = {}
    for r in rows:
        for part in (r['items'] or '').split(','):
            part = part.strip()
            if not part:
                continue
            # "Назва xN" або просто "Назва"
            import re
            m = re.match(r'^(.+?)\s+[xхХ×](\d+)$', part)
            if m:
                name = m.group(1).strip()
                qty  = int(m.group(2))
            else:
                name = part
                qty  = 1
            counts[name] = counts.get(name, 0) + qty

    sorted_items = sorted(counts.items(), key=lambda x: x[1], reverse=True)[:limit]
    total_qty = sum(counts.values()) or 1
    return [
        {'name': name, 'qty': qty, 'pct': round(qty / total_qty * 100, 1)}
        for name, qty in sorted_items
    ]


def get_operators_stats(date_from: str, date_to: str) -> list:
    """Статистика операторів: замовлень та виручка за діапазон."""
    conn = get_conn()
    rows = conn.execute('''
        SELECT o.operator_id,
               op.name                        AS operator_name,
               COUNT(o.id)                    AS orders,
               COALESCE(SUM(o.amount), 0)     AS revenue,
               SUM(CASE WHEN o.status='delivered' THEN 1 ELSE 0 END) AS delivered
        FROM orders o
        LEFT JOIN operators op ON op.id = o.operator_id
        WHERE date(o.order_date) BETWEEN ? AND ?
          AND (o.deleted IS NULL OR o.deleted=0)
        GROUP BY o.operator_id
        ORDER BY orders DESC
    ''', (date_from, date_to)).fetchall()
    conn.close()
    return [{'operator_id': r['operator_id'],
             'name':        r['operator_name'] or f'#{r["operator_id"]}',
             'orders':      r['orders'],
             'revenue':     round(r['revenue'], 2),
             'delivered':   r['delivered']}
            for r in rows]


# ─────────────────────────────────────────────────────────
# Phase 5 — INTELLIGENCE
# ─────────────────────────────────────────────────────────

def get_birthday_reminders(days_ahead: int = 3) -> list:
    """
    Клієнти у яких день народження протягом наступних days_ahead днів.
    birthday зберігається як 'DD.MM.YYYY', 'DD.MM' або 'YYYY-MM-DD'.
    Порівнюємо тільки день і місяць — рік ігноруємо.
    """
    from datetime import date, timedelta
    import re
    conn = get_conn()
    rows = conn.execute(
        "SELECT id, phone, name, birthday FROM customers WHERE birthday IS NOT NULL AND birthday != '' AND blocked=0"
    ).fetchall()
    conn.close()

    today    = date.today()
    upcoming = []
    for r in rows:
        bd_str = (r['birthday'] or '').strip()
        day, mon = None, None
        for pat, fmt in [
            (r'^\d{2}\.\d{2}\.\d{4}$', '%d.%m.%Y'),
            (r'^\d{4}-\d{2}-\d{2}$',   '%Y-%m-%d'),
            (r'^\d{2}\.\d{2}$',         '%d.%m'),
        ]:
            if re.match(pat, bd_str):
                from datetime import datetime as _dt
                try:
                    parsed = _dt.strptime(bd_str, fmt)
                    day, mon = parsed.day, parsed.month
                except ValueError:
                    pass
                break
        if day is None:
            continue
        # Перевіряємо наступні days_ahead днів
        for delta in range(days_ahead + 1):
            check = today + timedelta(days=delta)
            if check.day == day and check.month == mon:
                upcoming.append({
                    'customer_id': r['id'],
                    'phone':       r['phone'],
                    'name':        r['name'] or '',
                    'birthday':    bd_str,
                    'days_until':  delta,
                    'is_today':    delta == 0,
                })
                break
    upcoming.sort(key=lambda x: x['days_until'])
    return upcoming


def get_reengagement_customers(days_inactive: int = 30, limit: int = 20) -> list:
    """
    Клієнти що не замовляли більше days_inactive днів — кандидати для повторного залучення.
    """
    conn = get_conn()
    rows = conn.execute('''
        SELECT c.id, c.phone, c.name, c.total_orders, c.total_spent,
               MAX(date(o.order_date)) AS last_order_date,
               julianday('now') - julianday(MAX(o.order_date)) AS days_ago
        FROM customers c
        JOIN orders o ON o.customer_id = c.id
          AND (o.deleted IS NULL OR o.deleted=0)
        WHERE c.blocked = 0
        GROUP BY c.id
        HAVING days_ago >= ?
        ORDER BY days_ago DESC
        LIMIT ?
    ''', (days_inactive, limit)).fetchall()
    conn.close()
    return [{'customer_id': r['id'], 'phone': r['phone'], 'name': r['name'] or '',
             'total_orders': r['total_orders'], 'total_spent': round(r['total_spent'] or 0, 2),
             'last_order_date': r['last_order_date'],
             'days_ago': int(r['days_ago'] or 0)}
            for r in rows]


def get_vip_candidates(min_orders: int = 5, limit: int = 15) -> list:
    """
    Клієнти з >=min_orders замовленнями без VIP-статусу — кандидати для підвищення.
    """
    conn = get_conn()
    rows = conn.execute('''
        SELECT id, phone, name, total_orders, total_spent
        FROM customers
        WHERE total_orders >= ? AND vip = 0 AND blocked = 0
        ORDER BY total_orders DESC, total_spent DESC
        LIMIT ?
    ''', (min_orders, limit)).fetchall()
    conn.close()
    return [{'customer_id': r['id'], 'phone': r['phone'], 'name': r['name'] or '',
             'total_orders': r['total_orders'], 'total_spent': round(r['total_spent'] or 0, 2)}
            for r in rows]


# ─── Reminders CRUD ───────────────────────────────────────

def get_reminders(done: bool = False, limit: int = 50) -> list:
    """Список нагадувань (за замовчуванням — тільки невиконані)."""
    conn = get_conn()
    rows = conn.execute('''
        SELECT r.*, c.name AS customer_name
        FROM reminders r
        LEFT JOIN customers c ON c.id = r.customer_id
        WHERE r.done = ?
        ORDER BY COALESCE(r.due_date, date('now')), r.due_time, r.created_at
        LIMIT ?
    ''', (1 if done else 0, limit)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def create_reminder(data: dict, actor_id: int = 0) -> dict:
    """Створює нагадування. data: {type, customer_id?, phone?, text, due_date?, due_time?}"""
    conn = get_conn()
    try:
        text = (data.get('text') or '').strip()
        if not text:
            return {'ok': False, 'error': 'Текст нагадування обов\'язковий'}
        cur = conn.execute('''
            INSERT INTO reminders (type, customer_id, phone, text, due_date, due_time, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (data.get('type', 'callback'),
              data.get('customer_id'),
              data.get('phone'),
              text,
              data.get('due_date'),
              data.get('due_time'),
              actor_id))
        rid = cur.lastrowid
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, 'operator', 'reminder', rid, 'create', None,
             json.dumps({'text': text, 'type': data.get('type', 'callback')}, ensure_ascii=False))
        )
        conn.commit()
        return {'ok': True, 'id': rid}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def complete_reminder(reminder_id: int, actor_id: int = 0) -> dict:
    """Позначає нагадування як виконане."""
    conn = get_conn()
    try:
        row = conn.execute('SELECT * FROM reminders WHERE id=?', (reminder_id,)).fetchone()
        if not row:
            return {'ok': False, 'error': 'NOT_FOUND'}
        conn.execute(
            'UPDATE reminders SET done=1, done_at=CURRENT_TIMESTAMP, done_by=? WHERE id=?',
            (actor_id, reminder_id)
        )
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, 'operator', 'reminder', reminder_id, 'complete',
             json.dumps(dict(row), ensure_ascii=False, default=str), None)
        )
        conn.commit()
        return {'ok': True}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def get_due_reminders() -> list:
    """Повертає невиконані нагадування, час яких настав і які ще не були відправлені в TG."""
    conn = get_conn()
    rows = conn.execute('''
        SELECT r.*, c.name AS customer_name
        FROM reminders r
        LEFT JOIN customers c ON c.id = r.customer_id
        WHERE r.done = 0
          AND r.tg_sent = 0
          AND (
            -- прострочені (минула дата) — надсилати одразу
            (r.due_date IS NOT NULL AND r.due_date < date('now'))
            OR
            -- сьогодні (NULL або сьогоднішня дата) і час настав
            (
              (r.due_date IS NULL OR r.due_date = date('now'))
              AND (r.due_time IS NULL OR r.due_time <= strftime('%H:%M', 'now', 'localtime'))
            )
          )
        ORDER BY r.due_date, r.due_time
    ''').fetchall()
    conn.close()
    return [dict(r) for r in rows]


def mark_reminder_tg_sent(reminder_id: int) -> None:
    """Позначає нагадування як відправлене в Telegram."""
    conn = get_conn()
    try:
        conn.execute(
            "UPDATE reminders SET tg_sent=1, tg_sent_at=CURRENT_TIMESTAMP WHERE id=?",
            (reminder_id,)
        )
        conn.commit()
    finally:
        conn.close()


# ─── Order Tags ────────────────────────────────────────────

VALID_TAGS = {'urgent', 'allergy', 'vip', 'problem'}

def set_order_tags(order_id: int, tags: list, actor_id: int = 0, actor_role: str = 'operator') -> dict:
    """Встановлює теги замовлення. tags — список рядків із VALID_TAGS."""
    clean = [t for t in tags if t in VALID_TAGS]
    tags_str = ','.join(clean)
    conn = get_conn()
    try:
        row = conn.execute('SELECT tags FROM orders WHERE id=?', (order_id,)).fetchone()
        if not row:
            return {'ok': False, 'error': 'NOT_FOUND'}
        before = row['tags'] or ''
        conn.execute('UPDATE orders SET tags=? WHERE id=?', (tags_str, order_id))
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'order', order_id, 'tags',
             json.dumps({'tags': before}, ensure_ascii=False),
             json.dumps({'tags': tags_str}, ensure_ascii=False))
        )
        conn.commit()
        return {'ok': True, 'tags': tags_str}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


# ─── Bulk Actions ──────────────────────────────────────────

def bulk_assign_courier(order_ids: list, courier_id, actor_id: int = 0, actor_role: str = 'manager') -> dict:
    """Призначає кур'єра для списку замовлень (пропускає видалені)."""
    if not order_ids:
        return {'ok': True, 'updated': 0}
    conn = get_conn()
    try:
        updated = 0
        for oid in order_ids:
            row = conn.execute('SELECT * FROM orders WHERE id=? AND (deleted IS NULL OR deleted=0)', (oid,)).fetchone()
            if not row:
                continue
            before = dict(row)
            conn.execute('UPDATE orders SET courier_id=? WHERE id=?', (courier_id, oid))
            conn.execute(
                'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) VALUES (?,?,?,?,?,?,?)',
                (actor_id, actor_role, 'order', oid, 'update',
                 json.dumps({'courier_id': before.get('courier_id')}, ensure_ascii=False),
                 json.dumps({'courier_id': courier_id}, ensure_ascii=False))
            )
            updated += 1
        conn.commit()
        return {'ok': True, 'updated': updated}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def bulk_update_status(order_ids: list, new_status: str, actor_id: int = 0, actor_role: str = 'manager') -> dict:
    """Змінює статус для списку замовлень через state machine. Повертає скільки оновлено/пропущено."""
    import business_logic as _bl
    if not order_ids:
        return {'ok': True, 'updated': 0, 'skipped': 0}
    conn = get_conn()
    try:
        updated = skipped = 0
        for oid in order_ids:
            row = conn.execute('SELECT * FROM orders WHERE id=? AND (deleted IS NULL OR deleted=0)', (oid,)).fetchone()
            if not row:
                skipped += 1; continue
            cur = row['status'] or 'new'
            allowed = _bl.allowed_transitions(cur)
            if new_status not in allowed:
                skipped += 1; continue
            conn.execute('UPDATE orders SET status=? WHERE id=?', (new_status, oid))
            conn.execute(
                'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) VALUES (?,?,?,?,?,?,?)',
                (actor_id, actor_role, 'order', oid, 'status_change',
                 json.dumps({'status': cur}, ensure_ascii=False),
                 json.dumps({'status': new_status}, ensure_ascii=False))
            )
            updated += 1
        conn.commit()
        return {'ok': True, 'updated': updated, 'skipped': skipped}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


# ─── Global Search ─────────────────────────────────────────

def global_search(q: str, limit: int = 5) -> dict:
    """
    Шукає одразу по замовленнях, клієнтах і кур'єрах.
    Повертає {'orders': [...], 'customers': [...], 'couriers': [...]}.
    """
    if not q or not q.strip():
        return {'orders': [], 'customers': [], 'couriers': []}
    conn  = get_conn()
    like  = f'%{q.strip()}%'
    is_id = q.strip().lstrip('#').isdigit()
    id_val = int(q.strip().lstrip('#')) if is_id else -1

    # Orders
    orders = conn.execute('''
        SELECT o.id, o.order_date, o.cust_phone, o.order_phone,
               o.amount, o.status, o.city, o.address, o.items,
               c.name AS cust_name
        FROM orders o
        LEFT JOIN customers c ON c.phone = o.cust_phone
        WHERE (o.deleted IS NULL OR o.deleted=0)
          AND (
            o.id=?
            OR o.cust_phone LIKE ?
            OR o.order_phone LIKE ?
            OR o.address    LIKE ?
            OR o.items      LIKE ?
            OR o.comment    LIKE ?
          )
        ORDER BY o.order_date DESC
        LIMIT ?
    ''', (id_val, like, like, like, like, like, limit)).fetchall()

    # Customers
    customers = conn.execute('''
        SELECT id, phone, name, total_orders, total_spent, vip, blocked
        FROM customers
        WHERE (deleted IS NULL OR deleted=0)
          AND (phone LIKE ? OR name LIKE ?)
        ORDER BY total_orders DESC
        LIMIT ?
    ''', (like, like, limit)).fetchall()

    # Couriers
    couriers = conn.execute('''
        SELECT id, name, phone, active
        FROM couriers
        WHERE name LIKE ? OR phone LIKE ?
        LIMIT ?
    ''', (like, like, limit)).fetchall()

    conn.close()

    STATUS_UK = {
        'new': 'Новий', 'confirmed': 'Підтверджено', 'cooking': 'Готується',
        'on_way': 'В дорозі', 'delivered': 'Доставлено', 'cancelled': 'Скасовано',
    }

    return {
        'orders': [{
            'id':      r['id'],
            'date':    (r['order_date'] or '')[:10],
            'phone':   r['cust_phone'] or r['order_phone'] or '',
            'name':    r['cust_name'] or '',
            'amount':  r['amount'] or 0,
            'status':  r['status'] or 'new',
            'status_label': STATUS_UK.get(r['status'] or 'new', r['status'] or ''),
            'city':    r['city'] or '',
            'address': r['address'] or '',
            'items':   (r['items'] or '')[:60],
        } for r in orders],
        'customers': [{
            'id':           r['id'],
            'phone':        r['phone'] or '',
            'name':         r['name'] or '',
            'total_orders': r['total_orders'] or 0,
            'total_spent':  r['total_spent'] or 0,
            'vip':          r['vip'] or 0,
            'blocked':      r['blocked'] or 0,
        } for r in customers],
        'couriers': [{
            'id':     r['id'],
            'name':   r['name'] or '',
            'phone':  r['phone'] or '',
            'active': r['active'] if r['active'] is not None else 1,
        } for r in couriers],
    }


# ─── Courier Salary ────────────────────────────────────────

def get_courier_rate(courier_id: int) -> float:
    """Ставка кур'єра за одну доставку (грн)."""
    conn = get_conn()
    row = conn.execute('SELECT rate FROM courier_rates WHERE courier_id=?', (courier_id,)).fetchone()
    conn.close()
    return float(row['rate']) if row else 0.0


def set_courier_rate(courier_id: int, rate: float, actor_id: int = 0, actor_role: str = 'manager') -> dict:
    """Встановлює або оновлює ставку кур'єра."""
    conn = get_conn()
    try:
        old_rate = get_courier_rate(courier_id)
        conn.execute('''
            INSERT INTO courier_rates (courier_id, rate, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(courier_id) DO UPDATE SET rate=excluded.rate, updated_at=CURRENT_TIMESTAMP
        ''', (courier_id, rate))
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'courier', courier_id, 'set_rate',
             json.dumps({'rate': old_rate}, ensure_ascii=False),
             json.dumps({'rate': rate}, ensure_ascii=False))
        )
        conn.commit()
        return {'ok': True}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def get_courier_salary(courier_id: int, date_from: str, date_to: str) -> dict:
    """
    Розраховує зарплату кур'єра за період.
    Рахує тільки delivered замовлення типу delivery.
    """
    conn = get_conn()
    rate_row = conn.execute('SELECT rate FROM courier_rates WHERE courier_id=?', (courier_id,)).fetchone()
    rate = float(rate_row['rate']) if rate_row else 0.0

    row = conn.execute('''
        SELECT COUNT(*) AS deliveries, COALESCE(SUM(amount), 0) AS order_sum
        FROM orders
        WHERE courier_id = ?
          AND status = 'delivered'
          AND delivery_type = 'delivery'
          AND (deleted IS NULL OR deleted = 0)
          AND date(order_date) >= ?
          AND date(order_date) <= ?
    ''', (courier_id, date_from, date_to)).fetchone()

    deliveries = row['deliveries'] or 0
    earned = round(deliveries * rate, 2)

    # Виплачено за цей же період
    paid_row = conn.execute('''
        SELECT COALESCE(SUM(amount), 0) AS paid
        FROM courier_payouts
        WHERE courier_id = ?
          AND date(paid_at) >= ?
          AND date(paid_at) <= ?
    ''', (courier_id, date_from, date_to)).fetchone()
    paid = round(float(paid_row['paid'] or 0), 2)

    # Деталі доставок
    orders = conn.execute('''
        SELECT o.id, o.order_date, o.amount, o.city, o.address
        FROM orders o
        WHERE o.courier_id = ?
          AND o.status = 'delivered'
          AND o.delivery_type = 'delivery'
          AND (o.deleted IS NULL OR o.deleted = 0)
          AND date(o.order_date) >= ?
          AND date(o.order_date) <= ?
        ORDER BY o.order_date DESC
    ''', (courier_id, date_from, date_to)).fetchall()

    conn.close()
    return {
        'courier_id':  courier_id,
        'date_from':   date_from,
        'date_to':     date_to,
        'rate':        rate,
        'deliveries':  deliveries,
        'earned':      earned,
        'paid':        paid,
        'balance':     round(earned - paid, 2),
        'orders':      [dict(r) for r in orders],
    }


def get_salary_summary(date_from: str, date_to: str) -> list:
    """Підсумок по всіх активних кур'єрах за період."""
    conn = get_conn()
    couriers = conn.execute(
        'SELECT id, name, phone FROM couriers WHERE active=1 ORDER BY name'
    ).fetchall()
    conn.close()
    result = []
    for c in couriers:
        s = get_courier_salary(c['id'], date_from, date_to)
        s['name']  = c['name']
        s['phone'] = c['phone'] or ''
        result.append(s)
    return result


def record_payout(courier_id: int, amount: float, date_from: str, date_to: str,
                  deliveries: int = 0, note: str = '',
                  actor_id: int = 0, actor_role: str = 'manager') -> dict:
    """Записує виплату кур'єру та логує."""
    conn = get_conn()
    try:
        cur = conn.execute('''
            INSERT INTO courier_payouts
                (courier_id, amount, deliveries, period_from, period_to, note, actor_id, actor_role)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (courier_id, amount, deliveries, date_from, date_to, note, actor_id, actor_role))
        pid = cur.lastrowid
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) VALUES (?,?,?,?,?,?,?)',
            (actor_id, actor_role, 'courier', courier_id, 'payout', None,
             json.dumps({'payout_id': pid, 'amount': amount, 'period_from': date_from,
                         'period_to': date_to, 'deliveries': deliveries, 'note': note},
                        ensure_ascii=False))
        )
        conn.commit()
        return {'ok': True, 'payout_id': pid}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def import_customers_csv(rows: list, actor_id: int = 0) -> dict:
    """
    Масовий імпорт клієнтів.
    rows — список dicts: {phone, name?, notes?, birthday?}
    Пропускає рядки без phone або з некоректним номером.
    Повертає {ok, imported, skipped, errors}.
    """
    conn = get_conn()
    imported = skipped = 0
    errors   = []
    try:
        for i, row in enumerate(rows):
            phone_raw = str(row.get('phone') or '').strip()
            phone = _normalize_phone(phone_raw)
            if not phone:
                skipped += 1
                errors.append(f'Рядок {i+1}: некоректний телефон «{phone_raw}»')
                continue
            name     = str(row.get('name') or '').strip()
            notes    = str(row.get('notes') or '').strip()
            birthday = str(row.get('birthday') or '').strip()
            # INSERT OR IGNORE — не перезаписуємо існуючих клієнтів
            cur = conn.execute('''
                INSERT OR IGNORE INTO customers (phone, name, notes, birthday)
                VALUES (?, ?, ?, ?)
            ''', (phone, name or None, notes or None, birthday or None))
            if cur.rowcount:
                conn.execute(
                    'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
                    'VALUES (?,?,?,?,?,?,?)',
                    (actor_id, 'manager', 'customer', cur.lastrowid, 'import',
                     None, json.dumps({'phone': phone, 'name': name}, ensure_ascii=False))
                )
                imported += 1
            else:
                skipped += 1
        conn.commit()
        return {'ok': True, 'imported': imported, 'skipped': skipped, 'errors': errors[:20]}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e), 'imported': 0, 'skipped': 0, 'errors': []}
    finally:
        conn.close()


def get_order_timeline(order_id: int) -> list:
    """
    Повертає хронологію дій із action_logs для конкретного замовлення.
    Включає: create, status→*, assign_courier, delete, tags, update.
    """
    conn = get_conn()
    rows = conn.execute('''
        SELECT action, before, after, actor_role, created_at
        FROM action_logs
        WHERE entity_type = 'order' AND entity_id = ?
        ORDER BY created_at ASC
    ''', (order_id,)).fetchall()
    conn.close()
    result = []
    for r in rows:
        try:
            before = json.loads(r['before']) if r['before'] else {}
        except Exception:
            before = {}
        try:
            after = json.loads(r['after']) if r['after'] else {}
        except Exception:
            after = {}
        result.append({
            'action':     r['action'],
            'actor_role': r['actor_role'] or 'system',
            'created_at': r['created_at'] or '',
            'before':     before,
            'after':      after,
        })
    return result


def get_payout_history(courier_id: int, limit: int = 30) -> list:
    """Останні виплати кур'єра."""
    conn = get_conn()
    rows = conn.execute('''
        SELECT * FROM courier_payouts
        WHERE courier_id = ?
        ORDER BY paid_at DESC
        LIMIT ?
    ''', (courier_id, limit)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


# ─── Shift Report ──────────────────────────────────────────

def get_shift_report(date_from: str, date_to: str,
                     time_from: str = '', time_to: str = '') -> dict:
    """
    Повертає зведений звіт за зміну/день.
    date_from / date_to: 'YYYY-MM-DD'
    time_from / time_to: 'HH:MM' (необов'язково)
    """
    conn = get_conn()

    ts_from = f"{date_from} {time_from or '00:00'}:00"
    ts_to   = f"{date_to} {time_to or '23:59'}:59"

    base_where = "(deleted IS NULL OR deleted=0) AND order_date >= ? AND order_date <= ?"
    base_p     = [ts_from, ts_to]

    # ── Загальні метрики ──────────────────────────────────────
    row = conn.execute(
        f"SELECT COUNT(*) cnt, COALESCE(SUM(amount),0) revenue "
        f"FROM orders WHERE {base_where}",
        base_p
    ).fetchone()
    total_orders  = row['cnt']
    total_revenue = round(float(row['revenue']), 2)

    # ── По статусах ───────────────────────────────────────────
    status_rows = conn.execute(
        f"SELECT status, COUNT(*) cnt, COALESCE(SUM(amount),0) rev "
        f"FROM orders WHERE {base_where} GROUP BY status",
        base_p
    ).fetchall()
    by_status = {r['status']: {'cnt': r['cnt'], 'rev': round(float(r['rev']), 2)}
                 for r in status_rows}

    # ── По типу оплати ────────────────────────────────────────
    pay_rows = conn.execute(
        f"SELECT payment_type, COUNT(*) cnt, COALESCE(SUM(amount),0) rev "
        f"FROM orders WHERE {base_where} AND (deleted IS NULL OR deleted=0) "
        f"AND status='delivered' "
        f"GROUP BY payment_type",
        [ts_from, ts_to]
    ).fetchall()
    by_payment = {(r['payment_type'] or 'Не вказано'): {'cnt': r['cnt'], 'rev': round(float(r['rev']), 2)}
                  for r in pay_rows}

    # ── По містах ─────────────────────────────────────────────
    city_rows = conn.execute(
        f"SELECT COALESCE(NULLIF(city,''),'(не вказано)') city, COUNT(*) cnt, "
        f"COALESCE(SUM(amount),0) rev "
        f"FROM orders WHERE {base_where} GROUP BY city ORDER BY cnt DESC LIMIT 10",
        base_p
    ).fetchall()
    by_city = [{'city': r['city'], 'cnt': r['cnt'], 'rev': round(float(r['rev']), 2)}
               for r in city_rows]

    # ── По кур'єрах ───────────────────────────────────────────
    courier_rows = conn.execute(
        f"SELECT c.name courier_name, COUNT(*) cnt, COALESCE(SUM(o.amount),0) rev "
        f"FROM orders o LEFT JOIN couriers c ON c.id=o.courier_id "
        f"WHERE {base_where.replace('deleted', 'o.deleted').replace('order_date', 'o.order_date')} "
        f"AND o.courier_id IS NOT NULL "
        f"GROUP BY o.courier_id ORDER BY cnt DESC",
        base_p
    ).fetchall()
    by_courier = [{'name': r['courier_name'] or '—', 'cnt': r['cnt'], 'rev': round(float(r['rev']), 2)}
                  for r in courier_rows]

    # ── Топ позиції (парсинг items текстом) ───────────────────
    items_rows = conn.execute(
        f"SELECT items FROM orders WHERE {base_where} AND items IS NOT NULL AND items!=''",
        base_p
    ).fetchall()
    items_counter: dict = {}
    for row in items_rows:
        raw = row['items'] or ''
        for part in raw.split(','):
            part = part.strip()
            if not part:
                continue
            # "Назва х2" або "Назва x2" або "Назва 2шт" → нормалізуємо
            import re as _re
            m = _re.match(r'^(.+?)\s*[xXхХ×*]\s*(\d+)$', part)
            if m:
                name = m.group(1).strip()
                qty  = int(m.group(2))
            else:
                # "Назва 2" in the end
                m2 = _re.match(r'^(.+?)\s+(\d+)$', part)
                if m2:
                    name = m2.group(1).strip()
                    qty  = int(m2.group(2))
                else:
                    name = part
                    qty  = 1
            if name:
                items_counter[name] = items_counter.get(name, 0) + qty
    top_items = sorted(items_counter.items(), key=lambda x: -x[1])[:10]

    # ── Нові клієнти за зміну ─────────────────────────────────
    new_custs = conn.execute(
        "SELECT COUNT(*) cnt FROM customers WHERE created_at >= ? AND created_at <= ?",
        [ts_from, ts_to]
    ).fetchone()['cnt']

    # ── Погодинний розподіл ───────────────────────────────────
    hour_rows = conn.execute(
        f"SELECT strftime('%H', order_date) hr, COUNT(*) cnt, COALESCE(SUM(amount),0) rev "
        f"FROM orders WHERE {base_where} GROUP BY hr ORDER BY hr",
        base_p
    ).fetchall()
    by_hour = [{'hour': r['hr'], 'cnt': r['cnt'], 'rev': round(float(r['rev']), 2)}
               for r in hour_rows]

    # ── Середній чек ─────────────────────────────────────────
    delivered_cnt = by_status.get('delivered', {}).get('cnt', 0)
    delivered_rev = by_status.get('delivered', {}).get('rev', 0.0)
    avg_order = round(delivered_rev / delivered_cnt, 2) if delivered_cnt else 0.0

    conn.close()
    return {
        'period':         {'from': ts_from, 'to': ts_to},
        'total_orders':   total_orders,
        'total_revenue':  total_revenue,
        'avg_order':      avg_order,
        'new_customers':  new_custs,
        'by_status':      by_status,
        'by_payment':     by_payment,
        'by_city':        by_city,
        'by_courier':     by_courier,
        'top_items':      [{'name': n, 'qty': q} for n, q in top_items],
        'by_hour':        by_hour,
    }


# ─── Action Logs ──────────────────────────────────────────

# ─── Password hashing (PBKDF2-SHA256, 600k iterations) ────

def _hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    dk   = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode(), 600_000)
    return f'pbkdf2:sha256:600000:{salt}:{dk.hex()}'


def _verify_password(password: str, stored_hash: str) -> bool:
    try:
        parts = stored_hash.split(':')
        if parts[0] == 'pbkdf2' and parts[1] == 'sha256':
            iterations = int(parts[2])
            salt       = parts[3]
            dk_hex     = parts[4]
            dk = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode(), iterations)
            return _hmac.compare_digest(dk.hex(), dk_hex)
        return False
    except Exception:
        return False


# ─── Users ────────────────────────────────────────────────

VALID_ROLES = {
    'owner', 'director', 'investor', 'logistics',
    'senior_operator', 'operator', 'admin', 'cashier', 'cook', 'courier'
}

# Ролі що бачать замовлення всіх міст (location=NULL)
GLOBAL_ROLES = {'owner', 'director', 'investor', 'logistics', 'senior_operator', 'operator'}


def ensure_first_owner() -> dict | None:
    """Якщо таблиця users порожня — створює першого owner з випадковим паролем."""
    conn = get_conn()
    count = conn.execute('SELECT COUNT(*) FROM users').fetchone()[0]
    conn.close()
    if count > 0:
        return None

    import random, string
    password = ''.join(random.choices(string.ascii_letters + string.digits, k=12))
    pw_hash  = _hash_password(password)

    conn = get_conn()
    try:
        cur = conn.execute(
            'INSERT INTO users (login, password_hash, role, display_name, is_active) VALUES (?,?,?,?,1)',
            ('admin', pw_hash, 'owner', 'Власник')
        )
        user_id = cur.lastrowid
        conn.commit()
    finally:
        conn.close()

    print('=' * 60)
    print('  🔑  ПЕРШИЙ ЗАПУСК — обліковий запис власника')
    print(f'  Логін:    admin')
    print(f'  Пароль:   {password}')
    print('  Змініть пароль після першого входу!')
    print('=' * 60)
    return {'login': 'admin', 'password': password, 'user_id': user_id}


def get_user_by_login(login: str) -> dict | None:
    conn = get_conn()
    row  = conn.execute('SELECT * FROM users WHERE login=? COLLATE NOCASE', (login.strip(),)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_user_by_id(user_id: int) -> dict | None:
    conn = get_conn()
    row  = conn.execute('SELECT * FROM users WHERE id=?', (user_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def authenticate_user(login: str, password: str) -> dict | None:
    """Перевіряє логін+пароль. Повертає user dict (без hash) або None."""
    user = get_user_by_login(login)
    if not user or not user['is_active']:
        return None
    if not _verify_password(password, user['password_hash']):
        return None
    conn = get_conn()
    conn.execute('UPDATE users SET last_login=CURRENT_TIMESTAMP WHERE id=?', (user['id'],))
    conn.commit()
    conn.close()
    user.pop('password_hash', None)
    return user


def create_user(login: str, password: str, role: str, display_name: str = '',
                location: str = None, courier_id: int = None,
                actor_id: int = 0) -> dict:
    if role not in VALID_ROLES:
        return {'ok': False, 'error': f'Невалідна роль: {role}'}
    if not login.strip():
        return {'ok': False, 'error': 'Логін обов\'язковий'}
    if len(password) < 6:
        return {'ok': False, 'error': 'Пароль мінімум 6 символів'}
    pw_hash = _hash_password(password)
    conn = get_conn()
    try:
        cur = conn.execute(
            'INSERT INTO users (login, password_hash, role, display_name, location, courier_id, created_by) '
            'VALUES (?,?,?,?,?,?,?)',
            (login.strip(), pw_hash, role, (display_name or '').strip(), location, courier_id, actor_id or None)
        )
        new_id = cur.lastrowid
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, 'system', 'user', new_id, 'create', None,
             json.dumps({'login': login, 'role': role}, ensure_ascii=False))
        )
        conn.commit()
        return {'ok': True, 'id': new_id}
    except Exception as e:
        conn.rollback()
        if 'UNIQUE' in str(e):
            return {'ok': False, 'error': 'Логін вже зайнятий'}
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def list_users(include_inactive: bool = False) -> list:
    conn = get_conn()
    q = ('SELECT id, login, role, display_name, location, courier_id, '
         'is_active, created_at, last_login FROM users')
    if not include_inactive:
        q += ' WHERE is_active=1'
    q += ' ORDER BY role, login'
    rows = conn.execute(q).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_user(user_id: int, fields: dict, actor_id: int = 0) -> dict:
    ALLOWED = {'display_name', 'role', 'location', 'courier_id', 'is_active', 'theme'}
    conn = get_conn()
    try:
        old = conn.execute('SELECT * FROM users WHERE id=?', (user_id,)).fetchone()
        if not old:
            return {'ok': False, 'error': 'NOT_FOUND'}
        updates, vals = [], []
        for k, v in fields.items():
            if k in ALLOWED:
                updates.append(f'{k}=?'); vals.append(v)
        if 'password' in fields:
            pw = str(fields['password'])
            if len(pw) < 6:
                return {'ok': False, 'error': 'Пароль мінімум 6 символів'}
            updates.append('password_hash=?'); vals.append(_hash_password(pw))
        if not updates:
            return {'ok': False, 'error': 'Нічого оновлювати'}
        vals.append(user_id)
        conn.execute(f'UPDATE users SET {", ".join(updates)} WHERE id=?', vals)
        conn.execute(
            'INSERT INTO action_logs (actor_id, actor_role, entity_type, entity_id, action, before, after) '
            'VALUES (?,?,?,?,?,?,?)',
            (actor_id, 'system', 'user', user_id, 'update',
             json.dumps({k: dict(old).get(k) for k in fields if k != 'password'}, ensure_ascii=False),
             json.dumps({k: fields[k] for k in fields if k != 'password'}, ensure_ascii=False))
        )
        conn.commit()
        return {'ok': True}
    except Exception as e:
        conn.rollback()
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


# ─── Sessions ─────────────────────────────────────────────

_SESSION_TTL_SEC = 8 * 3600   # 8 годин


def create_session_record(user_id: int, token: str, ip: str = '') -> int:
    """Зберігає SHA-256 хеш токена в sessions. Повертає session id."""
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    expires    = datetime.utcnow() + timedelta(seconds=_SESSION_TTL_SEC)
    conn = get_conn()
    try:
        cur = conn.execute(
            'INSERT INTO sessions (user_id, token_hash, expires_at, ip) VALUES (?,?,?,?)',
            (user_id, token_hash, expires.strftime('%Y-%m-%d %H:%M:%S'), ip)
        )
        sid = cur.lastrowid
        conn.commit()
        # Залишаємо тільки 5 активних сесій на юзера
        conn.execute('''
            DELETE FROM sessions
            WHERE user_id=? AND revoked=0 AND id NOT IN (
                SELECT id FROM sessions WHERE user_id=? AND revoked=0
                ORDER BY created_at DESC LIMIT 5
            )
        ''', (user_id, user_id))
        conn.commit()
        return sid
    finally:
        conn.close()


def check_session_active(token: str) -> bool:
    """True якщо сесія є в БД, не відкликана і не прострочена."""
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    conn = get_conn()
    row = conn.execute(
        "SELECT id FROM sessions WHERE token_hash=? AND revoked=0 AND expires_at > datetime('now')",
        (token_hash,)
    ).fetchone()
    conn.close()
    return row is not None


def revoke_session_record(token: str) -> None:
    """Відкликає сесію по токену (logout)."""
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    conn = get_conn()
    try:
        conn.execute('UPDATE sessions SET revoked=1 WHERE token_hash=?', (token_hash,))
        conn.commit()
    finally:
        conn.close()


def revoke_all_user_sessions(user_id: int) -> None:
    """Відкликає всі сесії юзера (зміна пароля / деактивація)."""
    conn = get_conn()
    try:
        conn.execute('UPDATE sessions SET revoked=1 WHERE user_id=?', (user_id,))
        conn.commit()
    finally:
        conn.close()


def get_action_logs(entity_type: str = '', action: str = '', actor_id: int = 0,
                    date_from: str = '', date_to: str = '',
                    limit: int = 100, offset: int = 0) -> dict:
    """Повертає action_logs з фільтрами для /admin/logs."""
    conn = get_conn()
    where, params = ['1=1'], []
    if entity_type:
        where.append('entity_type=?'); params.append(entity_type)
    if action:
        where.append('action LIKE ?'); params.append(f'%{action}%')
    if actor_id:
        where.append('actor_id=?'); params.append(actor_id)
    if date_from:
        where.append("date(created_at)>=?"); params.append(date_from)
    if date_to:
        where.append("date(created_at)<=?"); params.append(date_to)

    total = conn.execute(
        f'SELECT COUNT(*) FROM action_logs WHERE {" AND ".join(where)}', params
    ).fetchone()[0]

    rows = conn.execute(
        f'SELECT * FROM action_logs WHERE {" AND ".join(where)} '
        f'ORDER BY id DESC LIMIT ? OFFSET ?',
        params + [limit, offset]
    ).fetchall()
    conn.close()
    return {'total': total, 'items': [dict(r) for r in rows]}
