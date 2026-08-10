# RollHouse Lite

Портативная AHK-only версия RollHouse без Python-сервера, OCR, CRM, Telegram и веб-пульта.

## Что нужно на новом ПК

1. AutoHotkey v1.1, не v2.
2. Syrve / BackOffice должен быть установлен и открыт.
3. Папка `RollHouseLite` целиком.

## Запуск

Запусти:

`RollHouseLite.ahk`

Горячие клавиши по умолчанию:

- `~` — открыть пульт.
- `F1` — быстрое окно СІВ.
- `Enter` в пульте — внести цепочку в Syrve.
- `Shift+Enter` — обычный Enter без запуска цепочки.

## Что умеет

- Вставить комментарий, кухню, адрес, карту клиента.
- Выставить время готовности.
- Пробить подарок по PLU: Pepsi / Brooklyn / Burger.
- Поставить оплату: готівка / картка.
- Ввести `Решта з` для налички или нажать `Без здачі`.
- Пробить СІВ: палочки обычные/учебные + соевый/имбирь/васаби по формуле RollHouse.

## Чего тут специально нет

- Нет сервера Flask.
- Нет OCR/Tesseract.
- Нет CRM и базы `rollhouse.db`.
- Нет Telegram-отчёта F5.
- Нет автопоиска заказов.
- Нет чтения Google Sheets.

## Калибровка

Открой пульт `~` → шестерёнка.

Для каждой точки нажми кнопку, наведи мышь в Syrve и нажми `Enter`:

- Коментар
- Кухня
- Адреса
- Карта
- Час
- Таблиця страв
- Хрестик оплати
- Тип оплати
- Решта/сума
- Без здачі

После переноса на другой ПК калибровать почти точно нужно заново: экран, масштаб Windows и размер окна Syrve меняют координаты.

## Поиск WinAPI/UIA ID кнопок Syrve

Запусти `SyrveIdInspector.ahk`.

- Наведи мышь на нужную кнопку/поле в Syrve.
- Нажми `F8`.
- Смотри строки `AutomationId`, `Name`, `ControlType`, `Patterns`.
- Если есть `AutomationId` и `Patterns: Invoke`, кнопку можно нажимать без координат через UIA.
- `F9` делает дамп активного окна Syrve.
- `F10` пробует вызвать действие элемента под мышью через `el.Click()`.

Лог сохраняется рядом: `syrve_id_inspector_last.txt`.

### SyrveIdInspector v2

Close the old inspector window and start `SyrveIdInspector.ahk` again. The window title must be `Syrve ID Inspector v2`.

V2 uses the smallest UIA element under the mouse and also shows `actionable candidate`: the closest element that has Invoke/Toggle/Selection/Legacy action patterns.
