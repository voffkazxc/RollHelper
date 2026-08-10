#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%\brands\rollclub   ; дані Roll Club (конфіг, промо, кухні, img)
FileEncoding, UTF-8

; Налаштування координат
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen

; Максимальна швидкість виконання
SetBatchLines, -1
ListLines, Off

; Налаштування вводу (миттєве виконання)
SendMode Input
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1

; ── RollHelper: перемикання бренду назад на Roll House (через трей) ──
Menu, Tray, Add
Menu, Tray, Add, Перемкнути на Roll House, SwitchToRollHouse
Menu, Tray, Add, 🌐 Веб-пульт (бета), OpenWebPult

; ── RollHelper: сервер iiko-моста (читання полів ПО ІМЕНАХ) ──
global RH_SERVER := "http://127.0.0.1:5000"
global RH_SERVER_OK := 0
RhPing()
if (!RH_SERVER_OK) {
    ; Запуск через start.bat — надійніше: прибиває старий сервер, чистить кеш,
    ; ставить правильну робочу папку. (Прямий pythonw інколи не піднімався.)
    Run, cmd /c start.bat, %A_ScriptDir%\..\server, Hide
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
    IniWrite, F2,    %ConfigPath%, Hotkeys, WaitOrder
    IniWrite, F3,    %ConfigPath%, Hotkeys, WaitCall
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

IniRead, pluGunkan,   %ConfigPath%, PLU, Gunkan,   02929
IniRead, pluPepsi,    %ConfigPath%, PLU, Pepsi,    02216
IniRead, pluBurger,   %ConfigPath%, PLU, Burger,   02217
IniRead, pluSandwich, %ConfigPath%, PLU, Sandwich, 02926
IniRead, pluSticksNorm, %ConfigPath%, PLU, SticksNorm, 00143
IniRead, pluSticksEdu,  %ConfigPath%, PLU, SticksEdu,  00144
IniRead, pluUtensils,   %ConfigPath%, PLU, Utensils,   02439
IniRead, pluSoy,        %ConfigPath%, PLU_SIV, Soy,        00424
IniRead, pluGinger,     %ConfigPath%, PLU_SIV, Ginger,     00428
IniRead, pluWasabi,     %ConfigPath%, PLU_SIV, Wasabi,     00426

IniRead, hkMain, %ConfigPath%, Hotkeys, Main, vkC0
IniRead, hkSiv,  %ConfigPath%, Hotkeys, Siv,  F1
IniRead, hkWait, %ConfigPath%, Hotkeys, WaitOrder, F2
IniRead, hkCall, %ConfigPath%, Hotkeys, WaitCall, F3
IniRead, uiTheme, %ConfigPath%, UI, Theme, light
global uiTheme

; Очищення від можливих артефактів кодування (нульових байтів)
hkMain := RegExReplace(hkMain, "[^a-zA-Z0-9!#^+]")
hkSiv  := RegExReplace(hkSiv,  "[^a-zA-Z0-9!#^+]")
hkWait := RegExReplace(hkWait, "[^a-zA-Z0-9!#^+]")
hkCall := RegExReplace(hkCall, "[^a-zA-Z0-9!#^+]")
if (hkMain = "") hkMain := "vkC0"
if (hkSiv  = "") hkSiv  := "F1"
if (hkWait = "") hkWait := "F2"
if (hkCall = "") hkCall := "F3"

; ========================================================
; ГЛОБАЛЬНІ ЗМІННІ
; ========================================================
global rawComment   := ""
global cleanComment := ""
global infoText     := ""
global addrNote     := ""
global extractedTime:= ""
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
global CHECK_POINT_ENABLED := 1  ; РУБИЛЬНИК звірки точки. 1 = на тильду тиснути "Найти точку" і звіряти з нашою KML-зоною (тільки доставка, один раз, синхронно). << УВІМКНЕНО
global RcLastZone := ""   ; остання визначена нами KML-зона (для звірки з iiko)
global tochkaX := 0, tochkaY := 0  ; приціл поля "Точка"
global autoMode    := 0   ; 🤖 авто-режим (концепція/подарунок/пакет) — тумблер у пульті
global kcBusy      := 0   ; монітор КЦ зайнятий (анти-реентрі)
global kcLastNo    := ""  ; останній помічений № (щоб не дублювати звук)
global kcPaused    := 0   ; пауза монітора: чекаємо Ctrl+Enter оператора
global RcZonesOk   := 0   ; 1 = KML завантажено

; ========================================================
; ГАРЯЧІ КЛАВІШІ
; ========================================================
Hotkey, %hkMain%, TriggerMain, On
Hotkey, %hkSiv%,  TriggerSiv,  On
Hotkey, %hkWait%, TriggerWait, On
Hotkey, %hkCall%, TriggerCall, On

SetTimer, RollFocusWatcher, 300


return

RollFocusWatcher:
    if !WinExist("Rollclub PRO 33.0")
        return
    if WinActive("Rollclub PRO 33.0")
        return
    if WinActive("Налаштування PRO")
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
        Gui, Roll:Show
        WinActivate, Rollclub PRO 33.0
        return
    }
    ; Пульту немає взагалі → повний скан
    if (commX = 0 || commX = "" || commX = "ERROR") {
        MsgBox, 48, Налаштування, Координати не встановлені!`nЗараз відкриється вікно налаштувань.
        GoSub, OpenSettings
        return
    }

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
        Click, %commX%, %commY%
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
    GoSub, AddSivVisual
return

TriggerWait:
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

; ========================================================
; БАЗА КУХОНЬ
; ========================================================
LoadKitchens:
    Kitchens := []
    if !FileExist(KitchensPath)
        return
    ; читаємо файл напряму як UTF-8 (IniRead через WinAPI ламає кирилицю)
    FileRead, raw, *P65001 %KitchensPath%
    curSec := ""
    curObj := ""
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        ; секція
        if (SubStr(line, 1, 1) = "[" && SubStr(line, 0) = "]") {
            if (curObj)
                Kitchens.Push(curObj)
            curSec := SubStr(line, 2, StrLen(line) - 2)
            curObj := {Name: curSec, City: "", Address: "", KmlKey: "", Remark: "", Center: "Стандарт", Pickup: "Стандарт", FarZone: "Стандарт", StopList: ""}
            continue
        }
        ; key=value
        eqPos := InStr(line, "=")
        if (eqPos = 0 || !curObj)
            continue
        k := Trim(SubStr(line, 1, eqPos - 1))
        v := Trim(SubStr(line, eqPos + 1))
        if (k = "City")
            curObj.City := v
        else if (k = "Address")
            curObj.Address := v
        else if (k = "KmlKey")
            curObj.KmlKey := v
        else if (k = "Remark")
            curObj.Remark := v
        else if (k = "Center")
            curObj.Center := v
        else if (k = "Pickup")
            curObj.Pickup := v
        else if (k = "FarZone")
            curObj.FarZone := v
        else if (k = "StopList")
            curObj.StopList := v
    }
    if (curObj)
        Kitchens.Push(curObj)
    logFile := A_ScriptDir "\siv_debug.log"
    kCnt := Kitchens.MaxIndex() ? Kitchens.MaxIndex() : 0
    FileAppend, `n[DEBUG] %A_Now% - Event: Kitchens loaded = %kCnt%`n, %logFile%
return

DetectKitchenStatus:
    detectedCity    := ""
    kitchenLine     := ""
    hasKitchenAlert := 0
    citySource      := ""
    ; джерело — або адреса (доставка), або пункт самовивозу, або сам коментар
    searchText := rawAddress
    if (hasPickup && pickupPoint != "")
        searchText := searchText . " " . pickupPoint
    if (searchText = "" && hasPickup && rawComment != "")
        searchText := rawComment
    logFile := A_ScriptDir "\siv_debug.log"
    rawAddrShort := SubStr(rawAddress, 1, 200)
    pickShort    := SubStr(pickupPoint, 1, 200)
    FileAppend, `n[DEBUG] %A_Now% - Event: rawAddress = "%rawAddrShort%" pickup = "%pickShort%"`n, %logFile%
    if (searchText = "")
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
    if (detectedCity = "Франківськ" || detectedCity = "ІФ")
        detectedCity := "Івано-Франківськ"
    if (detectedCity = "Ровно")
        detectedCity := "Рівне"
    if (detectedCity = "Днепр")
        detectedCity := "Дніпро"

    if (hasPickup)
        citySource := " (самовивіз)"
    FileAppend, [DEBUG] %A_Now% - Event: detectedCity = "%detectedCity%"%citySource%`n, %logFile%
    if (detectedCity = "")
        return
    ; Більше не показуємо всі кухні міста списком, бо маємо точну зону KML
    kitchenLine := ""
    hasKitchenAlert := 0
return

AppendPromoToBase:
    if (promoFound = "")
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
    ; Підтримує: "Виделка/Ніж/Ложка x4", "Виделка x2", "Ніж x1"
    if RegExMatch(workComment, "i)(Виделк[аи]\/Ніж\/Ложк[аи]|Виделк[аи]|Ніж|Ложк[аи])\s*(?:x|х|×)?\s*(\d+)?", mUten) {
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
        FileAppend, `n[DEBUG] %A_Now% - Event: Utensils detected (%utensilsText% x%parsedUtensils%) — auto-PLU %pluUtensils%`n, %logFile%
    }

    ; --- День народження ---
    if RegExMatch(workComment, "i)(день\s*народ|день\s*рождени|-10%\s*до\s*дня|знижка\s+до\s+дня\s+народ|знижка\s+на\s+день\s+народ|(?<![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])ДН(?![а-яА-ЯіїєґІЇЄҐёЁa-zA-Z])\s*знижка)") {
        hasBirthday := 1
        if (cardText = "")
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
    if (isFutureDate) {
        extractedTime := ""   ; передзамовлення — час вже виставлений в CRM, не чіпаємо
    } else {
        ; Конкретний час у коментарі — беремо його
        RegExMatch(workComment, "(\d{2}:\d{2})", timeMatch)
        if (timeMatch1 != "") {
            extractedTime := timeMatch1
        } else {
            ; Самовивіз — 41 хв, доставка — 91 хв
            tHH := A_Hour + 0
            tMM := A_Min + (hasPickup ? 41 : 91)
            tHH += Floor(tMM / 60)
            tMM := Mod(tMM, 60)
            tHH := Mod(tHH, 24)
            extractedTime := Format("{:02}:{:02}", tHH, tMM)
        }
    }

    paymentMethod := ""
    paymentNum    := ""

    if RegExMatch(workComment, "i)Готівкою\s*№(\d+)", mCash) {
        paymentMethod := "Готівкою"
        paymentNum    := mCash1
        autoCash      := 1
    }
    if (paymentMethod = "" && RegExMatch(workComment, "i)(?:---ОПЛАЧЕНО---\s*)?(?:Картою[^№\r\n]*|ОПЛАЧЕНО\s*)№(\d+)", mCard)) {
        paymentMethod := "Оплачено"
        paymentNum    := mCard1
    }
    if (paymentMethod = "" && RegExMatch(workComment, "i)QR\s*code[^\d]*(\d{5,})", mQR)) {
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

    if RegExMatch(workComment, "i)!!!ПЕРШЕМОБ") {
        autoGunkan := 1
        if (cardText = "")
            cardText := "ПЕРШЕМОБ"
        else
            cardText := "ПЕРШЕМОБ | " . cardText
    }

    if (orderSum > 0) {
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
        sw := RegExReplace(sw, "i)ОПЛАЧЕНО\s*№?\s*\d*", " ")
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
                SoundBeep, 1800, 200
                Sleep, 80
                SoundBeep, 1800, 200
                Sleep, 80
                SoundBeep, 1800, 400
            }
        }
        rcDebugLog .= "[8] addrMismatch=" . addrMismatch . "`n"

        ; Записуємо лог завжди
        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[ADDR-PARSE] %A_Now%`n%rcDebugLog%, %logFile%
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

    _brandName := (BRAND = "rollclub") ? "Roll Club" : "Roll House"
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
    Gui, Roll:Add, Text, x174 y14 w104 h18 Right +0x200, %_rhNow%
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x280 y14 w36 h22 Center +Border +0x200 HwndhSwitchBrand gSwitchToRollHouse, RH
    Gui, Roll:Add, Text, x320 y14 w28 h22 Center +Border +0x200 HwndhSettingsGear gOpenSettings, Set
    RhRegColor(hSwitchBrand, RhB_CardFill, RhB_Text)
    RhRegColor(hSettingsGear, RhB_CardFill, RhB_Text)
    ; --- Тумблер авто-режиму ---
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x166 y34 w178 h22 Center +Border +0x200 HwndhAutoToggle vRhAutoLbl gRhAutoToggle, 🤖 АВТО: ВИМК
    RhRegColor(hAutoToggle, RhB_CardFill, RhB_Text)

    Gui, Roll:Font, s8 bold cFFFFFF, %RhFontName%
    Gui, Roll:Add, Text, x16 y54 w74 h20 Center +0x200 HwndhOnlinePill, %_serverPill%
    RhRegColor(hOnlinePill, (RH_SERVER_OK ? RhB_Green : RhB_Red), RhB_White)
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x100 y54 w244 h22 Center +Border +0x200 HwndhOpenKitchens gOpenKitchensEditor, Кухні
    RhRegColor(hOpenKitchens, RhB_CardFill, RhB_Text)
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
    if (hasFilaClub || hasBirthday || hasAllergy || promoFound != "" || hasCustomerReq || needCall || !isPost) {
        Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
        Gui, Roll:Add, Text, x%x0% y%curY% w%w0% h16 +0x200, ВАЖЛИВО
        curY += 20
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
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x116 y%curY% w108 h24 Center +0x200 HwndhCalcPickup gCalcPickup, СВ +40
    Gui, Roll:Add, Text, x236 y%curY% w108 h24 Center +0x200 HwndhCalcDelivery gCalcDelivery, ДОСТ +90
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
    ControlsToMove.Push(hC8), ControlsToMove.Push(hC9), ControlsToMove.Push(hC10)
    curY += 18
    Gui, Roll:Font, s10 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x16 y%curY% w40 h24 Center vVisRolls gRhSivInlineUpdate Number -E0x200 HwndhC11, %VisRolls%
    Gui, Roll:Add, Edit, x68 y%curY% w40 h24 Center vVisNorm gRhSivInlineUpdate Number -E0x200 HwndhC12, %parsedSticksNorm%
    Gui, Roll:Add, Edit, x120 y%curY% w40 h24 Center vVisEdu gRhSivInlineUpdate Number -E0x200 HwndhC13, %parsedSticksEdu%
    ControlsToMove.Push(hC11), ControlsToMove.Push(hC12), ControlsToMove.Push(hC13)
    Gui, Roll:Font, s8 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x176 y%curY% w168 h24 +0x200 vRhSivPreview HwndhRhSivPreview, Соус 0 · Імбир 0 · Васабі 0
    ControlsToMove.Push(hRhSivPreview)
    curY += 36

    GuiBaseHeight := curY
    Gui, Roll:Show, x350 y20 w360 h%GuiBaseHeight%, Rollclub PRO 33.0
    Gui, Roll:+LastFound
    RollHwnd := WinExist()
    ; примусова перемальовка ВСІХ статиків — щоб кольори лягли з ПЕРШОГО показу
    ; (RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW = 0x185)
    DllCall("RedrawWindow", "Ptr", RollHwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
    GoSub, RhSivInlineUpdate

    if (RcRawShown) {
        RcRawShown := 0
        GoSub, RcToggleRawText
    }

    if (rawAddress != "" && !hasPickup)
        SetTimer, RcCheckZone, -450
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
    _soyC := Ceil(_r / 2.0)
    _soyM := (_r < 2) ? _r : 2
    _soy  := (_soyC > _soyM) ? _soyC : _soyM
    _gw   := Ceil(_r / 4.0)
    if (_r == 0) {
        _soy := 0
        _gw  := 0
    }
    GuiControl, Roll:, RhSivPreview, Соєвий %_soy% · Імбир %_gw% · Васабі %_gw%
return

RhAutoToggle:
    ; ГОЛОВНИЙ РУБИЛЬНИК: якщо авто-КЦ вимкнено — F4 нічого не робить (швидкий ручний пульт).
    if (!AUTO_KC_ENABLED) {
        SetTimer, KcMonitor, Off
        autoMode := 0
        ToolTip, Авто-КЦ ВИМКНЕНО (ручний режим)
        SetTimer, RemoveFinishTip, -1500
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

KcMonitor:
    if (!AUTO_KC_ENABLED || !autoMode)
    {
        SetTimer, KcMonitor, Off
        autoMode := 0
        return
    }
    if (kcBusy || kcPaused)
        return
    kcBusy := 1
    WinActivate, ahk_exe BackOffice.exe
    Sleep, 150
    Send, ^{Tab}
    Sleep, 450
    Send, ^{Tab}
    Sleep, 650
    listResp := RhGet("/api/iiko/kc-list", 8000)
    takeNo := ""
    RegExMatch(listResp, "take_no\D+(\d+)", tM)
    takeNo := tM1
    FileAppend, % "[" . A_Now . "] KC takeNo=" . takeNo . " paused=" . kcPaused . " poiskX=" . poiskX . " rowX=" . rowX . " resp=" . SubStr(listResp,1,160) . "`n", %A_ScriptDir%\ahk_debug.log
    if (takeNo = "" || takeNo = "0")
    {
        kcBusy := 0
        return
    }
    ; --- capture: Poisk -> open first row ---
    if (poiskX != 0)
    {
        Click, %poiskX%, %poiskY%
        Sleep, 200
        Send, ^a
        Sleep, 50
        SendInput, %takeNo%
        Sleep, 800
    }
    if (rowX != 0)
    {
        Click, %rowX%, %rowY%
        Sleep, 120
        Click, %rowX%, %rowY%
        Sleep, 700
    }
    ; operator-conflict dialog (standard dialog class)
    if WinExist("ahk_class #32770")
    {
        WinActivate, ahk_class #32770
        Sleep, 120
        Send, {Right}{Enter}
        Sleep, 350
        kcBusy := 0
        return
    }
    ; opened -> read (tilde) + punch + sound + pause
    Sleep, 400
    GoSub, TriggerMain
    Sleep, 3000
    GoSub, ApplyRollclub
    Sleep, 500
    GoSub, SoundOk
    kcPaused := 1
    kcBusy := 0
return

#IfWinActive Rollclub PRO 33.0
Enter::GoSub, ApplyRollclub
NumpadEnter::GoSub, ApplyRollclub
+Enter::Send, {Enter}
+NumpadEnter::Send, {Enter}
^Enter::GoSub, FinishOrder
^NumpadEnter::GoSub, FinishOrder
#IfWinActive

; Фініш також з вікна iiko (там фокус після пробивання Enter-ом)
#IfWinActive ahk_exe BackOffice.exe
^Enter::GoSub, FinishOrder
^NumpadEnter::GoSub, FinishOrder
#IfWinActive

#IfWinActive СИВ (Модуль)
Enter::GoSub, SivVisApply
NumpadEnter::GoSub, SivVisApply
#IfWinActive

^!r::Reload                ; Ctrl+Alt+R — перезавантажити скрипт (підхопити свіжий код з диску)
F4::GoSub, RhAutoToggle    ; глобально: повний автомат (монітор КЦ) увімк/вимк

; ========================================================
; НАЛАШТУВАННЯ
; ========================================================
OpenSettings:
    Gui, Settings:Destroy
    Gui, Settings:+AlwaysOnTop +ToolWindow

    RhApplyTheme()
    Gui, Settings:Color, %RhC_BG%, %RhC_Panel%

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
    Gui, Settings:Add, Text, w300 Center x10 y+15, ТЕМА
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x10 y+10 w60, Стиль:
    _themeIdx := (uiTheme = "dark") ? 2 : 1
    Gui, Settings:Add, DropDownList, x+5 yp-3 w220 vNewUiTheme Choose%_themeIdx%, Light Premium|Neon Dark

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, w300 Center x10 y+15, ЗОНИ ДОСТАВКИ (KML)
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, x10 y+10 w290 h28 gRcLoadKmlFile, Завантажити KML-файл зон

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, w300 Center x10 y+15, PLU КОДИ ПОДАРУНКІВ
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x10 y+10 w60, Гункан:
    Gui, Settings:Add, Edit, x+5 yp-3 w80 vNewGunkan Center, %pluGunkan%
    Gui, Settings:Add, Text, x+10 yp+3 w50, Пепсі:
    Gui, Settings:Add, Edit, x+5 yp-3 w80 vNewPepsi Center, %pluPepsi%
    Gui, Settings:Add, Text, x10 y+10 w60, Бургер:
    Gui, Settings:Add, Edit, x+5 yp-3 w80 vNewBurger Center, %pluBurger%
    Gui, Settings:Add, Text, x+10 yp+3 w55, Сендвіч:
    Gui, Settings:Add, Edit, x+5 yp-3 w80 vNewSandwich Center, %pluSandwich%

    Gui, Settings:Add, Text, x10 y+10 w60, Бамбукові:
    Gui, Settings:Add, Edit, x+5 yp-3 w80 vNewSticksNorm Center, %pluSticksNorm%
    Gui, Settings:Add, Text, x+10 yp+3 w55, Навчальні:
    Gui, Settings:Add, Edit, x+5 yp-3 w80 vNewSticksEdu Center, %pluSticksEdu%

    Gui, Settings:Add, Text, x10 y+10 w70, Прибори В/Н/Л:
    Gui, Settings:Add, Edit, x+5 yp-3 w80 vNewUtensils Center, %pluUtensils%

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, w300 Center x10 y+15, ГАРЯЧІ КЛАВІШІ
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x10 y+10 w140, Головне меню:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkMain, %hkMain%
    Gui, Settings:Add, Text, x10 y+10 w140, Швидкий СИВ:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkSiv, %hkSiv%
    Gui, Settings:Add, Text, x10 y+10 w140, Авто-Прийом CRM:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkWait, %hkWait%
    Gui, Settings:Add, Text, x10 y+10 w140, Автоприйом Дзвінка:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkCall, %hkCall%

    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, w290 h35 x10 y+15 gSaveSettings, Зберегти та Перезапустити
    Gui, Settings:Show,, Налаштування PRO
return

SaveSettings:
    Gui, Settings:Submit
    uiThemeSave := InStr(NewUiTheme, "Dark") ? "dark" : "light"
    IniWrite, %uiThemeSave%, RkConfig.ini, UI, Theme
    IniWrite, %NewGunkan%,   RkConfig.ini, PLU, Gunkan
    IniWrite, %NewPepsi%,    RkConfig.ini, PLU, Pepsi
    IniWrite, %NewBurger%,   RkConfig.ini, PLU, Burger
    IniWrite, %NewSandwich%, RkConfig.ini, PLU, Sandwich
    IniWrite, %NewSticksNorm%, RkConfig.ini, PLU, SticksNorm
    IniWrite, %NewSticksEdu%,  RkConfig.ini, PLU, SticksEdu
    IniWrite, %NewUtensils%,   RkConfig.ini, PLU, Utensils
    IniWrite, %NewHkMain%,   RkConfig.ini, Hotkeys, Main
    IniWrite, %NewHkSiv%,    RkConfig.ini, Hotkeys, Siv
    IniWrite, %NewHkWait%,   RkConfig.ini, Hotkeys, WaitOrder
    IniWrite, %NewHkCall%,   RkConfig.ini, Hotkeys, WaitCall
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
    if (presetNotes = "")
        presetNotes := "Стандарт|Стоп|по узгодженню"

    rowY := 80
    for idx, k in Kitchens {
        label := k.Name . " (" . k.City . ")"
        Gui, Kitch:Add, Text, x10 y%rowY% w130 h22 +0x200, %label%

        vRemark := "KRem_" . idx
        valRem := k.Remark
        Gui, Kitch:Add, Edit, x150 y%rowY% w150 h22 v%vRemark%, %valRem%

        vCenter := "KCen_" . idx
        optCenter := RcBuildKitchOpts(k.Center, presetNotes)
        Gui, Kitch:Add, ComboBox, x310 y%rowY% w110 v%vCenter%, %optCenter%

        vPickup := "KPic_" . idx
        optPickup := RcBuildKitchOpts(k.Pickup, presetNotes)
        Gui, Kitch:Add, ComboBox, x430 y%rowY% w110 v%vPickup%, %optPickup%

        vFar := "KFar_" . idx
        optFar := RcBuildKitchOpts(k.FarZone, presetNotes)
        Gui, Kitch:Add, ComboBox, x550 y%rowY% w110 v%vFar%, %optFar%

        vStop := "KSto_" . idx
        valStop := k.StopList
        Gui, Kitch:Add, Edit, x670 y%rowY% w150 h22 v%vStop%, %valStop%

        rowY += 26
    }

    rowY += 10
    Gui, Kitch:Font, s10 bold, Segoe UI
    Gui, Kitch:Add, Button, x10  y%rowY% w155 h32 gOpenPresetsEditor, ⚙ Пресети
    Gui, Kitch:Add, Button, x175 y%rowY% w180 h32 gSaveKitchens,     💾 Зберегти
    Gui, Kitch:Add, Button, x365 y%rowY% w200 h32 gResetKitchensOk,  🔄 Скинути в Стандарт
    Gui, Kitch:Add, Button, x575 y%rowY% w180 h32 gKitchClose,       ✖ Закрити
    Gui, Roll:Hide
    Gui, Kitch:Show, , Кухні — статуси
    WinActivate, Кухні — статуси
return

SaveKitchens:
    Gui, Kitch:Submit, NoHide
    for idx, k in Kitchens {
        vRem := "KRem_" . idx
        vCen := "KCen_" . idx
        vPic := "KPic_" . idx
        vFar := "KFar_" . idx
        vSto := "KSto_" . idx

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
        if (A_LoopField = val)
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
        if (A_LoopField = val) {
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
return

; ========================================================
; РОЗРАХУНОК ЧАСУ
; ========================================================
CalcPickup:
    CalcType := 40
    GoSub, ProcessTimeCalc
return
CalcDelivery:
    CalcType := 90
    GoSub, ProcessTimeCalc
return
ProcessTimeCalc:
    ; час готовності = ЗАРАЗ + offset (натиснув двічі — той самий результат, не накопичує)
    total := A_Hour*60 + A_Min + CalcType
    HH := Mod(Floor(total / 60), 24)
    MM := Mod(total, 60)
    GuiControl, Roll:, ReadyTimeH, % Format("{:02}", HH)
    GuiControl, Roll:, ReadyTimeM, % Format("{:02}", MM)
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
        Send, {Enter}
        Sleep, 300
        Send, ^a{BackSpace}
        Sleep, 50
        SendInput, %parsedSticksNorm%{Enter}
        Sleep, 500
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
        Send, {Enter}
        Sleep, 300
        Send, ^a{BackSpace}
        Sleep, 50
        SendInput, %parsedSticksEdu%{Enter}
        Sleep, 500
    }

    if (parsedUtensils != "" && parsedUtensils > 0) {
        Click, %itemX%, %itemY%
        Sleep, 400
        Send, {PgDn}
        Sleep, 300
        Send, {Enter}
        Sleep, 400
        SendInput, %pluUtensils%
        Sleep, 300
        Send, {Down}
        Sleep, 200
        Send, {Enter}
        Sleep, 300
        Send, ^a{BackSpace}
        Sleep, 50
        SendInput, %parsedUtensils%{Enter}
        Sleep, 500
    }

    Gui, Roll:Show
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
    Gui, SivVis:Add, Text,  x10  y45  w180, 🍣 ІНФО: Соуси пробиваються автоматично!
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
return

    ; ========================================================
    ; СИВ — ПРОБИТТЯ
; ========================================================
SivVisApply:
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

    VisRolls := (VisRolls = "") ? 0 : VisRolls + 0
    VisNorm := (VisNorm = "") ? 0 : VisNorm + 0
    VisEdu := (VisEdu = "") ? 0 : VisEdu + 0

    ; Соуси (СІВ): рахуємо від кількості ролів (поле «Роли»)
    _soyC := Ceil(VisRolls / 2.0)
    _soyM := (VisRolls < 2) ? VisRolls : 2
    soyQty := (VisRolls > 0) ? ((_soyC > _soyM) ? _soyC : _soyM) : 0
    gwQty  := (VisRolls > 0) ? Ceil(VisRolls / 4.0) : 0

    logFile := A_ScriptDir "\siv_debug.log"
    FileAppend, `n=== ПАЛОЧКИ СТАРТ === %A_Now%`n, %logFile%
    FileAppend, ДАНІ: Бамбукові=%VisNorm% | Навчальні=%VisEdu%`n, %logFile%
    FileAppend, ІНФО: Соуси (соєвий, імбир, васабі) пробиваються автоматично!`n, %logFile%

    ; ---- КРОК 1: Пробитие палочек через координати (без модифікаторів) ----
    if (VisNorm > 0 || VisEdu > 0) {
        ; Пробиваем через основное окно заказа (как купоны)
        if (VisNorm > 0 && itemX != 0) {
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
            Send, {Enter}
            Sleep, 300
            Send, ^a{BackSpace}
            Sleep, 50
            SendInput, %VisNorm%{Enter}
            Sleep, 500
        }

        if (VisEdu > 0 && itemX != 0) {
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
            Send, {Enter}
            Sleep, 300
            Send, ^a{BackSpace}
            Sleep, 50
            SendInput, %VisEdu%{Enter}
            Sleep, 500
        }
    }

    ; ---- КРОК 2: СОУСИ (соєвий ×soyQty, імбир/васабі ×gwQty) ----
    logFile := A_ScriptDir "\siv_debug.log"
    FileAppend, `n=== СИВ СТАРТ === %A_Now%`n, %logFile%
    FileAppend, soyQty=%soyQty% gwQty=%gwQty% VisRolls=%VisRolls%`n, %logFile%

    if (soyQty > 0 && itemX != 0) {
        Click, %itemX%, %itemY%
        Sleep, 400
        Send, {PgDn}
        Sleep, 300
        Send, {Enter}
        Sleep, 400
        SendInput, %pluSoy%
        Sleep, 300
        Send, {Down}
        Sleep, 200
        Send, {Enter}
        Sleep, 300
        Send, ^a{BackSpace}
        Sleep, 50
        SendInput, %soyQty%{Enter}
        Sleep, 500
    }
    if (gwQty > 0 && itemX != 0) {
        Click, %itemX%, %itemY%
        Sleep, 400
        Send, {PgDn}
        Sleep, 300
        Send, {Enter}
        Sleep, 400
        SendInput, %pluGinger%
        Sleep, 300
        Send, {Down}
        Sleep, 200
        Send, {Enter}
        Sleep, 300
        Send, ^a{BackSpace}
        Sleep, 50
        SendInput, %gwQty%{Enter}
        Sleep, 500

        Click, %itemX%, %itemY%
        Sleep, 400
        Send, {PgDn}
        Sleep, 300
        Send, {Enter}
        Sleep, 400
        SendInput, %pluWasabi%
        Sleep, 300
        Send, {Down}
        Sleep, 200
        Send, {Enter}
        Sleep, 300
        Send, ^a{BackSpace}
        Sleep, 50
        SendInput, %gwQty%{Enter}
        Sleep, 500
    }

    MouseMove, %originalMouseX%, %originalMouseY%, 0
    Gui, Roll:Show
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

; --------------------------------------------------------
; Обгортки для кожного елементу
SivClickStickNorm:
    sivImg := "img\item_sticks_norm.png"
    sivAmt := VisNorm
    sivOff := 228
    GoSub, SivDoClickWorker
return

SivClickStickEdu:
    sivImg := "img\item_sticks_edu.png"
    sivAmt := VisEdu
    sivOff := 169
    GoSub, SivDoClickWorker
return

SivClickSoy:
    sivImg := "img\item_soy.png"
    sivAmt := soyQty
    sivOff := SIVOffsetX
    GoSub, SivDoClickWorker
return

SivClickGinger:
    sivImg := "img\item_ginger.png"
    sivAmt := gwQty
    sivOff := SIVOffsetX
    GoSub, SivDoClickWorker
return

SivClickWasabi:
    sivImg := "img\item_wasabi.png"
    sivAmt := gwQty
    sivOff := SIVOffsetX
    GoSub, SivDoClickWorker
return

; --------------------------------------------------------
; Головний клікер по полю кількості
SivDoClickWorker:
    ImageSearch, fX, fY, 0, 0, A_ScreenWidth, A_ScreenHeight, *75 %sivImg%
    if (ErrorLevel == 0) {
        tX := fX + sivOff
        tY := fY + 8
        Click, %tX%, %tY%, 2
        Sleep, 50
        SendInput, ^a{BackSpace}%sivAmt%{Enter}
        Sleep, 50
        return
    }
    logFile := A_ScriptDir "\siv_debug.log"
    FileAppend, >> ПОМИЛКА: не знайдено %sivImg%`n, %logFile%
return

; ========================================================
; ФІНАЛЬНЕ ВНЕСЕННЯ
; ========================================================
ApplyRollclub:
    Gui, Roll:Submit, NoHide
    Gui, Roll:Destroy

    ; ==== DEBUG: лог запису ====
    FormatTime, _wT,, yyyy-MM-dd HH:mm:ss
    _w := "==== WRITE " . _wT . " | No=" . kcLastNo . " hasPickup=" . hasPickup . " ===="
    _w .= "`n comm : x=" . commX . " txt=[" . OrderComment . "]"
    _w .= "`n info : x=" . infoX . " txt=[" . ClientInfo . "]"
    _w .= "`n addr : x=" . addrX . " txt=[" . AddressNote . "]"
    _w .= "`n time : x=" . timeX . " h=" . ReadyTimeH . " m=" . ReadyTimeM
    _w .= "`n cash : do=" . DoAutoCash . " crossX=" . crossX . " cashX=" . cashX
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

    if (DoAutoCash == 1 && crossX != 0 && cashX != 0) {
        Sleep, 400
        Click, %crossX%, %crossY%
        Sleep, 400
        Click, %cashX%, %cashY%
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

    if ((autoGunkan || autoPepsi || autoBurger || autoSandwich) && itemX != 0) {
        if (autoBurger) {
            GoSub, NewGiftMacro
            SendInput, %pluBurger%
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

    if (itemX != 0) {
        if (VisNorm > 0) {
            GoSub, NewGiftMacro
            SendInput, %pluSticksNorm%
            Sleep, 300
            Send, {Down}
            Sleep, 200
            Send, {Enter}
            Sleep, 300
            Send, ^a{BackSpace}
            Sleep, 50
            SendInput, %VisNorm%{Enter}
            Sleep, 500
        }
        if (VisEdu > 0) {
            GoSub, NewGiftMacro
            SendInput, %pluSticksEdu%
            Sleep, 300
            Send, {Down}
            Sleep, 200
            Send, {Enter}
            Sleep, 300
            Send, ^a{BackSpace}
            Sleep, 50
            SendInput, %VisEdu%{Enter}
            Sleep, 500
        }

        ; Соуси НЕ б'ємо тут — їх б'є кнопка СІВ «Пробити ПАЛОЧКИ» (щоб не задвоїти)
        _s := 0
        _i := 0
        _w := 0

        if (_s > 0) {
            GoSub, NewGiftMacro
            SendInput, %pluSoy%
            Sleep, 300
            Send, {Down}{Enter}
            Sleep, 300
            Send, ^a{BackSpace}%_s%{Enter}
            Sleep, 500
        }
        if (_i > 0) {
            GoSub, NewGiftMacro
            SendInput, %pluGinger%
            Sleep, 300
            Send, {Down}{Enter}
            Sleep, 300
            Send, ^a{BackSpace}%_i%{Enter}
            Sleep, 500
        }
        if (_w > 0) {
            GoSub, NewGiftMacro
            SendInput, %pluWasabi%
            Sleep, 300
            Send, {Down}{Enter}
            Sleep, 300
            Send, ^a{BackSpace}%_w%{Enter}
            Sleep, 500
        }
    }

    ; --- Самовивіз: авто Концепція + Точка за точкою з коментаря (1:1) ---
    ; Концепцію беремо з таблиці PickupConcept(), вписуємо її → Tab → Space →
    ; PgUp → Enter (перевірена послідовність: після концепції список точок
    ; фільтрується, PgUp бере потрібну, "Ролл Клаб КЦ" не чіпаємо).
    if (autoMode && hasPickup && kontsX != 0) {
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
        }
    }

    if (autoMode) {
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
return

; ── ФІНІШ: Подтвердить → Зберегти на точку (Ctrl+Enter). Окремо, безпечно. ──
FinishOrder:
    FileAppend, % "[" . A_Now . "] FINISH confirm=" . confirmX . "," . confirmY . " save=" . saveX . "," . saveY . "`n", %A_ScriptDir%\ahk_debug.log
    if (confirmX = 0 || saveX = 0) {
        MsgBox, 48, Фініш, Приціли "Подтвердить"/"Зберегти на точку" не задані.`nНалаштування → калібрувати.
        return
    }
    MouseGetPos, _fmx, _fmy
    Click, %confirmX%, %confirmY%      ; Подтвердить
    Sleep, 700
    Click, %saveX%, %saveY%            ; Сохранить на точку
    Sleep, 400
    MouseMove, %_fmx%, %_fmy%, 0
    kcPaused := 0
    ToolTip, Confirmed + saved. Monitor resumed.
    SetTimer, RemoveFinishTip, -2000
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
    if (InStr(pt, "Драгоманова"))
        return "Київ Драгоманова"
    if (InStr(pt, "Конституції"))
        return "РК Харків Конституції Доставка"
    if (InStr(pt, "Садовий"))
        return "Харків Нові Дома"
    if (InStr(pt, "Липа"))
        return "Львов Липа"
    if (InStr(pt, "Лаврухіна"))
        return "Київ Лаврухіна"
    if (InStr(pt, "Мудрого"))
        return "Дніпро Мудрого"
    if (InStr(pt, "Стрільців"))
        return "Київ Стрільців"
    if (InStr(pt, "Антонова"))
        return "Київ Антонова"
    if (InStr(pt, "Вернадського") || InStr(pt, "Біла Церква"))
        return "Біла Церква"
    if (InStr(pt, "Незалежності") || InStr(pt, "Одеса"))
        return "Приморська"
    if (InStr(pt, "Перемоги") || InStr(pt, "Франківськ") || InStr(pt, "ІФ"))
        return "Франківськ Фудотека"
    if (InStr(pt, "Кулика") || InStr(pt, "Рівне"))
        return "Рівне"
    if (InStr(pt, "600") || InStr(pt, "Вінниця"))
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
    global rawAddress, hasPickup, RcZones, RcZonesOk, detectedCity
    SetTimer, RcCheckZone, Off
    addr := Trim(rawAddress)
    if (addr = "" || hasPickup) {
        GuiControl, Roll:, KitchenStatusText,
        return
    }
    addr := RegExReplace(addr, "i)[,\s]+(эт|поверх|кв|квартира|под|під|п|к|парадна)\.?\s*\d+.*$", "")
    addr := RegExReplace(addr, "i)^(Днепр|Дніпро|Харьков|Харків|Одесса|Одеса|Киев|Київ|Львов|Львів|Винница|Вінниця|Рівне|Ровно)[,\s]+", "")
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
        if (zone != "") {
            kAlertText := ""
            kAlertBeep := 0
            for _, k in Kitchens {
                kSearchTerm := (k.KmlKey != "") ? k.KmlKey : k.Name
                if (InStr(zone, kSearchTerm)) {
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
                    break
                }
            }
            if (kAlertBeep)
                SoundBeep, 600, 250
            result := zone
            RcLastZone := zone
            GuiControl, Roll:, MapSearch, %result%
            RhRegColor(hZoneBox, RhB_Green, RhB_White)
            DllCall("InvalidateRect", "Ptr", hZoneBox, "Ptr", 0, "Int", 1)
            GuiControl, Roll:, KitchenStatusText, %kAlertText%
            if (CHECK_POINT_ENABLED && !hasPickup && naitiX != 0 && tochkaX != 0)
                SetTimer, RcVerifyPoint, -300
        } else {
            result := "Точку не знайдено в зонах доставки"
            GuiControl, Roll:, MapSearch, %result%
            RhRegColor(hZoneBox, RhB_Red, RhB_White)
            DllCall("InvalidateRect", "Ptr", hZoneBox, "Ptr", 0, "Int", 1)
            GuiControl, Roll:, KitchenStatusText,
        }
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

; === RcVerifyPoint: натиснути "Найти точку", прочитати "Точка", звірити з нашою KML-зоною. Доставка. Один раз. Тільки попередження. ===
RcVerifyPoint:
    SetTimer, RcVerifyPoint, Off
    if (!CHECK_POINT_ENABLED || hasPickup || naitiX = 0 || tochkaX = 0)
        return
    if (iikoWinExe != "" && iikoWinExe != "ERROR")
        WinActivate, ahk_exe %iikoWinExe%
    Sleep, 150
    Click, %naitiX%, %naitiY%
    Sleep, 1800
    Clipboard := ""
    Click, %tochkaX%, %tochkaY%
    Sleep, 200
    Send, ^a
    Sleep, 60
    Send, ^c
    ClipWait, 0.8
    iikoPoint := Trim(Clipboard)
    Send, {Escape}
    matched := 0
    if (iikoPoint != "" && RcLastZone != "") {
        if (InStr(iikoPoint, RcLastZone) || InStr(RcLastZone, iikoPoint))
            matched := 1
        else {
            for _, k in Kitchens {
                kTerm := (k.KmlKey != "") ? k.KmlKey : k.Name
                if (kTerm != "" && InStr(RcLastZone, kTerm) && InStr(iikoPoint, kTerm)) {
                    matched := 1
                    break
                }
            }
        }
    }
    FormatTime, _vt,, yyyy-MM-dd HH:mm:ss
    FileAppend, % "==== POINT-CHECK " . _vt . " | our=[" . RcLastZone . "] iiko=[" . iikoPoint . "] match=" . matched . "`n", %A_ScriptDir%\parse_debug.log
    if (matched) {
        GuiControl, Roll:, MapSearch, % "ЗБІГ точки: " . iikoPoint
        RhRegColor(hZoneBox, RhB_Green, RhB_White)
        SoundBeep, 880, 90
    } else {
        GuiControl, Roll:, MapSearch, % "РОЗБІЖНІСТЬ! наша: " . RcLastZone . "  |  iiko: " . iikoPoint
        RhRegColor(hZoneBox, RhB_Red, RhB_White)
        SoundBeep, 440, 180
        Sleep, 80
        SoundBeep, 311, 280
    }
    DllCall("InvalidateRect", "Ptr", hZoneBox, "Ptr", 0, "Int", 1)
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
RhGet(endpoint, recvMs := 3000) {
    global RH_SERVER
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", RH_SERVER . endpoint, false)
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
