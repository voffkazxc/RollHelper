"""
Скидає PIN дашборду на 111111.
Запусти: python show_pin.py  (поки сервер зупинений)
"""
import sys, os, sqlite3

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data', 'rollhouse.db')

NEW_PIN = '1111'

conn = sqlite3.connect(DB_PATH)
conn.execute("PRAGMA journal_mode=WAL")

# Показати поточний PIN
row = conn.execute("SELECT value FROM settings WHERE section='auth' AND key='dashboard_pin'").fetchone()
if row:
    print(f"\n  Поточний PIN в БД: {row[0]}")
else:
    print("\n  PIN в БД не знайдено")

# Скинути на 111111
conn.execute(
    "INSERT OR REPLACE INTO settings (section, key, value) VALUES ('auth','dashboard_pin',?)",
    (NEW_PIN,)
)
conn.commit()
conn.close()

print(f"  ✅  PIN скинуто на: {NEW_PIN}")
print(f"\n  1. Запусти start.bat")
print(f"  2. Заходь з PIN: {NEW_PIN}")
print(f"  3. Зміни PIN в Налаштуваннях\n")
input("Натисни Enter щоб закрити...")
