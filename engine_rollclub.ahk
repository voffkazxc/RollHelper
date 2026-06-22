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

IniRead, pluGunkan,   %ConfigPath%, PLU, Gunkan,   02929
IniRead, pluPepsi,    %ConfigPath%, PLU, Pepsi,    02216
IniRead, pluBurger,   %ConfigPath%, PLU, Burger,   02217
IniRead, pluSandwich, %ConfigPath%, PLU, Sandwich, 02926
IniRead, pluSticksNorm, %ConfigPath%, PLU, SticksNorm, 00143
IniRead, pluSticksEdu,  %ConfigPath%, PLU, SticksEdu,  00144
IniRead, pluUtensils,   %ConfigPath%, PLU, Utensils,   02439

IniRead, hkMain, %ConfigPath%, Hotkeys, Main, vkC0
IniRead, hkSiv,  %ConfigPath%, Hotkeys, Siv,  F1
IniRead, hkWait, %ConfigPath%, Hotkeys, WaitOrder, F2
IniRead, hkCall, %ConfigPath%, Hotkeys, WaitCall, F3

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
global RcZonesOk   := 0   ; 1 = KML завантажено

; ========================================================
; ГАРЯЧІ КЛАВІШІ
; ========================================================
Hotkey, %hkMain%, TriggerMain, On
Hotkey, %hkSiv%,  TriggerSiv,  On
Hotkey, %hkWait%, TriggerWait, On
Hotkey, %hkCall%, TriggerCall, On

SetTimer, RollFocusWatcher, 300

MsgBox, 64, Rollclub PRO 33.0, Готовий до роботи!, 2
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
    Gui, Roll:Destroy
    Gui, Roll:+AlwaysOnTop -MaximizeBox -MinimizeBox +ToolWindow
    Gui, Roll:Color, FFFFFF, FFFFFF
    Gui, Roll:Font, s9 cBlack, Segoe UI

    curY := 8

    ; ── Бренд + пошук точки на карті ──
    Gui, Roll:Font, s9 bold cBlack, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w46 h22 +0x200, Бренд:
    Gui, Roll:Font, s9 norm cBlack, Segoe UI
    Gui, Roll:Add, DropDownList, x58 y%curY% w276 vBrandSel gBrandChangeRC AltSubmit Choose2, 🏠 Roll House|🟢 Roll Club
    curY += 30
    Gui, Roll:Font, s11 norm cBlack, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w26 h22 +0x200, 🔎
    Gui, Roll:Font, s9 norm c808080, Segoe UI
    _mapInit := (rawAddress != "" && !hasPickup) ? "🔄 Визначаю зону..." : "Знайти точку на карті..."
    Gui, Roll:Add, Edit, x38 y%curY% w268 h22 vMapSearch, %_mapInit%
    Gui, Roll:Font, s9 norm cBlack, Segoe UI
    Gui, Roll:Add, Button, x310 y%curY% w24 h22 gRcLoadKmlFile, 📂
    curY += 26
    Gui, Roll:Font, s9 bold cRed, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w324 Center vKitchenStatusText
    curY += 16
    Gui, Roll:Font, s9 norm cBlack, Segoe UI

    ; ── АЛЕРТИ (компактні плашки) ──
    if (isFutureDate) {
        Gui, Roll:Color, FFF0F0
        Gui, Roll:Font, s11 bold cRed, Segoe UI
        futTxt := "⚠️ ПЕРЕДЗАМОВЛЕННЯ на " . warnReason
        if (futureTime != "")
            futTxt .= " о " . futureTime
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, %futTxt%
        curY += 22
        Gui, Roll:Font, s9 bold cRed, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, ‼ ЗМІНИ ДАТУ В IIKO! НЕ СЬОГОДНІ!
        curY += 20
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    }

    ; Заголовок міста та статус кухонь прибрано (тепер статус відображається прямо біля зони)

    if (addrMismatch) {
        Gui, Roll:Font, s10 bold cRed, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, 🚨 ВУЛИЦЯ ≠ АДРЕСА!
        curY += 18
        Gui, Roll:Font, s8 bold cRed, Segoe UI
        mismatchLine := "Комент: " . commentStreet . " / Адреса: " . SubStr(rawAddress, 1, 40)
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, %mismatchLine%
        curY += 18
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    }

    if (hasFilaClub) {
        Gui, Roll:Font, s10 bold cRed, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, ⚠ ПРОМОКОД FILACLUB — ПРОБИТИ!
        curY += 22
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    }

    if (hasAllergy) {
        Gui, Roll:Font, s10 bold cRed, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, 🚨 АЛЕРГІЯ — окремий бокс, ПІДПИСАТИ!
        curY += 22
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    }

    if (hasBirthday) {
        Gui, Roll:Font, s10 bold cFF6600, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, 🎂 ДЕНЬ НАРОДЖЕННЯ — знижка!
        curY += 22
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    }

    if (hasPickup) {
        pickLabel := "🥡 САМОВИВІЗ"
        if (pickupPoint != "") {
            pickLabel := pickLabel . " — " . pickupPoint
            ; Перевірити статус цієї кухні
            for _, k in Kitchens {
                if (InStr(pickupPoint, k.Name) || InStr(k.Name, pickupPoint)) {
                    pickExtra := ""
                    if (k.Pickup != "Стандарт")
                        pickExtra .= " ⏰ " . k.Pickup
                    if (k.StopList != "")
                        pickExtra .= " 🛑 " . k.StopList
                    if (pickExtra != "") {
                        pickLabel .= pickExtra
                        SoundBeep, 600, 250
                    }
                    break
                }
            }
        }
        Gui, Roll:Font, s10 bold c1B5E20, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, %pickLabel%
        curY += 22
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    }

    if (hasUtensils) {
        Gui, Roll:Font, s9 bold cFF00AA, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, 🍴 ПРИБОРИ %utensilsText% x%parsedUtensils% (PLU %pluUtensils%)
        curY += 20
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    }

    if (promoFound != "") {
        if (promoKnown) {
            Gui, Roll:Font, s9 bold c007700, Segoe UI
            promoMsg := "✅ Промо: " . promoFound . " (в базі)"
            Gui, Roll:Add, Text, x10 y%curY% w324 Center, %promoMsg%
            curY += 20
        } else {
            Gui, Roll:Font, s9 bold cRed, Segoe UI
            promoMsg := "❓ НОВИЙ ПРОМО: " . promoFound
            Gui, Roll:Add, Text, x10 y%curY% w210 +0x200, %promoMsg%
            Gui, Roll:Font, s8 norm cBlack, Segoe UI
            Gui, Roll:Add, Button, x226 y%curY% w108 h20 gAppendPromoToBase, ➕ В базу
            curY += 24
        }
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    }

    if (hasCustomerReq) {
        Gui, Roll:Font, s9 bold c8000FF, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324, 💬 ПРОХАННЯ КЛІЄНТА:
        curY += 16
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
        Gui, Roll:Add, Edit, x10 y%curY% w324 r2 ReadOnly, %customerReqText%
        curY += 36
    }

    if (needCall) {
        Gui, Roll:Font, s10 bold cFF4400, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, 📞 ПЕРЕДЗВОНИТИ КЛІЄНТУ!
        curY += 22
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    } else if (!isPost) {
        Gui, Roll:Font, s10 bold c0055CC, Segoe UI
        Gui, Roll:Add, Text, x10 y%curY% w324 Center, 🆕 НОВИЙ КЛІЄНТ — зателефонуй!
        curY += 22
        Gui, Roll:Font, s9 norm cBlack, Segoe UI
    }

    ; ── Вихідний текст (кнопка-тогл) ──
    Gui, Roll:Font, s9 norm c0C447C, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w270 +0x200 gRcToggleRawText, 👁️ Показати вихідний текст
    Gui, Roll:Add, Text, x284 y%curY% w50 Right +0x200 gRcToggleRawText vRcRawArrow, ▶ показати
    curY += 22

    ; ── Коментар ──
    Gui, Roll:Font, s9 bold cBlack, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w200, 📝 Коментар:
    curY += 16
    Gui, Roll:Font, s9 norm cBlack, Segoe UI
    Gui, Roll:Add, Edit, x10 y%curY% w324 r2 vOrderComment, %cleanComment%
    curY += 42

    ; ── Карта / Кухня / Адреса (в рядок) ──
    Gui, Roll:Font, s8 bold cBlack, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w52 h20 +0x200, 💳 Карта
    Gui, Roll:Font, s9 norm, Segoe UI
    Gui, Roll:Add, Edit, x64 y%curY% w270 h20 r1 vClientCard, %cardText%
    curY += 24
    Gui, Roll:Font, s8 bold cBlack, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w52 h20 +0x200, 🍳 Кухня
    Gui, Roll:Font, s9 norm, Segoe UI
    Gui, Roll:Add, Edit, x64 y%curY% w270 h20 r1 vClientInfo, %infoText%
    curY += 24
    Gui, Roll:Font, s8 bold cBlack, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w52 h20 +0x200, 🏠 Адреса
    Gui, Roll:Font, s9 norm, Segoe UI
    Gui, Roll:Add, Edit, x64 y%curY% w270 h20 r1 vAddressNote, %addrNote%
    curY += 28

    ; ── Сума + подарунки ──
    Gui, Roll:Font, s9 bold c0C447C, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w324 +0x200, 💰 Сума %orderSum% грн
    curY += 20
    Gui, Roll:Font, s8 norm cBlack, Segoe UI
    Gui, Roll:Add, Checkbox, x10  y%curY% w100 vGiftGunkan   Checked%autoGunkan%,   Гункан
    Gui, Roll:Add, Checkbox, x112 y%curY% w58  vGiftPepsi    Checked%autoPepsi%,    Пепсі
    Gui, Roll:Add, Checkbox, x172 y%curY% w62  vGiftBurger   Checked%autoBurger%,   Бургер
    Gui, Roll:Add, Checkbox, x236 y%curY% w98  vGiftSandwich Checked%autoSandwich%, Сендвіч
    curY += 22
    Gui, Roll:Add, Checkbox, x10  y%curY% w110 vGiftSticksNorm Checked%autoSticksNorm%, 🥢 Бамбук (%parsedSticksNorm%)
    Gui, Roll:Add, Checkbox, x124 y%curY% w108 vGiftSticksEdu  Checked%autoSticksEdu%,  🥢 Навч (%parsedSticksEdu%)
    Gui, Roll:Add, Checkbox, x236 y%curY% w98  vGiftUtensils   Checked%autoUtensils%,    🍴 Приб (%parsedUtensils%)
    curY += 24
    Gui, Roll:Font, s9 bold cD05000, Segoe UI
    Gui, Roll:Add, Checkbox, x10 y%curY% w324 vDoAutoCash Checked%autoCash%, 💵 Готівка (Решта з %calcChange%)
    curY += 28

    ; ── Час + калькулятор ──
    Gui, Roll:Font, s10 bold cBlack, Segoe UI
    Gui, Roll:Add, Text, x10 y%curY% w28 h24 +0x200, ⏱️
    Gui, Roll:Font, s10 norm, Segoe UI
    Gui, Roll:Add, Edit, x40 y%curY% w56 h22 vReadyTime Center, %extractedTime%
    Gui, Roll:Font, s8 bold, Segoe UI
    Gui, Roll:Add, Button, x102 y%curY% w110 h24 gCalcPickup,   🏃 СВ (+40)
    Gui, Roll:Add, Button, x216 y%curY% w118 h24 gCalcDelivery, 🚗 ДОСТ (+90)
    curY += 32

    ; ── Дії ──
    Gui, Roll:Font, s9 bold cBlack, Segoe UI
    Gui, Roll:Add, Button, x10  y%curY% w240 h28 gAddSticksOnly,     🥢 Пробити ПАЛОЧКИ
    Gui, Roll:Font, s11 norm, Segoe UI
    Gui, Roll:Add, Button, x256 y%curY% w36 h28 gOpenKitchensEditor, 🏪
    Gui, Roll:Add, Button, x298 y%curY% w36 h28 gOpenSettings,       ⚙️
    curY += 34

    Gui, Roll:Font, s11 bold cBlack, Segoe UI
    Gui, Roll:Add, Button, x10 y%curY% w324 h34 gApplyRollclub, ✔️ ВНЕСТИ В ЗАМОВЛЕННЯ
    curY += 38

    ; ── Прихований Edit для вихідного тексту (розкривається знизу) ──
    Gui, Roll:Font, s9 norm cBlack, Segoe UI
    Gui, Roll:Add, Edit, x10 y%curY% w324 r5 vRcRawEdit ReadOnly +Hidden, %rawComment%

    Gui, Roll:Show, x350 y20, Rollclub PRO 33.0
    Gui, Roll:+LastFound
    RollHwnd    := WinExist()
    RcRawShown  := 0
    GuiControlGet, _rp, Roll:Pos, RcRawEdit
    RcRawEditH  := _rph + 6
    if (rawAddress != "" && !hasPickup)
        SetTimer, RcCheckZone, -450
    MouseMove, 570, 250, 0
return

; ========================================================
; ЛОКАЛЬНІ ГАРЯЧІ КЛАВІШІ
; ========================================================
#IfWinActive Rollclub PRO 33.0
Enter::GoSub, ApplyRollclub
NumpadEnter::GoSub, ApplyRollclub
+Enter::Send, {Enter}
+NumpadEnter::Send, {Enter}
#IfWinActive

#IfWinActive СИВ (Модуль)
Enter::GoSub, SivVisApply
NumpadEnter::GoSub, SivVisApply
#IfWinActive

; ========================================================
; НАЛАШТУВАННЯ
; ========================================================
OpenSettings:
    Gui, Settings:Destroy
    Gui, Settings:+AlwaysOnTop +ToolWindow
    Gui, Settings:Font, s10 bold, Segoe UI
    Gui, Settings:Add, Text, w300 Center, 🎯 ПРИЦІЛЫ (Координати)
    Gui, Settings:Font, s9 norm, Segoe UI
    Gui, Settings:Add, Button, w140 x10 y+10 gSetCommTarget,  1. Коментар
    Gui, Settings:Add, Button, w140 x+10 yp  gSetCardTarget,  2. Карта Клієнта
    Gui, Settings:Add, Button, w140 x10  y+5 gSetInfoTarget,  3. Кухня
    Gui, Settings:Add, Button, w140 x+10 yp  gSetAddrTarget,  4. Адреса
    Gui, Settings:Add, Button, w140 x10  y+5 gSetTimeTarget,  Час
    Gui, Settings:Add, Button, w140 x+10 yp  gSetItemTarget,  Табл. Страв
    Gui, Settings:Add, Button, w140 x10  y+5 gSetCrossTarget, Хрестик Опл.
    Gui, Settings:Add, Button, w140 x+10 yp  gSetCashTarget,  Поле Оплати
    Gui, Settings:Add, Button, w140 x10  y+5 gSetSumTarget,   Сума Замовлення
    Gui, Settings:Add, Button, w140 x+10 yp  gCalibrateWaitZoneFromSettings,  🔲 Зона CRM (zxc)
    Gui, Settings:Add, Button, w140 x10  y+5 gSetCallTarget,  Авто-Прийом Дзв. (zxc1)
    Gui, Settings:Add, Button, w140 x+10 yp  gSetAdrReadTarget, 📍 Поле читання Адреси
    Gui, Settings:Add, Button, w290 x10  y+5 gSetKontsTarget,  🏪 Концепція (самовивіз)

    Gui, Settings:Font, s10 bold, Segoe UI
    Gui, Settings:Add, Text, w300 Center x10 y+15, 🎁 PLU КОДИ ПОДАРУНКІВ
    Gui, Settings:Font, s9 norm, Segoe UI
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

    Gui, Settings:Font, s10 bold, Segoe UI
    Gui, Settings:Add, Text, w300 Center x10 y+15, ⌨️ ГАРЯЧІ КЛАВІШІ
    Gui, Settings:Font, s9 norm, Segoe UI
    Gui, Settings:Add, Text, x10 y+10 w140, Головне меню:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkMain, %hkMain%
    Gui, Settings:Add, Text, x10 y+10 w140, Швидкий СИВ:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkSiv, %hkSiv%
    Gui, Settings:Add, Text, x10 y+10 w140, Авто-Прийом CRM:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkWait, %hkWait%
    Gui, Settings:Add, Text, x10 y+10 w140, Автоприйом Дзвінка:
    Gui, Settings:Add, Hotkey, x+5 yp-3 w140 vNewHkCall, %hkCall%

    Gui, Settings:Font, s10 bold, Segoe UI
    Gui, Settings:Add, Button, w290 h35 x10 y+15 gSaveSettings, 💾 Зберегти та Перезапустити
    Gui, Settings:Show,, Налаштування PRO
return

SaveSettings:
    Gui, Settings:Submit
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
    MsgBox, 4160, Налаштування, Клікни в поле КУХНЯ.
    KeyWait, LButton, Down
    MouseGetPos, infoX, infoY
    IniWrite, %infoX%, RkConfig.ini, Targets, InfoX
    IniWrite, %infoY%, RkConfig.ini, Targets, InfoY
    Gui, Settings:Show
return
SetAddrTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле АДРЕСА.
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
    HH := A_Hour
    MM := A_Min
    MM += CalcType
    HH += Floor(MM / 60)
    MM := Mod(MM, 60)
    HH := Mod(HH, 24)
    CalculatedTime := Format("{:02}:{:02}", HH, MM)
    GuiControl, Roll:, ReadyTime, %CalculatedTime%
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

    ; Соуси тепер пробиваються автоматично системою iiko
    soyQty := 0
    gwQty := 0
    
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

    ; ---- КРОК 2: СОУСИ (тепер пробиваються автоматично системою iiko) ----
    logFile := A_ScriptDir "\siv_debug.log"
    FileAppend, `n=== СИВ СТАРТ === %A_Now%`n, %logFile%
    FileAppend, soyQty=%soyQty% gwQty=%gwQty% VisRolls=%VisRolls%`n, %logFile%

    if (soyQty > 0 || gwQty > 0) {
        FileAppend, ІНФО: Соуси (соєвий, імбир, васабі) тепер пробиваються автоматично системою iiko!`n, %logFile%
        FileAppend, Розрахунок для довідки: Соя=%soyQty% | Імбир/Васабі=%gwQty%`n, %logFile%
    } else {
        FileAppend, soyQty=0 і gwQty=0 — соуси не потрібні`n, %logFile%
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
    Gui, Roll:Submit
    Gui, Roll:Destroy

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
        Click, %infoX%, %infoY%
        Sleep, 100
        Send, ^a
        Sleep, 50
        Send, ^v
    }

    if (AddressNote != "" && addrX != 0) {
        Clipboard := AddressNote
        Click, %addrX%, %addrY%
        Sleep, 200
        Send, ^a{BackSpace}^v
        Sleep, 300
    }

    if (ReadyTime != "" && timeX != 0) {
        Sleep, 300
        Click, %timeX%, %timeY%
        Sleep, 200
        timeParts := StrSplit(ReadyTime, ":")
        p1 := timeParts[1]
        p2 := timeParts[2]
        SendInput, ^a{BackSpace}%p1%{Right}%p2%{Enter}
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

    if ((GiftGunkan || GiftPepsi || GiftBurger || GiftSandwich) && itemX != 0) {
        if (GiftBurger) {
            GoSub, NewGiftMacro
            SendInput, %pluBurger%
            GoSub, FinishGiftMacro
        } else if (GiftSandwich) {
            GoSub, NewGiftMacro
            SendInput, %pluSandwich%
            GoSub, FinishGiftMacro
        } else if (GiftPepsi) {
            GoSub, NewGiftMacro
            SendInput, %pluPepsi%
            GoSub, FinishGiftMacro
        }
        if (GiftGunkan) {
            GoSub, NewGiftMacro
            SendInput, %pluGunkan%
            GoSub, FinishGiftMacro
        }
    }
    
    ; Автопробитие палочек (как гункан, но с количеством)
    if ((GiftSticksNorm || GiftSticksEdu) && itemX != 0) {
        if (GiftSticksNorm && parsedSticksNorm != "" && parsedSticksNorm > 0) {
            GoSub, NewGiftMacro
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
        if (GiftSticksEdu && parsedSticksEdu != "" && parsedSticksEdu > 0) {
            GoSub, NewGiftMacro
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
    }

    ; --- Самовивіз Садовий проїзд: виставляємо концепцію та точку ---
    if (hasPickup && InStr(pickupPoint, "Садовий") && kontsX != 0) {
        Sleep, 400
        Click, %kontsX%, %kontsY%       ; клік на поле "Концепція"
        Sleep, 300
        SetKeyDelay, 40
        Send, Дома                      ; вводимо назву концепції
        Sleep, 300
        Send, {Tab}                     ; Tab → підтвердити концепцію / перейти далі
        Sleep, 200
        Send, {Tab}                     ; Tab → поле "Точка"
        Sleep, 200
        Send, {Space}                   ; відкриваємо список
        Sleep, 200
        Send, {PgUp}                    ; прокручуємо до потрібної точки
        Sleep, 200
        Send, {Enter}                   ; підтверджуємо
        SetKeyDelay, -1
    }

    MouseMove, %originalMouseX%, %originalMouseY%, 0
return

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

; ── Попап «Вихідний текст» (за кліком на «показати») ──
RcToggleRawText:
    global RcRawShown, RcRawEditH, RollHwnd
    WinGetPos, , , , _h, ahk_id %RollHwnd%
    if (!RcRawShown) {
        GuiControl, Roll:Show, RcRawEdit
        GuiControl, Roll:, RcRawArrow, ▼ сховати
        WinMove, ahk_id %RollHwnd%, , , , , % _h + RcRawEditH
        RcRawShown := 1
    } else {
        GuiControl, Roll:Hide, RcRawEdit
        GuiControl, Roll:, RcRawArrow, ▶ показати
        WinMove, ahk_id %RollHwnd%, , , , , % _h - RcRawEditH
        RcRawShown := 0
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
    if (detectedCity != "") {
        encCity   := RcUriEncode(detectedCity)
        encStreet := RcUriEncode(addr)
        url := "https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&city=" . encCity . "&street=" . encStreet
    } else {
        url := "https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&q=" . RcUriEncode(addr)
    }
    resp := RcHttpGet(url, 6000)
    if (resp = "") {
        GuiControl, Roll:, MapSearch, ❓ Мережа недоступна
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
                    GuiControl, Roll:, MapSearch, ❓ Адресу не знайдено
                    return
                }
                resp := resp3
            } else {
                GuiControl, Roll:, MapSearch, ❓ Адресу не знайдено
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
                        parts .= "⏰ Центр: " . k.Center
                        kAlertBeep := 1
                    }
                    if (k.FarZone != "Стандарт") {
                        if (parts != "") parts .= " / "
                        parts .= "Дальня: " . k.FarZone
                        kAlertBeep := 1
                    }
                    if (k.Pickup != "Стандарт") {
                        if (parts != "") parts .= " / "
                        parts .= "🥡 Самовивіз: " . k.Pickup
                        kAlertBeep := 1
                    }
                    if (k.StopList != "") {
                        if (parts != "") parts .= "   "
                        parts .= "🛑 " . k.StopList
                        kAlertBeep := 1
                    }
                    if (k.Remark != "") {
                        if (parts != "") parts .= "   "
                        parts .= "📌 " . k.Remark
                    }
                    kAlertText := parts
                    break
                }
            }
            if (kAlertBeep)
                SoundBeep, 600, 250
            result := "📍 " . zone
            GuiControl, Roll:, KitchenStatusText, %kAlertText%
        } else {
            result := "⚠️ Поза зонами доставки"
            GuiControl, Roll:, KitchenStatusText,
        }
    } else if (!FileExist(kmlPath)) {
        result := "⚠️ KML не знайдено"
        GuiControl, Roll:, KitchenStatusText,
    } else if (!RcZonesOk) {
        result := "⚠️ KML: помилка читання"
        GuiControl, Roll:, KitchenStatusText,
    } else {
        result := "📍 " . lat . ", " . lng
        GuiControl, Roll:, KitchenStatusText,
    }
    GuiControl, Roll:, MapSearch, %result%
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
    if (!xml.load(kmlPath))
        return
    placemarks := xml.getElementsByTagName("Placemark")
    Loop % placemarks.length {
        pm := placemarks.item(A_Index - 1)
        nameNodes := pm.getElementsByTagName("name")
        zoneName  := (nameNodes.length > 0) ? Trim(RegExReplace(nameNodes.item(0).text, "[\r\n]+", " ")) : ("Зона " A_Index)
        coordNodes := pm.getElementsByTagName("coordinates")
        if (coordNodes.length = 0)
            continue
        coordText := Trim(coordNodes.item(0).text)
        coords := []
        Loop, Parse, coordText, `n, `r
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
