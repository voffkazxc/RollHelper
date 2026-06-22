"""
RollHouse PRO — управління користувачами (CLI)
Запуск: python manage_users.py  (поки сервер зупинений або паралельно)

Дії:
  python manage_users.py list              — список всіх юзерів
  python manage_users.py create            — створити нового юзера (інтерактивно)
  python manage_users.py reset <login>     — скинути пароль юзера
  python manage_users.py role <login>      — змінити роль юзера
  python manage_users.py deactivate <login>— деактивувати юзера
  python manage_users.py activate <login>  — активувати юзера
"""
import sys, os

# Підключаємо database.py напряму
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import database as db

ROLES = [
    ('owner',          'Власник — повний доступ до всього'),
    ('director',       'Директор — аналітика + звіти, тільки читання'),
    ('investor',       'Інвестор — тільки /analytics (KPI, виручка)'),
    ('logistics',      'Логіст — всі замовлення, призначення кур\'єрів'),
    ('senior_operator','Старший оператор — все що оператор + скасування + блокування'),
    ('operator',       'Оператор — створення та редагування замовлень'),
    ('admin',          'Адмін кухні — замовлення ТІЛЬКИ своєї точки'),
    ('cashier',        'Касир — замовлення своєї точки, оплата'),
    ('cook',           'Кухар — список замовлень своєї точки, статус cooking'),
    ('courier',        'Кур\'єр — тільки свої доставки, on_way/delivered'),
]

CITIES = ['Мерефа', 'Чугуїв', 'Берестин', 'Колл Центр']

# Ролі що потребують локації (не бачать інші міста)
LOCAL_ROLES = {'admin', 'cashier', 'cook', 'courier'}


def hr(char='─', n=60):
    print(char * n)


def pick(prompt, options, allow_empty=False):
    """Вибір з нумерованого списку."""
    for i, (k, desc) in enumerate(options, 1):
        print(f'  {i}. {k:20s} — {desc}')
    while True:
        val = input(f'{prompt}: ').strip()
        if allow_empty and not val:
            return None
        try:
            idx = int(val) - 1
            if 0 <= idx < len(options):
                return options[idx][0]
        except ValueError:
            pass
        try:
            # Перевіряємо чи ввели текстом
            keys = [k for k, _ in options]
            if val in keys:
                return val
        except Exception:
            pass
        print('  ❌  Невалідний вибір. Введіть номер або значення.')


def cmd_list():
    db.init_db()
    users = db.list_users(include_inactive=True)
    if not users:
        print('\n  Юзерів немає. Спочатку запусти start.bat — він створить owner.\n')
        return
    hr()
    print(f"  {'ID':<4} {'Логін':<22} {'Роль':<18} {'Ім\'я':<20} {'Локація':<12} {'Актив'}")
    hr()
    for u in users:
        status = '✅' if u['is_active'] else '❌'
        loc    = u['location'] or '(всі)'
        last   = (u['last_login'] or '')[:16] or '—'
        print(f"  {u['id']:<4} {u['login']:<22} {u['role']:<18} {(u['display_name'] or ''):<20} {loc:<12} {status}  (вхід: {last})")
    hr()
    print(f'  Всього: {len(users)} юзерів\n')


def cmd_create():
    db.init_db()
    hr()
    print('  СТВОРЕННЯ НОВОГО ЮЗЕРА')
    hr()

    login = input('  Логін (латиниця, без пробілів): ').strip()
    if not login:
        print('  ❌ Логін обов\'язковий'); return

    pw1 = input('  Пароль (мін. 6 символів): ').strip()
    pw2 = input('  Повторити пароль: ').strip()
    if pw1 != pw2:
        print('  ❌ Паролі не збігаються'); return
    if len(pw1) < 6:
        print('  ❌ Пароль мінімум 6 символів'); return

    name = input('  Відображуване ім\'я (Enter = порожньо): ').strip()

    print('\n  Роль:')
    role = pick('  Введіть номер', ROLES)
    if not role:
        return

    location = None
    if role in LOCAL_ROLES:
        print(f'\n  ⚠️  Роль "{role}" потребує прив\'язки до точки.')
        print('  Локація (місто):')
        city_opts = [(c, c) for c in CITIES] + [('(пропустити)', 'без локації')]
        loc_val = pick('  Введіть номер', city_opts, allow_empty=True)
        if loc_val and loc_val != '(пропустити)':
            location = loc_val

    print(f'\n  Створюю: логін={login}, роль={role}, локація={location or "(всі)"}')
    confirm = input('  Підтвердити? (y/n): ').strip().lower()
    if confirm != 'y':
        print('  Скасовано.'); return

    result = db.create_user(login, pw1, role, display_name=name, location=location)
    if result['ok']:
        print(f'\n  ✅  Юзера створено! ID={result["id"]}')
        print(f'  Логін: {login}')
        print(f'  Пароль: {pw1}')
        print(f'  Адреса входу: http://localhost:5000/login\n')
    else:
        print(f'\n  ❌  Помилка: {result["error"]}\n')


def cmd_reset(login: str):
    db.init_db()
    user = db.get_user_by_login(login)
    if not user:
        print(f'  ❌  Юзера "{login}" не знайдено'); return

    print(f'\n  Скидання пароля для: {user["login"]} ({user["role"]})')
    pw1 = input('  Новий пароль: ').strip()
    pw2 = input('  Повторити: ').strip()
    if pw1 != pw2:
        print('  ❌ Паролі не збігаються'); return
    if len(pw1) < 6:
        print('  ❌ Мінімум 6 символів'); return

    result = db.update_user(user['id'], {'password': pw1}, actor_id=0)
    if result['ok']:
        # Відкликаємо всі активні сесії
        db.revoke_all_user_sessions(user['id'])
        print(f'  ✅  Пароль змінено. Всі активні сесії відкликано.')
        print(f'  Новий пароль: {pw1}\n')
    else:
        print(f'  ❌  {result["error"]}\n')


def cmd_role(login: str):
    db.init_db()
    user = db.get_user_by_login(login)
    if not user:
        print(f'  ❌  Юзера "{login}" не знайдено'); return

    print(f'\n  Зміна ролі для: {user["login"]} (поточна роль: {user["role"]})')
    print('  Нова роль:')
    role = pick('  Введіть номер', ROLES)
    if not role:
        return

    location = user.get('location')
    if role in LOCAL_ROLES and not location:
        print(f'\n  ⚠️  Роль "{role}" рекомендує локацію. Поточна: {location or "(всі)"}')
        print('  Встановити локацію?')
        city_opts = [(c, c) for c in CITIES] + [('(залишити як є)', '')]
        loc_val = pick('  Введіть номер', city_opts, allow_empty=True)
        if loc_val and loc_val != '(залишити як є)':
            location = loc_val

    result = db.update_user(user['id'], {'role': role, 'location': location}, actor_id=0)
    if result['ok']:
        db.revoke_all_user_sessions(user['id'])
        print(f'  ✅  Роль змінено на "{role}". Сесії відкликано (наступний вхід застосує нову роль).\n')
    else:
        print(f'  ❌  {result["error"]}\n')


def cmd_deactivate(login: str):
    db.init_db()
    user = db.get_user_by_login(login)
    if not user:
        print(f'  ❌  Юзера "{login}" не знайдено'); return
    db.update_user(user['id'], {'is_active': 0}, actor_id=0)
    db.revoke_all_user_sessions(user['id'])
    print(f'  ✅  Юзера "{login}" деактивовано. Вхід заблоковано.\n')


def cmd_activate(login: str):
    db.init_db()
    user = db.get_user_by_login(login)
    if not user:
        print(f'  ❌  Юзера "{login}" не знайдено'); return
    db.update_user(user['id'], {'is_active': 1}, actor_id=0)
    print(f'  ✅  Юзера "{login}" активовано.\n')


def print_help():
    print(__doc__)


if __name__ == '__main__':
    args = sys.argv[1:]

    if not args or args[0] in ('-h', '--help', 'help'):
        print_help()
    elif args[0] == 'list':
        cmd_list()
    elif args[0] == 'create':
        cmd_create()
    elif args[0] == 'reset' and len(args) >= 2:
        cmd_reset(args[1])
    elif args[0] == 'role' and len(args) >= 2:
        cmd_role(args[1])
    elif args[0] == 'deactivate' and len(args) >= 2:
        cmd_deactivate(args[1])
    elif args[0] == 'activate' and len(args) >= 2:
        cmd_activate(args[1])
    else:
        print(f'  ❌  Невідома команда: {args[0]}')
        print_help()

    input('\nНатисни Enter щоб закрити...')
