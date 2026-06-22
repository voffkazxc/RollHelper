"""
RollHouse PRO — Business Logic Layer
=====================================
Чисті функції без Flask/SQLite залежностей.
Все що стосується правил — тут. app.py лише викликає.

UC-01  duplicate_order_check   — попередження якщо >1 замовлення за 5 хв
UC-02  validate_order          — валідація полів перед збереженням
UC-03  transition_status       — state machine статусів замовлення
UC-04  check_birthday_today    — перевірка дня народження клієнта
UC-05  suggest_promo           — авто-промо на основі кількості замовлень
"""

from datetime import datetime, timedelta
import re

# ──────────────────────────────────────────────
#  Константи
# ──────────────────────────────────────────────

DUPLICATE_WINDOW_MIN = 5          # хвилин між замовленнями = підозрілий дублікат

# Дозволені міста/точки. Порожній рядок = не вказано (дозволено для pickup)
ALLOWED_CITIES = {'Колл Центр', 'Мерефа', 'Чугуїв', 'Берестин', ''}

# Дозволені переходи статусів: ключ → множина куди можна
STATUS_TRANSITIONS = {
    'new':       {'confirmed', 'cancelled'},
    'confirmed': {'cooking', 'cancelled'},
    'cooking':   {'on_way', 'cancelled'},
    'on_way':    {'delivered', 'cancelled'},
    'delivered': set(),            # термінальний
    'cancelled': set(),            # термінальний
}

STATUS_LABELS = {
    'new':       'Новий',
    'confirmed': 'Підтверджено',
    'cooking':   'Готується',
    'on_way':    'В дорозі',
    'delivered': 'Доставлено',
    'cancelled': 'Скасовано',
}

MIN_ORDER_AMOUNT = 1     # грн — захист від нульових замовлень

# Промо: кожні N замовлень — подарунок
PROMO_MILESTONES = {
    5:  '🎁 5-е замовлення — безкоштовний ролл',
    10: '🎁 10-е замовлення — знижка 10%',
    20: '🎁 20-е замовлення — VIP-статус',
    50: '🎁 50-е замовлення — персональний бонус',
}


# ──────────────────────────────────────────────
#  UC-01  Duplicate order check
# ──────────────────────────────────────────────

def duplicate_order_check(recent_orders: list) -> dict:
    """
    Перевіряє чи є серед останніх замовлень клієнта дублікат
    (замовлення створене менш ніж DUPLICATE_WINDOW_MIN хвилин тому).

    recent_orders — список dict з полями: id, order_date, amount, deleted
    Повертає:
        {'duplicate': False}
        {'duplicate': True, 'order_id': X, 'minutes_ago': Y, 'amount': Z}
    """
    now = datetime.utcnow()
    cutoff = now - timedelta(minutes=DUPLICATE_WINDOW_MIN)

    for order in recent_orders:
        # Пропускаємо видалені
        if order.get('deleted'):
            continue
        date_str = order.get('order_date') or ''
        try:
            # SQLite зберігає як 'YYYY-MM-DD HH:MM:SS'
            order_dt = datetime.strptime(date_str[:19], '%Y-%m-%d %H:%M:%S')
        except ValueError:
            continue
        if order_dt >= cutoff:
            minutes_ago = max(0, int((now - order_dt).total_seconds() / 60))
            return {
                'duplicate': True,
                'order_id': order.get('id'),
                'minutes_ago': minutes_ago,
                'amount': order.get('amount'),
                'warning': f'Увага! Є замовлення #{order.get("id")} '
                           f'({minutes_ago} хв тому, '
                           f'{order.get("amount") or "?"} грн). '
                           f'Можливий дублікат.',
            }
    return {'duplicate': False}


# ──────────────────────────────────────────────
#  UC-02  Order validation
# ──────────────────────────────────────────────

def validate_order(data: dict, customer: dict = None) -> dict:
    """
    Валідує поля замовлення.
    customer — dict клієнта (з БД) якщо вже резолвлений.
    Повертає {'valid': True} або {'valid': False, 'errors': [...], 'blocked': bool}
    """
    errors = []

    # P2: blocked — HARD BLOCK, перевіряємо першим
    if customer and customer.get('blocked'):
        reason = (customer.get('blocked_reason') or '').strip()
        msg = '🚫 КЛІЄНТ ЗАБЛОКОВАНИЙ'
        if reason:
            msg += f': {reason}'
        return {'valid': False, 'errors': [msg], 'blocked': True}

    # Телефон обов'язковий
    phone = (data.get('phone') or '').strip()
    if not phone:
        if not data.get('customer_id'):
            errors.append('Телефон або customer_id обов\'язковий')

    # Сума
    amount = data.get('amount')
    if amount is not None:
        try:
            amount = float(amount)
            if amount < MIN_ORDER_AMOUNT:
                errors.append(f'Сума замовлення не може бути менше {MIN_ORDER_AMOUNT} грн')
            if amount > 50000:
                errors.append('Сума замовлення виглядає підозріло великою (>50 000 грн)')
        except (TypeError, ValueError):
            errors.append('Сума замовлення має бути числом')

    # Час готовності — формат HH:MM якщо переданий
    ready_time = (data.get('ready_time') or '').strip()
    if ready_time:
        if not re.match(r'^\d{1,2}:\d{2}$', ready_time):
            errors.append('Час готовності має бути у форматі HH:MM')

    # Тип оплати — якщо переданий, має бути зі списку
    payment_type = (data.get('payment_type') or '').strip()
    allowed_payments = {'cash', 'card', 'online', ''}
    if payment_type.lower() not in allowed_payments:
        errors.append(f'Невідомий тип оплати: {payment_type}')

    # delivery_type
    delivery_type = (data.get('delivery_type') or '').strip()
    allowed_delivery = {'delivery', 'pickup', 'self', ''}
    if delivery_type.lower() not in allowed_delivery:
        errors.append(f'Невідомий тип доставки: {delivery_type}')

    # Місто — має бути зі списку дозволених точок
    city = (data.get('city') or '').strip()
    if city not in ALLOWED_CITIES:
        errors.append(f'Невідоме місто/точка: {city!r}. Дозволені: {", ".join(sorted(c for c in ALLOWED_CITIES if c))}')

    if errors:
        return {'valid': False, 'errors': errors}
    return {'valid': True}


# ──────────────────────────────────────────────
#  UC-03  Status state machine
# ──────────────────────────────────────────────

def transition_status(current_status: str, new_status: str) -> dict:
    """
    Перевіряє чи можна перейти з current_status → new_status.
    Повертає {'ok': True} або {'ok': False, 'error': '...'}
    """
    if current_status not in STATUS_TRANSITIONS:
        return {'ok': False, 'error': f'Невідомий поточний статус: {current_status}'}
    if new_status not in STATUS_TRANSITIONS:
        return {'ok': False, 'error': f'Невідомий новий статус: {new_status}'}
    if new_status == current_status:
        return {'ok': False, 'error': 'Статус вже встановлено'}
    if new_status not in STATUS_TRANSITIONS[current_status]:
        allowed = ', '.join(STATUS_TRANSITIONS[current_status]) or 'немає (термінальний статус)'
        return {
            'ok': False,
            'error': (f'Неможливий перехід {STATUS_LABELS.get(current_status, current_status)}'
                      f' → {STATUS_LABELS.get(new_status, new_status)}. '
                      f'Дозволено: {allowed}'),
        }
    return {'ok': True}


def allowed_transitions(current_status: str) -> list:
    """Повертає список дозволених наступних статусів."""
    return list(STATUS_TRANSITIONS.get(current_status, set()))


def check_transition_actor(order: dict, new_status: str, actor_role: str, actor_id: int) -> dict:
    """
    BR-1: Оператор може скасувати ТІЛЬКИ своє замовлення у статусі 'new'.
    BR-2: Менеджер може скасувати будь-яке (крім delivered).
    BR-3: delivered — незмінний для всіх крім admin endpoint.
    Повертає {'ok': True} або {'ok': False, 'error': '...', 'error_code': '...'}
    """
    current = order.get('status', 'new')

    # BR-3: delivered — термінальний, перевіряємо тут явно
    if current == 'delivered':
        return {'ok': False, 'error': 'Доставлене замовлення змінити неможливо.',
                'error_code': 'STATUS_CONFLICT'}

    # Скасування — спеціальні правила
    if new_status == 'cancelled':
        if actor_role == 'manager' or actor_role == 'system':
            return {'ok': True}
        # BR-1: оператор/кур'єр — тільки своє і тільки new
        if current != 'new':
            return {'ok': False,
                    'error': 'Оператор може скасувати замовлення тільки у статусі "Новий".',
                    'error_code': 'ROLE_FORBIDDEN'}
        if actor_id and order.get('operator_id') and int(order['operator_id']) != int(actor_id):
            return {'ok': False,
                    'error': 'Оператор може скасувати тільки власне замовлення.',
                    'error_code': 'ROLE_FORBIDDEN'}
        return {'ok': True}

    # Кур'єр — тільки on_way та delivered на своєму замовленні
    if actor_role == 'courier':
        if new_status not in ('on_way', 'delivered'):
            return {'ok': False,
                    'error': 'Кур\'єр може змінювати статус тільки на "В дорозі" або "Доставлено".',
                    'error_code': 'ROLE_FORBIDDEN'}
        if order.get('courier_id') and int(order['courier_id']) != int(actor_id):
            return {'ok': False,
                    'error': 'Кур\'єр може змінювати тільки власні замовлення.',
                    'error_code': 'ROLE_FORBIDDEN'}

    return {'ok': True}


def check_delete_allowed(order: dict) -> dict:
    """
    BR-4: Видалення можливе тільки для статусів 'cancelled' або 'new'.
    """
    status = order.get('status', 'new')
    if status not in ('new', 'cancelled'):
        label = STATUS_LABELS.get(status, status)
        return {'ok': False,
                'error': f'Видалити можна тільки замовлення у статусі "Новий" або "Скасовано". Поточний: {label}.',
                'error_code': 'STATUS_CONFLICT'}
    return {'ok': True}


def check_confirmed_not_blocked(customer: dict) -> dict:
    """
    BR-6: якщо customer.blocked=1 → заборонити перехід → confirmed.
    Виклик перед зміною статусу на 'confirmed'.
    """
    if customer and customer.get('blocked'):
        reason = (customer.get('blocked_reason') or '').strip()
        msg = '🚫 Клієнт заблокований — підтвердження замовлення неможливе.'
        if reason:
            msg += f' Причина: {reason}'
        return {'ok': False, 'error': msg, 'error_code': 'CUSTOMER_BLOCKED'}
    return {'ok': True}


# ──────────────────────────────────────────────
#  UC-04  Birthday check
# ──────────────────────────────────────────────

def check_birthday_today(birthday: str) -> bool:
    """
    birthday — рядок 'DD.MM.YYYY' або 'YYYY-MM-DD' або 'DD.MM'
    Повертає True якщо сьогодні день народження.
    """
    if not birthday:
        return False
    today = datetime.now()
    # Спробуємо різні формати
    for fmt in ('%d.%m.%Y', '%Y-%m-%d', '%d.%m', '%d/%m/%Y'):
        try:
            dt = datetime.strptime(birthday.strip(), fmt)
            return dt.day == today.day and dt.month == today.month
        except ValueError:
            continue
    return False


def birthday_greeting(name: str) -> str:
    """Рядок-нагадування для оператора."""
    n = name.strip() if name else 'клієнт'
    return f'🎂 Сьогодні день народження у {n}! Привітайте і запропонуйте знижку.'


# ──────────────────────────────────────────────
#  UC-05  Promo suggestion
# ──────────────────────────────────────────────

def suggest_promo(total_orders: int) -> dict:
    """
    Перевіряє чи поточне замовлення є ювілейним (5, 10, 20, 50...).
    total_orders — вже після +1 (нове замовлення вже враховане).
    Повертає {'promo': True, 'message': '...'} або {'promo': False}
    """
    msg = PROMO_MILESTONES.get(total_orders)
    if msg:
        return {'promo': True, 'message': msg, 'milestone': total_orders}
    return {'promo': False}
