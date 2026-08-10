# PROJECT BACKLOG: UIA Migration & Refactoring Roadmap

## 📌 Цель
Полностью избавиться от координатных кликов, задержек Sleep и ненадежного чтения через буфер обмена, переведя все операции iiko на нативный UIA-драйвер (`lib/IikoDriver.ahk`).

---

## 📦 Пакет №1 — Кнопки действий (ВЫПОЛНЕНО ✅)
- `[x]` **1.1. Найти точку** (`buttonAssignDeliveryTerminal`) -> `IikoUI_AssignDeliveryTerminal()`
- `[x]` **1.2. Сохранить на точку** (`buttonSaveAndClose`) -> `IikoUI_SaveAndClose()`
- `[x]` **1.3. Подтвердить** (`buttonDeliveryConfirmation`) -> `IikoUI_ConfirmDelivery()`
- `[x]` **1.4. Без сдачи** (`buttonNoChange`) -> `IikoUI_NoChange()`

---

## 📦 Пакет №2 — Фокусировка и ввод полей (ВЫПОЛНЕНО ✅)
- `[x]` **2.1. Поле комментария заказа** (`memoEditDeliveryComment`) -> `IikoUI_FocusComment()` / `IikoUI_SetComment()`
- `[x]` **2.2. Поле адреса доставки** (`gridLookUpEditStreetAddress`) -> `IikoUI_FocusAddress()`
- `[x]` **2.3. Поле времени доставки** (`timeEditDeliveryTime`) -> `IikoUI_FocusDeliveryTime()`

---

## 📦 Пакет №3 — Выпадающие списки и выбор
- `[ ]` **3.1. Выбор концепции** (`restoCompletionConception`) — UIA-выбор вместо `kontsX, kontsY`.
- `[ ]` **3.2. Выбор терминала/кухни** (`lookUpEditDeliveryTerminal`) — UIA-выбор вместо `tochkaX, tochkaY`.
- `[ ]` **3.3. Кнопка «Без сдачи» / Очистка оплаты** (`buttonDeletePaymentItem`) — сброс старой оплаты.

---

## 📦 Пакет №4 — Прямое чтение данных (Без буфера обмена и Python!)
- `[ ]` **4.1. Чтение телефона и имени клиента** (`lookUpEditCustomerPhone`, `textEditName`).
- `[ ]` **4.2. Чтение адреса и номера заказа** (`gridLookUpEditStreetAddress`, `labelDeliveryNumber`).
- `[ ]` **4.3. Чтение текущей концепции и статуса** (`restoCompletionConception`, `labelDeliveryStatus`).
