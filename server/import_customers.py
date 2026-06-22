"""
Імпорт клієнтів в базу RollHouse.
Запуск: python import_customers.py customers.xlsx
        python import_customers.py customers.csv
        python import_customers.py phones.txt   (один номер на рядок)

Скрипт:
  - Нормалізує всі номери до 380XXXXXXXXX
  - Пропускає дублікати (за останніми 10 цифрами)
  - Виводить статистику після завершення
"""

import sys
import os
import re
import sqlite3

# Шлях до бази
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data', 'rollhouse.db')


def normalize(phone: str) -> str:
    digits = re.sub(r'\D', '', str(phone))
    if digits.startswith('380'):
        return digits
    elif digits.startswith('80') and len(digits) == 11:
        return '3' + digits
    elif digits.startswith('0') and len(digits) == 10:
        return '38' + digits
    elif len(digits) == 9:
        return '380' + digits
    return digits


def last10(phone: str) -> str:
    return normalize(phone)[-10:]


def load_phones(filepath: str) -> list:
    ext = filepath.lower().split('.')[-1]
    phones = []

    if ext in ('xlsx', 'xls'):
        try:
            import openpyxl
            wb = openpyxl.load_workbook(filepath, read_only=True, data_only=True)
            for sheet in wb.worksheets:
                for row in sheet.iter_rows(values_only=True):
                    for cell in row:
                        if cell:
                            s = str(cell).strip()
                            digits = re.sub(r'\D', '', s)
                            if 9 <= len(digits) <= 13:
                                phones.append(s)
        except ImportError:
            print("❌ Потрібен openpyxl: pip install openpyxl")
            sys.exit(1)

    elif ext == 'csv':
        import csv
        with open(filepath, encoding='utf-8-sig') as f:
            reader = csv.reader(f)
            for row in reader:
                for cell in row:
                    s = cell.strip()
                    digits = re.sub(r'\D', '', s)
                    if 9 <= len(digits) <= 13:
                        phones.append(s)

    elif ext == 'txt':
        with open(filepath, encoding='utf-8') as f:
            for line in f:
                s = line.strip()
                if s:
                    phones.append(s)

    else:
        print(f"❌ Непідтримуваний формат: {ext}")
        sys.exit(1)

    return phones


def import_phones(phones: list):
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")

    # Завантажуємо існуючі last10 в пам'ять — швидка перевірка без SQL на кожен рядок
    existing = set(
        row[0] for row in conn.execute("SELECT substr(phone,-10) FROM customers").fetchall()
    )

    added = 0
    skipped_invalid = 0
    skipped_dup = 0

    rows = []
    seen_in_batch = set()

    for raw in phones:
        norm = normalize(raw)
        if len(norm) < 9:
            skipped_invalid += 1
            continue
        l10 = norm[-10:]
        if l10 in existing or l10 in seen_in_batch:
            skipped_dup += 1
            continue
        rows.append((norm,))
        seen_in_batch.add(l10)
        added += 1

        # Вставляємо пачками по 1000
        if len(rows) >= 1000:
            conn.executemany(
                "INSERT OR IGNORE INTO customers (phone) VALUES (?)", rows
            )
            conn.commit()
            rows = []
            print(f"  ⏳ {added} записів вставлено...", end='\r')

    if rows:
        conn.executemany("INSERT OR IGNORE INTO customers (phone) VALUES (?)", rows)
        conn.commit()

    conn.close()
    return added, skipped_dup, skipped_invalid


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Використання: python import_customers.py <файл.xlsx|.csv|.txt>")
        sys.exit(1)

    filepath = sys.argv[1]
    if not os.path.exists(filepath):
        print(f"❌ Файл не знайдено: {filepath}")
        sys.exit(1)

    print(f"📂 Читаємо: {filepath}")
    phones = load_phones(filepath)
    print(f"✅ Знайдено номерів: {len(phones)}")

    print("💾 Імпортуємо в базу...")
    added, dups, invalid = import_phones(phones)

    print(f"""
════════════════════════════════
  Імпорт завершено
  Додано:          {added:>7}
  Дублікати:       {dups:>7}
  Невалідні:       {invalid:>7}
  Всього в файлі:  {len(phones):>7}
════════════════════════════════
""")
