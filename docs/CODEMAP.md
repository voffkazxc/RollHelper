# RollHelper: карта кода и точка входа для нового агента

> Актуально на 2026-08-12. Этот файл описывает то, что реально существует в коде сейчас.
> Если старый план или бэкап противоречит этой карте, сначала проверять текущий код и `STATUS.md`.

## Что читать первым

1. `docs/CODEMAP.md` — где находится рабочий код и что является источником правды.
2. `STATUS.md` — текущие ограничения, известные проблемы и ближайшая проверка.
3. `docs/RELEASE_GUARDRAILS.md` — обязательные границы при выпуске пакетов: что нельзя менять в чужих брендах и модулях.
4. Документ конкретной подсистемы, если задача относится к зонам, лаунчеру или обзвону.
5. Только после этого — `PLAN.md`, `PROJECT_BACKLOG.md` и `docs/ARCHITECTURE_DECOMPOSITION.md`: в них есть история и целевая архитектура, но не всё уже реализовано.

## Рабочие точки входа

| Компонент | Точка входа | Состояние |
|---|---|---|
| RollHouse из исходников | `main.ahk` | Основной рабочий AHK v1-файл бренда |
| RollClub из исходников | `engine_rollclub.ahk` | Отдельный AHK v1-файл; из RollHouse не переключается |
| RollHouse из пакета | `start_rollhouse.bat` | Создаётся скриптом `packaging/build-rollhouse-mvp.ps1` |
| Локальный сервер | `../server/app.py` | В исходной рабочей копии лежит рядом с репозиторием |
| Launcher | `Launcher/RollHelperLauncher/RollHelperLauncher.csproj` | WPF, .NET 8, универсален для brand/module/tool |
| Автообзвон | `tools/call_listener/microsip_assistant.py` | Экспериментальный отдельный Python GUI, не часть обычного RollHouse MVP |
| Отчёт нагрузки | `modules/rollhouse-report-load/report_load.ahk` | Подключаемый UIA-модуль без Excel, Telegram и Python |

`main.ahk` жёстко запускает RollHouse. Строки в старых документах о выборе `BrandActive` и переходе из `main.ahk` в RollClub больше не описывают рабочий интерфейс.

## RollHouse MVP

Профиль находится в `config/mvp_modules.ini` и применяется через `core/modules/ModuleRegistry.ahk`.

Включено:

- чтение заказа и пульт по тильде;
- Enter и перенос данных в Syrve;
- F1 и СІВ;
- `Ctrl+Enter` для подтверждения и сохранения;
- настройки, WinAPI-карта, подарки, PLU и зоны.

Выключено профилем или отсутствует без отдельного пакета:

- `Ctrl+F4` и дежурство;
- F5 и отчёт, пока дополнение `rollhouse-report-load` не установлено и не включено лаунчером;
- F2/F6/F7/Ctrl+F6 и обзвон;
- OCR, CRM, web-pult beta и developer diagnostics.

Не удалять этот код вслепую: сначала физически отделить модуль и проверить обычный заказ.

## Дополнение «Отчёт — нагрузка»

Источник модуля: `modules/rollhouse-report-load/report_load.ahk`. Сборка ZIP выполняется через `packaging/build-report-load-module.ps1`, а `packaging/build-release.ps1` добавляет пакет `rollhouse-report-load` в общий release manifest как дополнение RollHouse.

Модуль через UIA находит нативную таблицу Syrve `gridDeliveries`, фокусирует её и копирует названия групп штатной командой таблицы. Количество берётся из заголовков групп, а суммы — напрямую из UIA footer-элементов `Сумма к оплате`. Данные показываются в отдельном окне с кнопкой копирования. Microsoft Excel, Telegram, Python, сервер и логин API не нужны.

В окне доступны два представления одних данных: короткий цифровой отчёт и текст `Для керівника`. Второй вариант формирует разные украинские описания для точек с учётом количества заказов и рассчитывает средний чек, округлённый до целых гривен.

Для работы оператор должен открыть в Syrve вкладку `Доставки`. Если таблица не открыта, модуль сразу показывает понятное сообщение и не запускает медленный рекурсивный поиск по окнам.

`core/modules/ModuleRegistry.ahk` читает состояние установленных дополнений из `%LOCALAPPDATA%\Programs\RollHelper\State\packages.json`. После установки и включения дополнения становятся доступны F5 и пункт трея `Звіт — навантаження`.

## Как RollHouse связан с сервером

В режиме разработки:

```text
main.ahk
  -> HTTP http://127.0.0.1:5000
  -> ../server/app.py
  -> parser.py / pult_logic.py / business_logic.py / iiko_bridge.py
```

В релизный ZIP сервер и Python копируются внутрь пакета:

```text
package/
  package.json
  start_rollhouse.bat
  RollHelper/
    main.ahk
    AutoHotkeyU64.exe
    config/
    core/
    lib/
    brands/rollhouse/
  server/
  runtime/python/
```

Состав пакета определяет `packaging/build-rollhouse-mvp.ps1`. На компьютере оператора установленный Python и AutoHotkey для этого ZIP не требуются.

## RollClub MVP и WinAPI-сканер

RollClub запускается через `engine_rollclub.ahk`. Базовый пакет содержит тильду, Enter, F1 и `Ctrl+Enter`; дежурство `Ctrl+F4` и зоны доставки остаются отдельными дополнениями.

Ctrl+F4 выполняется внутри основного процесса `engine_rollclub.ahk`, а пакет `rollclub-duty` только разрешает эту функцию. Быстрое чтение списка зафиксировано отдельно в `brands/rollclub/server/rollclub_kc_legacy.py`; `packaging/build-rollclub-mvp.ps1` подключает его только к серверу RollClub. Отдельный AHK-процесс дополнения не должен управлять Syrve параллельно с основным пультом.

Определение зоны по KML не считается точным, если координата находится ближе 100 метров к границе полигона, попала сразу в несколько пересекающихся полигонов или Nominatim нашёл только улицу без номера дома. В таком случае пульт показывает жёлтое предупреждение, не меняет время автоматически и оставляет окончательную проверку за точкой Syrve при внесении заказа.

В настройках RollClub вкладка WinAPI показывает старые координатные роли понятными оператору названиями. Внутренний ключ роли хранится отдельно и не меняется при переименовании подписи. Кнопка `Замінити вибране` принимает только стабильный текстовый `AutomationId` или осмысленный `Name`. Временный числовой ID и общий элемент `Элемент редактирования` не сохраняются: оператору нужно кликнуть саму ячейку или кнопку Syrve.

Символ `⚠` у существующей записи означает старую рискованную привязку, которую нужно переснять. `Видалити зі списку` работает и для роли без WinAPI ID: роль скрывается, но старые координаты не удаляются. Кнопка `Повернути приховані елементи` возвращает скрытые роли.

К рабочей логике уже подключены с координатным запасным вариантом: первая строка таблицы заказа для PLU/СІВ, крестик удаления оплаты, `Знайти точку`, `Підтвердити` и `Зберегти на точку`.

Поля комментария, карты клиента, кухни, адреса и времени пока нельзя считать полностью переведёнными на WinAPI. Их старые числовые ID нестабильны, поэтому до отдельной ручной проверки продолжает работать координатный fallback.

## Настройки и данные оператора

Не путать файлы программы с данными пользователя.

Уже вынесены из версии пакета:

- пользовательский KML: `%LOCALAPPDATA%\RollHelper\UserData\rollhouse\zones.kml`;
- предыдущий KML: `%LOCALAPPDATA%\RollHelper\UserData\rollhouse\zones.previous.kml`;
- цены зон: `%LOCALAPPDATA%\RollHelper\UserData\rollhouse\DeliveryPrices.ini`;
- состояние лаунчера: `%LOCALAPPDATA%\Programs\RollHelper\State\packages.json`;
- разметка лаунчера: `%LOCALAPPDATA%\Programs\RollHelper\State\launcher-ui.json`;
- лог лаунчера: `%LOCALAPPDATA%\RollHelper\Logs\launcher.log`.
- рабочие настройки RollClub, включая координаты, PLU и горячие клавиши: `%LOCALAPPDATA%\Programs\RollHelper\UserData\rollclub\RkConfig.ini`;
- карта WinAPI RollClub: `%LOCALAPPDATA%\Programs\RollHelper\UserData\rollclub\RkUiaMap.ini`.

При первом запуске RollClub координаты и карта WinAPI автоматически восстанавливаются из наиболее полного предыдущего пакета. Файл `brands/rollclub/RkConfig.ini` внутри ZIP является только шаблоном значений по умолчанию. Все изменения из настроек записываются в `UserData`, поэтому обновление бренда не должно затирать настройку оператора.

Пока остаются внутри версии RollHouse и требуют осторожности при обновлениях:

- `brands/rollhouse/RkConfig.ini` — WinAPI-привязки, PLU, подарки, горячие клавиши и другие настройки;
- `brands/rollhouse/last_enter_state.ini` — runtime-снимок последнего Enter;
- `ahk_debug.log` и другие рабочие логи рядом со скриптом.

Для RollHouse это остаётся архитектурным долгом: лаунчер пока не мигрирует его `RkConfig.ini` между версиями. Не переносить реализацию RollClub обратно на пакетный конфиг.

## Launcher и релизы

Текущий опубликованный релиз лаунчера: `0.1.42`.
Текущий пакет RollHouse в манифесте: `0.1.18`.
Текущее дополнение отчёта в манифесте: `rollhouse-report-load` версии `0.1.17`.
Текущий пакет RollClub после этого прохода: `0.1.12`; дополнение F4 — `0.1.1`, зоны — `0.1.1`.

Источник обновлений по умолчанию:

`https://github.com/voffkazxc/RollHelper/releases/latest/download/release-manifest.json`

Лаунчер уже умеет:

- обновлять сам себя отдельно от выбранной программы;
- устанавливать и запускать универсальные пакеты;
- показывать модули только после выбора основной программы;
- устанавливать, отключать и удалять модули;
- сохранять размер окна, разделитель и ширину колонок.

Для новой версии уже установленного дополнения кнопка в правой панели называется «Обновить». Обновление только дополнения не должно повышать версию или статус RollHouse: manifest переиспользует прежний ZIP бренда. Правила перед выпуском нового бренда или модуля: `docs/OPERATOR_UI_COMPATIBILITY.md`.

Поддержка модулей в лаунчере реализована. Первое рабочее дополнение `Отчёт — нагрузка` публикуется как отдельный module-пакет для RollHouse. Специфика RollHouse или RollClub не должна добавляться в код лаунчера.

Сборка полного релиза:

```powershell
.\packaging\build-release.ps1 -Version <version>
```

Сборка только нового лаунчера без повышения версии RollHouse:

```powershell
.\packaging\build-launcher-release.ps1 `
  -Version <launcher-version> `
  -PackagesManifestPath <previous-release-manifest.json> `
  -PackageAssetBaseUrl <url-предыдущего-релиза>
```

## Основные каталоги

| Путь | Назначение |
|---|---|
| `main.ahk` | Монолит RollHouse и основной production entrypoint |
| `engine_rollclub.ahk` | Монолит RollClub |
| `brands/rollhouse/` | Конфиг, шаблоны, KML и данные RollHouse |
| `brands/rollclub/` | Конфиг, кухни, промо и данные RollClub |
| `core/orchestration/` | Пассивный координатор операций |
| `core/modules/` | Реестр модулей и применение MVP-профиля |
| `lib/` | Общие AHK-библиотеки UIA/WinAPI |
| `Launcher/` | Исходники, документация и тесты WPF-лаунчера |
| `packaging/` | Сборка ZIP-пакетов и release manifest |
| `tools/call_listener/` | Экспериментальный автообзвон, аудио и модели |
| `_archive/` и `*.BEFORE_*` | История и бэкапы, не production-источник |

## Что не считать источником правды

- `*.BEFORE_*`, `*.bak_*`, старые portable-сборки и `RollHouseLite*`;
- тестовые дампы, OCR-картинки, временные `.txt` и старые логи;
- `PLAN.md` как описание уже реализованной архитектуры;
- `PROJECT_BACKLOG.md` как полный список оставшихся задач;
- целевую структуру из `docs/ARCHITECTURE_DECOMPOSITION.md` как уже существующие каталоги.

## Проверки перед изменением

1. Посмотреть `git status` и не включать в коммит runtime-файлы пользователя.
2. Для `main.ahk` использовать только AutoHotkey v1.1; AHK v2 не подходит.
3. После изменения launcher запускать:
   - `Launcher/tests/test-module-lifecycle.ps1`;
   - `Launcher/tests/test-self-update.ps1`.
4. После изменения RollHouse проверить вручную минимум: тильда, Enter, F1 и `Ctrl+Enter`.
5. Не включать отключённые MVP-модули только ради теста базового заказа.

## Документы по подсистемам

- `STATUS.md` — актуальный рабочий статус.
- `Launcher/README.md` — формат пакетов, обновление launcher и модули.
- `docs/ROLLHOUSE_ZONES.md` — KML и цены зон.
- `docs/SMOKE_CHECKLIST_STAGE1.md` — проверка OperationCoordinator и MVP-флагов.
- `CALL_LISTENER_HANDOFF.md` — состояние эксперимента автообзвона.
- `docs/ARCHITECTURE_DECOMPOSITION.md` — карта зависимостей и план будущего разделения.
- `UIA_CLICK_MIGRATION.md` и `PROJECT_BACKLOG.md` — история миграции UIA, не полный текущий статус.
