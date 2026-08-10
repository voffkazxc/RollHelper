# Syrve UIA map for RollHouse Lite

Source log: `syrve_id_inspector_history.txt`
Checked: 2026-08-01

## Stable roots

| Purpose | AutomationId | Notes |
|---|---|---|
| Main Syrve window | `MainForm` | Window title: `КЦ - Syrve Office 2025` |
| Order form root | `DeliveryOrderEditControl` | Use this as search root for current order |
| Main tab control | `tabControlMain` | Parent of delivery tabs |
| Order items grid/tree | `treeListItems` | Product rows are accessible as child DataItem/TreeItem values |
| Payments grid | `gridPaymentItems` | Payment rows/cells live here |

## Buttons with UIA click/invoke

| Action | AutomationId | Name | Patterns | Notes |
|---|---|---|---|---|
| No change | `buttonNoChange` | `Без сдачи` | `Invoke, Legacy` | F10 returned success |
| Delete payment row | `buttonDeletePaymentItem` | `X` | `Invoke, Legacy` | F10 returned success |
| Modifiers | `buttonModifers` | `Размеры и модификаторы` | `Invoke, Legacy` | Typo in Syrve ID is real: `Modifers` |
| Call customer | `buttonCallToCustomer` | `Позвонить` | `Invoke, Legacy` | F10-clickable button |

## Editable/readable fields

| Purpose | AutomationId | Example value | Notes |
|---|---|---|---|
| Order comment | `memoEditDeliveryComment` | `100 грн решта з 1200 грн` | Outer field; inner WinForms value element may expose Value pattern |
| Customer info / kitchen note / client card | `memoEditCustomerComment` | `карта` | Stable parent of client info field; inner edit has dynamic AutomationId such as `267456` |
| Address comment | `memoEditDeliveryAddressComment` | empty | Outer field; inner value element may expose Value pattern |
| Delivery time | `timeEditDeliveryTime` | `13:00` | Can be focused/read by UIA |
| Street/address | `gridLookUpEditStreetAddress` | `Чугуїв, Лугова вулиця, 3` | Dropdown-like field |
| House | `textEditDeliveryHouse` | `3` | Text field |
| Customer phone | `lookUpEditCustomerPhone` | `+38 096 338-18-46` | Dropdown-like field |
| Customer name | `textEditName` | `Катерина` | Text field |
| Order type | `restoCompletionOrderType` | `Передзамовлення` | Dropdown-like field |
| Delivery terminal/kitchen | `lookUpEditDeliveryTerminal` | `RH Чугуїв: Чугуїв доставка` | Dropdown-like field |

## Order grid details

The order composition is visible through UIA now, without OCR, if reading children of `treeListItems`.
Examples seen in the log:

- TreeItem `Узел1` value: `Сет місяця Лайт червень;1;;899;899`
- DataItem `Блюдо row 1` value: `Сет місяця Лайт червень`
- DataItem `Количество row 1` value: `1`
- For focusing before PLU input, click first non-empty child named like `Блюдо row N` under `treeListItems`; direct click on the root grid can report success while focus stays elsewhere.

This means RollHouse Lite can likely read current order items by walking `treeListItems` children and extracting row values.

## Payment grid details

Payment type cells do not have stable AutomationId in the captured log. Use parent `gridPaymentItems`, then find children by `Name`, for example:

- `Тип оплаты row 0`
- `Свойства row 0`
- `Сумма row 0`
- After clicking `Сумма row 0`, Syrve opens a dynamic inner edit such as `AutomationId=2430612`; do not store that dynamic id.

For setting cash/card, safest likely flow is:

1. Focus/click `gridPaymentItems` or child `Тип оплаты row 0` by UIA.
2. Type configured iiko keyword (`гот`, `банк`, etc.).
3. Press Enter.
4. Use `buttonNoChange` by UIA for no-change action.

## Implementation note

Coordinates should become fallback only. Main path should use:

- find window `MainForm`
- find active order root `DeliveryOrderEditControl`
- find descendants by AutomationId/name
- call UIA `.Click()` / Invoke/Legacy where supported
- for fields, prefer ValuePattern where available, otherwise focus and send text
