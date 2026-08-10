# Документация: Нативный UIA-клик из AHK v1 без Python-сервера

## 📌 Цель
Исключить цепочку `AHK -> HTTP -> Python -> UIAutomation -> iiko` для кликов по кнопкам и перевести все нажатия на мгновенный нативный вызов через **`UIA_Interface.ahk`** напрямую из AutoHotkey.

---

## 🛠 Выявленные сложности и решения (Troubleshooting)

### 1. Почему не работает WinAPI `BM_CLICK` / `WM_COMMAND`?
Кнопки в iiko (WPF / WinForms XtraLayoutControl) **не имеют отдельных Window Handles (HWND)**. Весь интерфейс рендерится внутри единого системного окна `iikoCard5.Pos.Host.exe`. Поэтому нативные клики WinAPI без координат невозможны, а UIA (UI Automation) является единственным надежным прямым способом.

### 2. Ошибка: `Window not found`
* **Причина**: Переменная `iikoWinExe` была пуста при вызове клика, из-за чего AHK не мог найти окно iiko.
* **Решение**: Поиск окна жестко привязан к процессу:
  ```autohotkey
  hwnd := WinExist("ahk_exe iikoCard5.Pos.Host.exe")
  ```

### 3. Ошибка: `Method Call not supported by the UIA_Element7 Class`
* **Причина**: Прямой вызов `btn.Invoke()` на объекте `UIA_Element` в AHK v1 вызывает исключение COM-класса.
* **Решение**: Использовать нативный метод библиотеки **`btn.Click()`**. Внутри библиотеки Descolada `Click()` сам проверяет доступность `InvokePattern` и безопасно нажимает кнопку без эмуляции движения мыши.

---

## ⚡️ Результат тестирования
* **Кнопка «Найти точку»** (`buttonAssignDeliveryTerminal`):
  * Успешно выполнена за **2219 мс** при первом холодном поиске элемента (последующие клики выполняются мгновенно).
  * Мышь не перемещается, клик проходит напрямую через UI Automation.

---

## 📋 Реестр AutomationId кнопок iiko (Карточка доставки)

| AutomationId | Название кнопки | Назначение |
| :--- | :--- | :--- |
| `buttonAssignDeliveryTerminal` | **Найти точку** | Назначение терминала/точки |
| `buttonSaveAndClose` | **Сохранить на точку / Сохранить** | Сохранение и закрытие заказа |
| `buttonClose` | **Выйти** | Закрытие формы |
| `buttonDeliveryConfirmation` | **Подтвердить** | Подтверждение доставки |
| `buttonCancelDelivery` | **Отменить доставку** | Отмена заказа |
| `buttonDeliveryRegionsMap` | **Карта** | Показ карты районов |
| `buttonDeletePaymentItem` | **X** | Удаление позиции оплаты |
| `buttonDeleteItem` | **X** | Удаление позиции из заказа |
| `buttonNoChange` | **Без сдачи** | Оплата без сдачи |
| `buttonModifers` | **Размеры и модификаторы** | Выбор модификаторов |
| `buttonDecrease` | **-** | Уменьшение количества |
| `buttonIncrease` | **+** | Увеличение количества |
| `buttonAdditionalInfo` | **Дополнительная информация** | Инфо о заказе |
| `buttonBlackList` | **Высокий риск** | Черный список |
| `buttonCallToCustomer` | **Позвонить** | Звонок клиенту |
| `buttonCallToCourier` | **Позвонить** | Звонок курьеру |
| `btnPbxCallAccept` | **Принять** | Принять звонок PBX |
| `btnPbxCallReject` | **Отклонить** | Отклонить звонок PBX |
| `buttonDeliveryProblem` | **Проблема!** | Отметка проблемы |
