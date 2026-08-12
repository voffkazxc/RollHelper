#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%\brands\rollclub   ; дані Roll Club (конфіг, промо, кухні, img)
FileEncoding, UTF-8
#Include %A_ScriptDir%\lib\IikoUI.ahk
#Include %A_ScriptDir%\core\orchestration\OperationCoordinator.ahk
#Include %A_ScriptDir%\core\modules\ModuleRegistry.ahk

OpCoord_Init("rollclub", A_ScriptDir)
ModuleRegistry_Init(A_ScriptDir, "rollclub", "mvp")
ModuleRegistry_RegisterExternal("duty", "rollclub-duty")
OnMessage(0x8001, "RcDutyModuleMessage")

if (Module_IsEnabled("duty")) {
    EnvSet, ROLLHELPER_ROLLCLUB_DUTY_HWND, %A_ScriptHwnd%
    ModuleRegistry_RunExternal("duty")
}
RhKillDuplicateInstances()

; Налаштування координат
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen

; Максимальна швидкість виконання
SetBatchLines, -1
ListLines, Off

; ── Автозакриття діалогу "Сумма заказа" (інший прайс-лист) ──
SetTimer, CloseSummaAlert, 500

; Налаштування вводу (миттєве виконання)
SendMode Input
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1

Menu, Tray, Add
Menu, Tray, Add, ⚙ Налаштування RollClub, OpenSettings

; ── RollHelper: сервер iiko-моста (читання полів ПО ІМЕНАХ) ──
global RH_SERVER := "http://127.0.0.1:5000"
global RH_SERVER_OK := 0
RhPing()
if (!RH_SERVER_OK) {
    RcLaunchServerProcess(0)
    Loop, 16 {
        Sleep, 500
        if (RhPing())
            break
    }
}
; Зелене сповіщення внизу справа (як у Roll House) — показуємо ЗАВЖДИ при старті
if (RH_SERVER_OK)
    TrayTip, RollClub PRO, 🟢 Сервер запущено — читання через сервер, 2, 1
else
    TrayTip, RollClub PRO, ⚠️ Сервер не відповідає — читання буде кліком, 3, 2

; ========================================================
; АВТОСТВОРЕННЯ КОНФІГУ якщо немає
; ========================================================
ConfigPath := A_ScriptDir "\brands\rollclub\RkConfig.ini"
global UIA_MAP_CONFIG := ConfigPath
rcLogPath  := A_ScriptDir "\siv_debug.log"

if !FileExist(ConfigPath) {
    IniWrite, 0,     %ConfigPath%, Targets, CommX
    IniWrite, 0,     %ConfigPath%, Targets, CommY
    IniWrite, 0,     %ConfigPath%, Targets, CardX
    IniWrite, 0,     %ConfigPath%, Targets, CardY
    IniWrite, 0,     %ConfigPath%, Targets, InfoX
    IniWrite, 0,     %ConfigPath%, Targets, InfoY
    IniWrite, 0,     %ConfigPath%, Targets, AddrX
    IniWrite, 0,     %ConfigPath%, Targets, AddrY
    IniWrite, 0,     %ConfigPath%, Targets, TimeX
    IniWrite, 0,     %ConfigPath%, Targets, TimeY
    IniWrite, 0,     %ConfigPath%, Targets, CashX
    IniWrite, 0,     %ConfigPath%, Targets, CashY
    IniWrite, 0,     %ConfigPath%, Targets, CrossX
    IniWrite, 0,     %ConfigPath%, Targets, CrossY
    IniWrite, 0,     %ConfigPath%, Targets, ItemX
    IniWrite, 0,     %ConfigPath%, Targets, ItemY
    IniWrite, 0,     %ConfigPath%, Targets, SumX
    IniWrite, 0,     %ConfigPath%, Targets, SumY
    IniWrite, 02929, %ConfigPath%, PLU, Gunkan
    IniWrite, 02216, %ConfigPath%, PLU, Pepsi
    IniWrite, 02217, %ConfigPath%, PLU, Burger
    IniWrite, 02926, %ConfigPath%, PLU, Sandwich
    IniWrite, 00143, %ConfigPath%, PLU, SticksNorm
    IniWrite, 00144, %ConfigPath%, PLU, SticksEdu
    IniWrite, 02439, %ConfigPath%, PLU, Utensils
    IniWrite, 00140, %ConfigPath%, PLU, Fork
    IniWrite, 00142, %ConfigPath%, PLU, Knife
    IniWrite, 00424, %ConfigPath%, PLU_SIV, Soy
    IniWrite, 00428, %ConfigPath%, PLU_SIV, Ginger
    IniWrite, 00426, %ConfigPath%, PLU_SIV, Wasabi
    IniWrite, 0,     %ConfigPath%, Targets, WaitX
    IniWrite, 0,     %ConfigPath%, Targets, WaitY
    IniWrite, 0,     %ConfigPath%, Targets, CallX
    IniWrite, 0,     %ConfigPath%, Targets, CallY
    IniWrite, 0,     %ConfigPath%, Targets, AdrReadX
    IniWrite, 0,     %ConfigPath%, Targets, AdrReadY
    IniWrite, 0,     %ConfigPath%, Targets, KontsX
    IniWrite, 0,     %ConfigPath%, Targets, KontsY
    IniWrite, vkC0,  %ConfigPath%, Hotkeys, Main
    IniWrite, F1,    %ConfigPath%, Hotkeys, Siv
    MsgBox, 64, Rollclub PRO, Створено новий RkConfig.ini`nЗараз відкриється вікно налаштувань!, 3
    GoSub, OpenSettings
}

; ========================================================
; ЧИТАННЯ КОНФІГУ
; ========================================================
IniRead, commX,  %ConfigPath%, Targets, CommX,  0
IniRead, commY,  %ConfigPath%, Targets, CommY,  0
IniRead, cardX,  %ConfigPath%, Targets, CardX,  0
IniRead, cardY,  %ConfigPath%, Targets, CardY,  0
IniRead, infoX,  %ConfigPath%, Targets, InfoX,  0
IniRead, infoY,  %ConfigPath%, Targets, InfoY,  0
IniRead, addrX,  %ConfigPath%, Targets, AddrX,  0
IniRead, addrY,  %ConfigPath%, Targets, AddrY,  0
IniRead, timeX,  %ConfigPath%, Targets, TimeX,  0
IniRead, timeY,  %ConfigPath%, Targets, TimeY,  0
IniRead, cashX,  %ConfigPath%, Targets, CashX,  0
IniRead, cashY,  %ConfigPath%, Targets, CashY,  0
IniRead, crossX, %ConfigPath%, Targets, CrossX, 0
IniRead, crossY, %ConfigPath%, Targets, CrossY, 0
IniRead, itemX,  %ConfigPath%, Targets, ItemX,  0
IniRead, itemY,  %ConfigPath%, Targets, ItemY,  0
IniRead, sumX,   %ConfigPath%, Targets, SumX,   0
IniRead, sumY,   %ConfigPath%, Targets, SumY,   0
IniRead, waitX,  %ConfigPath%, Targets, WaitX,  0
IniRead, waitY,  %ConfigPath%, Targets, WaitY,  0
IniRead, callX,    %ConfigPath%, Targets, CallX,    0
IniRead, callY,    %ConfigPath%, Targets, CallY,    0
IniRead, adrReadX, %ConfigPath%, Targets, AdrReadX, 0
IniRead, adrReadY, %ConfigPath%, Targets, AdrReadY, 0
IniRead, kontsX,   %ConfigPath%, Targets, KontsX,   0
IniRead, kontsY,   %ConfigPath%, Targets, KontsY,   0
IniRead, confirmX, %ConfigPath%, Targets, ConfirmX, 0
IniRead, confirmY, %ConfigPath%, Targets, ConfirmY, 0
IniRead, saveX,    %ConfigPath%, Targets, SaveX,    0
IniRead, saveY,    %ConfigPath%, Targets, SaveY,    0
IniRead, naitiX,   %ConfigPath%, Targets, NaitiX,   0
IniRead, naitiY,   %ConfigPath%, Targets, NaitiY,   0
IniRead, tochkaX,  %ConfigPath%, Targets, TochkaX,  0
IniRead, tochkaY,  %ConfigPath%, Targets, TochkaY,  0
IniRead, poiskX,   %ConfigPath%, Targets, PoiskX,   0
IniRead, poiskY,   %ConfigPath%, Targets, PoiskY,   0
IniRead, rowX,     %ConfigPath%, Targets, RowX,     0
IniRead, rowY,     %ConfigPath%, Targets, RowY,     0

; Рубильники
IniRead, CHECK_POINT_ENABLED, %ConfigPath%, Main, CheckPoint, 1
; У старих конфігураціях подарунки залишаються доступними. У пакеті RollClub
; цей перемикач вимкнено, бо акція завершилась.
IniRead, RC_GIFTS_ENABLED, %ConfigPath%, Features, Gifts, 1

IniRead, pluGunkan,   %ConfigPath%, PLU, Gunkan,   02929
IniRead, pluPepsi,    %ConfigPath%, PLU, Pepsi,    02216
IniRead, pluBurger,   %ConfigPath%, PLU, Burger,   02217
IniRead, pluSandwich, %ConfigPath%, PLU, Sandwich, 02926
IniRead, pluSticksNorm, %ConfigPath%, PLU, SticksNorm, 00143
IniRead, pluSticksEdu,  %ConfigPath%, PLU, SticksEdu,  00144
IniRead, pluUtensils,   %ConfigPath%, PLU, Utensils,   02439
IniRead, pluFork,       %ConfigPath%, PLU, Fork,       00140
IniRead, pluKnife,      %ConfigPath%, PLU, Knife,      00142
IniRead, pluSoy,        %ConfigPath%, PLU_SIV, Soy,        00424
IniRead, pluGinger,     %ConfigPath%, PLU_SIV, Ginger,     00428
IniRead, pluWasabi,     %ConfigPath%, PLU_SIV, Wasabi,     00426

IniRead, hkMain,   %ConfigPath%, Hotkeys, Main,      vkC0
IniRead, hkSiv,   %ConfigPath%, Hotkeys, Siv,       F1
IniRead, hkFinish,%ConfigPath%, Hotkeys, Finish,    ^+Enter
IniRead, uiTheme, %ConfigPath%, UI, Theme, light
global uiTheme

; Очищення від можливих артефактів кодування (нульових байтів)
hkMain   := RegExReplace(hkMain,   "[^a-zA-Z0-9!#^+]")
hkSiv    := RegExReplace(hkSiv,    "[^a-zA-Z0-9!#^+]")
hkFinish := RegExReplace(hkFinish, "[^a-zA-Z0-9!#^+]")
if (hkMain   = "") hkMain   := "vkC0"
if (hkSiv    = "") hkSiv    := "F1"
if (hkFinish = "") hkFinish := "^+Enter"

; ========================================================
; ГЛОБАЛЬНІ ЗМІННІ
; ========================================================
global rawComment   := ""
global cleanComment := ""
global infoText     := ""
global addrNote     := ""
global extractedTime:= ""
global extractedTimeAuto := 0
global clientChange := ""
global cardText     := ""
global orderSum     := 0
global calcChange   := 0
global autoCash     := 0
global autoGunkan   := 0
global autoPepsi    := 0
global autoBurger   := 0
global autoSandwich := 0
global autoSticksNorm := 0
global autoSticksEdu  := 0
global isPost       := 0
global postNum      := ""
global needCall     := 0
global isFutureDate := 0
global warnReason   := ""
global parsedSticksNorm := ""
global parsedSticksEdu  := ""
global isWaiting    := 0
global isWaitingCall:= 0
; callX / callY читаються з INI (рядки 87-88), не перезаписувати

; --- Нові флаги розширеного парсингу (PRO 33.0) ---
global hasFilaClub      := 0
global hasBirthday      := 0     ; день народження
global hasAllergy       := 0     ; алергія — окремий бокс
global hasPickup        := 0     ; Самовивіз
global hasUtensils      := 0     ; Виделка/Ніж/Ложка детектовано
global utensilsText     := ""
global parsedUtensils   := ""    ; кількість приборів з тексту
global autoUtensils     := 0     ; авто-пробити прибори (PLU)
global hasCustomerReq   := 0     ; прохання клієнта
global customerReqText  := ""
global promoFound       := ""    ; знайдений код промо
global promoKnown       := 0     ; 1 = в базі, 0 = новий
global pickupPoint      := ""    ; точка самовивозу з тексту
global addrMismatch    := 0    ; 1 = вулиця в коменті ≠ адресна строка
global commentStreet   := ""   ; вулиця витягнута з коментаря
global blockedHit      := 0    ; 1 = адреса на перекритій вулиці (brands/rollclub/BlockedStreets.txt)
global blockedInfo     := ""   ; текст плашки: "Вулиця — ділянка"

OnMessage(0x0138, "WM_CTLCOLORSTATIC")
global RhStaticColors := {}
global RhStaticBrush := {}

; --- База промокодів ---
global PromoPath := A_ScriptDir "\brands\rollclub\RkPromo.ini"
global KnownPromos := {}
GoSub, LoadPromoBase

; --- База кухонь ---
global KitchensPath  := A_ScriptDir "\brands\rollclub\RkKitchens.ini"
global PresetsPath   := A_ScriptDir "\brands\rollclub\RkPresets.txt"
global Kitchens := []          ; масив об'єктів {Name, City, Address, ...}
global rawAddress      := ""   ; скопійований адрес з iiko
global detectedCity    := ""   ; визначене місто
global kitchenLine     := ""   ; готова рядок-плашка для пульта
global hasKitchenAlert := 0    ; 1 якщо хоч одна точка міста ≠ ok
global RcCurrentKitchen := ""   ; поточна кухня з RkKitchens.ini для часу/алертів
global RcKitchenLastSyncTick := 0
global RcKitchenSyncCooldownMs := 180000
GoSub, SyncKitchensFromSheet
GoSub, LoadKitchens

; Зона пошуку вікна модифікаторів (по скринах)
global SIVSearchX1 := 490
global SIVSearchY1 := 140
global SIVSearchX2 := 965
global SIVSearchY2 := 655

; Зміщення до поля кількості (виміряно по скріншоту)
global SIVOffsetX := 227
global SIVOffsetY := 5

global RollHwnd    := 0   ; hwnd головного вікна Roll
global RcRawShown  := 0   ; 1 = вихідний текст розгорнуто
global RcRawEditH  := 0   ; висота Edit-контролу (px)
global RcZones     := []  ; [{name, coords:[...]}] — кеш зон з KML
global AUTO_KC_ENABLED := 0  ; ГОЛОВНИЙ РУБИЛЬНИК авто-КЦ. 0 = вимкнено (швидкий ручний пульт, БЕЗ фонового монітора). 1 = увімкнути авто (експеримент).
global CHECK_POINT_ENABLED       ; РУБИЛЬНИК звірки точки (значення береться з RkConfig.ini).
global RcLastZone := ""   ; остання визначена нами KML-зона (для звірки з iiko)
global tochkaX, tochkaY             ; приціл поля "Точка" — значення з IniRead рядок 130-131
global autoMode    := 0   ; 🤖 авто-режим (концепція/подарунок/пакет) — тумблер у пульті
global kcBusy      := 0   ; монітор КЦ зайнятий (анти-реентрі)
global rhPunchBusy := 0   ; 1 = зараз іде пробиття/PLU; F4/KC не має права робити кліки
global kcStop      := 0   ; F4-стоп: сигнал негайно перервати поточний захід
global kcLastNo    := ""  ; останній помічений № (щоб не дублювати звук)
global kcPaused    := 0   ; пауза монітора: чекаємо Ctrl+Enter оператора
global RcZonesOk   := 0   ; 1 = KML завантажено

; ========================================================
; ГАРЯЧІ КЛАВІШІ
; ========================================================
Hotkey, %hkMain%, TriggerMain, On
Hotkey, %hkSiv%,  TriggerSiv,  On
; FinishOrder тепер статична клавіша в #IfWinActive блоках (надійніше ніж Hotkey динамічний)

SetTimer, RollFocusWatcher, 300
SetTimer, RcKitchensBackgroundSync, 180000


return

RollFocusWatcher:
    if !WinExist("Rollclub PRO 33.0")
        return
    if WinActive("Rollclub PRO 33.0")
        return
    if WinActive("Налаштування RollClub")
        return
    if WinActive("Кухні — статуси")
        return
    if WinActive("СИВ (Модуль)")
        return
    Gui, Roll:Hide
return

; ========================================================
; ГОЛОВНИЙ ТРИГЕР
; ========================================================
TriggerMain:
    OpCoord_Event("ReadingOrder", "trigger", "TriggerMain", "inDutyTake=" . _inDutyTake . ";dutyOn=" . dutyOn)
    GoSub, KcStopDuty          ; ручна робота → дежурство стоп
    ; При дежурстві (_inDutyTake=1) НЕ тоглимо видимість, а ЗАВЖДИ робимо повний перечит нового заказу.
    ; Ручна тільда — як раніше: тогл показати/сховати.
    if (!_inDutyTake) {
        ; Пульт видимий → сховати (тогл)
        if WinExist("Rollclub PRO 33.0") {
            Gui, Roll:Hide
            return
        }
        ; Пульт захований → показати без ресканування
        DetectHiddenWindows, On
        rollHidden := WinExist("Rollclub PRO 33.0")
        DetectHiddenWindows, Off
        if (rollHidden) {
            GoSub, RcKitchensSyncIfStale
            Gui, Roll:Show
            WinActivate, Rollclub PRO 33.0
            GoSub, RhRepaintRollPult
            return
        }
    }
    ; Пульту немає взагалі → повний скан
    if (commX = 0 || commX = "" || commX = "ERROR") {
        MsgBox, 48, Налаштування, Координати не встановлені!`nЗараз відкриється вікно налаштувань.
        GoSub, OpenSettings
        return
    }

    GoSub, RcKitchensSyncIfStale

    ; --- Читання коментаря+суми: спершу СЕРВЕР (по іменах), інакше КЛІКОМ ---
    rawComment := ""
    orderSum := 0
    _srvOk := 0
    if (RH_SERVER_OK || RhPing()) {
        _d := RhGet("/api/iiko/read", 8000)
        if (_d != "" && !InStr(_d, """ok"":false") && !InStr(_d, """ok"": false")) {
            RegExMatch(_d, """comment""\s*:\s*""((?:[^""\\]|\\.)*)""", _mc)
            _srvComment := StrReplace(StrReplace(_mc1, "\n", "`n"), "\r", "")
            if (_srvComment != "") {
                rawComment := _srvComment
                RegExMatch(_d, """sum""\s*:\s*(\d+)", _ms)
                orderSum := _ms1 + 0
                _srvOk := 1
            }
        }
    }
    if (!_srvOk) {
        ; Фолбек — читання кліком (як раніше, якщо сервер не відповів)
        Clipboard := ""
        IikoUI_FocusComment()
        Sleep, 100
        Send, ^a
        Sleep, 50
        Send, ^c
        ClipWait, 1.5
        rawComment := Clipboard

        if (sumX != 0 && sumX != "ERROR") {
            Clipboard := ""
            Click, %sumX%, %sumY%
            Sleep, 150
            Send, ^c
            ClipWait, 1
            tempSum := RegExReplace(Clipboard, "[^\d,.]", "")
            tempSum := StrReplace(tempSum, ",", ".")
            tempSum := RegExReplace(tempSum, "\..*", "")
            if (tempSum != "")
                orderSum := tempSum + 0
        }
    }

    ; Читаємо адресу заказу (для детекту міста та статусу кухонь)
    rawAddress := ""
    if (adrReadX != 0 && adrReadX != "ERROR") {
        Clipboard := ""
        Click, %adrReadX%, %adrReadY%
        Sleep, 100
        Send, ^a
        Sleep, 50
        Send, ^c
        ClipWait, 1
        rawAddress := Clipboard
    }

    ; Видима підказка: через що прочитали замовлення
    if (_srvOk)
        ToolTip, % "📡 Прочитано через СЕРВЕР", 30, 30
    else
        ToolTip, % "🖱 Прочитано КЛІКОМ (сервер не відповів)", 30, 30
    SetTimer, RcRemoveTip, -2500

    GoSub, SilentMagicClean
    GoSub, DetectKitchenStatus
    GoSub, DrawRollclub
return

RcRemoveTip:
    ToolTip
return

TriggerSiv:
    OpCoord_Event("PunchingSiv", "trigger", "TriggerSiv", "dutyOn=" . dutyOn)
    GoSub, KcStopDuty
    GoSub, AddSivVisual
return

TriggerWait:
    GoSub, KcStopDuty
    if (isWaiting) {
        isWaiting := 0
        SetTimer, LoopWaitOrder, Off
        ToolTip
        return
    }

    ; Читаємо зону пошуку з INI
    IniRead, zoneX1, %ConfigPath%, WaitZone, X1, 0
    IniRead, zoneY1, %ConfigPath%, WaitZone, Y1, 0
    IniRead, zoneX2, %ConfigPath%, WaitZone, X2, 0
    IniRead, zoneY2, %ConfigPath%, WaitZone, Y2, 0

    if (zoneX1 = 0 && zoneY1 = 0 && zoneX2 = 0 && zoneY2 = 0) {
        MsgBox, 48, Авто-Прийом CRM, Зона пошуку не задана!`nЗараз вкажи два кути: верхній лівий та нижній правий.
        GoSub, CalibrateWaitZone
        return
    }

    ; Показати рамку зони на 2 сек (превью), потім прибрати щоб не заважала ImageSearch
    GoSub, ShowZoneFrame
    Sleep, 2000
    Gui, ZoneFrame:Destroy

    isWaiting := 1
    waitScanCount := 0
    SetTimer, LoopWaitOrder, 500
    GoSub, LoopWaitOrder
return

CalibrateWaitZone:
    MsgBox, 4160, Калібрування зони, Клікни у ВЕРХНІЙ ЛІВИЙ кут зони пошуку.
    KeyWait, LButton, Down
    MouseGetPos, zoneX1, zoneY1
    KeyWait, LButton, Up
    Sleep, 200

    MsgBox, 4160, Калібрування зони, Тепер клікни у НИЖНІЙ ПРАВИЙ кут зони пошуку.
    KeyWait, LButton, Down
    MouseGetPos, zoneX2, zoneY2
    KeyWait, LButton, Up

    ; Гарантуємо правильний порядок координат
    if (zoneX1 > zoneX2) {
        tmp := zoneX1
        zoneX1 := zoneX2
        zoneX2 := tmp
    }
    if (zoneY1 > zoneY2) {
        tmp := zoneY1
        zoneY1 := zoneY2
        zoneY2 := tmp
    }

    IniWrite, %zoneX1%, %ConfigPath%, WaitZone, X1
    IniWrite, %zoneY1%, %ConfigPath%, WaitZone, Y1
    IniWrite, %zoneX2%, %ConfigPath%, WaitZone, X2
    IniWrite, %zoneY2%, %ConfigPath%, WaitZone, Y2

    zW := zoneX2 - zoneX1
    zH := zoneY2 - zoneY1
    MsgBox, 64, Збережено, Зона пошуку: %zoneX1%,%zoneY1% → %zoneX2%,%zoneY2%`nРозмір: %zW% x %zH% px`n`nТепер натисни %hkWait% для запуску., 3
return

ShowZoneFrame:
    Gui, ZoneFrame:Destroy
    zW := zoneX2 - zoneX1
    zH := zoneY2 - zoneY1
    Gui, ZoneFrame:+AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, ZoneFrame:Color, FF0000
    WinSet, TransColor, FF0000 180,
    ; Створюємо 4 лінії рамки (2px товщина)
    borderT := 2
    innerW := zW - (borderT * 2)
    innerH := zH - (borderT * 2)
    Gui, ZoneFrame:Add, Progress, x0 y0 w%zW% h%borderT% BackgroundRed
    Gui, ZoneFrame:Add, Progress, x0 y0 w%borderT% h%zH% BackgroundRed
    rX := zW - borderT
    Gui, ZoneFrame:Add, Progress, x%rX% y0 w%borderT% h%zH% BackgroundRed
    bY := zH - borderT
    Gui, ZoneFrame:Add, Progress, x0 y%bY% w%zW% h%borderT% BackgroundRed
    Gui, ZoneFrame:Show, x%zoneX1% y%zoneY1% w%zW% h%zH% NoActivate, ZoneFrameWin
    WinSet, ExStyle, +0x80020, ZoneFrameWin  ; WS_EX_TRANSPARENT + WS_EX_TOOLWINDOW
    WinSet, TransColor, 000000, ZoneFrameWin
return

LoopWaitOrder:
    if (!isWaiting) {
        SetTimer, LoopWaitOrder, Off
        ToolTip
        return
    }

    waitScanCount++

    ; Розрахунок розміру зони
    zW := zoneX2 - zoneX1
    zH := zoneY2 - zoneY1

    ; ImageSearch в межах заданої зони (допуск *50 для субпіксельного згладжування тексту)
    ImageSearch, foundX, foundY, %zoneX1%, %zoneY1%, %zoneX2%, %zoneY2%, *50 img\zxc.png
    lastErr := ErrorLevel

    ; Дебаг-тултіп з повною інформацією
    if (lastErr = 2)
        errTxt := "⛔ ПОМИЛКА (файл/зона)"
    else if (lastErr = 1)
        errTxt := "🔍 Шукаю..."
    else
        errTxt := "✅ ЗНАЙДЕНО"
    ToolTip, ⌛ Авто-прийом CRM замовлень...`nЗона: [%zoneX1%`,%zoneY1%] → [%zoneX2%`,%zoneY2%] (%zW%x%zH% px)`nСкан #%waitScanCount% | %errTxt%`nНатисни %hkWait% для зупинки., %zoneX1%, % zoneY1 - 70

    if (lastErr == 0) {
        isWaiting := 0
        SetTimer, LoopWaitOrder, Off
        ToolTip, 🟢 ЗАМОВЛЕННЯ ЗНАЙДЕНО! [%foundX%x%foundY%], %foundX%, % foundY - 30

        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: Order Found at %foundX%x%foundY% (zone %zoneX1%,%zoneY1%-%zoneX2%,%zoneY2%) scan#%waitScanCount%`n, %logFile%

        ; Клікаємо туди, де знайшли
        Click, %foundX%, %foundY%, 2
        Sleep, 100
        Click, %foundX%, %foundY%, 2

        ; Короткий звуковий сигнал
        if FileExist(A_WinDir "\Media\Alarm01.wav") {
            SoundPlay, %A_WinDir%\Media\Alarm01.wav
        } else {
            SoundBeep, 800, 300
        }

        SetTimer, RemoveWaitToolTip, -3000
    }
return

RemoveWaitToolTip:
    ToolTip
return

TriggerCall:
    GoSub, KcStopDuty
    if (isWaitingCall) {
        isWaitingCall := 0
        SetTimer, LoopWaitCall, Off
        ToolTip, , , , 2
        return
    }

    if (callX = 0 || callX = "" || callX = "ERROR") {
        MsgBox, 48, Налаштування, Приціл Авто-Прийому Дзвінка не встановлено!`nВідкриється вікно налаштувань.
        GoSub, OpenSettings
        return
    }

    isWaitingCall := 1
    SetTimer, LoopWaitCall, 500
    GoSub, LoopWaitCall
return

LoopWaitCall:
    if (!isWaitingCall) {
        SetTimer, LoopWaitCall, Off
        ToolTip, , , , 2
        return
    }

    cYOffset := callY + 50
    ToolTip, 📞 Автоприйом дзвінка...`nНатисни %hkCall% для зупинки., %callX%, %cYOffset%, 2

    ; Шукаємо тільки в зоні прицілу (±150 пікселів)
    cX1 := callX - 150
    cY1 := callY - 150
    cX2 := callX + 150
    cY2 := callY + 150
    if (cX1 < 0)
        cX1 := 0
    if (cY1 < 0)
        cY1 := 0
    if (cX2 > A_ScreenWidth)
        cX2 := A_ScreenWidth
    if (cY2 > A_ScreenHeight)
        cY2 := A_ScreenHeight

    ImageSearch, foundCallX, foundCallY, %cX1%, %cY1%, %cX2%, %cY2%, *30 img\zxc1.png
    if (ErrorLevel == 0) {
        clkX := foundCallX + 10
        clkY := foundCallY + 10
        Click, %clkX%, %clkY%, 2
        Sleep, 100
        Click, %clkX%, %clkY%, 2

        isWaitingCall := 0
        SetTimer, LoopWaitCall, Off
        ToolTip, 🟢 ДЗВІНОК ПРИЙНЯТО!, %foundCallX%, % foundCallY - 30, 2

        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: Call Found and Answered at %foundCallX%x%foundCallY%`n, %logFile%

        SetTimer, RemoveCallToolTip, -3000
    }
return

RemoveCallToolTip:
    ToolTip, , , , 2
return

RemoveFilaClubToolTip:
    ToolTip, , , , 4
return


; ========================================================
; БАЗА ПРОМОКОДІВ
; ========================================================
LoadPromoBase:
    KnownPromos := {}
    if !FileExist(PromoPath)
        return
    FileRead, raw, *P65001 %PromoPath%
    inKnown := 0
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        if (SubStr(line, 1, 1) = "[" && SubStr(line, 0) = "]") {
            sec := SubStr(line, 2, StrLen(line) - 2)
            inKnown := (sec = "Known") ? 1 : 0
            continue
        }
        if (!inKnown)
            continue
        eqPos := InStr(line, "=")
        kLow := (eqPos ? Trim(SubStr(line, 1, eqPos - 1)) : Trim(line))
        StringLower, kLow, kLow
        if (kLow != "")
            KnownPromos[kLow] := 1
    }
return
LoadKitchens:
    RcLoadZoneMap()
    global Kitchens, RcKitchensOk:= []
    if !FileExist(KitchensPath)
        return
    ; читаємо файл напряму як UTF-8 (IniRead через WinAPI ламає кирилицю)
    FileRead, raw, *P65001 %KitchensPath%
    curSec := ""
    curObj := ""
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField)
        if (line == "" || SubStr(line, 1, 1) == ";")
            continue
        ; секція
        if (SubStr(line, 1, 1) == "[" && SubStr(line, 0) == "]") {
            if (curObj)
                Kitchens.Push(curObj)
            curSec := SubStr(line, 2, StrLen(line) - 2)
            curObj := {Name: curSec, City: "", Address: "", KmlKey: "", Remark: "", Center: "Стандарт", Pickup: "Стандарт", FarZone: "Стандарт", StopList: ""}
            continue
        }
        ; key=value
        eqPos := InStr(line, "=")
        if (eqPos == 0 || !curObj)
            continue
        k := Trim(SubStr(line, 1, eqPos - 1))
        v := Trim(SubStr(line, eqPos + 1))
        if (k == "City")
            curObj.City := v
        else if (k == "Address")
            curObj.Address := v
        else if (k == "KmlKey")
            curObj.KmlKey := v
        else if (k == "Remark")
            curObj.Remark := v
        else if (k == "Center")
            curObj.Center := v
        else if (k == "Pickup")
            curObj.Pickup := v
        else if (k == "FarZone")
            curObj.FarZone := v
        else if (k == "StopList")
            curObj.StopList := v
    }
    if (curObj)
        Kitchens.Push(curObj)
    logFile := A_ScriptDir "\siv_debug.log"
    kCnt := Kitchens.MaxIndex() ? Kitchens.MaxIndex() : 0
    FileAppend, `n[DEBUG] %A_Now% - Event: Kitchens loaded = %kCnt%`n, %logFile%
return

SyncKitchensFromSheet:
    global RcKitchenLastSyncTick
    syncScript := A_ScriptDir "\..\server\sync_rollclub_kitchens.py"
    if !FileExist(syncScript)
        return
    RunWait, %ComSpec% /c python sync_rollclub_kitchens.py --quiet, %A_ScriptDir%\..\server, Hide UseErrorLevel
    if (ErrorLevel) {
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: Kitchens sheet sync failed, ErrorLevel=%ErrorLevel%`n, %logFile%
    } else {
        RcKitchenLastSyncTick := A_TickCount
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: Kitchens sheet sync OK`n, %logFile%
    }
return

RcKitchensSyncIfStale:
    global RcKitchenLastSyncTick, RcKitchenSyncCooldownMs
    if (RcKitchensSyncBlocked())
        return
    if (RcKitchenLastSyncTick && (A_TickCount - RcKitchenLastSyncTick < RcKitchenSyncCooldownMs))
        return
    GoSub, SyncKitchensFromSheet
    GoSub, LoadKitchens
return

RcKitchensBackgroundSync:
    GoSub, RcKitchensSyncIfStale
return

RcKitchensSyncBlocked() {
    global rhPunchBusy, kcBusy, _inDutyTake, dutyOn, kcForce
    if (rhPunchBusy || kcBusy || _inDutyTake || dutyOn || kcForce)
        return 1
    return 0
}

RcFindKitchenFromText(text) {
    global Kitchens
    hay := text
    StringLower, hay, hay
    if (hay == "")
        return ""
    for _, k in Kitchens {
        n := k.Name, a := k.Address, key := k.KmlKey
        StringLower, n, n
        StringLower, a, a
        StringLower, key, key
        if ((n != "" && InStr(hay, n)) || (key != "" && InStr(hay, key)) || (a != "" && InStr(hay, a)))
            return k
    }
    return ""
}

RcKitchenFromKmlZone(zoneName) {
    global RcZoneMap
    if (!IsObject(RcZoneMap))
        RcLoadZoneMap()
    zoneExact := Trim(zoneName)
    if (RcZoneMap.HasKey(zoneExact)) {
        return RcZoneMap[zoneExact]
    }
    ; fallback
    zoneClean := Trim(RegExReplace(zoneName, "[\[\]]", ""))
    type := RcDeliveryKindFromZone(zoneClean)
    dbgkterms := ""
    global Kitchens
    for _, k in Kitchens {
        kTerm := (k.KmlKey != "") ? k.KmlKey : k.Name
        if (kTerm != "" && InStr(zoneClean, kTerm)) {
            return {Kitchen: k.Name, Type: type}
        }
    }
    return ""
}

RcDeliveryKindFromZone(zone) {
    z := zone
    StringLower, z, z
    if (RegExMatch(z, "i)(даль|дал|збільш|підвищ|повыш|збільшеного|збільшена)"))
        return "FAR"
    return "STANDARD"
}

RcKitchenMinutes(kind, defaultMin) {
    global RcCurrentKitchen
    if (!IsObject(RcCurrentKitchen))
        return defaultMin
    val := ""
    if (kind = "pickup")
        val := RcCurrentKitchen.Pickup
    else if (kind = "far")
        val := RcCurrentKitchen.FarZone
    else
        val := RcCurrentKitchen.Center
    return RcParseKitchenMinutes(val, defaultMin)
}

RcParseKitchenMinutes(text, defaultMin) {
    t := Trim(text)
    if (t == "")
        return defaultMin
    StringLower, t, t
    if InStr(t, "стандарт")
        return defaultMin
    if InStr(t, "стоп")
        return "стоп"
    t := StrReplace(t, "–", "-")
    t := StrReplace(t, "—", "-")
    t := StrReplace(t, ",", ".")
    if RegExMatch(t, "(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)", m)
        return RcValueToMinutes(m2)
    if RegExMatch(t, "(\d+(?:\.\d+)?)", m)
        return RcValueToMinutes(m1)
    return defaultMin
}

RcValueToMinutes(value) {
    n := value + 0
    if (n <= 0)
        return 0
    if (n <= 8)
        return Round(n * 60)
    return Round(n)
}

RcGetEffectiveTime(kitchenKey, zoneType, isPickup, ByRef outCenterRaw, ByRef outFarRaw, ByRef outMinFar) {
    global Kitchens
    k := ""
    for _, obj in Kitchens {
        if (obj.Name == kitchenKey) {
            k := obj
            break
        }
    }
    if (!k)
        return isPickup ? 40 : 90
        
    outCenterRaw := k.Center
    outFarRaw := k.FarZone
    outMinFar := 0
    eff := 0
    
    if (isPickup) {
        eff := RcParseKitchenMinutes(k.Pickup, 40)
        return eff
    }
        
    centerMins := RcParseKitchenMinutes(k.Center, 90)
    if (centerMins == "стоп") {
        eff := "стоп"
    } else if (zoneType == "STANDARD" || zoneType == "center") {
        eff := centerMins
    } else {
        farMins := RcParseKitchenMinutes(k.FarZone, 90)
        if (farMins == "стоп") {
            eff := "стоп"
        } else {
            outMinFar := centerMins + 30
            if (farMins > centerMins)
                eff := farMins
            else
                eff := outMinFar
        }
    }
    logTime := "DELIVERY_TIME:`nkitchen=[" kitchenKey "]`nzoneType=[" zoneType "]`ncenterRaw=[" k.Center "]`nfarRaw=[" k.FarZone "]`ncenterMinutes=[" centerMins "]`nfarMinutes=[" (farMins?farMins:"") "]`nminimumFar=[" outMinFar "]`neffectiveMinutes=[" eff "]`n`n"
    FileAppend, % logTime, %A_ScriptDir%\parse_debug.log
    return eff
}

RcSetReadyByMinutes(minutes) {
    if (minutes == "стоп")
        return
    total := A_Hour*60 + A_Min + minutes
    HH := Mod(Floor(total / 60), 24)
    MM := Mod(total, 60)
    GuiControl, Roll:, ReadyTimeH, % Format("{:02}", HH)
    GuiControl, Roll:, ReadyTimeM, % Format("{:02}", MM)
}

DetectKitchenStatus:
    detectedCity    := ""
    kitchenLine     := ""
    hasKitchenAlert := 0
    citySource      := ""
    ; джерело — або адреса (доставка), або пункт самовивозу, або сам коментар
    searchText := rawAddress
    if (hasPickup && pickupPoint != "")
        searchText := searchText . " " . pickupPoint
    if (searchText == "" && hasPickup && rawComment != "")
        searchText := rawComment
    logFile := A_ScriptDir "\siv_debug.log"
    rawAddrShort := SubStr(rawAddress, 1, 200)
    pickShort    := SubStr(pickupPoint, 1, 200)
    FileAppend, `n[DEBUG] %A_Now% - Event: rawAddress = "%rawAddrShort%" pickup = "%pickShort%"`n, %logFile%
    if (searchText == "")
        return
    ; визначаємо місто (порядок важливий: довші назви спершу)
    ; \b у PCRE не працює для кирилиці — використовуємо власні межі через look-around
    cityList := ["Біла Церква","Івано-Франківськ","Франківськ","Дніпро","Днепр","Харків","Одеса","Львів","Київ","Рівне","Ровно","Вінниця","ІФ"]
    for _, c in cityList {
        pat := "i)(?<![а-яА-ЯіїєґІЇЄҐёЁ])" . c . "(?![а-яА-ЯіїєґІЇЄҐёЁ])"
        if RegExMatch(searchText, pat) {
            detectedCity := c
            break
        }
    }
    ; нормалізація аліасів
    if (detectedCity == "Франківськ" || detectedCity == "ІФ")
        detectedCity := "Івано-Франківськ"
    if (detectedCity == "Ровно")
        detectedCity := "Рівне"
    if (detectedCity == "Днепр")
        detectedCity := "Дніпро"

    if (hasPickup)
        citySource := " (самовивіз)"
    FileAppend, [DEBUG] %A_Now% - Event: detectedCity = "%detectedCity%"%citySource%`n, %logFile%
    if (detectedCity == "")
        return
    ; Більше не показуємо всі кухні міста списком, бо маємо точну зону KML
    kitchenLine := ""
    hasKitchenAlert := 0
return

AppendPromoToBase:
    if (promoFound == "")
        return
    kLow := promoFound
    StringLower, kLow, kLow
    if (KnownPromos[kLow])
        return
    ; дописати в файл як UTF-8
    if !FileExist(PromoPath) {
        fNew := FileOpen(PromoPath, "w", "UTF-8")
        if (fNew) {
            fNew.Write("[Known]`n")
            fNew.Close()
        }
    }
    fApp := FileOpen(PromoPath, "a", "UTF-8")
    if (fApp) {
        fApp.Write("`n" . promoFound . "=1")
        fApp.Close()
    }
    KnownPromos[kLow] := 1
    promoKnown := 1
    logFile := A_ScriptDir "\siv_debug.log"
    FileAppend, `n[DEBUG] %A_Now% - Event: Promo added to base: %promoFound%`n, %logFile%
    MsgBox, 64, База промокодів, Промокод "%promoFound%" додано в базу!, 2
    GoSub, DrawRollclub
return

; ========================================================
; МАГІЧНЕ ОЧИЩЕННЯ
; ========================================================
SilentMagicClean:
    infoText     := ""
    addrNote     := ""
    extractedTime:= ""
    clientChange := ""
    cardText     := ""
    cleanComment := ""
    autoGunkan   := 0
    autoPepsi    := 0
    autoBurger   := 0
    autoSandwich := 0
    autoSticksNorm := 0
    autoSticksEdu  := 0
    autoCash     := 0
    calcChange   := 0
    isPost       := 0
    postNum      := ""
    needCall     := 0
    isFutureDate := 0
    warnReason   := ""
    parsedSticksNorm := ""
    parsedSticksEdu  := ""
    extractedTimeAuto := 0
    RcCurrentKitchen := ""
    ; Нові флаги
    hasFilaClub     := 0
    hasBirthday     := 0
    hasAllergy      := 0
    hasPickup       := 0
    hasUtensils     := 0
    utensilsText    := ""
    parsedUtensils  := ""
    autoUtensils    := 0
    hasCustomerReq  := 0
    customerReqText := ""
    promoFound      := ""
    promoKnown      := 0
    pickupPoint     := ""
    addrMismatch   := 0
    commentStreet  := ""
    blockedHit     := 0
    blockedInfo    := ""

    ; --- Викидаємо хвіст "Доставка перенесена на точку ..." для подальшого парсингу ---
    workComment := RegExReplace(rawComment, "i)Доставка перенесена на точку.*$", "")

    if RegExMatch(workComment, "i)Пост-(\d+)", mPost) {
        isPost  := 1
        postNum := mPost1
    }

    if RegExMatch(workComment, "i)(Передзвонити|Перетелефонувати)")
        needCall := 1

    FormatTime, todayDt, %A_Now%, yyyy-MM-dd
    FormatTime, todayD,  %A_Now%, dd
    FormatTime, todayM,  %A_Now%, MM
    FormatTime, todayY,  %A_Now%, yyyy
    FormatTime, todayDow,%A_Now%, dddd
    futureTime := ""    ; час біля майбутньої дати (перекриває "Найближчим часом")

    ; 1) ISO YYYY-MM-DD
    if RegExMatch(workComment, "(\d{4})-(\d{2})-(\d{2})(?:[T\s]+(\d{1,2}):(\d{2}))?", sysD) {
        if (sysD1 . "-" . sysD2 . "-" . sysD3 != todayDt) {
            isFutureDate := 1
            warnReason   := sysD3 . "." . sysD2 . "." . sysD1
            if (sysD4 != "")
                futureTime := Format("{:02}:{:02}", sysD4, sysD5)
        }
    }

    ; 2) DD.MM(.YY|YYYY)?  /  DD/MM(.YY|YYYY)?
    ; шукаємо першу дату; також ловимо опціональний час поруч (на 17:00 / к 17:00 / о 17:00 / 17:00)
    if (!isFutureDate && RegExMatch(workComment, "(?<![\d\/\.\-])(\d{1,2})[\.\/\-](\d{1,2})(?:[\.\/\-](\d{2,4}))?(?:[^\d\r\n]{1,30}?(?:на|о|к|до)?\s*(\d{1,2}):(\d{2}))?", dM)) {
        dD := dM1 + 0
        dMo := dM2 + 0
        dYr := (dM3 != "") ? dM3 + 0 : todayY + 0
        if (dYr < 100)
            dYr += 2000
        ; ігноруємо нереалістичні (день>31, місяць>12)
        if (dD >= 1 && dD <= 31 && dMo >= 1 && dMo <= 12) {
            ; конструюємо рядок дати для порівняння
            cmpDt := Format("{:04}-{:02}-{:02}", dYr, dMo, dD)
            if (cmpDt > todayDt) {
                isFutureDate := 1
                warnReason   := Format("{:02}.{:02}.{:04}", dD, dMo, dYr)
                if (dM4 != "")
                    futureTime := Format("{:02}:{:02}", dM4, dM5)
            }
        }
    }

    ; 3) словесні: завтра / післязавтра / післяпіслязавтра / послезавтра / на вихідні / через тиждень
    if (!isFutureDate && RegExMatch(workComment, "i)(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])(післяпіслязавтра|післязавтра|послезавтра|завтра|на\s+вихідні|на\s+вих[іы]дных|через\s+тиждень|наступного\s+тижня|на\s+наступн)(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])", kw)) {
        isFutureDate := 1
        warnReason   := kw1
    }

    ; 4) "на 30 травня" / "на 5 червня" / "на 30 мая"
    if (!isFutureDate && RegExMatch(workComment, "i)(\d{1,2})\s+(січн|лют|берез|квіт|травн|червн|липн|серпн|верес|жовтн|листопад|грудн|январ|феврал|март|апрел|ма[яй]|июн|июл|август|сентябр|октябр|ноябр|декабр)", mNm)) {
        monthMap := {січн:1,январ:1,лют:2,феврал:2,берез:3,март:3,квіт:4,апрел:4,травн:5,"ма[яй]":5,червн:6,июн:6,липн:7,июл:7,серпн:8,август:8,верес:9,сентябр:9,жовтн:10,октябр:10,листопад:11,ноябр:11,грудн:12,декабр:12}
        dD := mNm1 + 0
        monKey := mNm2
        StringLower, monKey, monKey
        dMo := 0
        ; пошук місяця за префіксом
        for k, v in monthMap {
            if RegExMatch(monKey, "i)^" . k)
                dMo := v
        }
        if (dMo > 0 && dD >= 1 && dD <= 31) {
            dYr := todayY + 0
            cmpDt := Format("{:04}-{:02}-{:02}", dYr, dMo, dD)
            ; якщо вже минула цього року — то наступного
            if (cmpDt < todayDt)
                dYr += 1
            cmpDt := Format("{:04}-{:02}-{:02}", dYr, dMo, dD)
            if (cmpDt > todayDt) {
                isFutureDate := 1
                warnReason   := Format("{:02}.{:02}.{:04}", dD, dMo, dYr)
            }
        }
    }

    ; 5) день тижня — якщо вказано НЕ сегоднішній
    if (!isFutureDate && RegExMatch(workComment, "i)(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])(понеділок|вівторок|середу?|четвер|п[''’]ятницю?|суботу?|неділю?|понедельник|вторник|сред[уы]|четверг|пятниц[уы]|суббот[уы]|воскресень[ея])(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])", mDow)) {
        dowMap := {понеділок:"Monday",понедельник:"Monday",вівторок:"Tuesday",вторник:"Tuesday",серед:"Wednesday",сред:"Wednesday",четвер:"Thursday",четверг:"Thursday","п''ятниц":"Friday","п’ятниц":"Friday",пятниц:"Friday",субот:"Saturday",суббот:"Saturday",неділ:"Sunday",воскресень:"Sunday"}
        gotDow := mDow1
        StringLower, gotDow, gotDow
        matchedEng := ""
        for k, v in dowMap {
            if RegExMatch(gotDow, "i)^" . k)
                matchedEng := v
        }
        if (matchedEng != "" && matchedEng != todayDow) {
            isFutureDate := 1
            warnReason   := mDow1
        }
    }

    if (isFutureDate) {
        ; шукаємо час "к HH:MM" / "на HH:MM" / "о HH годині"
        if (futureTime = "" && RegExMatch(workComment, "i)(?:на|до|к|о)\s+(\d{1,2}):(\d{2})", mHt))
            futureTime := Format("{:02}:{:02}", mHt1, mHt2)
        if (futureTime = "" && RegExMatch(workComment, "(?<!\d)(\d{1,2}):(\d{2})(?!\d)", mHt2x))
            futureTime := Format("{:02}:{:02}", mHt2x1, mHt2x2)
        ; тричі писк — гучно
        SoundBeep, 1500, 300
        Sleep, 60
        SoundBeep, 1500, 300
        Sleep, 60
        SoundBeep, 1500, 400
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: FUTURE-DATE detected (%warnReason%) time=%futureTime%`n, %logFile%
    }

    ; --- FilaClub (старий детект, залишаємо для гучного попередження) ---
    if RegExMatch(workComment, "i)(?:Промокод\s*:\s*)?(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z0-9])(FilaClub|Филоклаб)(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z0-9])", mFila) {
        hasFilaClub := 1
        SoundBeep, 1100, 250
        Sleep, 80
        SoundBeep, 1100, 250
        ToolTip, ⚠ ПРОМОКОД FILACLUB`nНе забудь пробити!, 20, 20, 4
        SetTimer, RemoveFilaClubToolTip, -7000
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: FilaClub promo detected (%mFila1%)`n, %logFile%
    }

    ; --- Самовивіз (детект до парсингу адресних нотаток) ---
    if RegExMatch(workComment, "i)(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])Самовивіз(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])") {
        hasPickup := 1
        if RegExMatch(workComment, "i)Самовивіз:\s*([^\.\r\n]+?)(?=\s*(?:Знижка|Доставка|Прибори|Купон|Подарунок|Найближчим|\d{4}-\d{2}|$))", mPick)
            pickupPoint := Trim(mPick1)
    }

    ; --- Виделка/Ніж/Ложка → авто-пробитие через окремий PLU ---
    ; Підтримує тільки явні прибори: "Виделка/Ніж/Ложка x4", "Виделка x2", "Ніж x1".
    ; Слово "Прибори:" саме по собі не означає вилку/ніж: сайт так само пише "Прибори: Звичайні x2" для паличок.
    if RegExMatch(workComment, "i)(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z0-9])(Виделк[аи]\/Ніж\/Ложк[аи]|Виделк[аи]|Ніж|Ложк[аи])(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z0-9])\s*(?:x|х|×)?\s*(\d+)?", mUten) {
        hasUtensils := 1
        utensilsText := Trim(mUten1)
        if (mUten2 != "") {
            parsedUtensils := mUten2
            autoUtensils := 1
        } else {
            parsedUtensils := "1"
            autoUtensils := 1
        }
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: Utensils detected (%utensilsText% x%parsedUtensils%) — fork=%pluFork% knife=%pluKnife%`n, %logFile%
    }

    ; --- День народження ---
    if RegExMatch(workComment, "i)(день\s*народ|день\s*рождени|-10%\s*до\s*дня|знижка\s+до\s+дня\s+народ|знижка\s+на\s+день\s+народ|(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])ДН(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])\s*знижка)") {
        hasBirthday := 1
        if (cardText == "")
            cardText := "ДН " . A_DD . "." . A_MM . "." . A_YYYY
        else
            cardText .= " | ДН " . A_DD . "." . A_MM . "." . A_YYYY
        SoundBeep, 900, 300
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: Birthday detected (card+=DN)`n, %logFile%
    }

    ; --- Алергія (окремий флаг + червона плашка) ---
    if RegExMatch(workComment, "i)(алерг|аллерг)") {
        hasAllergy := 1
        SoundBeep, 1200, 400
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: ALLERGY detected`n, %logFile%
    }

    ; --- Час ---
    if (hasPickup && pickupPoint != "")
        RcCurrentKitchen := RcFindKitchenFromText(pickupPoint)
    if (isFutureDate) {
        extractedTime := ""   ; передзамовлення — час вже виставлений в CRM, не чіпаємо
    } else {
        ; Конкретний час у коментарі — беремо його
        RegExMatch(workComment, "(\d{2}:\d{2})", timeMatch)
        if (timeMatch1 != "") {
            extractedTime := timeMatch1
            extractedTimeAuto := 0
        } else {
            ; Самовивіз/доставка — з Google Sheet/RkKitchens.ini, якщо є; інакше старий fallback.
            readyOffset := hasPickup ? RcKitchenMinutes("pickup", 40) : RcKitchenMinutes("center", 90)
            tHH := A_Hour + 0
            tMM := A_Min + readyOffset
            tHH += Floor(tMM / 60)
            tMM := Mod(tMM, 60)
            tHH := Mod(tHH, 24)
            extractedTime := Format("{:02}:{:02}", tHH, tMM)
            extractedTimeAuto := 1
        }
    }

    paymentMethod := ""
    paymentNum    := ""

    if RegExMatch(workComment, "i)Готівкою\s*№(\d+)", mCash) {
        paymentMethod := "Готівкою"
        paymentNum    := mCash1
        autoCash      := 1
    }
    if (paymentMethod == "" && RegExMatch(workComment, "i)(?:---ОПЛАЧЕНО---\s*)?(?:Картою[^№\r\n]*|ОПЛАЧЕНО\s*)№(\d+)", mCard)) {
        paymentMethod := "Оплачено"
        paymentNum    := mCard1
    }
    if (paymentMethod == "" && RegExMatch(workComment, "i)QR\s*code[^\d]*(\d{5,})", mQR)) {
        paymentMethod := "QR"
        paymentNum    := mQR1
    }

    ; --- Решта з: цифра ABO слово (ні/нет/без решти/no) ---
    if RegExMatch(workComment, "i)[Рр]ешт[уа]\s+з[:\s]+(\d+)", mReshta) {
        clientChange := mReshta1
        autoCash     := 1
    } else if RegExMatch(workComment, "i)[Рр]ешт[уа]\s+з[:\s]+(ні|нет|без\s+решти|no)") {
        clientChange := ""
        autoCash     := 1
    }

    if RegExMatch(workComment, "i)(?:Звичайні|Звичайних)[^\d]*(\d+)", mNorm) {
        parsedSticksNorm := mNorm1
        autoSticksNorm := 1
    }
    if RegExMatch(workComment, "i)(?:Учбові|Навчальні)[^\d]*(\d+)", mEdu) {
        parsedSticksEdu := mEdu1
        autoSticksEdu := 1
    }

    if (RC_GIFTS_ENABLED && RegExMatch(workComment, "i)!!!ПЕРШЕМОБ")) {
        autoGunkan := 1
        if (cardText == "")
            cardText := "ПЕРШЕМОБ"
        else
            cardText := "ПЕРШЕМОБ | " . cardText
    }

    if (RC_GIFTS_ENABLED && orderSum > 0) {
        if (orderSum >= 1599)
            autoBurger := 1
        else if (orderSum >= 999)
            autoSandwich := 1
        else if (orderSum >= 699)
            autoPepsi := 1
    }

    ; --- Кухня (розширений regex + позначка алергії) ---
    kitchenNote    := ""
    textForKitchen := workComment
    textForKitchen := RegExReplace(textForKitchen, "i)Пост-\d+", " ")
    textForKitchen := RegExReplace(textForKitchen, "i)---ОПЛАЧЕНО---", " ")
    textForKitchen := RegExReplace(textForKitchen, "i)Картою[^№\r\n]*№\s*\d+", " ")
    textForKitchen := RegExReplace(textForKitchen, "i)Готівкою\s*№\s*\d+", " ")
    textForKitchen := RegExReplace(textForKitchen, "i)QR\s*code\s*№?\s*\d+", " ")
    textForKitchen := RegExReplace(textForKitchen, "i)Фоп\s+\S+\s+\S+", " ")
    textForKitchen := RegExReplace(textForKitchen, "\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?", " ")
    Loop {
        if (!RegExMatch(textForKitchen, "i)([^.,;!?\r\n]*(?:без\s+[а-яіїєґa-z]+|не\s+(?:додавати|додавайте|кладіть|класти|клас[ьт]и|ложите|кладите|клад[іиь]|положить|положите)|алерг|аллерг|(?:менше|меньше)\s+[а-яіїєґ]+|добре\s+просмаж|наріжте|хрумткими|хрусткими|хрустящ|покласти|більше\s+[а-яіїєґ]+|розріжте|порізати|соус[ауи]?\s+(?:окремо|отдельно)|підпиш[іи]|підписати\s+бокс|подпиш[ит]|гостр[оаиі]|острый)[^.,;!?\r\n]*)", kMatch))
            break
        candidate := Trim(kMatch1)
        if (kitchenNote != "")
            kitchenNote .= " | "
        kitchenNote .= candidate
        textForKitchen := StrReplace(textForKitchen, kMatch1, "", , 1)
    }
    if (kitchenNote != "") {
        if (hasAllergy)
            infoText := "🚨 АЛЕРГІЯ! " . kitchenNote
        else
            infoText := "🍳 " . kitchenNote
    } else if (hasAllergy) {
        infoText := "🚨 АЛЕРГІЯ — окремий бокс, підписати!"
    }

    ; --- Адресні нотатки: явні маркери ---
    if RegExMatch(workComment, "i)(?:Коментар|Комментарий)\s+до?\s*адреси?:\s*(.*?)(?=\s*(?:Купон:|Подарунок:|Промокод:|Прибори:|Звичайні:|Учбові:|Найближчим|Самовивіз|\d{4}-\d{2}-\d{2}|$))", mAddr)
        addrNote := Trim(mAddr1)
    if RegExMatch(workComment, "i)(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])доставка:\s*(.*?)(?=\s*(?:Купон:|Подарунок:|Прибори:|Найближчим|\d{4}-\d{2}-\d{2}|$))", mDel) {
        cand := Trim(mDel1)
        if (cand != "" && !InStr(addrNote, cand))
            addrNote := (addrNote != "") ? (addrNote . " | " . cand) : cand
    }

    ; --- Пред-чистка тексту для адресного парсингу (зрізаємо шум) ---
    textForAddr := workComment
    textForAddr := RegExReplace(textForAddr, "i)Пост-\d+", " ")
    textForAddr := RegExReplace(textForAddr, "i)(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])(Mob|Сайт)(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])", " ")
    textForAddr := RegExReplace(textForAddr, "i)!!!ПЕРШЕМОБ", " ")
    textForAddr := RegExReplace(textForAddr, "i)(Передзвонити|Перетелефонувати)", " ")
    textForAddr := RegExReplace(textForAddr, "i)---ОПЛАЧЕНО---", " ")
    textForAddr := RegExReplace(textForAddr, "i)Картою[^№\r\n]*№\s*\d+", " ")
    textForAddr := RegExReplace(textForAddr, "i)Готівкою\s*№\s*\d+", " ")
    textForAddr := RegExReplace(textForAddr, "i)ОПЛАЧЕНО\s*№\s*\d+", " ")
    textForAddr := RegExReplace(textForAddr, "i)QR\s*code\s*№?\s*\d+", " ")
    textForAddr := RegExReplace(textForAddr, "№\s*\d+", " ")
    textForAddr := RegExReplace(textForAddr, "i)Фоп\s+\S+\s+\S+", " ")
    textForAddr := RegExReplace(textForAddr, "\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?", " ")
    textForAddr := RegExReplace(textForAddr, "i)Прибори:[^|]*?(?=(?:Купон|Подарунок|Найближчим|Самовивіз|Знижка|$))", " ")
    textForAddr := RegExReplace(textForAddr, "i)Купон:[^|]*?(?=(?:Прибори|Подарунок|Найближчим|Самовивіз|Знижка|$))", " ")
    textForAddr := RegExReplace(textForAddr, "i)Подарунок:[^|]*?(?=(?:Прибори|Купон|Найближчим|Самовивіз|Знижка|$))", " ")
    textForAddr := RegExReplace(textForAddr, "i)Звичайні:\s*\d+", " ")
    textForAddr := RegExReplace(textForAddr, "i)Учбові:\s*\d+", " ")
    textForAddr := RegExReplace(textForAddr, "i)Решт[ау]\s+з[:\s]+\S+", " ")
    textForAddr := RegExReplace(textForAddr, "i)Знижка(?:\s+\S+){1,3}\s*-?\d*", " ")
    textForAddr := RegExReplace(textForAddr, "i)Найближчим\s+часом", " ")
    textForAddr := RegExReplace(textForAddr, "i)Самовивіз:\s*[^\.\r\n]+?(?=(?:Знижка|Доставка|Прибори|Купон|Подарунок|$))", " ")
    ; Прибираємо "Коментар до адреси:" — вже оброблений явним маркером, не дублюємо
    textForAddr := RegExReplace(textForAddr, "i)(?:Коментар|Комментарий)\s+до?\s*адреси?:.*?(?=(?:\||Купон:|Подарунок:|Прибори:|Знижка|Найближчим|Самовивіз|\d{4}-\d{2}|$))", " ")
    ; Прибираємо назву вулиці з кінця — вона вже пішла в perевірку адреси, тут шум
    textForAddr := RegExReplace(textForAddr, "i)(?:вул\.?\s+)(?:[А-ЯІЇЄҐа-яіїєґ][А-ЯІЇЄҐа-яіїєґ\-]+\s*){1,3}\.?\s*$", " ")
    textForAddr := RegExReplace(textForAddr, "i)(?:[А-ЯІЇЄҐа-яіїєґ][А-ЯІЇЄҐа-яіїєґ\-]+\s+){1,3}вулиця\.?\s*$", " ")

    ; --- Адресні нотатки за ключовиками (розширений набір) ---
    Loop {
        if (!RegExMatch(textForAddr, "i)([^.,;!?\r\n]*(?:домофон|під'їзд|подъезд|поверх\b|этаж|квартир[аи]|кв\s*\d|парадн|будинок(?!\s+\d)|дом\b|зателефону|набрати|наберіть|наберите|подзвон|позвон|(?<!пере)(?<!Пере)дзвонит|(?<!пере)(?<!Пере)дзвоніть|звонить|код\s|шлагбаум|зустрін|встрет|вийду|выйду|консьєрж|ресепшн|рецепц|охорон|заїзд|заїжджати|вхід|вход|корпус|фасад|ворот[аи]?|брам[аи]|хвіртк|паркан|забор|ЖК(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])|БЦ(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])|ТРЦ(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])|ТЦ(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])|торгов(?:ий|ого|ому)\s+центр|бизнес\s+центр|бізнес\s+центр|до\s+оф[іи]су|в\s+оф[іи]с|оф[іи]с(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])|двір(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])|двор(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])|у\s+двор[іе]|во\s+двор[еі]|задн[ийі]й\s+двір|задний\s+двор|за\s+домом|орієнтир|ориентир|навпроти|напроти|напротив|між\s+|между\s+|поряд\s+з|поруч\s+з|возле|біля\s+(?!буд|під'ї|дом[ау])|рядом|зі\s+сторони|со\s+стороны|метро(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])|м\.\s*[А-ЯІЇЄҐ]|АТБ|Сільпо|Епіцентр|Ашан|школ[аиу]|садок|садочок|інститут|институт|університет|університету|університеті|лікарн|больниц|поліклін|поликлин|госпітал|КПП|блок-пост|військов|военн|приватний\s+сектор|частный\s+сектор|приватн|частн|парк\s+|сквер|зупинк|остановк|пам'?ятник|памятник|по\s+червоній\s+лінії|по\s+красной\s+линии)[^.,;!?\r\n]*)", aMatch))
            break
        candidate := Trim(aMatch1)
        candidate := RegExReplace(candidate, "\s+", " ")
        if (candidate != "" && StrLen(candidate) < 200) {
            alreadyCovered := 0
            Loop, Parse, addrNote, |
            {
                existingPart := Trim(A_LoopField)
                if (existingPart != "" && (InStr(candidate, existingPart) || InStr(existingPart, candidate)))
                    alreadyCovered := 1
            }
            if (!alreadyCovered)
                addrNote := (addrNote != "") ? (addrNote . " | " . candidate) : candidate
        }
        textForAddr := StrReplace(textForAddr, aMatch1, "", , 1)
    }

    ; --- Третя особа отримувач → в адресну нотатку ---
    Loop {
        if (!RegExMatch(textForAddr, "i)([^.,;!?\r\n]*(?:отримувач|получатель|забере(?:\s+його|\s+замовлення)?|заберет|получит|віддати|віддасть|передати|передасть|занес[іи]ть|віднес[іи])[^.,;!?\r\n]*)", rMatch))
            break
        candidate := Trim(rMatch1)
        if (candidate != "" && !InStr(addrNote, candidate)) {
            addrNote := (addrNote != "") ? (addrNote . " | 👤 " . candidate) : ("👤 " . candidate)
        }
        textForAddr := StrReplace(textForAddr, rMatch1, "", , 1)
    }

    ; --- Телефон у вільному тексті (виключаючи №XXX оплати) ---
    textNoPay := RegExReplace(workComment, "i)№\s*\d+", "")
    if RegExMatch(textNoPay, "((?:\+?38\s*)?0\d{2}[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2})", mPhone) {
        phoneClean := RegExReplace(mPhone1, "[\s\-]", "")
        if (StrLen(phoneClean) >= 10) {
            phoneTag := "📞 Доп. контакт: " . phoneClean
            if (!InStr(addrNote, phoneClean))
                addrNote := (addrNote != "") ? (addrNote . " | " . phoneTag) : phoneTag
        }
    }

    ; --- Промокод: пошук токена і звірка з базою ---
    promoFound := ""
    promoKnown := 0
    if RegExMatch(workComment, "i)[Пп]ромокод[:\s]+([A-Za-zА-Яа-яІіЇїЄєҐґ0-9_\-]{3,40})", mPromo) {
        promoFound := Trim(mPromo1)
    } else {
        ; шукати у вільному тексті відоме слово з бази
        for kLow, _ in KnownPromos {
            if RegExMatch(workComment, "i)(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z0-9])" . kLow . "(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z0-9])") {
                promoFound := kLow
                break
            }
        }
    }
    if (promoFound != "") {
        promoLow := promoFound
        StringLower, promoLow, promoLow
        if (KnownPromos[promoLow])
            promoKnown := 1
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: Promo "%promoFound%" (known=%promoKnown%)`n, %logFile%
    }

    ; --- Прохання клієнта (питання/прохання) ---
    ; Regex дозволяє перетинати коми (але не крапку/знак питання/оклику/новий рядок)
    Loop {
        if (!RegExMatch(textForAddr, "i)([^.!?\r\n]{0,200}(?:будь\s+ласка|могли\s+б|якщо\s+можна|якщо\s+можливо|чи\s+можна|чи\s+можливо|можна\?|можно\s+ли|если\s+можно|просьба|прохання|прошу,?|пишіть\s+на\s+вайбер|пишите\s+на\s+вайбер|перетелефонуй|перезвонит)[^.!?\r\n]{0,150})", qMatch))
            break
        candidate := Trim(qMatch1)
        ; Занадто короткий фрагмент (лише "будь ласка" без контексту) — шум, прибираємо
        if (StrLen(candidate) < 15) {
            textForAddr := StrReplace(textForAddr, qMatch1, "", , 1)
            continue
        }
        ; Не дублюємо те, що вже є в адресній нотатці
        alreadyInAddr := 0
        Loop, Parse, addrNote, |
        {
            ap := Trim(A_LoopField)
            if (ap != "" && (InStr(candidate, ap) || InStr(ap, candidate)))
                alreadyInAddr := 1
        }
        if (!alreadyInAddr) {
            hasCustomerReq := 1
            if (customerReqText != "")
                customerReqText .= " | "
            customerReqText .= candidate
        }
        textForAddr := StrReplace(textForAddr, qMatch1, "", , 1)
    }

    ; --- Залишок тексту ---
    textForAddr := Trim(RegExReplace(textForAddr, "\s+", " "))
    if (textForAddr != "" && textForAddr != " " && StrLen(textForAddr) > 3) {
        if (!hasCustomerReq && !hasDeliveryTime)
            addrNote := (addrNote != "") ? (addrNote . " | " . textForAddr) : textForAddr
    }

    ; --- Python AI Parse (Enhancement) ---
    pyResp := RhGet("/api/iiko/parse_ahk?text=" . RcUriEncode(workComment))
    if (pyResp != "") {
        Loop, Parse, pyResp, `n, `r
        {
            eqPos := InStr(A_LoopField, "=")
            if (eqPos > 0) {
                pKey := SubStr(A_LoopField, 1, eqPos - 1)
                pVal := SubStr(A_LoopField, eqPos + 1)

                if (pKey == "isPickup" && pVal == "1")
                    hasPickup := 1
                if (pKey == "isFastDelivery" && pVal == "1")
                    isFastDelivery := 1
                if (pKey == "FilaClub" && pVal == "1")
                    hasFilaClub := 1
                if (pKey == "Allergy" && pVal == "1")
                    hasAllergy := 1
                if (pKey == "Birthday" && pVal == "1")
                    hasBirthday := 1
                if (pKey == "SticksNorm" && pVal != "0") {
                    parsedSticksNorm := pVal
                    autoSticksNorm := 1
                }
                if (pKey == "SticksEdu" && pVal != "0") {
                    parsedSticksEdu := pVal
                    autoSticksEdu := 1
                }
                if (pKey == "Utensils" && pVal != "0" && hasUtensils) {
                    parsedUtensils := pVal
                    autoUtensils := 1
                }
                if (pKey == "RestChange" && pVal != "") {
                    clientChange := pVal
                    autoCash := 1
                }
                if (pKey == "addrNote" && pVal != "") {
                    if (!InStr(addrNote, pVal))
                        addrNote := (addrNote != "") ? (pVal . " | " . addrNote) : pVal
                }
                if (pKey == "kitchenNote" && pVal != "") {
                    if (!InStr(kitchenNote, pVal))
                        kitchenNote := (kitchenNote != "") ? (kitchenNote . " | " . pVal) : pVal
                }
                if (pKey == "infoText" && pVal != "")
                    infoText := pVal
                if (pKey == "isPost" && pVal == "1")
                    isPost := 1
                if (pKey == "postNum" && pVal != "")
                    postNum := pVal
                if (pKey == "needCall" && pVal == "1")
                    needCall := 1
            }
        }
    }

    ; --- Клієнт замовив прибори (Виделка/Ніж/Ложка) → палички НЕ пробиваємо ---
    if (hasUtensils)
    {
        parsedSticksNorm := "0"
        parsedSticksEdu  := "0"
        autoSticksNorm := 0
        autoSticksEdu  := 0
    }

    ; ==== DEBUG: дамп розбору ====
    FormatTime, _dbgT,, yyyy-MM-dd HH:mm:ss
    _dbg := "==== " . _dbgT . " | No=" . kcLastNo . " ===="
    _dbg .= "`nRAW    : " . workComment
    _dbg .= "`nKITCHEN: " . infoText
    _dbg .= "`nKITraw : " . kitchenNote
    _dbg .= "`nADDR   : " . addrNote
    _dbg .= "`nCUSTREQ: " . customerReqText
    _dbg .= "`nPICKUP : " . hasPickup . " / " . pickupPoint . " -> " . PickupConcept(pickupPoint)
    _dbg .= "`nPAY    : " . paymentMethod . " #" . paymentNum . " | change=" . clientChange
    _dbg .= "`nSTICKS : norm=" . parsedSticksNorm . " edu=" . parsedSticksEdu
    _dbg .= "`nUTENS  : text=[" . utensilsText . "] qty=" . parsedUtensils
    _dbg .= "`n"
    FileAppend, %_dbg%`n, %A_ScriptDir%\parse_debug.log, UTF-8

    cleanParts := []

    if RegExMatch(workComment, "i)(Знижка\s+на\s+таксі:\s*-\d+)", mTaxi)
        cleanParts.Push(Trim(mTaxi1))

    if RegExMatch(workComment, "i)(Знижка\s+самовивіз:\s*-\d+)", mPickDisc)
        cleanParts.Push(Trim(mPickDisc1))

    if (hasPickup)
        cleanParts.Push("САМОВИВІЗ")

    if (needCall)
        cleanParts.Push("Передзвонити")

    if (paymentMethod != "" && paymentNum != "")
        cleanParts.Push(paymentMethod . " №" . paymentNum)

    if (hasBirthday)
        cleanParts.Push("🎂 ДН — знижка")

    if (promoFound != "") {
        if (promoKnown)
            cleanParts.Push("Промо: " . promoFound)
        else
            cleanParts.Push("❓Промо НОВИЙ: " . promoFound)
    }

    cleanComment := ""
    for i, part in cleanParts
        cleanComment .= (cleanComment != "" ? " " : "") . part

    if (clientChange != "")
        calcChange := clientChange
    else if (orderSum > 0)
        calcChange := Ceil(orderSum / 200) * 200
    else
        calcChange := 1000

    ; --- Виявляємо "Вулиця не обрана" в адресі ---
    addrNotSelected := (rawAddress != "" && InStr(rawAddress, "Вулиця не обрана") > 0)

    ; --- Порівняння вулиці з коментаря vs адресна строка ---
    addrMismatch      := 0
    commentStreet     := ""
    commentStreetType := ""
    rcDebugLog        := ""
    if (!hasPickup && rawAddress != "" && rawComment != "") {
        ; Зачищаємо відомий шум — залишається тільки вулиця
        sw := rawComment
        rcDebugLog .= "[1] rawComment=`"" . SubStr(sw, 1, 120) . "`"`n"
        sw := RegExReplace(sw, "i)!*ПЕРШЕМОБ", " ")
        sw := RegExReplace(sw, "i)Сайт|Mob|Моб", " ")
        sw := RegExReplace(sw, "i)Пост-\d+", " ")
        sw := RegExReplace(sw, "i)Передзвонити|Перетелефонувати", " ")
        sw := RegExReplace(sw, "i)---ОПЛАЧЕНО---", " ")
        sw := RegExReplace(sw, "i)Готівкою\s*№?\s*\d*", " ")
        sw := RegExReplace(sw, "i)Картою[^№\r\n]*№\s*\d+", " ")
        sw := RegExReplace(sw, "i)ОПЛАЧЕНО\s*№?\s*\d+", " ")
        sw := RegExReplace(sw, "i)QR\s*code\s*№?\s*\d+", " ")
        sw := RegExReplace(sw, "i)№\s*\d+", " ")
        sw := RegExReplace(sw, "i)Найближчим\s+часом", " ")
        sw := RegExReplace(sw, "i)Якнайшвидше|Як\s+найшвидше", " ")
        sw := RegExReplace(sw, "i)Знижка\s+\S+\s*-?\d*", " ")
        sw := RegExReplace(sw, "i)Купон:.*?(?=\||Київ|Харків|Одеса|Дніпро|Вінниця|вул|просп|пров|бульв|площа|$)", " ")
        sw := RegExReplace(sw, "i)Подарунок:.*?(?=\||Київ|Харків|Одеса|Дніпро|Вінниця|вул|просп|пров|бульв|площа|$)", " ")
        sw := RegExReplace(sw, "i)Прибори:.*?(?=\||Київ|Харків|Одеса|Дніпро|Вінниця|вул|просп|пров|бульв|площа|$)", " ")
        sw := RegExReplace(sw, "i)Решт[ау]\s+з[:\s]+\S+", " ")
        sw := RegExReplace(sw, "i)Промокод[:\s]+\S+", " ")
        sw := RegExReplace(sw, "i)FilaClub|Филоклаб", " ")
        sw := RegExReplace(sw, "i)Коментар\s+до\s+адреси[:\s]*", " ")
        sw := RegExReplace(sw, "i)Коментарій\s+до\s+адреси[:\s]*", " ")
        sw := RegExReplace(sw, "i)Фоп\s+[А-ЯІЇЄҐа-яіїєґ\.\s]+", " ")
        sw := RegExReplace(sw, "i)Самовивіз[^\r\n]*", " ")
        sw := RegExReplace(sw, "\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?", " ")
        sw := RegExReplace(sw, "(?<!\d)\d{1,2}:\d{2}(?!\d)", " ")
        sw := RegExReplace(sw, "\d+", " ")
        sw := RegExReplace(sw, "[^Ѐ-ӿ\s\-]", " ")   ; залишаємо тільки кириличні слова

        sw := RegExReplace(sw, "i)(?:домофон|під'їзд|подъезд|поверх|этаж|квартир[аи]?|кв\s*\d|парадн|будинок|дом\b|код\s)[^.,;!?\r\n]*", " ")

        sw := Trim(RegExReplace(sw, "\s+", " "))
        rcDebugLog .= "[2] after cleanup=`"" . sw . "`"`n"

        ; Типи вулиць (порядок важливий: довші варіанти першими)
        streetTypesList := "проспект|провулок|вулиця|бульвар|площадь|переулок|набережна|шосе|узвіз|тупік|тупик|проїзд|алея|площа|просп|пров|вул"

        ; АДРЕСА ЗАВЖДИ В КІНЦІ — беремо лише останні 6 слів щоб не плутати з текстом посередині
        swTail := sw
        wordArr := StrSplit(sw, " ")
        if (wordArr.MaxIndex() > 6) {
            swTail := ""
            startIdx := wordArr.MaxIndex() - 5
            Loop, % wordArr.MaxIndex() - startIdx + 1
            {
                swTail .= (A_Index > 1 ? " " : "") . wordArr[startIdx + A_Index - 1]
            }
        }
        rcDebugLog .= "[3] swTail=`"" . swTail . "`"`n"

        ; Витягуємо ТИП вулиці тільки з хвостової частини
        commentStreetType := ""
        sw2 := " " . swTail . " "
        Loop, Parse, streetTypesList, |
        {
            tw := A_LoopField
            if RegExMatch(sw2, "i)(?<=\s)" . tw . "(?=\s)") {
                commentStreetType := tw
                break
            }
        }
        rcDebugLog .= "[4] commentStreetType=`"" . commentStreetType . "`"`n"

        ; Витягуємо НАЗВУ вулиці: прибираємо тип, беремо останнє слово що лишилось
        swName := swTail
        if (commentStreetType != "")
            swName := RegExReplace(swName, "i)(?:^|\s)" . commentStreetType . "(?:\s|$)", " ")
        swName := Trim(RegExReplace(swName, "\s+", " "))
        if RegExMatch(swName, "([А-ЯІЇЄҐа-яіїєґёЁ][А-ЯІЇЄҐа-яіїєґёЁ\-]{2,})\s*$", mLast)
            commentStreet := mLast1
        rcDebugLog .= "[5] commentStreet=`"" . commentStreet . "`"`n"
        rcDebugLog .= "[6] rawAddress=`"" . rawAddress . "`"`n"

        ; Порівнювати з адресою тільки якщо знайдено ТИП вулиці в коментарі
        ; (без типу — "Парковка", "Коментар" і подібне не є назвою вулиці)
        if (commentStreet != "" && commentStreetType != "" && StrLen(commentStreet) > 3) {
            StringLower, cLow, commentStreet
            addrCopy := rawAddress
            StringLower, addrCopy, addrCopy

            nameInAddr := InStr(addrCopy, cLow)

            ; Перевіряємо тип вулиці (якщо клієнт вказав тип і в адресі теж є тип)
            typeOk := 1
            if (commentStreetType != "") {
                StringLower, ctLow, commentStreetType
                ; Шукаємо тип в адресному рядку
                addrTypeLow := ""
                addrCopy2 := " " . addrCopy . " "
                Loop, Parse, streetTypesList, |
                {
                    tw2 := A_LoopField
                    if RegExMatch(addrCopy2, "i)(?<=[\s,])" . tw2 . "(?=[\s,])") {
                        addrTypeLow := tw2
                        break
                    }
                }
                if (addrTypeLow != "") {
                    ; Скорочення сумісні: "вул" ⊂ "вулиця", "пров" ⊂ "провулок" тощо
                    typeOk := InStr(addrTypeLow, ctLow) || InStr(ctLow, addrTypeLow)
                }
                ; Якщо в адресі нема типу взагалі — не штрафуємо
            }

            rcDebugLog .= "[7] nameInAddr=" . nameInAddr . " typeOk=" . typeOk . "`n"
            if (!nameInAddr || !typeOk) {
                addrMismatch := 1
                SoundPlay, %A_ScriptDir%\beep_err.wav
                Sleep, 550
                SoundPlay, %A_ScriptDir%\beep_err.wav
                Sleep, 550
                SoundPlay, %A_ScriptDir%\beep_err.wav
            }
        }
        rcDebugLog .= "[8] addrMismatch=" . addrMismatch . "`n"

        ; Записуємо лог завжди
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[ADDR-PARSE] %A_Now%`n%rcDebugLog%, %logFile%
    }

    ; --- Перевірка перекритих вулиць (brands/rollclub/BlockedStreets.txt) ---
    if (!hasPickup && rawAddress != "") {
        blockedInfo := RcBlockedStreetHit(rawAddress)
        if (blockedInfo != "") {
            blockedHit := 1
            SoundPlay, %A_ScriptDir%\beep_err.wav
        }
    }

return

; ========================================================
; ПУЛЬТ КЕРУВАННЯ
; ========================================================
DrawRollclub:
    RhStaticColors := {}
    Gui, Roll:Destroy
    Gui, Roll:+AlwaysOnTop -MaximizeBox -MinimizeBox +ToolWindow

    RhApplyTheme()
    RhB_Gift := RhB_Accent

    _brandName := (BRAND == "rollclub") ? "Roll Club" : "Roll House"
    _orderType := isPickup ? "Самовивіз" : "Доставка"
    _serverPill := RH_SERVER_OK ? "ONLINE" : "OFFLINE"
    FormatTime, _rhNow,, dd.MM.yyyy HH:mm

    Gui, Roll:Color, %RhC_BG%, %RhC_Panel%
    Gui, Roll:Margin, 16, 16

    x0 := 16
    w0 := 328
    gap := 8
    curY := 14

    ; Header
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w72 h18 +0x200, Бренд
    Gui, Roll:Font, s14 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y32 w142 h26 +0x200, Roll Club

    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x174 y14 w136 h22 Right +0x200, %_rhNow%
    Gui, Roll:Font, s13 bold c%RhC_Text%, Segoe UI Symbol
    Gui, Roll:Add, Text, x316 y14 w32 h26 Center +Border +0x200 HwndhSettingsGear gOpenSettings, ⚙
    RhRegColor(hSettingsGear, RhB_CardFill, RhB_Text)

    Gui, Roll:Font, s8 bold cFFFFFF, %RhFontName%
    Gui, Roll:Add, Text, x16 y54 w66 h20 Center +0x200 HwndhOnlinePill vRhServerPill, %_serverPill%
    RhRegColor(hOnlinePill, (RH_SERVER_OK ? RhB_Green : RhB_Red), RhB_White)
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x90 y54 w254 h22 Center +0x200, %_rhNow% · F1 СІВ
    curY := 84

    ; ZONE BLOCK — саме важливе, має бути одразу помітним!
    Gui, Roll:Font, s9 bold c555555, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h28 Center +0x200 HwndhZoneBox vMapSearch, Визначення зони...
    RhRegColor(hZoneBox, 0xE8E8E8, 0x555555)
    curY += 30
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200 vKitchenStatusText,
    curY += 20

    ; Alerts
    if (isFutureDate || hasFilaClub || hasBirthday || hasAllergy || promoFound != "" || hasCustomerReq || needCall || !isPost) {
        Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200, ВАЖЛИВО
        curY += 20
    }
    if (isFutureDate) {
        ; Противний сигнал — передзамовлення не можна пропустити!
        SoundPlay, %A_ScriptDir%\beep_future.wav
        Sleep, 300
        SoundPlay, %A_ScriptDir%\beep_future.wav
        Gui, Roll:Font, s9 bold cFFFFFF, %RhFontName%
        _fdLabel := "ПЕРЕДЗАМОВЛЕННЯ"
        if (futureTime != "")
            _fdLabel .= " — " . futureTime
        if (warnReason != "")
            _fdLabel .= " (" . warnReason . ")"
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h24 Center +0x200 HwndhFutureDate, %_fdLabel%
        RhRegColor(hFutureDate, RhB_Red, RhB_White)
        curY += 28
    }
    if (hasAllergy) {
        Gui, Roll:Font, s9 bold cFFFFFF, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h24 Center +0x200 HwndhAllergy, АЛЕРГІЯ
        RhRegColor(hAllergy, RhB_Red, RhB_White)
        curY += 28
    }
    if (hasFilaClub) {
        Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h22 Center +0x200 HwndhFila, FILA CLUB
        RhRegColor(hFila, RhB_StatusSoft, RhB_Text)
        curY += 26
    }
    if (hasBirthday) {
        Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h22 Center +0x200 HwndhBDay, ДЕНЬ НАРОДЖЕННЯ
        RhRegColor(hBDay, RhB_StatusSoft, RhB_Text)
        curY += 26
    }
    if (promoFound != "") {
        if (promoKnown) {
            Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
            Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h22 Center +0x200 HwndhPromoBase, ПРОМО В БАЗІ: %promoFound%
            RhRegColor(hPromoBase, RhB_StatusSoft, RhB_Text)
        } else {
            Gui, Roll:Font, s8 bold cFFFFFF, %RhFontName%
            Gui, Roll:Add, Text, x%x0% y%curY% w212 h22 Center +0x200 HwndhPromoNew, НОВЕ ПРОМО: %promoFound%
            RhRegColor(hPromoNew, RhB_Red, RhB_White)
            Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
            Gui, Roll:Add, Text, x236 y%curY% w108 h22 Center +Border +0x200 HwndhAppendPromo gAppendPromoToBase, В базу
            RhRegColor(hAppendPromo, RhB_CardFill, RhB_Text)
        }
        curY += 26
    }
    if (hasCustomerReq) {
        Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200, ПРОХАННЯ КЛІЄНТА
        curY += 18
        Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
        Gui, Roll:Add, Edit, x%x0% y%curY% w%w0% r2 ReadOnly -E0x200, %customerReqText%
        curY += 44
    }
    if (needCall) {
        Gui, Roll:Font, s9 bold cFFFFFF, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h22 Center +0x200 HwndhNeedCall, ПЕРЕДЗВОНИТИ КЛІЄНТУ
        RhRegColor(hNeedCall, RhB_Red, RhB_White)
        curY += 28
    } else if (!isPost) {
        Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h22 Center +0x200 HwndhNewClient, НОВИЙ КЛІЄНТ — зателефонуй
        RhRegColor(hNewClient, RhB_StatusSoft, RhB_Text)
        curY += 28
    }
    if (curY > 88)
        curY += 8

    ; Client block
    Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200, КЛІЄНТ
    curY += 20

    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w156 h16 +0x200, Кухня
    Gui, Roll:Add, Text, x188 y%curY% w156 h16 +0x200, Карта
    curY += 18
    Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x%x0% y%curY% w156 h24 r1 vClientInfo -E0x200, %infoText%
    Gui, Roll:Add, Edit, x188 y%curY% w156 h24 r1 vClientCard -E0x200, %cardText%
    curY += 34

    ; Address block
    Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200, АДРЕСА
    curY += 20
    Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x%x0% y%curY% w%w0% h24 r1 vAddressNote -E0x200, %addrNote%
    curY += 28

    ; --- Плашка перекритої вулиці ---
    if (blockedHit) {
        Gui, Roll:Font, s9 bold cD32F2F, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h34 +0x0, % "ПЕРЕКРИТО - уточни ділянку у гостя:`n" . blockedInfo
        curY += 40
    }


    ; Order block
    Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w180 h16 +0x200, ЗАМОВЛЕННЯ
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x232 y%curY% w112 h16 Right +0x200, %orderSum% грн
    curY += 20

    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w250 h16 +0x200, Коментар
    _btnTxt := RcRawShown ? "Сховати" : "Вихідний"
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x276 y%curY% w68 h20 Center +0x200 gRcToggleRawText HwndhRcRawBtn, %_btnTxt%
    RhRegColor(hRcRawBtn, RhB_CardFill, RhB_Text)
    curY += 22

    Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x%x0% y%curY% w%w0% r2 vOrderComment -E0x200, %cleanComment%
    _rawEditY := curY + 44
    curY += 44

    ; Raw comment hidden initially
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%_rawEditY% w%w0% h16 +0x200 vRawTxtLbl Hidden, Вихідний текст
    Gui, Roll:Add, Edit, x%x0% y%_rawEditY%+18 w%w0% r4 ReadOnly -E0x200 vRawTxtBox Hidden, %rawComment%

    ControlsToMove := []

    if (RC_GIFTS_ENABLED) {
        ; Extras block
        Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200 vLblGifts HwndhC1, ДОПИ
        ControlsToMove.Push(hC1)
        curY += 20

        Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
        Gui, Roll:Add, Text, x16  y%curY% w76 h24 Center +0x200 HwndhGiftG gToggleGiftG, Гункан
        Gui, Roll:Add, Text, x100 y%curY% w76 h24 Center +0x200 HwndhGiftP gToggleGiftP, Пепсі
        Gui, Roll:Add, Text, x184 y%curY% w76 h24 Center +0x200 HwndhGiftB gToggleGiftB, Бургер
        Gui, Roll:Add, Text, x268 y%curY% w76 h24 Center +0x200 HwndhGiftS gToggleGiftS, Сендвіч
        ControlsToMove.Push(hGiftG), ControlsToMove.Push(hGiftP), ControlsToMove.Push(hGiftB), ControlsToMove.Push(hGiftS)
        RhRegColor(hGiftG, (autoGunkan   ? RhB_GiftGunkan   : RhB_Chip), RhB_Text)
        RhRegColor(hGiftP, (autoPepsi    ? RhB_GiftPepsi    : RhB_Chip), RhB_Text)
        RhRegColor(hGiftB, (autoBurger   ? RhB_GiftBurger   : RhB_Chip), RhB_Text)
        RhRegColor(hGiftS, (autoSandwich ? RhB_GiftSandwich : RhB_Chip), RhB_Text)
        curY += 34
    }

    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200 vLblPayment HwndhC2, Оплата
    ControlsToMove.Push(hC2)
    curY += 18
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    _payText := "Готівка — решта з " . calcChange
    Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h28 Center +0x200 HwndhPayCash gToggleAutoCash, %_payText%
    ControlsToMove.Push(hPayCash)
    RhRegColor(hPayCash, (autoCash ? RhB_TintGreen : RhB_Chip), RhB_Text)
    curY += 40

    ; Time block
    Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200 vLblTime HwndhC3, ЧАС ГОТОВНОСТІ
    ControlsToMove.Push(hC3)
    curY += 20
    timeParts := StrSplit(extractedTime, ":")
    timeH := timeParts[1]
    timeM := timeParts[2]
    Gui, Roll:Font, s10 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x16 y%curY% w36 h24 vReadyTimeH Center Number Limit2 -E0x200 HwndhC4, %timeH%
    ControlsToMove.Push(hC4)
    Gui, Roll:Font, s10 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x56 y%curY% w10 h24 Center +0x200 +BackgroundTrans HwndhC5, :
    ControlsToMove.Push(hC5)
    Gui, Roll:Font, s10 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x68 y%curY% w36 h24 vReadyTimeM Center Number Limit2 -E0x200 HwndhC6, %timeM%
    ControlsToMove.Push(hC6)
    _pickupMin := RcKitchenMinutes("pickup", 40)
    _deliveryMin := RcKitchenMinutes(RcDeliveryKindFromZone(RcLastZone), 90)
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x116 y%curY% w108 h24 Center +0x200 HwndhCalcPickup vRhCalcPickupBtn gCalcPickup, % "СВ +" . _pickupMin
    Gui, Roll:Add, Text, x236 y%curY% w108 h24 Center +0x200 HwndhCalcDelivery vRhCalcDeliveryBtn gCalcDelivery, % "ДОСТ +" . _deliveryMin
    ControlsToMove.Push(hCalcPickup), ControlsToMove.Push(hCalcDelivery)
    RhRegColor(hCalcPickup, RhB_TintGreen, RhB_Text)
    RhRegColor(hCalcDelivery, RhB_TintAmber, RhB_Text)
    curY += 40

    ; SIV block
    Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200 vLblSIV HwndhC7, СІВ
    ControlsToMove.Push(hC7)
    curY += 20
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x16 y%curY% w36 h16 +0x200 HwndhC8, Роли
    Gui, Roll:Add, Text, x68 y%curY% w36 h16 +0x200 HwndhC9, Зв
    Gui, Roll:Add, Text, x120 y%curY% w36 h16 +0x200 HwndhC10, Уч
    Gui, Roll:Add, Text, x172 y%curY% w36 h16 +0x200 HwndhC14, Пр
    ControlsToMove.Push(hC8), ControlsToMove.Push(hC9), ControlsToMove.Push(hC10), ControlsToMove.Push(hC14)
    curY += 18
    Gui, Roll:Font, s10 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x16 y%curY% w40 h24 Center vVisRolls gRhSivInlineUpdate Number -E0x200 HwndhC11, %VisRolls%
    Gui, Roll:Add, Edit, x68 y%curY% w40 h24 Center vVisNorm gRhSivInlineUpdate Number -E0x200 HwndhC12, %parsedSticksNorm%
    Gui, Roll:Add, Edit, x120 y%curY% w40 h24 Center vVisEdu gRhSivInlineUpdate Number -E0x200 HwndhC13, %parsedSticksEdu%
    Gui, Roll:Add, Edit, x172 y%curY% w40 h24 Center vVisUtensils gRhSivInlineUpdate Number -E0x200 HwndhC15, %parsedUtensils%
    ControlsToMove.Push(hC11), ControlsToMove.Push(hC12), ControlsToMove.Push(hC13), ControlsToMove.Push(hC15)
    curY += 28
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x16 y%curY% w328 h20 +0x200 vRhSivPreview HwndhRhSivPreview, Соус 0 · Імбир 0 · Васабі 0
    ControlsToMove.Push(hRhSivPreview)
    curY += 32

    GuiBaseHeight := curY
    Gui, Roll:Show, x350 y20 w360 h%GuiBaseHeight%, Rollclub PRO 33.0
    Gui, Roll:+LastFound
    RollHwnd := WinExist()
    GoSub, RhRepaintRollPult
    GoSub, RhSivInlineUpdate

    if (RcRawShown) {
        RcRawShown := 0
        GoSub, RcToggleRawText
    }

    if (rawAddress != "" && !hasPickup)
        SetTimer, RcCheckZone, -450
    ; Звірка точки відбувається при натисканні Внести (GoSub RcCheckZone на початку ApplyRollclub)
return
; ========================================================
; TOGGLE ГІФТИ ТА КЕШ
; ========================================================
ToggleGiftG:
    autoGunkan := !autoGunkan
    autoPepsi := 0, autoBurger := 0, autoSandwich := 0
    GoSub, RefreshGifts
return
ToggleGiftP:
    autoPepsi := !autoPepsi
    autoGunkan := 0, autoBurger := 0, autoSandwich := 0
    GoSub, RefreshGifts
return
ToggleGiftB:
    autoBurger := !autoBurger
    autoGunkan := 0, autoPepsi := 0, autoSandwich := 0
    GoSub, RefreshGifts
return
ToggleGiftS:
    autoSandwich := !autoSandwich
    autoGunkan := 0, autoPepsi := 0, autoBurger := 0
    GoSub, RefreshGifts
return
RefreshGifts:
    if (!RC_GIFTS_ENABLED)
        return
    RhRegColor(hGiftG, (autoGunkan   ? RhB_GiftGunkan   : RhB_Chip), RhB_Text)
    RhRegColor(hGiftP, (autoPepsi    ? RhB_GiftPepsi    : RhB_Chip), RhB_Text)
    RhRegColor(hGiftB, (autoBurger   ? RhB_GiftBurger   : RhB_Chip), RhB_Text)
    RhRegColor(hGiftS, (autoSandwich ? RhB_GiftSandwich : RhB_Chip), RhB_Text)
    DllCall("InvalidateRect", "Ptr", hGiftG, "Ptr", 0, "Int", 1)
    DllCall("InvalidateRect", "Ptr", hGiftP, "Ptr", 0, "Int", 1)
    DllCall("InvalidateRect", "Ptr", hGiftB, "Ptr", 0, "Int", 1)
    DllCall("InvalidateRect", "Ptr", hGiftS, "Ptr", 0, "Int", 1)
return

ToggleAutoCash:
    autoCash := !autoCash
    RhRegColor(hPayCash, (autoCash ? RhB_TintGreen : RhB_Chip), RhB_Text)
    DllCall("InvalidateRect", "Ptr", hPayCash, "Ptr", 0, "Int", 1)
return

RcToggleRawText:
    RcRawShown := !RcRawShown
    offset := 86
    if (RcRawShown) {
        GuiControl, Roll:Show, RawTxtLbl
        GuiControl, Roll:Show, RawTxtBox
        GuiControl, Roll:, hRcRawBtn, Сховати
        for index, ctrl in ControlsToMove {
            GuiControlGet, pos, Roll:Pos, %ctrl%
            newY := posY + offset
            GuiControl, Roll:Move, %ctrl%, y%newY%
        }
        newH := GuiBaseHeight + offset
        WinMove, ahk_id %RollHwnd%, , , , , %newH%
    } else {
        GuiControl, Roll:Hide, RawTxtLbl
        GuiControl, Roll:Hide, RawTxtBox
        GuiControl, Roll:, hRcRawBtn, Вихідний
        for index, ctrl in ControlsToMove {
            GuiControlGet, pos, Roll:Pos, %ctrl%
            newY := posY - offset
            GuiControl, Roll:Move, %ctrl%, y%newY%
        }
        newH := GuiBaseHeight
        WinMove, ahk_id %RollHwnd%, , , , , %newH%
    }
return

RhSivInlineUpdate:
    Gui, Roll:Submit, NoHide
    _r := (VisRolls != "" ? VisRolls + 0 : 0)
    _u := (VisUtensils != "" ? VisUtensils + 0 : 0)
    _soyC := Ceil(_r / 2.0)
    _soyM := (_r < 2) ? _r : 2
    _soy  := (_soyC > _soyM) ? _soyC : _soyM
    _gw   := Ceil(_r / 4.0)
    if (_r == 0) {
        _soy := 0
        _gw  := 0
    }
    _sivText := "Соєвий " . _soy . " · Імбир " . _gw . " · Васабі " . _gw
    if (_u > 0)
        _sivText .= " · Прибори " . _u
    GuiControl, Roll:, RhSivPreview, %_sivText%
return

RhAutoToggle:
    ; ГОЛОВНИЙ РУБИЛЬНИК: якщо авто-КЦ вимкнено — F4 нічого не робить (швидкий ручний пульт).
    if (rhPunchBusy || _inDutyTake)
    {
        SetTimer, KcMonitor, Off
        autoMode := 0
        return
    }
    if (!AUTO_KC_ENABLED) {
        SetTimer, KcMonitor, Off
        autoMode := 0
        return
    }
    autoMode := !autoMode
    FormatTime, _atT,, yyyy-MM-dd HH:mm:ss
    FileAppend, % "==== F4/TOGGLE " . _atT . " -> autoMode=" . autoMode . " (kcBusy=" . kcBusy . " kcPaused=" . kcPaused . ")`n", %A_ScriptDir%\parse_debug.log
    if (autoMode)
        GuiControl, Roll:, RhAutoLbl, AUTO: ON
    else
        GuiControl, Roll:, RhAutoLbl, AUTO: OFF
    if (autoMode)
    {
        kcLastNo := ""
        SetTimer, KcMonitor, 1800
        ToolTip, Full-auto ON
    }
    else
    {
        SetTimer, KcMonitor, Off
        ToolTip, Full-auto OFF
    }
    SetTimer, RemoveFinishTip, -2000
return

KcStopDuty:
    ; будь-яка РУЧНА дія оператора (тільда/F1/F2/F3/Enter/Ctrl+Enter) → вимкнути дежурство + вікно "оператор працює".
    ; _inDutyTake=1 → викликано самим дежурством під час взяття, НЕ гасимо і вікно НЕ ставимо.
    if (!_inDutyTake)
        _punchUntil := A_TickCount + 12000     ; 12с оператор працює руками → дежурство/пошук не лізуть
    if (dutyOn && !_inDutyTake)
    {
        dutyOn := 0
        kcStop := 1
        SetTimer, KcDutyTick, Off
        ToolTip, Дежурство ВИМКНЕНО (ручний режим)
        SetTimer, RemoveToolTip, -1500
    }
return

KcDutyToggle:
    OpCoord_Event("DutyScanning", "toggle", "KcDutyToggle", "was_dutyOn=" . dutyOn . ";punchBusy=" . rhPunchBusy . ";inDutyTake=" . _inDutyTake)
    ; F4 з доповнення «Дежурство заказов»: бере перше вільне замовлення і зупиняється.
    FileAppend, % "[" . A_Now . "] F4-TOGGLE (was dutyOn=" . dutyOn . ")`n", %A_ScriptDir%\parse_debug.log
    if (rhPunchBusy || _inDutyTake)
    {
        dutyOn := 0
        kcStop := 1
        SetTimer, KcDutyTick, Off
        SetTimer, KcMonitor, Off
        FileAppend, % "[" . A_Now . "] F4 BLOCKED — punchBusy=" . rhPunchBusy . " inTake=" . _inDutyTake . "`n", %A_ScriptDir%\parse_debug.log
        ToolTip, F4 заблоковано: йде пробиття
        SetTimer, RemoveToolTip, -1500
        return
    }
    if (A_TickCount < _punchUntil)
    {
        FileAppend, % "[" . A_Now . "] F4 IGNORED — під час пробиття`n", %A_ScriptDir%\parse_debug.log
        return
    }
    dutyOn := !dutyOn
    if (dutyOn)
    {
        kcStop := 0
        kcTook := 0
        ToolTip, ⏳ Дежурю по заказах... (F4 — стоп)
        SetTimer, KcDutyTick, 1500
    }
    else
    {
        kcStop := 1                 ; перервати захід, що вже виконується
        SetTimer, KcDutyTick, Off
        ToolTip, Дежурство ВИМКНЕНО
        SetTimer, RemoveToolTip, -3000
    }
return

RcDutyModuleInvoke:
    global RcDutyModuleRequest
    if (RcDutyModuleRequest = 1)
        GoSub, KcDutyToggle
    RcDutyModuleRequest := 0
return

KcDutyTick:
    FileAppend, % "[" . A_Now . "] DUTY-TICK dutyOn=" . dutyOn . " kcBusy=" . kcBusy . "`n", %A_ScriptDir%\parse_debug.log
    if (rhPunchBusy || _inDutyTake)
    {
        dutyOn := 0
        kcStop := 1
        SetTimer, KcDutyTick, Off
        SetTimer, KcMonitor, Off
        FileAppend, % "[" . A_Now . "] DUTY-TICK BLOCKED — punchBusy=" . rhPunchBusy . " inTake=" . _inDutyTake . "`n", %A_ScriptDir%\parse_debug.log
        return
    }
    if (!dutyOn)
    {
        SetTimer, KcDutyTick, Off
        return
    }
    if (kcBusy)
        return
    kcForce := 1
    kcPaused := 0
    kcTook := 0
    GoSub, KcMonitor
    if (kcTook)
    {
        dutyOn := 0
        SetTimer, KcDutyTick, Off
        GoSub, LoudAlarm
    }
return

LoudAlarm:
    Loop, 6
    {
        SoundBeep, 900, 220
        SoundBeep, 1350, 220
    }
return

KcTakeOnce:
    ; один примусовий захід напівавтомата (минаючи авто-таймер і паузу)
    if (rhPunchBusy || _inDutyTake)
        return
    if (A_TickCount < _punchUntil)
        return
    if (kcBusy)
        return
    kcForce := 1
    kcPaused := 0
    GoSub, KcMonitor
return

KcMonitor:
    FileAppend, % "[" . A_Now . "] KcMON enter dutyOn=" . dutyOn . " kcForce=" . kcForce . " autoMode=" . autoMode . " AUTO=" . AUTO_KC_ENABLED . " kcBusy=" . kcBusy . " inTake=" . _inDutyTake . "`n", %A_ScriptDir%\parse_debug.log
    if (rhPunchBusy || _inDutyTake)
    {
        dutyOn := 0
        kcForce := 0
        kcStop := 1
        SetTimer, KcDutyTick, Off
        SetTimer, KcMonitor, Off
        FileAppend, % "[" . A_Now . "] KcMON BLOCKED — punchBusy=" . rhPunchBusy . " inTake=" . _inDutyTake . "`n", %A_ScriptDir%\parse_debug.log
        return
    }
    if (!kcForce && (!AUTO_KC_ENABLED || !autoMode))
    {
        SetTimer, KcMonitor, Off
        autoMode := 0
        return
    }
    if (kcBusy)
        return
    if (kcPaused && !kcForce)
        return
    if (A_TickCount < _punchUntil)          ; недавня ручна дія оператора → дежурство пропускає круг
    {
        kcForce := 0
        return
    }
    kcForce := 0
    kcBusy := 1
    kcStop := 0                     ; свіжий захід — скинути прапор стопу
    ; === ПРАВИЛЬНИЙ ПОРЯДОК: вікно → стерти старий № → оновити КЦ (Ctrl+Tab×2) → аж тоді питати сервер ===
    SetTitleMatchMode, 2
    if !WinExist("Syrve Office")
    {
        ToolTip, F4: вікно РК (Syrve Office) не знайдено — відкрий Доставки
        SetTimer, RemoveToolTip, -6000
        kcBusy := 0
        return
    }
    WinActivate, Syrve Office
    WinWaitActive, Syrve Office,, 2
    SetTitleMatchMode, 1
    Sleep, 200
    Send, {Esc}                    ; закрити випадкові випадашки/фокус у карточці
    Sleep, 120
    ; 1) оновити КЦ без кулдауна: на сусідню вкладку і назад.
    ; ВАЖЛИВО: до цього моменту НЕ клікаємо PoiskX/PoiskY — на карточці це поле "Оператор".
    Send, ^{Tab}
    Sleep, 220
    Send, ^{Tab}
    Sleep, 330
    if (kcStop)
    {
        kcBusy := 0
        ToolTip, Стоп (F4)
        SetTimer, RemoveToolTip, -1500
        return
    }
    ; 2) список свіжий — тепер питаємо сервер (+ серверний таймінг у bridge.log)
    ToolTip, F4: питаю сервер про годний заказ...
    listResp := RhGet("/api/iiko/kc-list", 12000)
    if InStr(listResp, "ACTIVE_ORDER_CARD")
    {
        ToolTip, F4: активна карточка — переходжу на Доставки...
        Send, {Esc}
        Sleep, 180
        Send, ^{Tab}
        Sleep, 700
        listResp := RhGet("/api/iiko/kc-list", 12000)
    }
    if InStr(listResp, "ACTIVE_ORDER_CARD")
    {
        kcBusy := 0
        ToolTip, F4: досі карточка заказа — відкрий вкладку Доставки
        SetTimer, RemoveToolTip, -6000
        return
    }
    Sleep, 30                       ; дати шанс F4-стопу під час блокуючого запиту
    if (kcStop)
    {
        kcBusy := 0
        ToolTip, Стоп (F4) — заказ не чіпаю
        SetTimer, RemoveToolTip, -1500
        return
    }
    takeNo := ""
    RegExMatch(listResp, "take_no\D+(\d+)", tM)
    takeNo := tM1
    FileAppend, % "[" . A_Now . "] KC takeNo=" . takeNo . " paused=" . kcPaused . " poiskX=" . poiskX . " rowX=" . rowX . " resp=" . SubStr(listResp,1,160) . "`n", %A_ScriptDir%\ahk_debug.log
    if (takeNo == "" || takeNo == "0")
    {
        _reason := ""
        RegExMatch(listResp, "reason""\s*:\s*""([^""]*)", _rM)
        _reason := _rM1
        ToolTip, % "F4: нема вільних для взяття`n" . _reason
        SetTimer, RemoveToolTip, -8000
        kcBusy := 0
        return
    }
    ToolTip, F4: беру заказ №%takeNo%...
    ; 3) тільки зараз можна чіпати поле Поиск: сервер підтвердив, що активний список Доставки.
    ; --- capture: Poisk -> open first row ---
    if (poiskX != 0)
    {
        Click, %poiskX%, %poiskY%
        Sleep, 200
        Send, ^a
        Sleep, 50
        Send, {Delete}          ; примусово стерти старий № перед вводом (інакше SendInput дописує → задвоєний фільтр → список порожній → холостий круг)
        Sleep, 80
        SendInput, %takeNo%
        Sleep, 800
    }
    ; --- ПЕРЕВІРКА перед пробиттям: список має звузитись РІВНО до нашого № ---
    ; якщо ні (ми не на Доставках / фільтр не спрацював) — НЕ пробиваємо, пропускаємо цей круг.
    _chk := RhGet("/api/iiko/kc-list", 6000)
    _cnt := ""
    RegExMatch(_chk, "count""\s*:\s*(\d+)", _cM)
    _cnt := _cM1
    if (_cnt != "1" || !InStr(_chk, takeNo))
    {
        ToolTip, % "F4: список не звузився до №" . takeNo . " — НЕ пробиваю (не на Доставках?)"
        SetTimer, RemoveToolTip, -5000
        kcBusy := 0
        return
    }
    ToolTip                     ; прибрати підказку — вона перекривала рядок, клік потрапляв у неї
    Sleep, 60
    if (kcStop)
    {
        kcBusy := 0
        ToolTip, Стоп (F4) — заказ не відкриваю
        SetTimer, RemoveToolTip, -1500
        return
    }
    if (rowX != 0)
    {
        Click, %rowX%, %rowY%
        Sleep, 120
        Click, %rowX%, %rowY%
        Sleep, 700
    }
    ; --- ЗАХИСТ: діалог "Подтверждение: Доставка обрабатывается оператором ... продолжить?" ---
    ;    З'являється НЕ миттєво після кліку — ЧЕКАЄМО його до 2с. Є → Нет (Esc) і ПРОПУСКАЄМО.
    SetTitleMatchMode, 2
    _busy := 0
    WinWait, Подтверждение,, 2
    if (!ErrorLevel)
        _busy := 1
    if (!_busy && WinExist("ahk_class #32770"))
        _busy := 1
    if (!_busy && WinExist("Підтвердження"))
        _busy := 1
    if (!_busy && WinExist("", "обрабат"))
        _busy := 1
    if (!_busy && WinExist("", "обробля"))
        _busy := 1
    SetTitleMatchMode, 1
    if (_busy)
    {
        Send, {Esc}
        Sleep, 250
        Send, {Esc}
        Sleep, 150
        ToolTip, % "Заказ №" . takeNo . " вже взяв інший оператор — пропускаю"
        SetTimer, RemoveToolTip, -4000
        kcBusy := 0
        return
    }
    ; opened -> read (tilde) + punch + sound + pause
    if (kcStop)
    {
        kcBusy := 0
        ToolTip, Стоп (F4) — не пробиваю
        SetTimer, RemoveToolTip, -1500
        return
    }
    Sleep, 300
    ; Заказ уже открыт: с этого момента F4/КЦ-дежурство больше не имеет права
    ; искать следующий заказ, пока текущий читается и пробивается.
    dutyOn := 0
    kcPaused := 1
    SetTimer, KcDutyTick, Off
    SetTimer, KcMonitor, Off
    _inDutyTake := 1
    GoSub, TriggerMain
    Sleep, 3000
    GoSub, ApplyRollclub
    _inDutyTake := 0
    Sleep, 500
    GoSub, SoundOk
    kcTook := 1
    ToolTip, ✅ ВЗЯВ №%takeNo% — перевір і натисни Ctrl+Enter
    SetTimer, RemoveToolTip, -15000
    kcPaused := 1
    kcBusy := 0
return

#IfWinActive Rollclub PRO 33.0
Enter::GoSub, ApplyRollclub
NumpadEnter::GoSub, ApplyRollclub
+Enter::Send, {Enter}
+NumpadEnter::Send, {Enter}
^Enter::GoSub, FinishOrder
^+Enter::GoSub, FinishOrder
^NumpadEnter::GoSub, FinishOrder
^+NumpadEnter::GoSub, FinishOrder
#IfWinActive

#IfWinActive ahk_exe BackOffice.exe
^Enter::GoSub, FinishOrder
^+Enter::GoSub, FinishOrder
^NumpadEnter::GoSub, FinishOrder
^+NumpadEnter::GoSub, FinishOrder
#IfWinActive

#IfWinActive СИВ (Модуль)
Enter::GoSub, SivVisApply
NumpadEnter::GoSub, SivVisApply
#IfWinActive

^!r::Reload                ; Ctrl+Alt+R — перезавантажити скрипт (підхопити свіжий код з диску)

; ========================================================
; НАЛАШТУВАННЯ
; ========================================================
OpenSettings:
    Gui, Settings:Destroy
    Gui, Settings:+AlwaysOnTop +ToolWindow +OwnDialogs +HwndSettingsHwnd

    RhApplyTheme()
    Gui, Settings:Color, %RhC_BG%, %RhC_Panel%

    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Tab3, x6 y6 w348 h610 vSettingsTab, WinAPI|PLU коди|Координати

    ; ── Вкладка 1: WinAPI scanner ───────────────────────────
    Gui, Settings:Tab, 1
    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y36 w320 Center, ЗБЕРЕЖЕНІ WinAPI ЕЛЕМЕНТИ
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, ListView, x16 y62 w322 h190 vUiaListView gUiaListClick Grid, Назва (роль)|AutomationId / Name
    Gui, Settings:Default
    Gui, ListView, UiaListView
    LV_ModifyCol(1, 142)
    LV_ModifyCol(2, 166)
    GoSub, LoadUiaMapToListView
    Gui, Settings:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, x16 y262 w156 h32 gLaunchScanner, Додати елемент
    Gui, Settings:Add, Button, x182 y262 w156 h32 gDeleteSelectedUiaBinding, Видалити вибране
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, x16 y302 w322 h42, Наведіть курсор на кнопку в Syrve та натисніть ліву кнопку миші.`nВиберіть рядок і натисніть «Видалити».

    ; ── Вкладка 2: PLU-коди оператора ─────────────────────────
    Gui, Settings:Tab, 2

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, w320 Center x16 y36, PLU КОДИ СІВ / ПРИБОРИ
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x24 y66 w170 h18, Позиція
    Gui, Settings:Add, Text, x+5 yp w80 h18 Center, PLU
    Gui, Settings:Add, Text, x24 y+6 w170 h22 +0x200, Бамбукові палички
    Gui, Settings:Add, Edit, x+5 yp w80 h22 vNewSticksNorm Center Limit10, %pluSticksNorm%
    Gui, Settings:Add, Text, x24 y+6 w170 h22 +0x200, Навчальні палички
    Gui, Settings:Add, Edit, x+5 yp w80 h22 vNewSticksEdu Center Limit10, %pluSticksEdu%
    Gui, Settings:Add, Text, x24 y+6 w170 h22 +0x200, Соєвий соус
    Gui, Settings:Add, Edit, x+5 yp w80 h22 vNewPluSoy Center Limit10, %pluSoy%
    Gui, Settings:Add, Text, x24 y+6 w170 h22 +0x200, Імбир
    Gui, Settings:Add, Edit, x+5 yp w80 h22 vNewPluGinger Center Limit10, %pluGinger%
    Gui, Settings:Add, Text, x24 y+6 w170 h22 +0x200, Васабі
    Gui, Settings:Add, Edit, x+5 yp w80 h22 vNewPluWasabi Center Limit10, %pluWasabi%
    Gui, Settings:Add, Text, x24 y+6 w170 h22 +0x200, Прибори разом
    Gui, Settings:Add, Edit, x+5 yp w80 h22 vNewUtensils Center Limit10, %pluUtensils%
    Gui, Settings:Add, Text, x24 y+6 w170 h22 +0x200, Вилка
    Gui, Settings:Add, Edit, x+5 yp w80 h22 vNewPluFork Center Limit10, %pluFork%
    Gui, Settings:Add, Text, x24 y+6 w170 h22 +0x200, Ніж
    Gui, Settings:Add, Edit, x+5 yp w80 h22 vNewPluKnife Center Limit10, %pluKnife%
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, x24 y+8 w300, PLU вводиться повністю, разом із нулями на початку.

    ; ── Вкладка 3: резервні координати та інші налаштування ──
    Gui, Settings:Tab, 3

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, w300 Center, ПРИЦІЛИ (координати)
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, w140 x10 y+10 gSetCommTarget,  1. Коментар
    Gui, Settings:Add, Button, w140 x+10 yp  gSetCardTarget,  2. Карта Клієнта
    Gui, Settings:Add, Button, w140 x10  y+5 gSetInfoTarget,  3. Кухня
    Gui, Settings:Add, Button, w140 x+10 yp  gSetAddrTarget,  4. Адреса
    Gui, Settings:Add, Button, w140 x10  y+5 gSetTimeTarget,  Час
    Gui, Settings:Add, Button, w140 x+10 yp  gSetItemTarget,  Табл. Страв
    Gui, Settings:Add, Button, w140 x10  y+5 gSetCrossTarget, Хрестик Опл.
    Gui, Settings:Add, Button, w140 x+10 yp  gSetCashTarget,  Поле Оплати
    Gui, Settings:Add, Button, w140 x10  y+5 gSetSumTarget,   Сума Замовлення
    Gui, Settings:Add, Button, w140 x+10 yp  gCalibrateWaitZoneFromSettings,  Зона CRM (zxc)
    Gui, Settings:Add, Button, w140 x10  y+5 gSetCallTarget,  Авто-Прийом Дзв. (zxc1)
    Gui, Settings:Add, Button, w140 x+10 yp  gSetAdrReadTarget, Поле читання адреси
    Gui, Settings:Add, Button, w290 x10  y+5 gSetKontsTarget,  Концепція (самовивіз)
    Gui, Settings:Add, Button, w140 x10  y+5 gSetConfirmTarget, Подтвердить (фініш)
    Gui, Settings:Add, Button, w140 x+10 yp  gSetSaveTarget,    Зберегти на точку
    Gui, Settings:Add, Button, w290 x10  y+5 gSetNaitiTarget,  Найти точку (кнопка iiko)
    Gui, Settings:Add, Button, w290 x10  y+5 gSetTochkaTarget, Точка (поле для звірки зони)
    Gui, Settings:Add, Button, w140 x10  y+5 gSetPoiskTarget,  Поле Поиск (КЦ)
    Gui, Settings:Add, Button, w140 x+10 yp  gSetRowTarget,    1-й рядок списку

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, w300 Center x10 y+15, ФУНКЦІЇ
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Checkbox, w290 x10 y+10 vNewCheckPoint Checked%CHECK_POINT_ENABLED%, 📍 Авто-Звірка Точки (клік iiko + порівняння)

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, w300 Center x10 y+15, ТЕМА
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x10 y+10 w60, Стиль:
    _themeIdx := (uiTheme == "dark") ? 2 : 1
    Gui, Settings:Add, DropDownList, x+5 yp-3 w220 vNewUiTheme Choose%_themeIdx%, Light Premium|Neon Dark

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, w300 Center x10 y+15, ЗОНИ ДОСТАВКИ (KML)
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, x10 y+10 w290 h28 gRcLoadKmlFile, Завантажити KML-файл зон

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, w300 Center x10 y+15, ГАРЯЧІ КЛАВІШІ
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x10 y+10 w140, Головне меню:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkMain, %hkMain%
    Gui, Settings:Add, Text, x10 y+10 w140, Швидкий СИВ:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkSiv, %hkSiv%
    Gui, Settings:Add, Text, x10 y+10 w140, Фініш (Зберегти):
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkFinish, %hkFinish%

    Gui, Settings:Tab
    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, w322 h35 x16 y630 gSaveSettings, Зберегти та Перезапустити
    Gui, Settings:Show, w360 h680, Налаштування RollClub
return

SaveSettings:
    Gui, Settings:Submit
    uiThemeSave := InStr(NewUiTheme, "Dark") ? "dark" : "light"
    IniWrite, %uiThemeSave%, RkConfig.ini, UI, Theme

    CHECK_POINT_ENABLED := NewCheckPoint
    IniWrite, %NewCheckPoint%, RkConfig.ini, Main, CheckPoint
    IniWrite, %NewSticksNorm%, RkConfig.ini, PLU, SticksNorm
    IniWrite, %NewSticksEdu%,  RkConfig.ini, PLU, SticksEdu
    IniWrite, %NewUtensils%,   RkConfig.ini, PLU, Utensils
    IniWrite, %NewPluFork%,    RkConfig.ini, PLU, Fork
    IniWrite, %NewPluKnife%,   RkConfig.ini, PLU, Knife
    IniWrite, %NewPluSoy%,     RkConfig.ini, PLU_SIV, Soy
    IniWrite, %NewPluGinger%,  RkConfig.ini, PLU_SIV, Ginger
    IniWrite, %NewPluWasabi%,  RkConfig.ini, PLU_SIV, Wasabi
    IniWrite, %NewHkMain%,   RkConfig.ini, Hotkeys, Main
    IniWrite, %NewHkSiv%,    RkConfig.ini, Hotkeys, Siv
    IniWrite, %NewHkFinish%, RkConfig.ini, Hotkeys, Finish
    MsgBox, 64, Збережено, Налаштування збережено! Перезапуск..., 2
    Reload
return

SettingsGuiClose:
SettingsGuiEscape:
    Gui, Settings:Destroy
return

; ========================================================
; КАЛІБРУВАННЯ ПРИЦІЛІВ
; ========================================================
SetCommTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле КОМЕНТАР.
    KeyWait, LButton, Down
    MouseGetPos, commX, commY
    IniWrite, %commX%, RkConfig.ini, Targets, CommX
    IniWrite, %commY%, RkConfig.ini, Targets, CommY
    Gui, Settings:Show
return
SetCardTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле КАРТА КЛІЄНТА.
    KeyWait, LButton, Down
    MouseGetPos, cardX, cardY
    IniWrite, %cardX%, RkConfig.ini, Targets, CardX
    IniWrite, %cardY%, RkConfig.ini, Targets, CardY
    Gui, Settings:Show
return
SetInfoTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування - КУХНЯ, КУХНЯ = комірка "Комментарий" у РЯДКУ СТРАВИ (стовпець Комментарий навпроти блюда).`n`nНЕ став на "Улица" і НЕ на "Информация о клиенте" - туди не можна (вулиця зітреться, кухня буде порожня).`n`nКлікни в ту комірку коментаря страви.
    KeyWait, LButton, Down
    MouseGetPos, infoX, infoY
    IniWrite, %infoX%, RkConfig.ini, Targets, InfoX
    IniWrite, %infoY%, RkConfig.ini, Targets, InfoY
    Gui, Settings:Show
return
SetAddrTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування - АДРЕСА, АДРЕСА = поле "Примечание к адресу" (блок Доставка праворуч, під Районом).`n`nКлікни туди.
    KeyWait, LButton, Down
    MouseGetPos, addrX, addrY
    IniWrite, %addrX%, RkConfig.ini, Targets, AddrX
    IniWrite, %addrY%, RkConfig.ini, Targets, AddrY
    Gui, Settings:Show
return
SetTimeTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в ПОЛЕ ЧАСУ.
    KeyWait, LButton, Down
    MouseGetPos, timeX, timeY
    IniWrite, %timeX%, RkConfig.ini, Targets, TimeX
    IniWrite, %timeY%, RkConfig.ini, Targets, TimeY
    Gui, Settings:Show
return
SetItemTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в ТАБЛИЦЮ СТРАВ.
    KeyWait, LButton, Down
    MouseGetPos, itemX, itemY
    IniWrite, %itemX%, RkConfig.ini, Targets, ItemX
    IniWrite, %itemY%, RkConfig.ini, Targets, ItemY
    Gui, Settings:Show
return
SetCrossTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни на ХРЕСТИК оплати.
    KeyWait, LButton, Down
    MouseGetPos, crossX, crossY
    IniWrite, %crossX%, RkConfig.ini, Targets, CrossX
    IniWrite, %crossY%, RkConfig.ini, Targets, CrossY
    Gui, Settings:Show
return
    total := A_Hour*60 + A_Min + CalcType
    HH := Mod(Floor(total / 60), 24)
    MM := Mod(total, 60)
    GuiControl, Roll:, ReadyTimeH, % Format("{:02}", HH)
    GuiControl, Roll:, ReadyTimeM, % Format("{:02}", MM)
return
SetCashTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в ПОЛЕ ОПЛАТИ.
    KeyWait, LButton, Down
    MouseGetPos, cashX, cashY
    IniWrite, %cashX%, RkConfig.ini, Targets, CashX
    IniWrite, %cashY%, RkConfig.ini, Targets, CashY
    Gui, Settings:Show
return
SetSumTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле СУМИ.
    KeyWait, LButton, Down
    MouseGetPos, sumX, sumY
    IniWrite, %sumX%, RkConfig.ini, Targets, SumX
    IniWrite, %sumY%, RkConfig.ini, Targets, SumY
    Gui, Settings:Show
return
CalibrateWaitZoneFromSettings:
    Gui, Settings:Hide
    Sleep, 300
    GoSub, CalibrateWaitZone
    Gui, Settings:Show
return
SetCallTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в ОБЛАСТЬ ДЗВІНКА (Приціл для zxc1.png).
    KeyWait, LButton, Down
    MouseGetPos, callX, callY
    IniWrite, %callX%, RkConfig.ini, Targets, CallX
    IniWrite, %callY%, RkConfig.ini, Targets, CallY
    Gui, Settings:Show
return
SetAdrReadTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле, де відображається АДРЕСА заказу (звідки скрипт буде ЧИТАТИ адресу для детекту міста).
    KeyWait, LButton, Down
    MouseGetPos, adrReadX, adrReadY
    IniWrite, %adrReadX%, RkConfig.ini, Targets, AdrReadX
    IniWrite, %adrReadY%, RkConfig.ini, Targets, AdrReadY
    Gui, Settings:Show
return
SetKontsTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле КОНЦЕПЦІЯ в iiko (для самовивозів Садовий проїзд).
    KeyWait, LButton, Down
    MouseGetPos, kontsX, kontsY
    IniWrite, %kontsX%, RkConfig.ini, Targets, KontsX
    IniWrite, %kontsY%, RkConfig.ini, Targets, KontsY
    Gui, Settings:Show
return

SetConfirmTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в кнопку "Подтвердить" (унизу зліва вікна заказу iiko).
    KeyWait, LButton, Down
    MouseGetPos, confirmX, confirmY
    IniWrite, %confirmX%, RkConfig.ini, Targets, ConfirmX
    IniWrite, %confirmY%, RkConfig.ini, Targets, ConfirmY
    Gui, Settings:Show
return

SetSaveTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в кнопку "Сохранить на точку" (унизу справа вікна заказу iiko).
    KeyWait, LButton, Down
    MouseGetPos, saveX, saveY
    IniWrite, %saveX%, RkConfig.ini, Targets, SaveX
    IniWrite, %saveY%, RkConfig.ini, Targets, SaveY
    Gui, Settings:Show
return

SetNaitiTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в кнопку "Найти точку" (справа у блоці Доставка iiko).
    KeyWait, LButton, Down
    MouseGetPos, naitiX, naitiY
    IniWrite, %naitiX%, RkConfig.ini, Targets, NaitiX
    IniWrite, %naitiY%, RkConfig.ini, Targets, NaitiY
    Gui, Settings:Show
return

SetTochkaTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування - ТОЧКА, ТОЧКА = поле "Точка*" (зверху форми, під Концепцією; те, що iiko заповнює після "Найти точку").`n`nКлікни в це поле.
    KeyWait, LButton, Down
    MouseGetPos, tochkaX, tochkaY
    IniWrite, %tochkaX%, RkConfig.ini, Targets, TochkaX
    IniWrite, %tochkaY%, RkConfig.ini, Targets, TochkaY
    Gui, Settings:Show
return

SetPoiskTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Nalashtuvannya, Click in the "Poisk" field (top of Dostavki list in iiko).
    KeyWait, LButton, Down
    MouseGetPos, poiskX, poiskY
    IniWrite, %poiskX%, RkConfig.ini, Targets, PoiskX
    IniWrite, %poiskY%, RkConfig.ini, Targets, PoiskY
    Gui, Settings:Show
return

SetRowTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Nalashtuvannya, Click on the FIRST row of the Dostavki list in iiko.
    KeyWait, LButton, Down
    MouseGetPos, rowX, rowY
    IniWrite, %rowX%, RkConfig.ini, Targets, RowX
    IniWrite, %rowY%, RkConfig.ini, Targets, RowY
    Gui, Settings:Show
return

; ── Звуки для авто-режиму (чути в навушниках) ──
SoundOk:        ; усе зійшлось → підійди й тисни Ctrl+Enter
    SoundBeep, 880, 90
    SoundBeep, 1318, 130
return
SoundErr:       ; щось не зійшлось / увага
    SoundBeep, 440, 180
    SoundBeep, 311, 280
return

; ========================================================
; РЕДАКТОР СТАТУСІВ КУХОНЬ
; ========================================================
OpenKitchensEditor:
    GoSub, LoadKitchens          ; перечитати з диска
    Gui, Kitch:Destroy
    Gui, Kitch:+AlwaysOnTop +ToolWindow
    Gui, Kitch:Font, s10 bold, Segoe UI
    Gui, Kitch:Add, Text, x10 y10 w820 Center, 🏪 СТАТУСИ КУХОНЬ (ТАБЛИЦЯ)
    Gui, Kitch:Font, s9 norm cGray, Segoe UI
    Gui, Kitch:Add, Text, x10 y+5 w820 Center, Доставка, Самовивіз, Дальня зона та Стоп-листи

    ; Заголовки колонок
    Gui, Kitch:Font, s9 bold cBlack, Segoe UI
    Gui, Kitch:Add, Text, x10  y60 w130, Кухня / Місто
    Gui, Kitch:Add, Text, x150 y60 w150, Примітка
    Gui, Kitch:Add, Text, x310 y60 w110, Центр
    Gui, Kitch:Add, Text, x430 y60 w110, Самовивіз
    Gui, Kitch:Add, Text, x550 y60 w110, Дальня зона
    Gui, Kitch:Add, Text, x670 y60 w150, Стоп
    Gui, Kitch:Font, s9 norm cBlack, Segoe UI

    ; Завантажуємо пресети з файлу (редагується через кнопку ⚙)
    presetNotes := ""
    if FileExist(PresetsPath) {
        loop, read, %PresetsPath%
        {
            line := Trim(A_LoopReadLine)
            if (line != "")
                presetNotes .= (presetNotes != "" ? "|" : "") . line
        }
    }
    if (presetNotes == "")
        presetNotes := "Стандарт|Стоп|по узгодженню"

    rowY := 80
    guiRow := 0
    for idx, k in Kitchens {
        guiRow += 1
        Kitchens[idx].GuiRow := guiRow
        label := k.Name . " (" . k.City . ")"
        Gui, Kitch:Add, Text, x10 y%rowY% w130 h22 +0x200, %label%

        vRemark := "KRem_" . guiRow
        valRem := k.Remark
        Gui, Kitch:Add, Edit, x150 y%rowY% w150 h22 v%vRemark%, %valRem%

        vCenter := "KCen_" . guiRow
        optCenter := RcBuildKitchOpts(k.Center, presetNotes)
        Gui, Kitch:Add, ComboBox, x310 y%rowY% w110 v%vCenter%, %optCenter%

        vPickup := "KPic_" . guiRow
        optPickup := RcBuildKitchOpts(k.Pickup, presetNotes)
        Gui, Kitch:Add, ComboBox, x430 y%rowY% w110 v%vPickup%, %optPickup%

        vFar := "KFar_" . guiRow
        optFar := RcBuildKitchOpts(k.FarZone, presetNotes)
        Gui, Kitch:Add, ComboBox, x550 y%rowY% w110 v%vFar%, %optFar%

        vStop := "KSto_" . guiRow
        valStop := k.StopList
        Gui, Kitch:Add, Edit, x670 y%rowY% w150 h22 v%vStop%, %valStop%

        rowY += 26
    }

    rowY += 10
    Gui, Kitch:Font, s10 bold, Segoe UI
    Gui, Kitch:Add, Button, x10  y%rowY% w120 h32 gSyncKitchensGoogle, Google
    Gui, Kitch:Add, Button, x140 y%rowY% w120 h32 gOpenPresetsEditor, Пресети
    Gui, Kitch:Add, Button, x270 y%rowY% w150 h32 gSaveKitchens,     Зберегти
    Gui, Kitch:Add, Button, x430 y%rowY% w180 h32 gResetKitchensOk,  Скинути в Стандарт
    Gui, Kitch:Add, Button, x620 y%rowY% w135 h32 gKitchClose,       Закрити
    Gui, Roll:Hide
    Gui, Kitch:Show, , Кухні — статуси
    WinActivate, Кухні — статуси
return

SaveKitchens:
    Gui, Kitch:Submit, NoHide
    for idx, k in Kitchens {
        guiRow := Kitchens[idx].GuiRow ? Kitchens[idx].GuiRow : idx
        vRem := "KRem_" . guiRow
        vCen := "KCen_" . guiRow
        vPic := "KPic_" . guiRow
        vFar := "KFar_" . guiRow
        vSto := "KSto_" . guiRow

        Kitchens[idx].Remark   := %vRem%
        Kitchens[idx].Center   := (%vCen% != "") ? %vCen% : "Стандарт"
        Kitchens[idx].Pickup   := (%vPic% != "") ? %vPic% : "Стандарт"
        Kitchens[idx].FarZone  := (%vFar% != "") ? %vFar% : "Стандарт"
        Kitchens[idx].StopList := %vSto%
    }
    GoSub, WriteKitchensFile
    MsgBox, % 64 + 262144, Кухні, Збережено!, 1
    Gui, Kitch:Destroy
    GoSub, DetectKitchenStatus
    Gui, Roll:Show
    GoSub, RhRepaintRollPult
return

SyncKitchensGoogle:
    if (RcKitchensSyncBlocked()) {
        MsgBox, % 48 + 262144, Кухні, Зараз іде активний сценарій.`nСпробуй оновити Google після завершення пробиття.
        return
    }
    Gui, Kitch:Submit, NoHide
    GoSub, SyncKitchensFromSheet
    GoSub, LoadKitchens
    MsgBox, % 64 + 262144, Кухні, Дані з Google Sheet оновлено., 1
    Gui, Kitch:Destroy
    GoSub, OpenKitchensEditor
return

ResetKitchensOk:
    MsgBox, % 4 + 262144, Кухні, Скинути ВСІ кухні в Стандарт і очистити Стоп-листи?
    IfMsgBox, Yes
    {
        for idx, k in Kitchens {
            Kitchens[idx].Remark   := ""
            Kitchens[idx].Center   := "Стандарт"
            Kitchens[idx].Pickup   := "Стандарт"
            Kitchens[idx].FarZone  := "Стандарт"
            Kitchens[idx].StopList := ""
        }
        GoSub, WriteKitchensFile
        Gui, Kitch:Destroy
        GoSub, OpenKitchensEditor
    }
return

; ========================================================
; РЕДАКТОР ПРЕСЕТІВ
; ========================================================
OpenPresetsEditor:
    Gui, Preset:Destroy
    Gui, Preset:+AlwaysOnTop +ToolWindow
    Gui, Preset:Font, s10 bold, Segoe UI
    Gui, Preset:Add, Text, x10 y10 w400 Center, ⚙ РЕДАКТОР ПРЕСЕТІВ
    Gui, Preset:Font, s8 norm cGray, Segoe UI
    Gui, Preset:Add, Text, x10 y+5 w400 Center, Кожен пресет — з нового рядка. Порядок рядків = порядок у списку.
    Gui, Preset:Font, s9 norm cBlack, Segoe UI

    ; Завантажуємо поточний файл
    presetFileText := ""
    if FileExist(PresetsPath) {
        loop, read, %PresetsPath%
        {
            presetFileText .= A_LoopReadLine . "`n"
        }
    }
    presetFileText := RTrim(presetFileText, "`n")

    Gui, Preset:Add, Edit, x10 y50 w400 h350 vPresetEditBox, %presetFileText%
    Gui, Preset:Font, s10 bold, Segoe UI
    Gui, Preset:Add, Button, x10 y+10 w190 h32 gSavePresets,        💾 Зберегти
    Gui, Preset:Add, Button, x210 y+0 w200 h32 gPresetClose,        ✖ Закрити
    Gui, Preset:Show, w420, Пресети — редагування
    WinActivate, Пресети — редагування
return

SavePresets:
    Gui, Preset:Submit, NoHide
    ; Очищаємо і записуємо рядки
    f := FileOpen(PresetsPath, "w", "UTF-8")
    if (!f) {
        MsgBox, 16, Помилка, Не вдалося зберегти файл пресетів!
        return
    }
    Loop, Parse, PresetEditBox, `n, `r
    {
        line := Trim(A_LoopField)
        if (line != "")
            f.WriteLine(line)
    }
    f.Close()
    MsgBox, % 64 + 262144, Пресети, Збережено!`nЗміни застосуються при наступному відкритті меню кухонь., 2
    Gui, Preset:Destroy
return

PresetClose:
    Gui, Preset:Destroy
return

RcBuildKitchOpts(val, presets) {
    ; Перевіряємо чи є значення в списку пресетів
    hasMatch := 0
    Loop, Parse, presets, |
    {
        if (A_LoopField == val)
            hasMatch := 1
    }

    ; Будуємо рядок для ComboBox
    ; Правило: після вибраного елемента НЕ додаємо роздільник |,
    ; бо || вже містить "кінець елемента + маркер вибору"
    ; Результат: "A|B||C|D" де B — вибраний
    out := ""
    justSelected := 0

    ; Якщо значення не в пресетах — додаємо його на початок як вибране
    if (val != "" && !hasMatch) {
        out := val . "||"
        justSelected := 1
    }

    Loop, Parse, presets, |
    {
        if (justSelected) {
            ; не додаємо "|" перед наступним елементом після ||
            out .= A_LoopField
            justSelected := 0
        } else {
            if (out != "")
                out .= "|"
            out .= A_LoopField
        }
        if (A_LoopField == val) {
            out .= "||"
            justSelected := 1
        }
    }
    return out
}

WriteKitchensFile:
    out := "; ===========================================================`n"
    out .= "; База кухонь Rollclub`n"
    out .= "; Status: ok | slow | nonstandard | stopped`n"
    out .= "; Редагування — кнопка 🏪 у пульті або вручну тут`n"
    out .= "; ===========================================================`n`n"
    for idx, k in Kitchens {
        out .= "[" . k.Name . "]`n"
        out .= "City=" . k.City . "`n"
        out .= "Address=" . k.Address . "`n"
        if (k.KmlKey != "")
            out .= "KmlKey=" . k.KmlKey . "`n"
        out .= "Remark=" . k.Remark . "`n"
        out .= "Center=" . k.Center . "`n"
        out .= "Pickup=" . k.Pickup . "`n"
        out .= "FarZone=" . k.FarZone . "`n"
        out .= "StopList=" . k.StopList . "`n`n"
    }
    ; записуємо через FileObject у UTF-8 з BOM
    FileDelete, %KitchensPath%
    f := FileOpen(KitchensPath, "w", "UTF-8")
    if (f) {
        f.Write(out)
        f.Close()
    }
return

KitchClose:
KitchGuiClose:
KitchGuiEscape:
    Gui, Kitch:Destroy
    Gui, Roll:Show
    GoSub, RhRepaintRollPult
return

; ========================================================
; РОЗРАХУНОК ЧАСУ
; ========================================================
CalcPickup:
    CalcType := RcGetEffectiveTime(RcCurrentKitchen.Name, "", true, cRaw, fRaw, minFar)
    GoSub, ProcessTimeCalc
return
CalcDelivery:
    mappedZone := RcKitchenFromKmlZone(RcLastZone)
    zType := "STANDARD"
    if (IsObject(mappedZone))
        zType := mappedZone.Type
    CalcType := RcGetEffectiveTime(RcCurrentKitchen.Name, zType, false, cRaw, fRaw, minFar)
    GoSub, ProcessTimeCalc
return
ProcessTimeCalc:
    if (CalcType == "стоп")
        return
    total := A_Hour*60 + A_Min + CalcType
    HFinishOrder:
    GoSub, KcStopDuty          ; ручний фініш (Ctrl+Enter) → дежурство стоп
    FileAppend, % "[" . A_Now . "] FINISH UIA/Coord attempt`n", %A_ScriptDir%\ahk_debug.log
    
    ; 1. Нативный UIA-клик Подтвердить (или fallback по координатам)
    if (!RcClickConfirm()) {
        if (confirmX != 0)
            Click, %confirmX%, %confirmY%
    }
    Sleep, 400
    
    ; 2. Нативный UIA-клик Сохранить на точку (или fallback по координатам)
    if (!RcClickSaveAndClose()) {
        if (saveX != 0)
            Click, %saveX%, %saveY%
    }
    Sleep, 400
    kcPaused := 0
    ToolTip, Confirmed + saved (UIA).
    SetTimer, RemoveFinishTip, -2000
return

; ========================================================
; ПРОБИТТЯ ТІЛЬКИ ПАЛОЧОК (как гункан, но с количеством)
; ========================================================
AddSticksOnly:
    Gui, Roll:Hide
    Sleep, 200

    ; Используем ту же логику, что и для купонов/гунканов
    if (parsedSticksNorm != "" && parsedSticksNorm > 0) {
        Click, %itemX%, %itemY%
        Sleep, 400
        Send, {PgDn}
        Sleep, 300
        Send, {Enter}
        Sleep, 400
        SendInput, %pluSticksNorm%
        Sleep, 300
        Send, {Down}
        Sleep, 200

        Loop, 3 {
            Send, {Enter}
            Sleep, 300
            Send, ^a{BackSpace}
            Sleep, 50
            SendInput, %parsedSticksNorm%
            Sleep, 150

            Clipboard := ""
            Send, ^a
            Sleep, 50
            Send, ^c
            ClipWait, 0.5
            if (Clipboard != "" && InStr(Clipboard, parsedSticksNorm)) {
                Send, {Enter}
                Sleep, 400
                break
            }
        }
    }

    if (parsedSticksEdu != "" && parsedSticksEdu > 0) {
        Click, %itemX%, %itemY%
        Sleep, 400
        Send, {PgDn}
        Sleep, 300
        Send, {Enter}
        Sleep, 400
        SendInput, %pluSticksEdu%
        Sleep, 300
        Send, {Down}
        Sleep, 200

        Loop, 3 {
            Send, {Enter}
            Sleep, 300
            Send, ^a{BackSpace}
            Sleep, 50
            SendInput, %parsedSticksEdu%
            Sleep, 150

            Clipboard := ""
            Send, ^a
            Sleep, 50
            Send, ^c
            ClipWait, 0.5
            if (Clipboard != "" && InStr(Clipboard, parsedSticksEdu)) {
                Send, {Enter}
                Sleep, 400
                break
            }
        }
    }

    Gui, Roll:Show
    GoSub, RhRepaintRollPult
return

; ========================================================
; СИВ — ВІКНО
; ========================================================
AddSivVisual:
    Gui, Roll:Hide
    Sleep, 200

    Gui, SivVis:Destroy
    Gui, SivVis:+AlwaysOnTop -MinimizeBox -MaximizeBox +ToolWindow
    Gui, SivVis:Font, s10 bold c0055AA, Segoe UI
    Gui, SivVis:Add, Text, x10 y10 w260, 📌 ПАЛОЧКИ (соуси автоматично)
    Gui, SivVis:Font, s10 norm cBlack, Segoe UI
    Gui, SivVis:Add, Text,  x10  y42  w250 h20 Center, ІНФО: соуси пробиваються автоматично
    Gui, SivVis:Add, Text,  x10  y75  w180, 🥢 БАМБУКОВІ палички:
    Gui, SivVis:Add, Edit,  x190 y73  w70  vVisNorm Number Center, %parsedSticksNorm%
    Gui, SivVis:Add, Text,  x10  y105 w180, 🥢 НАВЧАЛЬНІ палички:
    Gui, SivVis:Add, Edit,  x190 y103 w70  vVisEdu Number Center, %parsedSticksEdu%
    Gui, SivVis:Font, s10 bold, Segoe UI
    Gui, SivVis:Add, Button, x10  y145 w120 h30 Default gSivVisApply, ✔️ Пробити (Enter)
    Gui, SivVis:Font, s10 norm, Segoe UI
    Gui, SivVis:Add, Button, x140 y145 w120 h30 gSivVisCancel, ❌ Відміна
    Gui, SivVis:Show, x400 y200, СИВ (Модуль)
    MouseMove, 550, 240, 0
return

SivVisCancel:
SivVisGuiClose:
SivVisGuiEscape:
    Gui, SivVis:Destroy
    Gui, Roll:Show
    GoSub, RhRepaintRollPult
return

    ; ========================================================
    ; СИВ — ПРОБИТТЯ
; ========================================================
SivVisApply:
    _opSivToken := OpCoord_Begin("PunchingSiv", "SivVisApply", "source=F1")
    rhPunchBusy := 1
    dutyOn := 0
    kcForce := 0
    kcStop := 1
    SetTimer, KcDutyTick, Off
    SetTimer, KcMonitor, Off
    Gui, SivVis:Submit
    Gui, SivVis:Destroy

    logFile := A_ScriptDir "\siv_debug.log"
    FileAppend, `n[СИРІ ДАНІ З GUI] VisRolls='%VisRolls%' | VisNorm='%VisNorm%' | VisEdu='%VisEdu%'`n, %logFile%

    MouseGetPos, originalMouseX, originalMouseY
    Sleep, 200

    ; Очищення від сміття та примусове перетворення в числа
    VisRolls := RegExReplace(VisRolls, "[^\d]", "")
    VisNorm := RegExReplace(VisNorm, "[^\d]", "")
    VisEdu := RegExReplace(VisEdu, "[^\d]", "")

    VisRolls := (VisRolls == "") ? 0 : VisRolls + 0
    VisNorm := (VisNorm == "") ? 0 : VisNorm + 0
    VisEdu := (VisEdu == "") ? 0 : VisEdu + 0

    ; Соуси (СІВ): рахуємо від кількості ролів (поле «Роли»)
    _soyC := Ceil(VisRolls / 2.0)
    _soyM := (VisRolls < 2) ? VisRolls : 2
    soyQty := (VisRolls > 0) ? ((_soyC > _soyM) ? _soyC : _soyM) : 0
    gwQty  := (VisRolls > 0) ? Ceil(VisRolls / 4.0) : 0

    logFile := A_ScriptDir "\siv_debug.log"
    FileAppend, `n=== ПАЛОЧКИ СТАРТ === %A_Now%`n, %logFile%
    FileAppend, ДАНІ: Бамбукові=%VisNorm% | Навчальні=%VisEdu%`n, %logFile%
    FileAppend, ІНФО: Соуси (соєвий, імбир, васабі) пробиваються автоматично!`n, %logFile%

    ; ---- Пробивання: один RcStartPunch, потім серія RcPunchByPlu ----
    FileAppend, % "`n=== СИВ F1 === " . A_Now . " norm=" . VisNorm . " edu=" . VisEdu . " soy=" . soyQty . " gw=" . gwQty . "`n", %A_ScriptDir%\siv_debug.log

    _pluJobs := []
    RcAddPluJob(_pluJobs, pluSticksNorm, VisNorm)
    RcAddPluJob(_pluJobs, pluSticksEdu, VisEdu)
    RcAddPluJob(_pluJobs, pluSoy, soyQty)
    RcAddPluJob(_pluJobs, pluGinger, gwQty)
    RcAddPluJob(_pluJobs, pluWasabi, gwQty)
    RcPunchPluSeries(_pluJobs)

    MouseMove, %originalMouseX%, %originalMouseY%, 0
    Gui, Roll:Show
    GoSub, RhRepaintRollPult
    rhPunchBusy := 0
    OpCoord_End(_opSivToken, "ok", "rolls=" . VisRolls . ";norm=" . VisNorm . ";edu=" . VisEdu)
return

; --------------------------------------------------------
; Збереження модифікаторів
SivSave:
    Loop, 100 {
        ImageSearch, savX, savY, 0, 0, A_ScreenWidth, A_ScreenHeight, *70 img\btn_save.png
        if (ErrorLevel == 0) {
            sClkX := savX + 10
            sClkY := savY + 5
            Click, %sClkX%, %sClkY%
            Sleep, 300
            return
        }
        Sleep, 10
    }
    MsgBox, 48, СИВ, Не знайшов кнопку Зберегти!
return

; ========================================================
; ФІНАЛЬНЕ ВНЕСЕННЯ
; ========================================================
ApplyRollclub:
    _opEnterToken := OpCoord_Begin("EditingOrder", "ApplyRollclub", "inDutyTake=" . _inDutyTake)
    rhPunchBusy := 1
    dutyOn := 0
    kcForce := 0
    kcStop := 1
    SetTimer, KcDutyTick, Off
    SetTimer, KcMonitor, Off
    FileAppend, % "[" . A_Now . "] APPLY_LOCK on`n", %A_ScriptDir%\parse_debug.log
    GoSub, KcStopDuty          ; ручне пробиття (Enter) → дежурство стоп + вікно "оператор працює"
    SetTimer, RcCheckZone, Off   ; скасувати старий таймер (якщо був)
    Gui, Roll:Submit, NoHide
    Gui, Roll:Destroy
    ; Звірка точки — синхронно, ДО решти кліків (тільки доставка, тільки якщо увімкнено)
    if (!hasPickup && CHECK_POINT_ENABLED && naitiX != 0 && tochkaX != 0)
        GoSub, RcCheckZone

    ; ==== DEBUG: лог запису ====
    FormatTime, _wT,, yyyy-MM-dd HH:mm:ss
    _w := "==== WRITE " . _wT . " | No=" . kcLastNo . " hasPickup=" . hasPickup . " ===="
    _w .= "`n comm : x=" . commX . " txt=[" . OrderComment . "]"
    _w .= "`n info : x=" . infoX . " txt=[" . ClientInfo . "]"
    _w .= "`n addr : x=" . addrX . " txt=[" . AddressNote . "]"
    _w .= "`n time : x=" . timeX . " h=" . ReadyTimeH . " m=" . ReadyTimeM
    _w .= "`n cash : do=" . autoCash . " crossX=" . crossX . " cashX=" . cashX
    _w .= "`n card : x=" . cardX . " txt=[" . ClientCard . "]"
    _w .= "`n"
    FileAppend, %_w%`n, %A_ScriptDir%\parse_debug.log, UTF-8

    MouseGetPos, originalMouseX, originalMouseY
    Sleep, 400

    if (OrderComment != "" && commX != 0) {
        Clipboard := OrderComment
        Click, %commX%, %commY%
        Sleep, 200
        Send, ^a{BackSpace}
        Sleep, 50
        Send, ^v
        Sleep, 300
    }

    if (ClientCard != "" && cardX != 0) {
        Clipboard := ClientCard
        Click, %cardX%, %cardY%
        Sleep, 250
        Send, ^a{BackSpace}
        Sleep, 50
        Send, ^v{Enter}
        Sleep, 400
    }

    if (ClientInfo != "" && infoX != 0) {
        Clipboard := ClientInfo
        Sleep, 150
        Click, %infoX% %infoY% 2     ; подвійний клік -> режим редагування комірки коментаря страви
        Sleep, 200
        Send, ^a{BackSpace}
        Sleep, 60
        Send, ^v
        Sleep, 150
        Send, {Enter}                ; підтвердити комірку
        Sleep, 200
    }

    ; При самовивозі поле "Примечание к адресу" в iiko заблоковане — НЕ пишемо туди.
    if (AddressNote != "" && addrX != 0 && !hasPickup) {
        Clipboard := AddressNote
        Click, %addrX%, %addrY%
        Sleep, 200
        Send, ^a{BackSpace}^v
        Sleep, 300
    }

    if (ReadyTimeH != "" && ReadyTimeM != "" && timeX != 0) {
        Sleep, 300
        Click, %timeX%, %timeY%
        Sleep, 200
        SendInput, ^a{BackSpace}%ReadyTimeH%{Right}%ReadyTimeM%{Enter}
        Sleep, 200
    }

    if (autoCash == 1 && crossX != 0 && cashX != 0) {
        Sleep, 400
        Click, %crossX%, %crossY%
        Sleep, 400
        IikoUI_NoChange()
        Sleep, 400
        SetKeyDelay, 40
        Send, Готівка
        Sleep, 300
        Send, {PgDn}
        Sleep, 300
        Send, {Enter}
        Sleep, 600
        Send, {Tab 2}
        Sleep, 300
        Send, %calcChange%
        Sleep, 300
        Send, {Enter}
        SetKeyDelay, -1
        Sleep, 500
    }

    if (RC_GIFTS_ENABLED && (autoGunkan || autoPepsi || autoBurger || autoSandwich) && itemX != 0) {
        if (autoBurger) {
            GoSub, NewGiftMacro
            SendInput, %pluBurger%
            matched := 0
            iikoPointClean := Trim(iikoPoint)
            global RcCurrentZoneMapped, RcCurrentKitchen, RcCurrentDeliveryType, lastZoneName
            
            if (RcZonesOk && RcZones.MaxIndex() > 0) {
                if (RcCurrentZoneMapped && RcCurrentKitchen) {
                    matched := (RcKitchenFromIikoPoint(iikoPointClean) == RcCurrentKitchen.Name)
                    FileAppend, % "[" A_Now "] ZONE_MAP: zone=""" lastZoneName """ kitchen=""" RcCurrentKitchen.Name """ type=""" RcCurrentDeliveryType """ iikoPoint=""" iikoPointClean """ match=" (matched ? "true" : "false") "`n", %A_ScriptDir%\siv_debug.log
                } else {
                    for j, _ in RcZones {
                        if (InStr(iikoPointClean, RcZones[j].ZoneName))
                            matched := 1
                        if (InStr(RcZones[j].ZoneName, iikoPointClean))
                            matched := 1
                        if (matched)
                            break
                    }
                }
            }  
            GoSub, FinishGiftMacro
        } else if (autoSandwich) {
            GoSub, NewGiftMacro
            SendInput, %pluSandwich%
            GoSub, FinishGiftMacro
        } else if (autoPepsi) {
            GoSub, NewGiftMacro
            SendInput, %pluPepsi%
            GoSub, FinishGiftMacro
        }
        if (autoGunkan) {
            GoSub, NewGiftMacro
            SendInput, %pluGunkan%
            GoSub, FinishGiftMacro
        }
    }

    ; Пробиваємо СИВ (Палички та соуси)
    VisRolls := (VisRolls = "") ? 0 : RegExReplace(VisRolls, "[^\d]", "") + 0
    VisNorm := (VisNorm = "") ? 0 : RegExReplace(VisNorm, "[^\d]", "") + 0
    VisEdu := (VisEdu = "") ? 0 : RegExReplace(VisEdu, "[^\d]", "") + 0
    VisUtensils := (VisUtensils = "") ? 0 : RegExReplace(VisUtensils, "[^\d]", "") + 0

    if (VisNorm > 0 || VisEdu > 0 || VisUtensils > 0) {
        ; Розраховуємо соуси як у Roll House
        _soyQty := Floor((VisRolls + 1) / 2)
        _gwQty  := Floor((VisRolls + 3) / 4)
        if (VisRolls == 0) {
            _soyQty := 0
            _gwQty  := 0
        }
        ; Обмежуємо кількість соусів сумою паличок
        _totalSt := VisNorm + VisEdu
        if (_totalSt > 0) {
            _soyQty := (_soyQty > _totalSt) ? _totalSt : _soyQty
            _gwQty  := (_gwQty  > _totalSt) ? _totalSt : _gwQty
        }
        _rcLog := A_ScriptDir "\siv_debug.log"
        FileAppend, % "[" . A_Now . "] SIV_SERIES_START itemX=" . itemX . " norm=" . VisNorm . " edu=" . VisEdu . " utensils=" . VisUtensils . "`n", %_rcLog%
        _pluJobs := []
        RcAddPluJob(_pluJobs, pluSticksNorm, VisNorm)
        RcAddPluJob(_pluJobs, pluSticksEdu, VisEdu)
        RcAddPluJob(_pluJobs, pluSoy, _soyQty)
        RcAddPluJob(_pluJobs, pluGinger, _gwQty)
        RcAddPluJob(_pluJobs, pluWasabi, _gwQty)
        RcAddPluJob(_pluJobs, pluFork, VisUtensils)
        RcAddPluJob(_pluJobs, pluKnife, VisUtensils)
        RcPunchPluSeries(_pluJobs)
    }

    ; --- Самовивіз: авто Концепція + Точка за точкою з коментаря (1:1) ---
    ; Концепцію беремо з таблиці PickupConcept(), вписуємо її → Tab → Space →
    ; PgUp → Enter (перевірена послідовність: після концепції список точок
    ; фільтрується, PgUp бере потрібну, "Ролл Клаб КЦ" не чіпаємо).
    if (hasPickup && kontsX != 0) {  ; завжди ставимо точку для самовивозу (незалежно від autoMode)
        pickKonts := PickupConcept(pickupPoint)
        if (pickKonts != "") {
            Sleep, 400
            Click, %kontsX%, %kontsY%        ; поле "Концепція"
            Sleep, 300
            SetKeyDelay, 40
            Send, ^a{BackSpace}
            Sleep, 80
            Send, %pickKonts%                ; вписуємо назву концепції
            Sleep, 350
            Send, {Tab}                      ; підтвердити концепцію + перейти на "Точка"
            Sleep, 250
            Send, {Space}                    ; відкрити список точок
            Sleep, 250
            Send, {PgUp}                      ; вгору списку = потрібна точка під цю концепцію
            Sleep, 250
            Send, {Enter}                    ; підтвердити точку
            SetKeyDelay, -1
            SetTimer, RcPickupVerifyPoint, -100
        }
    }

    if (RC_GIFTS_ENABLED && autoMode) {
    ; --- Подарунок: сервер обирає найдорожчий → пробиваємо по PLU (к-сть 1) ---
    Sleep, 500
    giftResp := RhGet("/api/iiko/gift", 15000)
    FileAppend, % "[" . A_Now . "] GIFT resp=" . SubStr(giftResp,1,250) . "`n", %A_ScriptDir%\ahk_debug.log
    giftPlu := ""
    if RegExMatch(giftResp, "gift_plu\x22\s*:\s*\x22(\d+)", gM)
        giftPlu := gM1
    if (giftPlu != "" && itemX != 0)
        PunchGiftPlu(giftPlu)

    ; --- Пакет: якщо в підказках "Потрібно додати ПАКЕТ" → пробити (02901) ---
    if (itemX != 0 && RegExMatch(giftResp, "package\x22\s*:\s*true"))
        PunchGiftPlu("02901")
    }

    MouseMove, %originalMouseX%, %originalMouseY%, 0
    rhPunchBusy := 0
    FileAppend, % "[" . A_Now . "] APPLY_LOCK off`n", %A_ScriptDir%\parse_debug.log
    OpCoord_End(_opEnterToken, "ok", "apply_complete")
return

; ── ФІНІШ: Подтвердить → Зберегти на точку (Ctrl+Enter). Окремо, безпечно. ──
FinishOrder:
    _opFinishToken := OpCoord_Begin("FinishingOrder", "FinishOrder", "hotkey=Ctrl+Enter")
    GoSub, KcStopDuty          ; ручний фініш (Ctrl+Enter) → дежурство стоп
    FileAppend, % "[" . A_Now . "] FINISH via IikoUI Driver`n", %A_ScriptDir%\ahk_debug.log
    
    ; 1. Подтвердить (UIA + fallback)
    IikoUI_ConfirmDelivery()
    Sleep, 400
    
    ; 2. Сохранить на точку (UIA + fallback)
    IikoUI_SaveAndClose()
    Sleep, 400
    
    kcPaused := 0
    ToolTip, Confirmed + saved (IikoUI Driver).
    SetTimer, RemoveFinishTip, -2000
    OpCoord_End(_opFinishToken, "ok", "finish_complete")
return

RemoveFinishTip:
    ToolTip
return

; ── Пробити подарунок по PLU (кількість 1, ціна 0) ──
PunchGiftPlu(plu) {
    global itemX, itemY
    Click, %itemX%, %itemY%
    Sleep, 400
    Send, {PgDn}
    Sleep, 300
    Send, {Enter}
    Sleep, 400
    SendInput, %plu%
    Sleep, 400
    Send, {Down}
    Sleep, 250
    Send, {Enter}
    Sleep, 500
}

; ── Концепція самовивозу за точкою з коментаря (1:1). Точку обираємо тією ж назвою. ──
; Підправляти тут, якщо для якоїсь точки назва Точки в iiko ≠ назві Концепції.
PickupConcept(pt) {
    ; ── КИЇВ ──
    if (InStr(pt, "Драгоманова"))
        return "Київ Драгоманова"
    if (InStr(pt, "Антонова") || InStr(pt, "Солом'янськ"))
        return "Київ Антонова"
    if (InStr(pt, "Стрільців") || InStr(pt, "Лук'янівка"))
        return "Київ Стрільців"
    if (InStr(pt, "Лаврухіна"))
        return "Київ Лаврухіна"
    ; ── ХАРКІВ ──
    if (InStr(pt, "Конституції"))
        return "РК Харків Конституції Доставка"
    if (InStr(pt, "Садовий"))
        return "Харків Нові Дома"
    ; ── ЛЬВІВ ──
    if (InStr(pt, "Липа"))
        return "Львов Липа"
    ; ── ДНІПРО ──
    if (InStr(pt, "Мудрого") || InStr(pt, "Авіаторськ"))
        return "Дніпро Мудрого"
    ; ── БІЛА ЦЕРКВА ──
    if (InStr(pt, "Вернадського") || InStr(pt, "Біла Церква"))
        return "Біла Церква"
    ; ── ОДЕСА ──
    if (InStr(pt, "Незалежності") || InStr(pt, "Приморська") || InStr(pt, "Котовського") || InStr(pt, "Пересипськ"))
        return "Приморська"
    ; ── ІВАНО-ФРАНКІВСЬК ──
    if (InStr(pt, "Фудотека") || InStr(pt, "Промприлад") || InStr(pt, "Перемоги") || InStr(pt, "Франківськ") || InStr(pt, "ІФ"))
        return "Франківськ Фудотека"
    ; ── РІВНЕ ──
    if (InStr(pt, "Кулика") || InStr(pt, "Екватор"))
        return "Рівне"
    ; ── ВІННИЦЯ ──
    if (InStr(pt, "600") || InStr(pt, "Мегамолл") || InStr(pt, "Вінниц") || InStr(pt, "Винниц"))
        return "Вінниця"
    return ""
}

NewGiftMacro:
    Click, %itemX%, %itemY%
    Sleep, 400
    Send, {PgDn}
    Sleep, 300
    Send, {Enter}
    Sleep, 400
return

FinishGiftMacro:
    Sleep, 400
    Send, {Down}
    Sleep, 300
    Send, {Enter}
    Sleep, 500
return

RcAddPluJob(ByRef jobs, pluCode, qty) {
    if (qty <= 0 || pluCode = "" || pluCode = "0000")
        return
    jobs.Push({plu: pluCode, qty: qty})
}

RcUiaFind(role, defaultAid := "") {
    global UIA_MAP_CONFIG
    IniRead, mappedAid, %UIA_MAP_CONFIG%, UiaMap, %role%, %A_Space%
    aid := (mappedAid != "" && mappedAid != "ERROR") ? mappedAid : (defaultAid != "" ? defaultAid : role)
    if (aid = "")
        return ""
    iikoWin := IikoDriver_GetWindow()
    if (!iikoWin)
        return ""
    if (SubStr(aid, 1, 5) = "Name=") {
        try return iikoWin.FindFirstBy("Name=" . SubStr(aid, 6))
        catch e0
            return ""
    }
    try el := iikoWin.FindFirstBy("AutomationId=" . aid)
    catch e1
        el := ""
    if (IsObject(el))
        return el
    return IikoDriver_FindElement(aid)
}

RcClickFirstOrderRowUIA() {
    root := RcUiaFind("Табл. Страв", "treeListItems")
    try rootAid := root.CurrentAutomationId
    catch e0
        rootAid := ""
    if (!IsObject(root) || rootAid != "treeListItems")
        root := IikoDriver_FindElement("treeListItems")
    if (!IsObject(root))
        return 0

    try best := root.FindFirstBy("Name=Блюдо row 1")
    catch e1
        best := ""
    if (!IsObject(best)) {
        try children := root.FindAllBy("TrueCondition")
        catch e2
            children := ""
        if (IsObject(children)) {
            bestRow := 999999
            Loop, % children.MaxIndex() {
                el := children[A_Index]
                try name := el.CurrentName
                catch e3
                    name := ""
                if (RegExMatch(name, "^Блюдо row (\d+)$", rowMatch) && rowMatch1 > 0 && rowMatch1 < bestRow) {
                    best := el
                    bestRow := rowMatch1
                }
            }
        }
    }

    try {
        if (IsObject(best))
            best.Click()
        else
            root.Click()
        Sleep, 180
        return 1
    } catch e4 {
        return 0
    }
}

RcFocusOrderItems() {
    global itemX, itemY, rcLogPath
    MouseGetPos, _mx, _my
    if (RcClickFirstOrderRowUIA()) {
        MouseMove, %_mx%, %_my%, 0
        FileAppend, % "[" . A_Now . "] ITEMS_FOCUS uia=1`n", %rcLogPath%
        return 1
    }
    if (itemX = 0 || itemX = "ERROR") {
        FileAppend, % "[" . A_Now . "] ITEMS_FOCUS fail no_item_target`n", %rcLogPath%
        return 0
    }
    Click, %itemX%, %itemY%
    Sleep, 180
    MouseMove, %_mx%, %_my%, 0
    FileAppend, % "[" . A_Now . "] ITEMS_FOCUS fallback=coord itemX=" . itemX . "`n", %rcLogPath%
    return 1
}

RcPunchPluSeries(jobs) {
    global rcLogPath
    if (!IsObject(jobs) || jobs.MaxIndex() = "")
        return 1
    if (!RcFocusOrderItems()) {
        ToolTip, Не вдалося відкрити таблицю страв. СІВ зупинено.
        SetTimer, RcClearOkTip, -2000
        return 0
    }

    Sleep, 300
    Send, {PgDn}
    Sleep, 300
    Send, {Enter}
    Sleep, 400

    Loop, % jobs.MaxIndex() {
        job := jobs[A_Index]
        if (A_Index > 1) {
            Send, {Enter}
            Sleep, 350
        }
        RcPunchPluInOpenEditor(job.plu, job.qty)
        FileAppend, % "[" . A_Now . "] PUNCH_SERIES_JOB plu=" . job.plu . " qty=" . job.qty . "`n", %rcLogPath%
    }
    return 1
}

RcPunchPluInOpenEditor(pluCode, qty) {
    global itemX, itemY, rcLogPath, rhPunchBusy, dutyOn, kcForce, kcStop
    rhPunchBusy := 1
    dutyOn := 0
    kcForce := 0
    kcStop := 1
    SetTimer, KcDutyTick, Off
    SetTimer, KcMonitor, Off
    FileAppend, % "[" . A_Now . "] PUNCH_CALL plu=" . pluCode . " qty=" . qty . "`n", %rcLogPath%
    if (qty <= 0 || pluCode = "" || pluCode = "0000") {
        FileAppend, % "[" . A_Now . "] SKIP bad`n", %rcLogPath%
        return 1
    }

    ; PLU → вниз (автокомплет) → Enter → перехід на qty
    SendInput, %pluCode%
    Sleep, 400
    Send, {Down}
    Sleep, 300
    Send, {Enter}
    Sleep, 400

    ; qty вводимо одразу — DevExpress виділяє поле при вході, заміна відбувається автоматично
    SendInput, %qty%
    Sleep, 200

    ; Верифікація: ^a → ^c — читаємо що реально в полі qty
    Send, ^a
    Sleep, 50
    Clipboard := ""
    Send, ^c
    ClipWait, 1.0
    ; iiko показує qty як "4,000" (кома = десятковий роздільник) — беремо тільки цілу частину
    _got := RegExReplace(Clipboard, ",.*$", "")   ; відрізаємо ",000"
    _got := RegExReplace(_got, "[^\d]", "")        ; лишаємо тільки цифри
    FileAppend, % "[" . A_Now . "] VERIFY exp=" . qty . " got=[" . _got . "] raw=[" . Clipboard . "]`n", %rcLogPath%

    if (_got + 0 = qty + 0) {
        SoundPlay, %A_ScriptDir%\beep_ok.wav
        ToolTip, % "✓ OK  PLU:" . pluCode . "  x" . _got, 600, 400, 2
        Send, {Enter}                 ; коміт рядку
        Sleep, 400
        SetTimer, RcClearOkTip, -1200
    } else {
        ToolTip, % "❌ ERR  PLU:" . pluCode . "  exp:" . qty . "  got:" . _got, 600, 400, 2
        Send, {Escape}
        Sleep, 150
        SoundPlay, %A_ScriptDir%\beep_err.wav
        Sleep, 550
        SoundPlay, %A_ScriptDir%\beep_err.wav
        Sleep, 550
        SoundPlay, %A_ScriptDir%\beep_err.wav
        SetTimer, RcClearOkTip, -2500
    }
    return 1
}

; Backward-compatible wrapper for older call sites.
RcPunchByPlu(pluCode, qty) {
    jobs := []
    RcAddPluJob(jobs, pluCode, qty)
    return RcPunchPluSeries(jobs)
}

RcClearOkTip:
    ToolTip, , , , 2
return

CloseSummaAlert:
    if WinExist("Сумма заказа") {
        WinActivate, Сумма заказа
        Sleep, 100
        Send, {Enter}
    }
return

; ========================================================
; ЗАКРИТТЯ ВІКОН
; ========================================================
RollGuiClose:
    Gui, Roll:Destroy
return
RollGuiEscape:
    Gui, Roll:Hide
return

; ── RollHelper: перемкнути бренд назад на Roll House ──
SwitchToRollHouse:
    IniWrite, rollhouse, %A_ScriptDir%\settings.ini, App, Brand
    Run, "%A_AhkPath%" "%A_ScriptDir%\main.ahk"
    ExitApp
return

; ── Птичка в пульті: вибір Roll House → запуск його движка ──
BrandChangeRC:
    GuiControlGet, _bs, Roll:, BrandSel
    if (_bs = 1) {
        IniWrite, rollhouse, %A_ScriptDir%\settings.ini, App, Brand
        Run, "%A_AhkPath%" "%A_ScriptDir%\main.ahk"
        ExitApp
    }
return

RestartRhServer:
    global RH_SERVER_OK

    RH_SERVER_OK := 0
    if WinExist("Rollclub PRO 33.0 ahk_class AutoHotkeyGUI")
        GuiControl, Roll:, RhServerPill, RESTART
    TrayTip, RollClub PRO, 🔄 Перезапускаю сервер iiko-моста..., 2, 1

    RcLaunchServerProcess(1)
    Loop, 20 {
        Sleep, 500
        if (RhPing())
            break
    }

    if (RH_SERVER_OK) {
        if WinExist("Rollclub PRO 33.0 ahk_class AutoHotkeyGUI")
            GuiControl, Roll:, RhServerPill, ONLINE
        TrayTip, RollClub PRO, 🟢 Сервер перезапущено, 2, 1
    } else {
        if WinExist("Rollclub PRO 33.0 ahk_class AutoHotkeyGUI")
            GuiControl, Roll:, RhServerPill, OFFLINE
        TrayTip, RollClub PRO, ⚠️ Сервер не відповідає після рестарту, 4, 2
    }
return



; ═══════════════════════════════════════════════════════════
; ЗОНА НА КАРТІ — авто-визначення по адресі замовлення
; ═══════════════════════════════════════════════════════════

; ── Завантаження KML через діалог вибору файлу ──
; ── Завантаження KML через діалог вибору файлу ──
RcLoadKmlFile:
    global RcZonesOk
    FileSelectFile, _kmlSrc, 3, , Оберіть KML-файл зон доставки, KML-файл (*.kml)
    if (_kmlSrc = "")
        return
    _kmlDst := A_ScriptDir "\brands\rollclub\zones.kml"
    FileCopy, %_kmlSrc%, %_kmlDst%, 1
    if (ErrorLevel) {
        MsgBox, 16, Помилка, Не вдалося скопіювати файл.
        return
    }
    RcZonesOk := 0
    RcLoadKml(_kmlDst)
    if (RcZonesOk) {
        _cnt := RcZones.MaxIndex()
        MsgBox, 64, KML завантажено, Завантажено зон: %_cnt%, 2
    } else {
        MsgBox, 16, Помилка KML, Файл скопійовано, але зон не знайдено.`nПеревір формат файлу.
    }
return

; ── Таймер: запускається після показу вікна, оновлює MapSearch ──
RcCheckZone:
    global rawAddress, hasPickup, RcZones, RcZonesOk, detectedCity, RcCurrentKitchen, extractedTimeAuto
    SetTimer, RcCheckZone, Off
    addr := Trim(rawAddress)
    if (addr = "" || hasPickup) {
        GuiControl, Roll:, KitchenStatusText,
        return
    }
    addr := RegExReplace(addr, "i)[,\s]+(эт|поверх|кв|квартира|под|під|п|к|парадна)\.?\s*\d+.*$", "")
    addr := RegExReplace(addr, "i)^(Днепр|Дніпро|Харьков|Харків|Одесса|Одеса|Киев|Київ|Львов|Львів|Винница|Вінниця|Рівне|Ровно)[,\s]+", "")
    addr := RegExReplace(addr, "\s*\(.*?\)\s*", " ")
    addr := RegExReplace(addr, "i)Тополь[\-\s]*(\d)", "Тополя-$1")
    addr := RegExReplace(addr, "i)Победа[\-\s]*(\d)", "Перемога-$1")
    addr := RegExReplace(addr, "i)Сокол[\-\s]*(\d)", "Сокіл-$1")
    addr := RegExReplace(addr, "i)Красный Камень", "Червоний Камінь")
    addr := RegExReplace(addr, "i)Коммунар", "Покровський")
    addr := Trim(addr)

    ; Show loading state
    GuiControl, Roll:, MapSearch, Шукаємо адресу...
    RhRegColor(hZoneBox, RhB_CardFill, RhB_Text)
    DllCall("InvalidateRect", "Ptr", hZoneBox, "Ptr", 0, "Int", 1)

    if (detectedCity != "") {
        encCity   := RcUriEncode(detectedCity)
        encStreet := RcUriEncode(addr)
        url := "https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&city=" . encCity . "&street=" . encStreet
    } else {
        url := "https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&q=" . RcUriEncode(addr)
    }
    resp := RcHttpGet(url, 6000)
    if (resp = "") {
        GuiControl, Roll:, MapSearch, Мережа недоступна
        return
    }
    if (!RegExMatch(resp, """lat"":""([^""]+)""", mLat) || !RegExMatch(resp, """lon"":""([^""]+)""", mLon)) {
        resp2 := RcHttpGet("https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&q=" . RcUriEncode(addr), 6000)
        if (!RegExMatch(resp2, """lat"":""([^""]+)""", mLat) || !RegExMatch(resp2, """lon"":""([^""]+)""", mLon)) {
            if (InStr(addr, ",")) {
                addrNoHouse := Trim(RegExReplace(addr, ",[^,]+$", ""))
                resp3 := ""
                if (detectedCity != "") {
                    resp3 := RcHttpGet("https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&city=" . RcUriEncode(detectedCity) . "&street=" . RcUriEncode(addrNoHouse), 6000)
                }
                if (resp3 = "" || (!RegExMatch(resp3, """lat"":""([^""]+)""", mLat) || !RegExMatch(resp3, """lon"":""([^""]+)""", mLon)))
                    resp3 := RcHttpGet("https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&q=" . RcUriEncode(addrNoHouse), 6000)
                if (!RegExMatch(resp3, """lat"":""([^""]+)""", mLat) || !RegExMatch(resp3, """lon"":""([^""]+)""", mLon)) {
                    GuiControl, Roll:, MapSearch, Адресу не знайдено
                    return
                }
                resp := resp3
            } else {
                GuiControl, Roll:, MapSearch, Адресу не знайдено
                return
            }
        } else {
            resp := resp2
        }
    }
    lat := mLat1 + 0
    lng := mLon1 + 0
    kmlPath := A_ScriptDir "\brands\rollclub\zones.kml"
    if (!RcZonesOk && FileExist(kmlPath))
        RcLoadKml(kmlPath)
    if (RcZonesOk && RcZones.MaxIndex() > 0) {
        zone := RcFindZone(lng, lat)
        global RcCurrentDeliveryType, RcZoneMap, RcCurrentZoneMapped, lastZoneName
        lastZoneName := zone
        RcCurrentDeliveryType := ""
        RcCurrentZoneMapped := 0
        if (zone != "") {
            kAlertText := ""
            kAlertBeep := 0
            
            if (RcZoneMap.HasKey(zone)) {
                RcCurrentZoneMapped := 1
                RcCurrentDeliveryType := RcZoneMap[zone].Type
                mappedKitchName := RcZoneMap[zone].Kitchen
                for _, k in Kitchens {
                    if (k.Name = mappedKitchName) {
                        RcCurrentKitchen := k
                        break
                    }
                }
            } else {
                for _, k in Kitchens {
                    kSearchTerm := (k.KmlKey != "") ? k.KmlKey : k.Name
                    if (InStr(zone, kSearchTerm)) {
                        RcCurrentKitchen := k
                        break
                    }
                }
            }
            
            if (RcCurrentKitchen) {
                k := RcCurrentKitchen
                parts := ""
                if (k.Center != "Стандарт") {
                    parts .= "Центр: " . k.Center
                    kAlertBeep := 1
                }
                if (k.FarZone != "Стандарт") {
                    if (parts != "") parts .= " / "
                    parts .= "Дальня: " . k.FarZone
                    kAlertBeep := 1
                }
                if (k.Pickup != "Стандарт") {
                    if (parts != "") parts .= " / "
                    parts .= "Самовивіз: " . k.Pickup
                    kAlertBeep := 1
                }
                if (k.StopList != "") {
                    if (parts != "") parts .= "   "
                    parts .= "СТОП: " . k.StopList
                    kAlertBeep := 1
                }
                if (k.Remark != "") {
                    if (parts != "") parts .= "   "
                    parts .= k.Remark
                }
                kAlertText := parts
            }
            if (kAlertBeep)
                SoundBeep, 600, 250
            result := zone
            RcLastZone := zone
            GuiControl, Roll:, MapSearch, %result%
            mappedZone := RcKitchenFromKmlZone(RcLastZone)
            zType := "STANDARD"
            if (IsObject(mappedZone))
                zType := mappedZone.Type
            _deliveryMin := RcGetEffectiveTime(RcCurrentKitchen.Name, zType, false, cRaw, fRaw, minFar)
            GuiControl, Roll:, RhCalcDeliveryBtn, % "ДОСТ +" . _deliveryMin
            if (extractedTimeAuto && !hasPickup)
                RcSetReadyByMinutes(_deliveryMin)
            RhRegColor(hZoneBox, RhB_Green, RhB_White)
            DllCall("InvalidateRect", "Ptr", hZoneBox, "Ptr", 0, "Int", 1)
            GuiControl, Roll:, KitchenStatusText, %kAlertText%
        } else {
            RcLastZone := ""
            result := "Точку не знайдено в зонах доставки"
            GuiControl, Roll:, MapSearch, %result%
            RhRegColor(hZoneBox, RhB_Red, RhB_White)
            DllCall("InvalidateRect", "Ptr", hZoneBox, "Ptr", 0, "Int", 1)
            GuiControl, Roll:, KitchenStatusText,
        }

        ; (звірку точки тепер планує DrawRollclub незалежно від геокодингу)
    } else if (!FileExist(kmlPath)) {
        result := "Завантажте KML-файл зон (Налаштування → KML)"
        GuiControl, Roll:, MapSearch, %result%
        RhRegColor(hZoneBox, RhB_TintAmber, RhB_Text)
        DllCall("InvalidateRect", "Ptr", hZoneBox, "Ptr", 0, "Int", 1)
        GuiControl, Roll:, KitchenStatusText,
    } else if (!RcZonesOk) {
        result := "KML: помилка читання"
        GuiControl, Roll:, MapSearch, %result%
        RhRegColor(hZoneBox, RhB_TintAmber, RhB_Text)
        DllCall("InvalidateRect", "Ptr", hZoneBox, "Ptr", 0, "Int", 1)
        GuiControl, Roll:, KitchenStatusText,
    } else {
        result := lat . ", " . lng
        GuiControl, Roll:, MapSearch, %result%
        RhRegColor(hZoneBox, RhB_CardFill, RhB_Text)
        DllCall("InvalidateRect", "Ptr", hZoneBox, "Ptr", 0, "Int", 1)
        GuiControl, Roll:, KitchenStatusText,
    }
return

; === RcBlockedStreetHit: чи адреса на перекритій вулиці? Повертає "Вулиця — ділянка" або "". ===
RcBlockedStreetHit(addr) {
    blkFile := A_ScriptDir . "\brands\rollclub\BlockedStreets.txt"
    if !FileExist(blkFile)
        return ""
    FileRead, raw, *P65001 %blkFile%
    if (raw = "")
        return ""

    addrLow  := RcBlkNorm(addr)
    cityGate := ""

    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        ; місто-гейт: "# МІСТО: Київ" або "[Київ]"
        if RegExMatch(line, "i)^[#;]\s*(?:МІСТО|MICTO|ГОРОД|CITY)\s*[:=]\s*(.+)$", mCity) {
            cityGate := RcBlkNorm(mCity1)
            continue
        }
        if RegExMatch(line, "^\[(.+)\]$", mSec) {
            cityGate := RcBlkNorm(mSec1)
            continue
        }
        c1 := SubStr(line, 1, 1)
        if (c1 = "#" || c1 = ";")
            continue
        ; якщо задано місто — адреса має його містити
        if (cityGate != "" && !InStr(addrLow, cityGate))
            continue

        ; назва вулиці = частина до "(" ; ділянка = у дужках
        segTxt   := ""
        namePart := line
        if RegExMatch(line, "^(.*?)\((.*)\)\s*$", mSeg) {
            namePart := Trim(mSeg1)
            segTxt   := Trim(mSeg2)
        }
        nameNorm := RcBlkNorm(namePart)
        if (nameNorm = "" || StrLen(nameNorm) < 3)
            continue
        if InStr(addrLow, nameNorm) {
            disp := Trim(RegExReplace(namePart, "i)^\s*(?:вул|просп|пров|бульв|пл|наб)\.?\s+", ""))
            if (segTxt != "")
                disp .= " — " . segTxt
            return disp
        }
    }
    return ""
}

; === RcBlkNorm: нижній регістр, прибрати типи вулиць і не-кирилицю, стиснути пробіли. ===
RcBlkNorm(s) {
    StringLower, s, s
    s := RegExReplace(s, "[^Ѐ-ӿ\s]", " ")            ; лишити тільки кирилицю
    s := " " . Trim(RegExReplace(s, "\s+", " ")) . " "
    types := "проспект|провулок|вулиця|бульвар|набережна|проїзд|узвіз|шосе|алея|площа|просп|пров|бульв|вул"
    Loop, Parse, types, |
        s := RegExReplace(s, "i)(?<=\s)" . A_LoopField . "(?=\s)", " ")
    s := Trim(RegExReplace(s, "\s+", " "))
    return s
}

; === RcCheckZone:
    SetTimer, RcCheckZone, Off
    if (!CHECK_POINT_ENABLED || hasPickup || naitiX = 0 || tochkaX = 0) {
        return
    }
    ToolTip, Звірка доставки: підготовка...
    SoundBeep, 700, 90
    
    _prepRes := RhGet("/api/iiko/diagnose_point_prepare", 10000)
    isOk := false
    if (RegExMatch(_prepRes, """ok""\s*:\s*(true|1)", _mOk))
        isOk := true
    sessionId := ""
    if (RegExMatch(_prepRes, """session_id""\s*:\s*""([^""]+)""", mSession))
        sessionId := Trim(mSession1)
        
    if (iikoWinExe != "" && iikoWinExe != "ERROR")
        WinActivate, ahk_exe %iikoWinExe%
    Sleep, 150
    IikoUI_AssignDeliveryTerminal()
    
    diagSuccess := false
    iikoPoint := ""
    if (isOk && sessionId != "") {
        _diagRes := RhGet("/api/iiko/diagnose_point_collect?session_id=" sessionId, 25000)
        if (RegExMatch(_diagRes, """point""\s*:\s*""([^""]*)""", _mPt)) {
            iikoPoint := Trim(_mPt1)
            diagSuccess := true
        }
    }
    
    if (!diagSuccess) {
        Sleep, 1000
        Loop, 4 {
            if WinExist("Сумма заказа") {
                WinActivate, Сумма заказа
                Sleep, 150
                Send, {Enter}
                Sleep, 300
            } else if WinExist("Внимание") {
                WinActivate, Внимание
                Sleep, 150
                Send, {Enter}
                Sleep, 300
            } else
                break
        }
        Sleep, 600
        Clipboard := ""
        Click, %tochkaX%, %tochkaY%
        Sleep, 250
        Send, {End}
        Sleep, 50
        Send, +{Home}
        Sleep, 50
        Send, ^c
        ClipWait, 0.8
        iikoPoint := Trim(Clipboard)
        Send, {Escape}
    }
    
    mappedZone := RcKitchenFromKmlZone(RcLastZone)
    expectedKey := mappedZone ? mappedZone.Kitchen : ""
    actualKey := RcKitchenFromIikoPoint(iikoPoint)
    
    matched := (expectedKey != "" && expectedKey == actualKey)
    
    logMsg := "DELIVERY_IDENTITY:`nzone=[" RcLastZone "]`nexpected=[" expectedKey "]`npoint=[" iikoPoint "]`nactual=[" actualKey "]`nmatch=" matched "`n`n"
    FileAppend, % logMsg, %A_ScriptDir%\parse_debug.log
    
    if (matched) {
        ToolTip, % "✅ Доставка ОК: " . actualKey
        SoundPlay, %A_ScriptDir%\beep_ok.wav
        SetTimer, RemoveToolTip, -3000
    } else {
        _msg := "⚠ ДОСТАВКА РІЗНИТЬСЯ!`nExpected: " . expectedKey . "`nActual:  " . actualKey
        ToolTip, %_msg%
        SoundPlay, %A_ScriptDir%\beep_err.wav
        Sleep, 550
        SoundPlay, %A_ScriptDir%\beep_err.wav
        SetTimer, RemoveToolTip, -8000
    }
return

RcPickupVerifyPoint:
    SetTimer, RcPickupVerifyPoint, Off
    if (!CHECK_POINT_ENABLED || !hasPickup)
        return
        
    pickKonts := PickupConcept(pickupPoint)
    expectedKey := RcFindKitchenByConcept(pickKonts)
    
    ToolTip, Перевірка самовивозу...
    
    startMs := A_TickCount
    actualKey := ""
    iikoPoint := ""
    
    Loop {
        elapsed := A_TickCount - startMs
        if (elapsed > 2000)
            break
            
        res := RhGet("/api/iiko/read_identity_fast", 1500)
        if (RegExMatch(res, """point""\s*:\s*""([^""]*)""", mPt)) {
            pt := StrReplace(Trim(mPt1), "\u0022", """")
            pt := StrReplace(pt, "\u005C", "\")
            iikoPoint := pt
            actualKey := RcKitchenFromIikoPoint(pt)
            
            if (actualKey == expectedKey && actualKey != "") {
                break
            }
        }
        Sleep, 100
    }
    
    matched := (expectedKey != "" && expectedKey == actualKey)
    elapsedTotal := A_TickCount - startMs
    
    logMsg := "PICKUP_IDENTITY:`npickupPoint=[" pickupPoint "]`nconcept=[" pickKonts "]`nexpected=[" expectedKey "]`npoint=[" iikoPoint "]`nactual=[" actualKey "]`nmatch=" matched "`nwaitMs=" elapsedTotal "`n`n"
    FileAppend, % logMsg, %A_ScriptDir%\parse_debug.log
    
    if (matched) {
        ToolTip, % "✅ Самовивіз ОК: " . actualKey
        SoundPlay, %A_ScriptDir%\beep_ok.wav
        SetTimer, RemoveToolTip, -3000
    } else {
        _msg := "⚠ САМОВИВІЗ РІЗНИТЬСЯ!`nExpected: " . expectedKey . "`nActual:  " . actualKey
        ToolTip, %_msg%
        SoundPlay, %A_ScriptDir%\beep_err.wav
        Sleep, 550
        SoundPlay, %A_ScriptDir%\beep_err.wav
        SetTimer, RemoveToolTip, -8000
    }
return

RemoveToolTip:
    SetTimer, RemoveToolTip, Off
    ToolTip
return

RcHttpGet(url, timeoutMs := 5000) {
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, false)
        whr.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
        whr.SetRequestHeader("User-Agent", "RollHelper/2.0")
        whr.Send()
        return whr.ResponseText
    } catch {
        return ""
    }
}

RcUriEncode(str) {
    VarSetCapacity(buf, StrPut(str, "UTF-8") * 3 + 1)
    StrPut(str, &buf, "UTF-8")
    out := ""
    Loop {
        byte := NumGet(buf, A_Index - 1, "UChar")
        if (!byte)
            break
        ch := Chr(byte)
        out .= RegExMatch(ch, "[A-Za-z0-9\-_.~]") ? ch : Format("%{:02X}", byte)
    }
    return out
}

RcLoadZoneMap() {
    global RcZoneMap
    RcZoneMap := {}
    mapPath := A_ScriptDir "\brands\rollclub\zones_map.ini"
    if (!FileExist(mapPath))
        return
    IniRead, SectionNames, %mapPath%
    Loop, Parse, SectionNames, `n
    {
        sec := Trim(A_LoopField)
        if (sec = "")
            continue
        IniRead, n, %mapPath%, %sec%, Name
        IniRead, k, %mapPath%, %sec%, Kitchen
        IniRead, t, %mapPath%, %sec%, Type
        if (n != "" && n != "ERROR")
            RcZoneMap[n] := {Kitchen: k, Type: t}
    }
}

RcKitchenFromIikoPoint(point) {
    if (point == "" || point == "Ролл Клаб КЦ: Ролл Клаб КЦ")
        return ""
    if InStr(point, "РК Харків Конституції")
        return "РЕСТОРАН"
    if InStr(point, "РК Харків Нові Дома")
        return "НД"
    if InStr(point, "Одеса Приморська")
        return "Приморська"
    if InStr(point, "РК Дніпро Мудрого")
        return "Мудрого"
    if InStr(point, "РК Київ Антонова")
        return "Антонова"
    if InStr(point, "РК Київ Драгоманова")
        return "Драгоманова"
    if InStr(point, "РК Київ Стрільців")
        return "Лук'янівка"
    if InStr(point, "РК Київ Лаврухіна")
        return "Троєщина"
    if InStr(point, "Крива Липа")
        return "Крива Липа"
    if InStr(point, "Біла Церква")
        return "БЦ"
    if InStr(point, "РК Франківськ")
        return "Фудотека"
    if InStr(point, "РК Рівне")
        return "ТРЦ Екватор"
    if InStr(point, "РК Вінниця Мегамолл")
        return "Мегамолл"
    return ""
}

RcLoadKml(kmlPath) {
    global RcZones, RcZonesOk
    RcZones   := []
    RcZonesOk := 0
    xml := ComObjCreate("MSXML2.DOMDocument.6.0")
    xml.async := false
    xml.setProperty("SelectionLanguage", "XPath")
    if (!xml.load(kmlPath))
        return
    placemarks := xml.selectNodes("//*[local-name()='Placemark']")   ; ігнор namespace KML
    Loop % placemarks.length {
        pm := placemarks.item(A_Index - 1)
        nameNode := pm.selectSingleNode(".//*[local-name()='name']")
        zoneName := (nameNode) ? Trim(RegExReplace(nameNode.text, "[\r\n]+", " ")) : ("Зона " A_Index)
        coordNode := pm.selectSingleNode(".//*[local-name()='coordinates']")
        if (!coordNode)
            continue
        coordText := Trim(coordNode.text)
        coords := []
        cTextFixed := RegExReplace(coordText, "[\r\n\t]+", " ")
        Loop, Parse, cTextFixed, %A_Space%
        {
            lf := Trim(A_LoopField)
            if (lf = "")
                continue
            parts := StrSplit(lf, ",")
            if (parts.MaxIndex() >= 2)
                coords.Push([parts[1]+0, parts[2]+0])
        }
        if (coords.MaxIndex() >= 3)
            RcZones.Push({name: zoneName, coords: coords})
    }
    RcZonesOk := (RcZones.MaxIndex() > 0) ? 1 : 0
}

RcInPolygon(lng, lat, coords) {
    inside := 0
    n := coords.MaxIndex()
    j := n
    Loop % n {
        i  := A_Index
        xi := coords[i][1], yi := coords[i][2]
        xj := coords[j][1], yj := coords[j][2]
        if ((yi > lat) != (yj > lat))
            if (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)
                inside := !inside
        j := i
    }
    return inside
}

RcFindZone(lng, lat) {
    global RcZones
    for i, z in RcZones {
        if RcInPolygon(lng, lat, z.coords)
            return z.name
    }
    return ""
}

; ── RollHelper: HTTP до сервера iiko-моста ──
RhKillDuplicateInstances() {
    global RhSingleInstanceMutex

    currentPid := DllCall("GetCurrentProcessId", "UInt")
    thisScript := A_ScriptFullPath
    logPath := A_ScriptDir "\siv_debug.log"

    try wmi := ComObjGet("winmgmts:")
    catch {
        RhSingleInstanceMutex := DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", "Global\RollHelper_RollClub_Engine_AHK_V1", "Ptr")
        if (RhSingleInstanceMutex && A_LastError = 183) {
            TrayTip, RollClub PRO, ⚠️ АНК Roll Club вже запущено. Другу копію не відкриваю., 4, 2
            ExitApp
        }
        return
    }

    for proc in wmi.ExecQuery("Select ProcessId, CommandLine, Name from Win32_Process where Name like 'AutoHotkey%'") {
        pid := proc.ProcessId + 0
        cmd := proc.CommandLine . ""
        if (pid && pid != currentPid && InStr(cmd, thisScript)) {
            FileAppend, %A_Now% DUPLICATE_AHK_CLOSE pid=%pid% cmd=%cmd%`n, %logPath%
            Process, Close, %pid%
        }
    }

    Sleep, 250
    RhSingleInstanceMutex := DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", "Global\RollHelper_RollClub_Engine_AHK_V1", "Ptr")
    if (RhSingleInstanceMutex && A_LastError = 183) {
        TrayTip, RollClub PRO, ⚠️ АНК Roll Club вже запущено. Другу копію не відкриваю., 4, 2
        ExitApp
    }
}

RhGet(endpoint, recvMs := 3000) {
    global RH_SERVER
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", RH_SERVER . endpoint, false)
        whr.SetProxy(1)   ; HTTPREQUEST_PROXYSETTING_DIRECT — мимо будь-якого проксі (лікує залишок mitmproxy)
        whr.SetTimeouts(1500, 1500, recvMs, recvMs)
        whr.Send()
        return whr.ResponseText
    }
    return ""
}

RhPing() {
    global RH_SERVER_OK
    resp := RhGet("/ping", 1200)
    RH_SERVER_OK := (resp != "") ? 1 : 0
    return RH_SERVER_OK
}

OpenWebPult:
    _wpUrl := "http://127.0.0.1:5000/pult?brand=rollclub"
    Run, msedge.exe --app=%_wpUrl% --window-size=384,780, , UseErrorLevel
    if (ErrorLevel)
        Run, %_wpUrl%
return


; ========================================================
; THEME ENGINE
; ========================================================
RhApplyTheme() {
    global uiTheme
    global RhFontName, RhC_BG, RhC_Panel, RhC_Header, RhC_Header2, RhC_HeaderText, RhC_HeaderSub, RhC_Neon, RhC_Text, RhC_Muted, RhC_Subtle, RhC_Soft, RhC_SoftText
    global RhC_Card, RhC_Shadow, RhC_BlueSoft, RhC_TealSoft, RhC_GreenSoft, RhC_OrangeSoft, RhC_RedSoft, RhC_StatusBar
    global RhB_Accent, RhB_Neon, RhB_Apply, RhB_ButtonOff, RhB_Cash, RhB_Card, RhB_Gift, RhB_Siv, RhB_Text, RhB_Muted, RhB_White, RhB_Header, RhB_SettingsGear
    global RhB_Blue, RhB_Teal, RhB_Green, RhB_Orange, RhB_Red, RhB_CardFill, RhB_StatusSoft
    global RhB_Chip, RhB_TintGreen, RhB_TintAmber, RhB_TintRed, RhB_GiftGunkan, RhB_GiftPepsi, RhB_GiftBurger, RhB_GiftSandwich

    RhFontName := "Segoe UI"

    if (uiTheme = "dark") {
        RhC_BG := "070B14"
        RhC_Panel := "111827"
        RhC_Header := "09111F"
        RhC_Header2 := "102A38"
        RhC_HeaderText := "EAF2FF"
        RhC_HeaderSub := "7DD3FC"
        RhC_Neon := "22D3EE"
        RhC_Text := "EAF2FF"
        RhC_Muted := "A7B0C2"
        RhC_Subtle := "060A12"
        RhC_Soft := "102A38"
        RhC_SoftText := "7DD3FC"
        RhC_Card := "111827"
        RhC_Shadow := "050814"
        RhC_BlueSoft := "0B1B35"
        RhC_TealSoft := "07313A"
        RhC_GreenSoft := "092B22"
        RhC_OrangeSoft := "3A2107"
        RhC_RedSoft := "3A1010"
        RhC_StatusBar := "0C1422"

        RhB_Accent := 0x4AA316
        RhB_Neon := 0xEED322
        RhB_Apply := 0x5EC522
        RhB_ButtonOff := 0x554133
        RhB_Cash := 0x1673F9
        RhB_Card := 0xEB6325
        RhB_Gift := 0x9948EC
        RhB_Siv := 0xA6B814
        RhB_Text := 0xFFF2EA
        RhB_Muted := 0xC2B0A7
        RhB_White := 0xFFFFFF
        RhB_Header := 0x1F1109
        RhB_SettingsGear := 0xEED322
        RhB_Blue := 0xEB6325
        RhB_Teal := 0xA6B814
        RhB_Green := 0x5EC522
        RhB_Orange := 0x1673F9
        RhB_Red := 0x4444EF
        RhB_CardFill := 0x271811
        RhB_StatusSoft := 0x22140C

        RhB_Chip         := 0x2A2A2A
        RhB_TintGreen    := 0x143A1E
        RhB_TintAmber    := 0x0C2A3A
        RhB_TintRed      := 0x101040
        RhB_GiftGunkan   := 0x2A1840
        RhB_GiftPepsi    := 0x2A2418
        RhB_GiftBurger   := 0x102840
        RhB_GiftSandwich := 0x183040
    } else {
        RhC_BG := "F5F6F8"
        RhC_Panel := "FFFFFF"
        RhC_Header := "FFFFFF"
        RhC_Header2 := "F5F6F8"
        RhC_HeaderText := "1F1F1F"
        RhC_HeaderSub := "6B6B6B"
        RhC_Neon := "2563EB"
        RhC_Text := "1F1F1F"
        RhC_Muted := "6B6B6B"
        RhC_Subtle := "F5F6F8"
        RhC_Soft := "E5E7EB"
        RhC_SoftText := "374151"
        RhC_Card := "FFFFFF"
        RhC_Shadow := "E5E7EB"
        RhC_BlueSoft := "EEF2FF"
        RhC_TealSoft := "F5F6F8"
        RhC_GreenSoft := "F5F6F8"
        RhC_OrangeSoft := "F5F6F8"
        RhC_RedSoft := "FEF2F2"
        RhC_StatusBar := "F5F6F8"

        RhB_Accent := 0xEB6325
        RhB_Neon := 0xEB6325
        RhB_Apply := 0xEB6325
        RhB_ButtonOff := 0xFFFFFF
        RhB_Cash := 0xEB6325
        RhB_Card := 0xEB6325
        RhB_Gift := 0xEB6325
        RhB_Siv := 0xEB6325
        RhB_Text := 0x1F1F1F
        RhB_Muted := 0x6B6B6B
        RhB_White := 0xFFFFFF
        RhB_Header := 0xFFFFFF
        RhB_SettingsGear := 0xEB6325
        RhB_Blue := 0xEB6325
        RhB_Teal := 0xEB6325
        RhB_Green := 0x4AA316
        RhB_Orange := 0xEB6325
        RhB_Red := 0x2626DC
        RhB_CardFill := 0xFFFFFF
        RhB_StatusSoft := 0xF8F6F5

        ; --- сигнальні tint-кольори (BGR; відображаються як #RRGGBB) ---
        RhB_Chip         := 0xECE9E8   ; #E8E9EC  нейтральна кнопка (не активна)
        RhB_TintGreen    := 0xE1F0D9   ; #D9F0E1  стан OK
        RhB_TintAmber    := 0xD0EFFC   ; #FCEFD0  увага
        RhB_TintRed      := 0xD5D9FA   ; #FAD9D5  критично
        RhB_GiftGunkan   := 0xFBE7ED   ; #EDE7FB  фіолет
        RhB_GiftPepsi    := 0xF4ECE4   ; #E4ECF4  холодний
        RhB_GiftBurger   := 0xD2E7FC   ; #FCE7D2  оранж
        RhB_GiftSandwich := 0xCCF1FB   ; #FBF1CC  жовтий
    }
}


RhRegColor(hwnd, bg, tx) {
    global RhStaticColors
    RhStaticColors[hwnd] := {bg: bg, tx: tx}
}

RhRepaintRollPult:
    RhForceRepaintRollPult()
    SetTimer, RhRepaintRollPultLate1, -80
    SetTimer, RhRepaintRollPultLate2, -220
return

RhRepaintRollPultLate1:
    RhForceRepaintRollPult()
return

RhRepaintRollPultLate2:
    RhForceRepaintRollPult()
return

RhForceRepaintRollPult() {
    global RollHwnd, RhStaticColors
    if (!RollHwnd)
        return
    for hwnd, _ in RhStaticColors {
        DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
        DllCall("user32\UpdateWindow", "Ptr", hwnd)
    }
    ; RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW = 0x185
    DllCall("user32\RedrawWindow", "Ptr", RollHwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
}

WM_CTLCOLORSTATIC(wParam, lParam) {
    global RhStaticColors, RhStaticBrush
    if (lParam < 0)
        lParam += 0x100000000      ; 32-бітний AHK віддає hwnd зі знаком → нормалізуємо
    if (!RhStaticColors.HasKey(lParam))
        return
    o := RhStaticColors[lParam]
    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", o.tx)
    DllCall("gdi32\SetBkColor",   "Ptr", wParam, "UInt", o.bg)
    if (!RhStaticBrush.HasKey(o.bg))
        RhStaticBrush[o.bg] := DllCall("gdi32\CreateSolidBrush", "UInt", o.bg, "Ptr")
    return RhStaticBrush[o.bg]
}

; --- ПРОВЕРКА СЕРВЕРНОЙ ДИАГНОСТИКИ ТОЧКИ ---
^F12::
RcDiagnosePointTest:
    if (naitiX = 0 || naitiY = 0) {
        ToolTip, % "Спочатку проскануй замовлення, щоб знайти кнопку 'Найти точку'."
        SetTimer, RemoveToolTip, -3000
        return
    }
    ToolTip, PREPARE: отримання базового стану...
    
    _prepRes := RhGet("/api/iiko/diagnose_point_prepare", 10000)
    FileAppend, % "[" A_Now "] PREPARE: " _prepRes "`n", %A_ScriptDir%\siv_debug.log
    
    isOk := false
    if (RegExMatch(_prepRes, """ok""\s*:\s*(true|1)", _mOk)) {
        isOk := true
    }
    
    sessionId := ""
    if (RegExMatch(_prepRes, """session_id""\s*:\s*""([^""]+)""", mSession)) {
        sessionId := Trim(mSession1)
    }
    
    if (!isOk || sessionId = "") {
        ToolTip, PREPARE ERROR — клік скасовано
        SetTimer, RemoveToolTip, -3000
        return
    }
    
    if (iikoWinExe != "" && iikoWinExe != "ERROR")
        WinActivate, ahk_exe %iikoWinExe%
    Sleep, 150
    ToolTip, CLICK: Натискаю "Найти точку"...
    Click, %naitiX%, %naitiY%
    
    ToolTip, COLLECT: Очікування popup та читання Точки...
    _diagRes := RhGet("/api/iiko/diagnose_point_collect?session_id=" sessionId, 25000)
    FileAppend, % "[" A_Now "] COLLECT: " _diagRes "`n", %A_ScriptDir%\siv_debug.log
    
    pointStr := "N/A"
    pointBeforeStr := "N/A"
    popupsCount := 0
    elapsedMs := 0
    compReason := "N/A"
    
    if (RegExMatch(_diagRes, """point""\s*:\s*""([^""]*)""", _matchPt))
        pointStr := Trim(_matchPt1)
    if (RegExMatch(_diagRes, """point_before""\s*:\s*""([^""]*)""", _matchPb))
        pointBeforeStr := Trim(_matchPb1)
    if (RegExMatch(_diagRes, """popups_handled""\s*:\s*(\d+)", _matchC))
        popupsCount := _matchC1
    if (RegExMatch(_diagRes, """elapsed_ms""\s*:\s*([\d\.]+)", _matchT))
        elapsedMs := Round(_matchT1)
    if (RegExMatch(_diagRes, """completion_reason""\s*:\s*""([^""]+)""", _matchR))
        compReason := Trim(_matchR1)
        
    if (InStr(_diagRes, "unknown_popup")) {
        ToolTip, % "Увага! Невідомий popup! Див. лог.`nЧас: " elapsedMs " ms"
    } else {
        ToolTip, % "Точка: " pointStr "`nБуло: " pointBeforeStr "`nPopup: " popupsCount "`nПричина: " compReason "`nЧас: " elapsedMs " ms"
    }
    SetTimer, RemoveToolTip, -5000
return
; --------------------------------------------

RcFindKitchenByConcept(concept) {
    if (concept = "Київ Драгоманова")
        return "Драгоманова"
    if (concept = "Київ Антонова")
        return "Антонова"
    if (concept = "Київ Стрільців")
        return "Лук'янівка"
    if (concept = "Київ Лаврухіна")
        return "Троєщина"
    if (concept = "РК Харків Конституції Доставка")
        return "РЕСТОРАН"
    if (concept = "Харків Нові Дома")
        return "НД"
    if (concept = "Львов Липа")
        return "Крива Липа"
    if (concept = "Дніпро Мудрого")
        return "Мудрого"
    if (concept = "Біла Церква")
        return "БЦ"
    if (concept = "Приморська")
        return "Приморська"
    if (concept = "Франківськ Фудотека")
        return "Фудотека"
    if (concept = "Рівне")
        return "ТРЦ Екватор"
    if (concept = "Вінниця")
        return "Мегамолл"
    return ""
}


; === Identity Gatherer ===
    ToolTip, Читання ідентифікаторів...
    res := RhGet("/api/iiko/read_identity_fast")
    FileAppend, % "[" A_Now "] IDENTITY_RAW: " res "`n", %A_ScriptDir%\iiko_identity.log, UTF-8
    RegExMatch(res, """concept""\s*:\s*""([^""]*)""", mC)
    RegExMatch(res, """point""\s*:\s*""([^""]*)""", mP)
    conceptVal := Trim(mC1)
    pointVal := Trim(mP1)
    
    ToolTip, % "Concept: " conceptVal "`nPoint: " pointVal
    SetTimer, RemoveToolTip, -3000
    
    logLine := "[" A_Now "] Concept: [" conceptVal "] Point: [" pointVal "]`n"
    FileAppend, %logLine%, %A_ScriptDir%\iiko_identity.log, UTF-8
return

; ========================================================
;  WINAPI SCANNER — Roll Club
; ========================================================
LoadUiaMapToListView:
    Gui, Settings:Default
    Gui, ListView, UiaListView
    LV_Delete()
    IniRead, _uiaKeys, %UIA_MAP_CONFIG%, UiaMap
    if (_uiaKeys = "" || _uiaKeys = "ERROR")
        return
    Loop, Parse, _uiaKeys, `n, `r
    {
        if (A_LoopField = "")
            continue
        _pair := StrSplit(A_LoopField, "=", "", 2)
        if (_pair.Length() < 2)
            continue
        _name := Trim(_pair[1])
        _id := Trim(_pair[2])
        if (_name != "" && _id != "")
            LV_Add("", _name, _id)
    }
return

RcLaunchServerProcess(forceRestart := 0) {
    _packageRoot := A_ScriptDir . "\.."
    _serverDir := _packageRoot . "\server"
    _serverApp := _serverDir . "\app.py"
    _embeddedPython := _packageRoot . "\runtime\python\pythonw.exe"
    _packageRestart := _packageRoot . "\restart_rollclub_server.bat"
    _developmentStart := _serverDir . "\start.bat"

    if (forceRestart && FileExist(_packageRestart)) {
        Run, %ComSpec% /c ""%_packageRestart%"", %_packageRoot%, Hide
        return 1
    }

    if (!forceRestart && FileExist(_embeddedPython) && FileExist(_serverApp)) {
        Run, "%_embeddedPython%" "%_serverApp%", %_serverDir%, Hide
        return 1
    }

    if FileExist(_developmentStart) {
        Run, %ComSpec% /c ""%_developmentStart%"", %_serverDir%, Hide
        return 1
    }

    TrayTip, RollClub, Не знайдено файли локального сервера., 4, 2
    return 0
}

UiaListClick:
    if (A_GuiEvent = "DoubleClick")
        GoSub, DeleteSelectedUiaBinding
return

DeleteSelectedUiaBinding:
    Gui, Settings:Default
    Gui, ListView, UiaListView
    _row := LV_GetNext(0, "S")
    if (!_row) {
        MsgBox, 48, WinAPI Сканер, Спочатку виберіть елемент у списку.
        return
    }
    LV_GetText(_delName, _row, 1)
    LV_GetText(_delValue, _row, 2)
    Gui, Settings:+OwnDialogs +Disabled
    MsgBox, 292, Видалення WinAPI елемента, Видалити прив'язку?`n`nРоль: %_delName%`nID: %_delValue%
    Gui, Settings:-Disabled
    WinActivate, ahk_id %SettingsHwnd%
    IfMsgBox, No
        return
    IniDelete, %UIA_MAP_CONFIG%, UiaMap, %_delName%
    IniRead, _remainingUiaMap, %UIA_MAP_CONFIG%, UiaMap
    if (_remainingUiaMap = "" || _remainingUiaMap = "ERROR")
        IniDelete, %UIA_MAP_CONFIG%, UiaMap
    GoSub, LoadUiaMapToListView
    FileAppend, % "[" . A_Now . "] UIA_MAP_DELETE role=" . _delName . " value=" . _delValue . "`n", %A_ScriptDir%\ahk_debug.log
    MsgBox, 64, Видалено, Прив'язку "%_delName%" видалено з конфігурації Roll Club.
return

LaunchScanner:
    Gui, Settings:Hide
    Sleep, 200
    MsgBox, 4160, WinAPI Сканер, Наведіть курсор на потрібну кнопку в Syrve та натисніть ліву кнопку миші.
    KeyWait, LButton, Down
    MouseGetPos, _mx, _my, _mHwnd
    try {
        _uia := UIA_Interface()
        _root := ""
        if (_mHwnd)
            try _root := _uia.ElementFromHandle(_mHwnd)
        if (_root)
            _el := _uia.SmallestElementFromPoint(_mx, _my, true, _root)
        else
            _el := _uia.SmallestElementFromPoint(_mx, _my)
        _aId := ""
        _aName := ""
        try _aId := _el.CurrentAutomationId
        try _aName := _el.CurrentName
        _saveVal := _aId != "" ? _aId : (_aName != "" ? "Name=" . _aName : "")
        if (_saveVal = "") {
            MsgBox, 48, Помилка, Не вдалося знайти AutomationId або Name цього елемента.
            GoSub, OpenSettings
            return
        }
        InputBox, _newName, Збереження WinAPI елемента, Знайдено: %_saveVal%`n`nВведіть назву ролі (наприклад, КнопкаПодзвонити):,,,,,,,,
        if (ErrorLevel = 0 && _newName != "") {
            IniWrite, %_saveVal%, %UIA_MAP_CONFIG%, UiaMap, %_newName%
            MsgBox, 64, Збережено, Елемент "%_newName%" збережено.
        }
    } catch _ex {
        MsgBox, 48, Помилка UIA, Не вдалося зчитати елемент:`n%_ex%
    }
    GoSub, OpenSettings
return

RcDutyModuleMessage(wParam, lParam, msg, hwnd) {
    global RcDutyModuleRequest
    if (wParam != 1)
        return 0

    RcDutyModuleRequest := wParam
    SetTimer, RcDutyModuleInvoke, -10
    return 1
}
