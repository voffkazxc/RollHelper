"""
RollHouse PRO — Telegram Notifier
==================================
Відправляє повідомлення через Telegram Bot API.
Без зовнішніх залежностей (тільки stdlib urllib).

Налаштування зберігаються в таблиці settings:
  section=telegram, key=bot_token  → токен бота (від @BotFather)
  section=telegram, key=chat_id    → chat_id куди слати (менеджер / група)
  section=telegram, key=enabled    → '1' щоб увімкнути, '0' щоб вимкнути
"""

import json
import threading
import urllib.request
import urllib.parse
import urllib.error

_BASE = 'https://api.telegram.org/bot{token}/sendMessage'


def _do_send(token: str, chat_id: str, text: str):
    """Відправка в окремому потоці — не блокує Flask-запит."""
    url  = _BASE.format(token=token)
    data = urllib.parse.urlencode({
        'chat_id':    chat_id,
        'text':       text,
        'parse_mode': 'HTML',
    }).encode('utf-8')
    req = urllib.request.Request(url, data=data, method='POST')
    try:
        urllib.request.urlopen(req, timeout=5)
    except Exception as e:
        print(f'[Telegram] Помилка відправки: {e}')


def send(token: str, chat_id: str, text: str):
    """Надсилає повідомлення асинхронно (daemon thread)."""
    if not token or not chat_id or not text:
        return
    t = threading.Thread(target=_do_send, args=(token, chat_id, text), daemon=True)
    t.start()


# ──────────────────────────────────────────────────────
#  Шаблони повідомлень
# ──────────────────────────────────────────────────────

STATUS_UK = {
    'new':       '🆕 Новий',
    'confirmed': '✅ Підтверджено',
    'cooking':   '👨‍🍳 Готується',
    'on_way':    '🛵 В дорозі',
    'delivered': '📦 Доставлено',
    'cancelled': '❌ Скасовано',
}


def msg_new_order(order_id: int, phone: str, name: str,
                  amount: float, city: str, address: str,
                  items: str, comment: str) -> str:
    lines = [f'🍣 <b>Нове замовлення #{order_id}</b>']
    if name:
        lines.append(f'👤 {_esc(name)}  <code>{_esc(phone)}</code>')
    else:
        lines.append(f'📞 <code>{_esc(phone)}</code>')
    lines.append(f'💰 {amount} грн')
    if city:
        lines.append(f'📍 {_esc(city)}  {_esc(address or "")}')
    elif address:
        lines.append(f'📍 {_esc(address)}')
    if items:
        lines.append(f'🛒 {_esc(items)}')
    if comment:
        lines.append(f'💬 {_esc(comment)}')
    return '\n'.join(lines)


def msg_status_change(order_id: int, phone: str, name: str,
                      old_status: str, new_status: str,
                      courier_name: str = '') -> str:
    old_lbl = STATUS_UK.get(old_status, old_status)
    new_lbl = STATUS_UK.get(new_status, new_status)
    lines = [f'{new_lbl} — замовлення <b>#{order_id}</b>']
    label = name or phone
    if label:
        lines.append(f'👤 {_esc(label)}')
    if new_status == 'on_way' and courier_name:
        lines.append(f'🛵 Кур\'єр: {_esc(courier_name)}')
    if new_status in ('delivered', 'cancelled'):
        lines.append(f'({old_lbl} → {new_lbl})')
    return '\n'.join(lines)


def msg_reminder(text: str, phone: str = '', name: str = '') -> str:
    lines = [f'🔔 <b>Нагадування</b>: {_esc(text)}']
    if name or phone:
        lines.append(f'👤 {_esc(name or phone)}')
    return '\n'.join(lines)


def _esc(s: str) -> str:
    """HTML-екранування для Telegram."""
    return str(s).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
