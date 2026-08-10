RollHouse Lite Portable
=======================

Как запускать:
1. Открой Syrve / BackOffice и нужный заказ.
2. Запусти start_rollhouse_lite.bat.
3. Тильда открывает пульт, F1 пробивает СІВ.

Как закрыть:
- stop_rollhouse_lite.bat закрывает только этот RollHouseLite.ahk.

Что внутри:
- AutoHotkeyU64.exe: portable runtime AHK v1.1
- RollHouseLite\RollHouseLite.ahk: рабочая логика
- RollHouseLite\RkConfig.ini: горячие клавиши, PLU, настройки
- RollHouseLite\DeliveryPrices.ini: цены/зоны доставки
- RollHouseLite\zones.kml: зоны KML
- lib\UIA_Interface.ahk: UIA-библиотека

Важно:
- Для обычной работы Python/сервер не нужен.
- F5-отчёт работает встроенной AHK-логикой. Если когда-нибудь добавим report_after_excel.py, Python понадобится только для этого доп. хука.
