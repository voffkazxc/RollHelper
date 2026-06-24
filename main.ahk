#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
FileEncoding, UTF-8

; ══════════════════════════════════════════════════════════════
;  RollHelper — ВИБІР БРЕНДУ (Roll House / Roll Club)
;  Активний бренд зберігається у settings.ini (секція App, ключ Brand).
;  Дані бренду лежать у brands\<brand>\ — туди ж переводимо робочу папку,
;  тож усі відносні файли (RkConfig.ini, RkTemplates.txt, img\, DeliveryPrices.ini)
;  читаються саме з папки активного бренду. Сервер — спільний (APP_DIR\server).
; ══════════════════════════════════════════════════════════════
global APP_DIR := A_ScriptDir
IniRead, BrandActive, %APP_DIR%\settings.ini, App, Brand, rollhouse
; Лаунчер: якщо збережений бренд — Roll Club, відразу запускаємо його движок і виходимо.
; (main.ahk — це движок Roll House; Roll Club має власний engine_rollclub.ahk)
if (BrandActive = "rollclub") {
    Run, "%A_AhkPath%" "%APP_DIR%\engine_rollclub.ahk"
    ExitApp
}
global BRAND := "rollhouse"
global BRAND_DIR := APP_DIR . "\brands\rollhouse"
global RhEnterBusy := 0
global RhLastEnterTick := 0
global RhEnterCooldownMs := 2500
SetWorkingDir, %BRAND_DIR%

; ══════════════════════════════════════════════════════════════
;  RollHouse PRO — CRM-хелпери
; ══════════════════════════════════════════════════════════════
global crmCache     := {}   ; phone → badge text
global crmCacheTs   := {}   ; phone → timestamp (ms)
global CRM_CACHE_TTL := 300000  ; 5 хвилин

; Нормалізує телефон до 12-цифрового формату 380XXXXXXXXX
RhNormalizePhone(phone) {
    digits := RegExReplace(phone, "\D", "")
    if (SubStr(digits,1,3) = "380")
        return digits
    if (SubStr(digits,1,2) = "80" && StrLen(digits) = 11)
        return "3" . digits
    if (SubStr(digits,1,1) = "0" && StrLen(digits) = 10)
        return "38" . digits
    if (StrLen(digits) = 9)
        return "380" . digits
    return digits
}

; Повертає текст-підказку про клієнта для GUI (одним рядком)
RhCustomerBadge(phone) {
    global crmCache, crmCacheTs, CRM_CACHE_TTL
    if (!RH_SERVER_OK || phone = "")
        return ""
    norm := RhNormalizePhone(phone)
    ; Кеш — не долбимо сервер повторно
    if (crmCache[norm] != "" && (A_TickCount - crmCacheTs[norm]) < CRM_CACHE_TTL)
        return crmCache[norm]
    resp := RhGetCustomer(phone)
    if (resp = "")
        return ""
    ; Парсимо JSON вручну (AHK v1 немає JSON-бібліотеки)
    exists := InStr(resp, """exists"": true") || InStr(resp, """exists"":true")
    if (!exists)
        return "🆕 Новий клієнт"
    vip     := InStr(resp, """vip"": 1") || InStr(resp, """vip"":1")
    problem := InStr(resp, """problem"": 1") || InStr(resp, """problem"":1")
    ; Витягуємо total_orders
    RegExMatch(resp, """total_orders""\s*:\s*(\d+)", mO)
    orders := mO1 + 0
    RegExMatch(resp, """total_spent""\s*:\s*([\d\.]+)", mS)
    spent  := Round(mS1 + 0)
    RegExMatch(resp, """name""\s*:\s*""([^""]*)", mN)
    name   := mN1
    ; Витягуємо нотатки
    RegExMatch(resp, """notes""\s*:\s*""([^""]*)", mNotes)
    notes  := mNotes1

    badge := ""
    if (problem)
        badge .= "⚠️ ПРОБЛЕМНИЙ  "
    if (vip)
        badge .= "⭐ VIP  "
    if (name != "")
        badge .= name . "  "
    badge .= "📦 " . orders . " зам."
    if (spent > 0)
        badge .= "  💰 " . spent . " грн"
    if (notes != "")
        badge .= "  📝 " . notes
    ; Зберегти в кеш
    crmCache[norm]   := badge
    crmCacheTs[norm] := A_TickCount
    return badge
}

; Показує CRM-картку в маленькому попапі (для обзвону)
ShowCrmPopup(phone) {
    if (!RH_SERVER_OK || phone = "")
        return
    badge := RhCustomerBadge(phone)
    GuiControl, CallGui:, CallCrmLbl, % badge = "" ? "🆕 Новий клієнт" : badge
}

; ══════════════════════════════════════════════════════════════
;  RollHouse PRO — HTTP-хелпери для Python-сервера
;  Сервер: http://127.0.0.1:5000
; ══════════════════════════════════════════════════════════════
global RH_SERVER := "http://127.0.0.1:5000"
global RH_SERVER_OK := 0   ; 1 коли сервер відповів на ping

; Запит GET, повертає тіло відповіді або ""
; recvMs — таймаут отримання відповіді (мс). КОРОТКИЙ за замовчуванням,
; щоб «задуманий» сервер не морозив увесь скрипт на десятки секунд.
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

; Запит POST з JSON-тілом, повертає тіло відповіді або ""
RhPost(endpoint, jsonBody, recvMs := 3000) {
    global RH_SERVER
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", RH_SERVER . endpoint, false)
        whr.SetTimeouts(1500, 1500, recvMs, recvMs)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(jsonBody)
        return whr.ResponseText
    }
    return ""
}

; Перевірити чи сервер живий (швидкий пінг — макс ~1.2с)
RhPing() {
    global RH_SERVER_OK
    resp := RhGet("/ping", 1200)
    RH_SERVER_OK := (InStr(resp, "ok") > 0) ? 1 : 0
    return RH_SERVER_OK
}

; Отримати дані клієнта по номеру (повертає JSON-рядок або "")
RhGetCustomer(phone) {
    phone := RegExReplace(phone, "[\s\-\(\)\+]", "")
    return RhGet("/api/customer/" . phone)
}

; Зберегти/оновити клієнта
RhSaveCustomer(phone, name="", notes="", vip=0, problem=0) {
    phone := RegExReplace(phone, "[\s\-\(\)\+]", "")
    json  := "{""phone"":""" . phone . """,""name"":""" . name . """,""notes"":""" . notes . """,""vip"":" . vip . ",""problem"":" . problem . "}"
    return RhPost("/api/customer", json)
}

; Залогувати дзвінок
RhLogCall(phone, answered=0, duration=0) {
    phone := RegExReplace(phone, "[\s\-\(\)\+]", "")
    json  := "{""phone"":""" . phone . """,""answered"":" . answered . ",""duration"":" . duration . "}"
    RhPost("/api/call", json)
}

; --- ГЛОБАЛЬНІ НАЛАШТУВАННЯ ---
SetBatchLines, -1       
SetDefaultMouseSpeed, 0 
SetMouseDelay, -1       

global SIVOffsetX := 210 
global SIVOffsetY := 8   

; --- ІНІЦІАЛІЗАЦІЯ ТА КОНФІГ ---
IniRead, commX, RkConfig.ini, Targets, CommX, 0
IniRead, commY, RkConfig.ini, Targets, CommY, 0
IniRead, cardX, RkConfig.ini, Targets, CardX, 0
IniRead, cardY, RkConfig.ini, Targets, CardY, 0
IniRead, infoX, RkConfig.ini, Targets, InfoX, 0
IniRead, infoY, RkConfig.ini, Targets, InfoY, 0
IniRead, addrX, RkConfig.ini, Targets, AddrX, 0
IniRead, addrY, RkConfig.ini, Targets, AddrY, 0
IniRead, timeX, RkConfig.ini, Targets, TimeX, 0
IniRead, timeY, RkConfig.ini, Targets, TimeY, 0
IniRead, cashX, RkConfig.ini, Targets, CashX, 0
IniRead, cashY, RkConfig.ini, Targets, CashY, 0
IniRead, crossX, RkConfig.ini, Targets, CrossX, 0
IniRead, crossY, RkConfig.ini, Targets, CrossY, 0
IniRead, itemX, RkConfig.ini, Targets, ItemX, 0
IniRead, itemY, RkConfig.ini, Targets, ItemY, 0
IniRead, sumX, RkConfig.ini, Targets, SumX, 0
IniRead, sumY, RkConfig.ini, Targets, SumY, 0
IniRead, callX, RkConfig.ini, Targets, CallX, 0
IniRead, callY, RkConfig.ini, Targets, CallY, 0
IniRead, streetX, RkConfig.ini, Targets, StreetX, 0
IniRead, streetY, RkConfig.ini, Targets, StreetY, 0
IniRead, phoneX,  RkConfig.ini, Targets, PhoneX,  0
IniRead, phoneY,  RkConfig.ini, Targets, PhoneY,  0
IniRead, aikoInputX,  RkConfig.ini, Targets, AikoInputX,  0
IniRead, aikoInputY,  RkConfig.ini, Targets, AikoInputY,  0
IniRead, aikoCallX,   RkConfig.ini, Targets, AikoCallX,   0
IniRead, aikoCallY,   RkConfig.ini, Targets, AikoCallY,   0
IniRead, aikoHangupX,    RkConfig.ini, Targets, AikoHangupX,    0
IniRead, aikoHangupY,    RkConfig.ini, Targets, AikoHangupY,    0
IniRead, callEndX,       RkConfig.ini, Targets, CallEndX,       0
IniRead, callEndY,       RkConfig.ini, Targets, CallEndY,       0
IniRead, iikoWinExe,     RkConfig.ini, Targets, IikoWinExe,     ""
IniRead, iikoWinW,       RkConfig.ini, Targets, IikoWinW,       0
IniRead, iikoWinH,       RkConfig.ini, Targets, IikoWinH,       0
; --- Позиція головного вікна (запам'ятовується між запусками) ---
IniRead, rollWinX, RkConfig.ini, Window, RollX, 350
IniRead, rollWinY, RkConfig.ini, Window, RollY, 20
; --- Відносні координати (зміщення від кута вікна iiko) ---
IniRead, commRelX,  RkConfig.ini, TargetsRel, CommX,  0
IniRead, commRelY,  RkConfig.ini, TargetsRel, CommY,  0
IniRead, cardRelX,  RkConfig.ini, TargetsRel, CardX,  0
IniRead, cardRelY,  RkConfig.ini, TargetsRel, CardY,  0
IniRead, infoRelX,  RkConfig.ini, TargetsRel, InfoX,  0
IniRead, infoRelY,  RkConfig.ini, TargetsRel, InfoY,  0
IniRead, addrRelX,  RkConfig.ini, TargetsRel, AddrX,  0
IniRead, addrRelY,  RkConfig.ini, TargetsRel, AddrY,  0
IniRead, timeRelX,  RkConfig.ini, TargetsRel, TimeX,  0
IniRead, timeRelY,  RkConfig.ini, TargetsRel, TimeY,  0
IniRead, cashRelX,    RkConfig.ini, TargetsRel, CashX,     0
IniRead, cashRelY,    RkConfig.ini, TargetsRel, CashY,     0
IniRead, cashX,       RkConfig.ini, Targets,    CashX,     0
IniRead, cashY,       RkConfig.ini, Targets,    CashY,     0
IniRead, gotivkaX,    RkConfig.ini, Targets,    GotivkaX,  0
IniRead, gotivkaY,    RkConfig.ini, Targets,    GotivkaY,  0
IniRead, cardTermX,   RkConfig.ini, Targets,    CardTermX, 0
IniRead, cardTermY,   RkConfig.ini, Targets,    CardTermY, 0
; Слова для пошуку типу оплати у списку iiko (друкуються, щоб відфільтрувати пункт)
IniRead, paymentCashSearch, RkConfig.ini, Payment, CashSearch, готі
IniRead, paymentCardSearch, RkConfig.ini, Payment, CardSearch, банк
IniRead, changeX,    RkConfig.ini, Targets,    ChangeX, 0
IniRead, changeY,    RkConfig.ini, Targets,    ChangeY, 0
IniRead, changeRelX, RkConfig.ini, TargetsRel, ChangeX, 0
IniRead, changeRelY, RkConfig.ini, TargetsRel, ChangeY, 0
IniRead, crossRelX, RkConfig.ini, TargetsRel, CrossX, 0
IniRead, crossRelY, RkConfig.ini, TargetsRel, CrossY, 0
IniRead, itemRelX,  RkConfig.ini, TargetsRel, ItemX,  0
IniRead, itemRelY,  RkConfig.ini, TargetsRel, ItemY,  0
IniRead, sumRelX,   RkConfig.ini, TargetsRel, SumX,   0
IniRead, sumRelY,   RkConfig.ini, TargetsRel, SumY,   0
IniRead, callRelX,  RkConfig.ini, TargetsRel, CallX,  0
IniRead, callRelY,  RkConfig.ini, TargetsRel, CallY,  0
IniRead, streetRelX, RkConfig.ini, TargetsRel, StreetX, 0
IniRead, streetRelY, RkConfig.ini, TargetsRel, StreetY, 0
IniRead, phoneRelX,  RkConfig.ini, TargetsRel, PhoneX,  0
IniRead, phoneRelY,  RkConfig.ini, TargetsRel, PhoneY,  0
; Клавіша, що "натискає кнопку розмови" коли скрипт побачив картинку call_start.png
IniRead, hkAcceptTalk,  RkConfig.ini, Hotkeys, AcceptTalk,  Enter
IniRead, hkCallNext,    RkConfig.ini, Hotkeys, CallNext,    Space
IniRead, hkCallHangup,  RkConfig.ini, Hotkeys, CallHangup,  x
IniRead, hkCallPause,   RkConfig.ini, Hotkeys, CallPause,   p
IniRead, soundpadKeys,  RkConfig.ini, Hotkeys, SoundpadKeys, 1|x
; soundpadKeys — клавіші Soundpad через "|" (напр. "1|x|F9")
; Під час заморозки AHK блокує ці клавіші від Soundpad
global callWaitDeadline := 0  ; час (ms тіки) до якого чекаємо появу картинки розмови

; --- Режим обзвону ---
global callListMode := 0    ; 0=вимкнено, 1=ввімкнено
global callList := []       ; масив номерів
global callListIdx := 0     ; індекс наступного для дзвінка (1-based, 0=ще не дзвонили)
global callListCount := 0   ; всього в списку
global callMode := 0
global callAutoNext := 0    ; 1 = чекаємо кінця розмови для авто-переходу до наступного
global callPaused := 0      ; 1 = пауза, не переходимо до наступного
global callNoAnswer := 0    ; лічильник "не відповів / зайнято / скинув"
global callDialing := 0     ; 1 = зараз дзвонимо (ще не відповіли)
global callFrozen := 0      ; 1 = заморожено (вікно приховано, хоткеї вимкнено, прогрес збережено)
global iikoWinExe           ; exe процесу iiko (авто-визначається при першому налаштуванні прицілу)
global commRelX, commRelY, cardRelX, cardRelY, infoRelX, infoRelY
global addrRelX, addrRelY, timeRelX, timeRelY, cashRelX, cashRelY
global crossRelX, crossRelY, itemRelX, itemRelY, sumRelX, sumRelY
global callRelX, callRelY, streetRelX, streetRelY, phoneRelX, phoneRelY

; --- Хелпер: абсолютні координати з урахуванням позиції І розміру вікна iiko ---
; Якщо вікно змінило розмір — координати масштабуються пропорційно.
IikoXY(relX, relY, absX, absY, ByRef outX, ByRef outY) {
    global iikoWinExe, iikoWinW, iikoWinH
    outX := absX
    outY := absY
    if (!relX || relX = "ERROR" || iikoWinExe = "" || iikoWinExe = "ERROR")
        return
    WinGetPos, _wx, _wy, _wW, _wH, ahk_exe %iikoWinExe%
    if (ErrorLevel)
        return
    ; Якщо знаємо калібрований розмір — масштабуємо (працює при будь-якому розмірі)
    if (iikoWinW > 0 && iikoWinH > 0 && _wW > 0 && _wH > 0) {
        outX := Round(_wx + relX * _wW / iikoWinW)
        outY := Round(_wy + relY * _wH / iikoWinH)
    } else {
        outX := _wx + relX
        outY := _wy + relY
    }
}

; --- Активувати iiko (розгорнути якщо згорнуте, вивести на передній план) ---
IikoRestore() {
    global iikoWinExe
    if (iikoWinExe = "" || iikoWinExe = "ERROR")
        return
    WinActivate, ahk_exe %iikoWinExe%
    Sleep, 150
}

; ──────────────────────────────────────────────────────────────
; IikoClickAt(screenX, screenY) — клік в iiko БЕЗ руху миші
; Використовує ControlClick з флагом NA (PostMessage):
;   • фізична миша не рухається
;   • iiko не обов'язково має бути активним вікном
;   • ти можеш вільно користуватись мишею поки скрипт працює
; ──────────────────────────────────────────────────────────────
IikoClickAt(screenX, screenY, dbl=0) {
    global iikoWinExe
    if (iikoWinExe = "" || iikoWinExe = "ERROR")
        return
    ; Фізичний клік — DevExpress таблиця страв ігнорує ControlClick NA
    WinActivate, ahk_exe %iikoWinExe%
    Sleep, 80
    if (dbl)
        Click, %screenX%, %screenY%, 2
    else
        Click, %screenX%, %screenY%
}

; Те саме але приймає relX/relY/absX/absY (як IikoXY)
IikoClickRel(relX, relY, absX, absY, dbl=0) {
    IikoXY(relX, relY, absX, absY, _sx, _sy)
    IikoClickAt(_sx, _sy, dbl)
}

; ──────────────────────────────────────────────────────────────
; IikoPaste — вставити text у поле iiko КЛІКОМ по прицілу.
; Кожне поле керується своїм прицілом → передбачувано, без UIA.
; Координати масштабуються від положення/розміру вікна iiko (IikoXY).
; ──────────────────────────────────────────────────────────────
IikoPaste(relX, relY, absX, absY, text) {
    global iikoWinExe
    if (text = "")
        return
    if ((absX = 0 || absX = "ERROR") && (relX = 0 || relX = "ERROR" || relX = ""))
        return
    IikoXY(relX, relY, absX, absY, _x, _y)
    if (_x = "" || _x = 0)
        return
    Clipboard := text
    ClipWait, 1
    Click, %_x%, %_y%
    Sleep, % SpDly(150)
    Send, ^a
    Sleep, 50
    Send, ^v
    Sleep, % SpDly(150)
}

; ──────────────────────────────────────────────────────────────
; IikoCopyField — ПРОЧИТАТИ поле iiko кліком + Ctrl+A + Ctrl+C.
; Замінює сервер: текст замовлення беремо прямо з полів, без Python.
; Повертає вміст буфера або "".
; ──────────────────────────────────────────────────────────────
IikoCopyField(relX, relY, absX, absY) {
    global iikoWinExe
    if ((absX = 0 || absX = "ERROR") && (relX = 0 || relX = "ERROR" || relX = ""))
        return ""
    IikoXY(relX, relY, absX, absY, _x, _y)
    if (_x = "" || _x = 0)
        return ""
    if (iikoWinExe != "" && iikoWinExe != "ERROR")
        WinActivate, ahk_exe %iikoWinExe%
    Clipboard := ""
    Click, %_x%, %_y%
    Sleep, % SpDly(140)
    Send, ^a
    Sleep, 60
    Send, ^c
    ClipWait, 0.6
    _val := Clipboard
    return _val
}

; ──────────────────────────────────────────────────────────────
; ВИДИМИЙ клік: рухає РЕАЛЬНУ мишу до точки + показує підказку.
; Щоб оператор БАЧИВ, куди скрипт клікає (кінець «бою з тінню»).
; ──────────────────────────────────────────────────────────────
IikoClickAtV(screenX, screenY, label, dbl=0) {
    global iikoWinExe, speedMode
    if (screenX = "" || screenX = 0)
        return
    _ttx := screenX + 18
    _tty := screenY - 14
    ToolTip, % label, %_ttx%, %_tty%
    WinActivate, ahk_exe %iikoWinExe%
    moveSpeed := (speedMode = 3) ? 3 : ((speedMode = 2) ? 7 : 14)  ; повільніше в Безпечному
    MouseMove, %screenX%, %screenY%, %moveSpeed%
    Sleep, % SpDly(140)
    if (dbl)
        Click, %screenX%, %screenY%, 2
    else
        Click, %screenX%, %screenY%
    Sleep, % SpDly(140)
}

; Те саме, але приймає rel/abs (масштабується від вікна iiko)
IikoClickRelV(relX, relY, absX, absY, label, dbl=0) {
    IikoXY(relX, relY, absX, absY, _vx, _vy)
    IikoClickAtV(_vx, _vy, label, dbl)
}

; ──────────────────────────────────────────────────────────────
; ShowTarget — навести мишу на збережений приціл і показати підпис.
; Для кнопки «Перевірити приціли»: оператор бачить, де стоїть кожен маркер.
; ──────────────────────────────────────────────────────────────
ShowTarget(x, y, label) {
    if (x = "" || x = 0 || x = "ERROR") {
        ToolTip, % "❌ " . label . " — НЕ задано", 30, 30
        Sleep, 800
        return
    }
    MouseMove, %x%, %y%, 12
    _stx := x + 18
    _sty := y + 18
    ToolTip, % "📍 " . label, %_stx%, %_sty%
    Sleep, 950
}

; Відправити клавіші в iiko не активуючи вікно
IikoSend(keys) {
    global iikoWinExe
    ControlSend,, %keys%, ahk_exe %iikoWinExe%
}

; Фокусує поле через UIA (Python SetFocus), активує iiko БЕЗ руху миші,
; потім вставляє text через Send (йде в активне iiko → в сфокусоване поле).
IikoFocusPaste(autoId, text) {
    global RH_SERVER_OK, iikoWinExe
    if (!RH_SERVER_OK || text = "")
        return
    RhPost("/api/iiko/focus/" . autoId, "{}")   ; UIA SetFocus
    Sleep, 80
    WinActivate, ahk_exe %iikoWinExe%           ; iiko виходить на перед (без миші)
    Sleep, 80
    Clipboard := text
    ClipWait, 1
    Send, ^a                                     ; → в сфокусований контрол iiko
    Sleep, 40
    Send, ^v
    Sleep, 120
}

; Фокусує поле і активує iiko (для довільних Send-команд після виклику).
; Повертає 1 якщо сервер доступний.
IikoFocusField(autoId) {
    global RH_SERVER_OK, iikoWinExe
    if (!RH_SERVER_OK)
        return 0
    RhPost("/api/iiko/focus/" . autoId, "{}")
    Sleep, 80
    WinActivate, ahk_exe %iikoWinExe%
    Sleep, 80
    return 1
}

IniRead, pluPromo, RkConfig.ini, PLU, Promo, 0000
IniRead, pluPepsi, RkConfig.ini, PLU, Pepsi, 02216
IniRead, pluBrooklyn, RkConfig.ini, PLU, Brooklyn, 0000
IniRead, pluBurger, RkConfig.ini, PLU, Burger, 0000

; --- Пороги подарунків (грн) ---
IniRead, giftPepsiThreshold, RkConfig.ini, Gifts, PepsiThreshold, 699
IniRead, giftBrooklynThreshold, RkConfig.ini, Gifts, BrooklynThreshold, 899
IniRead, giftBurgerThreshold, RkConfig.ini, Gifts, BurgerThreshold, 1299

; --- PLU СИВ (палички, соус, імбир, васабі) ---
IniRead, pluSticksNorm, RkConfig.ini, PLU_SIV, SticksNorm, 00430
IniRead, pluSticksEdu,  RkConfig.ini, PLU_SIV, SticksEdu,  00432
IniRead, pluSoy,        RkConfig.ini, PLU_SIV, Soy,        00424
IniRead, pluGinger,     RkConfig.ini, PLU_SIV, Ginger,     00428
IniRead, pluWasabi,     RkConfig.ini, PLU_SIV, Wasabi,     00426
; Глобальний режим швидкості скрипта: 1=Безпечно, 2=Норма, 3=Швидко
IniRead, speedMode, RkConfig.ini, Speed, Mode, 3
IniRead, uiTheme, RkConfig.ini, UI, Theme, light
global speedMode, uiTheme

IniRead, p1X, RkConfig.ini, Autopilot, P1X, 0
IniRead, p1Y, RkConfig.ini, Autopilot, P1Y, 0
IniRead, p2X, RkConfig.ini, Autopilot, P2X, 0
IniRead, p2Y, RkConfig.ini, Autopilot, P2Y, 0
IniRead, p3X, RkConfig.ini, Autopilot, P3X, 0
IniRead, p3Y, RkConfig.ini, Autopilot, P3Y, 0
IniRead, p4X, RkConfig.ini, Autopilot, P4X, 0
IniRead, p4Y, RkConfig.ini, Autopilot, P4Y, 0
IniRead, p5X, RkConfig.ini, Autopilot, P5X, 0
IniRead, p5Y, RkConfig.ini, Autopilot, P5Y, 0
IniRead, p6X, RkConfig.ini, Autopilot, P6X, 0
IniRead, p6Y, RkConfig.ini, Autopilot, P6Y, 0
IniRead, tgGroup, RkConfig.ini, Autopilot, TgGroup, Call-center Roll-House

IniRead, hkMain, RkConfig.ini, Hotkeys, Main, vkC0
IniRead, hkSiv, RkConfig.ini, Hotkeys, Siv, F1

IfNotExist, RkTemplates.txt
    FileAppend, Доставка Мерефа: 100 грн`nДоставка Чугуїв: 100 грн`nДоставка Берестин: 120 грн`nПереказ на карту кур'єру`nБез здачі`nподзвонити по готовності, RkTemplates.txt

global rawComment := "", infoText := "", addrNote := "", cleanComment := "", extractedTime := "", clientChange := "", cardText := "", streetText := ""
global clientPhone := ""   ; номер телефону поточного клієнта
global autoPromo := 0, autoPepsi := 0, autoBrooklyn := 0, autoBurger := 0, orderSum := 0, autoCash := 0, autoCard := 0, calcChange := 0
global parsedSticksNorm := "", parsedSticksEdu := ""
global RcZones   := []  ; кеш полігонів з KML [{name, coords:[...]}]
global RcZonesOk := 0   ; 1 = KML вже завантажено
global RhStaticColors := {}
global RhStaticBrush  := {}
OnMessage(0x0138, "WM_CTLCOLORSTATIC")

; --- ЗАХИСТ ВІД КРИВИХ ГАРЯЧИХ КЛАВІШ ---
Hotkey, %hkMain%, TriggerMain, On, UseErrorLevel
if (ErrorLevel) {
    hkMain := "vkC0"
    IniWrite, %hkMain%, RkConfig.ini, Hotkeys, Main
    Hotkey, %hkMain%, TriggerMain, On
}

Hotkey, %hkSiv%, TriggerSiv, On, UseErrorLevel
if (ErrorLevel) {
    hkSiv := "F1"
    IniWrite, %hkSiv%, RkConfig.ini, Hotkeys, Siv
    Hotkey, %hkSiv%, TriggerSiv, On
}

TrayTip, RollHouse, ✅ Запущено (режим %speedMode%), 2, 1

; --- RollHelper: відкрити ВЕБ-пульт у вікні Edge (бета) ---
Menu, Tray, Add
Menu, Tray, Add, 🌐 Веб-пульт (бета), OpenWebPult

; --- Запуск Python-сервера (читає поля iiko «по іменах», надійніше за прицели) ---
; Сервер спільний для брендів; беремо вже робочий поряд: APP_DIR\..\server.
if (!RhPing()) {
    _serverDir := APP_DIR . "\..\server"
    Run, pythonw "%_serverDir%\app.py", %_serverDir%, Hide
    Loop, 10 {
        Sleep, 500
        if (RhPing())
            break
    }
    if (RH_SERVER_OK)
        TrayTip, RollHouse, 🟢 Сервер запущено, 2, 1
    else
        TrayTip, RollHouse, ⚠️ Сервер не відповідає, 3, 2
}

; --- Watchdog: перевіряти сервер кожні 60 секунд (неблокуючий) ---
SetTimer, WatchdogPing, 60000

; --- Стан головного вікна (для toggle ~, Esc, авто-сховання) ---
global rollExists  := 0   ; 1 = вікно створене (показане або сховане)
global rollVisible := 0   ; 1 = вікно зараз видиме
global RhRollHwnd  := 0   ; hwnd головного вікна Roll
global RhRawShown  := 0   ; 1 = исходник розгорнуто
global RhRawTop    := 0   ; Y-координата (клієнт) верху raw-edit
global RhRawDelta  := 0   ; на скільки px зсувати контроли / міняти висоту вікна
; Сховати вікно коли клікнули повз нього (втрата фокусу)
OnMessage(0x06, "Roll_WM_ACTIVATE")   ; WM_ACTIVATE
OnMessage(0x201, "Roll_WM_LBUTTONDOWN") ; WM_LBUTTONDOWN: fallback для ⚙
return

; Реагує на втрату фокусу головним вікном → ховає його (дані зберігаються)
Roll_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global rollExists, rollVisible
    if ((wParam & 0xFFFF) != 0)        ; не WA_INACTIVE — ігноруємо
        return
    if (!rollExists || !rollVisible)
        return
    _rh := WinExist("RollHouse MEGA 3.0 (PLU) ahk_class AutoHotkeyGUI")
    if (hwnd != _rh)                   ; деактивувалось не наше головне вікно
        return
    SetTimer, RollMaybeHide, -150
}


; Fallback для шестерінки: якщо нативний GUI-контрол не отримав gOpenSettings,
; відкриваємо налаштування по кліку в правий верхній кут головного вікна.
Roll_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global RhRollHwnd, rollExists, rollVisible
    if (!rollExists || !rollVisible || !RhRollHwnd)
        return

    _parent := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    if (hwnd != RhRollHwnd && _parent != RhRollHwnd)
        return
    WinGetClass, _ctrlClass, ahk_id %hwnd%
    if (_ctrlClass = "Button" || _ctrlClass = "Edit" || _ctrlClass = "ComboBox")
        return

    MouseGetPos, _mx, _my
    VarSetCapacity(_pt, 8, 0)
    NumPut(_mx, _pt, 0, "Int")
    NumPut(_my, _pt, 4, "Int")
    DllCall("ScreenToClient", "Ptr", RhRollHwnd, "Ptr", &_pt)
    _cx := NumGet(_pt, 0, "Int")
    _cy := NumGet(_pt, 4, "Int")

    if (_cx >= 294 && _cx <= 322 && _cy >= 19 && _cy <= 47) {
        SetTimer, RhFbOpenSettings, -1
        return 0
    }
    if (_cx >= 326 && _cx <= 350 && _cy >= 19 && _cy <= 47) {
        SetTimer, RhFbCloseRoll, -1
        return 0
    }
}

RhFbOpenSettings:
    GoSub, OpenSettings
return
RhFbCloseRoll:
    GoSub, RollGuiClose
return
; ══════════════════════════════════════════════════════════════
;  WATCHDOG — автоперезапуск сервера якщо він впав
; ══════════════════════════════════════════════════════════════
WatchdogPing:
    if (RhPing())
        return  ; сервер живий — нічого не робимо

    ; Сервер не відповідає — запускаємо перезапуск і ОДРАЗУ виходимо.
    ; БЕЗ циклу очікування: інакше скрипт «зависає» на ~10с і всі вікна мертві.
    ; Наступний тик (через 60с) сам перевірить, чи піднявся сервер.
    _ahkLog := A_ScriptDir . "\ahk_debug.log"
    FileAppend, % "[" . A_Now . "] WATCHDOG: server down, fire restart (non-blocking)`n", %_ahkLog%
    Run, cmd /c start.bat, %APP_DIR%\..\server, Hide
return

; --- ГОЛОВНИЙ ТРИГЕР ПАРСИНГУ ---
TriggerMain:
    ; --- LOG: first line ---
    _ahkLog := A_ScriptDir . "\ahk_debug.log"
    WinGet, _activeExeLog, ProcessName, A
    FileAppend, % "[" . A_Now . "] >>> TriggerMain START  activeWin=" . _activeExeLog . "  RH_SERVER_OK=" . RH_SERVER_OK . "  commX=" . commX . "`n", %_ahkLog%

    ; ~ працює як перемикач показу. Якщо вікно вже існує —
    ; показуємо/ховаємо БЕЗ повторного парсингу (дані зберігаються).
    if (rollExists) {
        if (rollVisible) {
            SaveRollPos()
            Gui, Roll:Hide
            rollVisible := 0
            FileAppend, % "[" . A_Now . "] TOGGLE: hide`n", %_ahkLog%
        } else {
            Gui, Roll:Show
            rollVisible := 1
            FileAppend, % "[" . A_Now . "] TOGGLE: show`n", %_ahkLog%
        }
        return
    }
    if (commX = 0 || commX = "ERROR") {
        FileAppend, % "[" . A_Now . "] RETURN: commX not set`n", %_ahkLog%
        MsgBox, 48, Налаштування, Вкажіть приціли в Налаштуваннях (⚙️)! Відкриваю меню...
        GoSub, OpenSettings
        return
    }

    ; ── Якщо сервер ще не пінгувався — спробуємо зараз ──
    if (!RH_SERVER_OK) {
        RhPing()
        FileAppend, % "[" . A_Now . "] after ping: RH_SERVER_OK=" . RH_SERVER_OK . "`n", %_ahkLog%
    }

    ; ── Читаємо ВСІ поля iiko через UIA (сервер знаходить поля ПО ІМЕНАХ) ──
    rawComment  := ""
    orderSum    := 0
    streetText  := ""
    clientPhone := ""
    _iikoTime   := ""

    if (RH_SERVER_OK) {
        ; з одним ретраєм, якщо телефон порожній
        Loop, 2 {
            _iikoData := RhGet("/api/iiko/read", 8000)
            FileAppend, % "[" . A_Now . "] API len=" . StrLen(_iikoData) . " first80=" . SubStr(_iikoData,1,80) . "`n", %_ahkLog%
            if (_iikoData != "") {
                RegExMatch(_iikoData, """phone""\s*:\s*""([^""]*)""", _mPh)
                _rawPhone := _mPh1
                _digits   := RegExReplace(_rawPhone, "[^\d]", "")
                if (StrLen(_digits) >= 9) {
                    clientPhone := _rawPhone
                    break
                }
            }
            if (A_Index = 1)
                Sleep, 1500
        }
        if (_iikoData != "") {
            RegExMatch(_iikoData, """comment""\s*:\s*""((?:[^""\\]|\\.)*)""", _mC)
            rawComment := StrReplace(_mC1, "\n", "`n")
            rawComment := StrReplace(rawComment, "\r", "")
            RegExMatch(_iikoData, """street""\s*:\s*""([^""]*)""", _mSt)
            streetText := _mSt1
            if RegExMatch(_iikoData, """city""\s*:\s*""([^""]*)""", _mCty) {
                if (_mCty1 != "")
                    streetText := _mCty1 . ", " . streetText
            }
            RegExMatch(_iikoData, """sum""\s*:\s*(\d+)", _mSum)
            orderSum := _mSum1 + 0
            RegExMatch(_iikoData, """time""\s*:\s*""([^""]*)""", _mT)
            _iikoTime := _mT1
        }
        if (clientPhone = "") {
            if (_iikoData = "")
                _errMsg := "⚠️ Сервер не відповідає. Зачекай пару секунд і натисни ~ ще раз."
            else if (InStr(_iikoData, """ok"": false") || InStr(_iikoData, """ok"":false")) {
                RegExMatch(_iikoData, """error""\s*:\s*""([^""]*)""", _mErr)
                _bridgeErr := _mErr1 ? _mErr1 : "Form not found"
                _errMsg := "⚠️ Bridge: " . _bridgeErr . ". Відкрий доставку в iiko."
            } else
                _errMsg := "⚠️ Телефон порожній у формі iiko. Перевір замовлення."
            FileAppend, % "[" . A_Now . "] ABORT: " . _errMsg . "`n", %_ahkLog%
            ToolTip, %_errMsg%
            SetTimer, RemoveToolTip, -6000
            return
        }
    } else {
        ToolTip, % "⚠️ Сервер ще не запущено. Зачекай 3-5 секунд після старту скрипта і натисни ~."
        SetTimer, RemoveToolTip, -6000
        return
    }

    GoSub, SilentMagicClean
    ; Якщо SilentMagicClean не знайшов час у коментарі — використовуємо час із поля iiko
    if (extractedTime = "" && _iikoTime != "")
        extractedTime := _iikoTime
    GoSub, DrawRollclub
    ; CRM lookup у фон — GUI вже відкрито, badge підтягнеться через ~300мс
    if (clientPhone != "" && RH_SERVER_OK)
        SetTimer, AsyncCrmLookupMain, -300
return

RemoveToolTip:
    ToolTip
return

TriggerSiv:
    GoSub, AddSivVisual
return

RhApplyTheme() {
    global uiTheme
    global RhFontName, RhC_BG, RhC_Panel, RhC_Header, RhC_Header2, RhC_HeaderText, RhC_HeaderSub, RhC_Neon, RhC_Text, RhC_Muted, RhC_Subtle, RhC_Soft, RhC_SoftText
    global RhC_Card, RhC_Shadow, RhC_BlueSoft, RhC_TealSoft, RhC_GreenSoft, RhC_OrangeSoft, RhC_RedSoft, RhC_StatusBar
    global RhB_Accent, RhB_Neon, RhB_Apply, RhB_ButtonOff, RhB_Cash, RhB_Card, RhB_Gift, RhB_Siv, RhB_Text, RhB_Muted, RhB_White, RhB_Header, RhB_SettingsGear
    global RhB_Blue, RhB_Teal, RhB_Green, RhB_Orange, RhB_Red, RhB_CardFill, RhB_StatusSoft

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
    } else {
        uiTheme := "light"
        RhC_BG := "F4F7FB"
        RhC_Panel := "FFFFFF"
        RhC_Header := "FFFFFF"
        RhC_Header2 := "EAF3FF"
        RhC_HeaderText := "0F172A"
        RhC_HeaderSub := "64748B"
        RhC_Neon := "14B8A6"
        RhC_Text := "0F172A"
        RhC_Muted := "64748B"
        RhC_Subtle := "DCE6F3"
        RhC_Soft := "ECFDF5"
        RhC_SoftText := "047857"
        RhC_Card := "FFFFFF"
        RhC_Shadow := "DCE6F3"
        RhC_BlueSoft := "EAF3FF"
        RhC_TealSoft := "E6FFFB"
        RhC_GreenSoft := "ECFDF5"
        RhC_OrangeSoft := "FFF7ED"
        RhC_RedSoft := "FEF2F2"
        RhC_StatusBar := "EAF0F7"

        RhB_Accent := 0xA6B814
        RhB_Neon := 0xA6B814
        RhB_Apply := 0x5EC522
        RhB_ButtonOff := 0xF3E6DC
        RhB_Cash := 0x5EC522
        RhB_Card := 0xEB6325
        RhB_Gift := 0x9948EC
        RhB_Siv := 0xA6B814
        RhB_Text := 0x2A170F
        RhB_Muted := 0x8B7464
        RhB_White := 0xFFFFFF
        RhB_Header := 0xFFFFFF
        RhB_SettingsGear := 0xEB6325
        RhB_Blue := 0xEB6325
        RhB_Teal := 0xA6B814
        RhB_Green := 0x5EC522
        RhB_Orange := 0x1673F9
        RhB_Red := 0x4444EF
        RhB_CardFill := 0xFFFFFF
        RhB_StatusSoft := 0xF7F0EA
    }
}
; --- ГОЛОВНИЙ ІНТЕРФЕЙС ---
DrawRollclub:
    RhApplyTheme()
    RhStaticColors := {}
    _brandName := (BRAND = "rollclub") ? "Roll Club" : "Roll House"
    _orderType := isPickup ? "Самовивіз" : "Доставка"
    _serverPill := RH_SERVER_OK ? "● ONLINE" : "● OFFLINE"
    _userLabel := A_UserName
    FormatTime, _rhNow,, dd.MM.yyyy HH:mm

    Gui, Roll:Destroy
    Gui, Roll:+AlwaysOnTop -MaximizeBox -MinimizeBox +ToolWindow +LastFound
    Gui, Roll:Color, %RhC_BG%, %RhC_Panel%
    Gui, Roll:Margin, 12, 12

    ; ── Premium Light App Header ─────────────────────────
    Gui, Roll:Add, Progress, x0 y0 w360 h88 -Theme c%RhC_Header%, 100
    Gui, Roll:Add, Progress, x0 y0 w360 h4 -Theme c%RhC_Neon%, 100
    Gui, Roll:Add, Progress, x16 y16 w46 h46 -Theme c%RhC_BlueSoft%, 100
    Gui, Roll:Font, s12 bold c%RhC_Neon%, %RhFontName%
    Gui, Roll:Add, Text, x16 y25 w46 h24 Center +BackgroundTrans, RH
    Gui, Roll:Font, s14 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x72 y14 w170 h24 +BackgroundTrans, АНК PRO V1
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x72 y39 w190 h16 +BackgroundTrans, %_brandName% · операторський пульт
    Gui, Roll:Font, s8 bold cFFFFFF, %RhFontName%
    Gui, Roll:Add, Text, x72 y60 w86 h20 Center +0x200 HwndhOnlinePill, %_serverPill%
    Gui, Roll:Font, s7 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x166 y59 w116 h20 Right +BackgroundTrans vRhClockLbl, %_rhNow% · ~ / F1
    RhRegColor(hOnlinePill, (RH_SERVER_OK ? RhB_Green : RhB_Red), RhB_White)
    Gui, Roll:Font, s13 bold c%RhC_Neon%, %RhFontName%
    Gui, Roll:Add, Button, x294 y19 w28 h28 HwndhSettingsGear gOpenSettings, ⚙
    RhRegColor(hSettingsGear, RhB_CardFill, RhB_SettingsGear)
    Gui, Roll:Font, s12 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Button, x326 y19 w24 h28 gRollGuiClose, ×

    ; ── Аналіз шаблонів (ТОП-6 за частотою використання) ──
    FileRead, allTemplates, RkTemplates.txt
    sortList := ""
    Loop, Parse, allTemplates, `n, `r
    {
        if (A_LoopField = "")
            continue
        safeKey := RegExReplace(A_LoopField, "[^\wА-Яа-яІіЄєЇїҐґЁё]", "")
        if (safeKey = "")
            safeKey := "Unk" . A_Index
        IniRead, count, RkConfig.ini, Usage, %safeKey%, 0
        sortList .= count . "|" . A_LoopField . "`n"
    }
    Sort, sortList, N R D`n
    top1 := "", top2 := "", top3 := "", top4 := "", top5 := "", top6 := ""
    Loop, Parse, sortList, `n
    {
        if (A_Index > 6 || A_LoopField = "")
            break
        arr := StrSplit(A_LoopField, "|", , 2)
        top%A_Index% := arr[2]
    }

    ; ── Пошук / бренд ────────────────────────────────────
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y104 w110 h18 +BackgroundTrans, 🔎 Адреса / зона
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x242 y104 w88 h18 Right +BackgroundTrans, бренд
    Gui, Roll:Font, s10 norm c%RhC_Text%, %RhFontName%
    _mapInit := (streetText != "" && !isPickup) ? "Визначаю зону..." : "Зона / точка на карті..."
    Gui, Roll:Add, Edit, x26 y126 w190 h26 vMapSearch, %_mapInit%
    _brandIdx := (BRAND = "rollclub") ? 2 : 1
    Gui, Roll:Add, DropDownList, x224 y126 w108 vBrandSel gBrandChange AltSubmit Choose%_brandIdx%, Roll House|Roll Club

    ; ── Карта замовлення: зона / сума / тип ──────────────
    if (isPickup)
        _zoneTxt := "Самовивіз " . pickupPoint
    else if (deliveryCostNum > 0)
        _zoneTxt := deliveryCostStr
    else
        _zoneTxt := "Зона не визначена"
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x34 y199 w80 h14 Center +BackgroundTrans, статус
    Gui, Roll:Add, Text, x140 y199 w80 h14 Center +BackgroundTrans, сума
    Gui, Roll:Add, Text, x246 y199 w78 h14 Center +BackgroundTrans, разом
    Gui, Roll:Font, s9 bold c%RhC_SoftText%, %RhFontName%
    Gui, Roll:Add, Text, x34 y216 w80 h18 Center +BackgroundTrans, %_orderType%
    Gui, Roll:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x140 y216 w80 h18 Center +BackgroundTrans, %orderSum% грн
    Gui, Roll:Font, s10 bold c%RhC_Neon%, %RhFontName%
    Gui, Roll:Add, Text, x246 y216 w78 h18 Center +BackgroundTrans, %totalSum% грн
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x26 y240 w306 h14 Center +BackgroundTrans, 📍 %_zoneTxt%

    ; ── Оплата ───────────────────────────────────────────
    DoAutoCash := autoCash
    DoAutoCard := autoCard
    Gui, Roll:Font, s10 bold cFFFFFF, %RhFontName%
    Gui, Roll:Add, Button, x14 y270 w160 h36 HwndhPayCash gRhTogCash, 💵 Готівка
    Gui, Roll:Add, Button, x184 y270 w160 h36 HwndhPayCard gRhTogCard, 💳 Картка
    RhRegColor(hPayCash, (DoAutoCash ? RhB_Cash : RhB_ButtonOff), (DoAutoCash ? RhB_White : RhB_Text))
    RhRegColor(hPayCard, (DoAutoCard ? RhB_Card : RhB_ButtonOff), (DoAutoCard ? RhB_White : RhB_Text))

    ; ── Коментар ─────────────────────────────────────────
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y326 w150 h18 +BackgroundTrans, 📝 Коментар
    Gui, Roll:Font, s8 norm c%RhC_Neon%, %RhFontName%
    Gui, Roll:Add, Button, x224 y324 w108 h22 vRhRawBtn gRhToggleRaw, вихідний »
    Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x26 y350 w306 r3 vOrderComment gRhRefreshEnterPreview, %cleanComment%
    Gui, Roll:Add, Edit, x26 y350 w306 r3 vRhRawEdit ReadOnly +Hidden, %rawComment%

    ; ── Кухня / адреса ───────────────────────────────────
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y426 w62 h22 +0x200 +BackgroundTrans, 🍳 Кухня
    Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x92 y426 w240 h22 r1 vClientInfo gRhRefreshEnterPreview, %infoText%
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y458 w62 h22 +0x200 +BackgroundTrans, 🏠 Адреса
    Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x92 y458 w240 h22 r1 vAddressNote gRhRefreshEnterPreview, %addrNote%

    ; ── Інлайн СІВ ───────────────────────────────────────
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y519 w36 h24 +0x200 +BackgroundTrans, 🥣
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x62 y519 w22 h24 +0x200 +BackgroundTrans, Рол
    Gui, Roll:Add, Edit, x86 y520 w34 h22 vVisRolls gRhRefreshEnterPreview Center Number,
    Gui, Roll:Add, Text, x126 y519 w18 h24 +0x200 +BackgroundTrans, Зв
    Gui, Roll:Add, Edit, x146 y520 w34 h22 vVisNorm gRhRefreshEnterPreview Center Number,
    Gui, Roll:Add, Text, x186 y519 w18 h24 +0x200 +BackgroundTrans, Уч
    Gui, Roll:Add, Edit, x206 y520 w34 h22 vVisEdu gRhRefreshEnterPreview Center Number,
    Gui, Roll:Font, s9 bold cFFFFFF, %RhFontName%
    Gui, Roll:Add, Button, x250 y518 w82 h26 HwndhSivGo gRhSivGo, Пробити
    RhRegColor(hSivGo, RhB_Siv, RhB_White)
    Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x26 y548 w306 h18 vRhSivPreview HwndhRhSivPreview +0x200, СІВ: введи Рол/Зв/Уч — покажу соус/імбир/васабі
    RhRegColor(hRhSivPreview, RhB_StatusSoft, RhB_Text)

    ; ── Подарунки ────────────────────────────────────────
    GiftPepsi := autoPepsi
    GiftBrooklyn := autoBrooklyn
    GiftBurger := autoBurger
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x14 y572 w86 h30 +0x200, 🎁 Подарунок
    Gui, Roll:Font, s9 bold cFFFFFF, %RhFontName%
    _giftPText := GiftPepsi ? "✓ Пепсі" : "Пепсі"
    Gui, Roll:Add, Button, x104 y572 w74 h30 vGiftPBtn HwndhGiftP gRhTogPepsi, %_giftPText%
    _giftBText := GiftBrooklyn ? "✓ Бруклін" : "Бруклін"
    Gui, Roll:Add, Button, x184 y572 w74 h30 vGiftBBtn HwndhGiftB gRhTogBrook, %_giftBText%
    _giftUText := GiftBurger ? "✓ Бургер" : "Бургер"
    Gui, Roll:Add, Button, x264 y572 w80 h30 vGiftUBtn HwndhGiftU gRhTogBurg, %_giftUText%
    RhRegColor(hGiftP, (GiftPepsi ? RhB_Gift : RhB_ButtonOff), (GiftPepsi ? RhB_White : RhB_Text))
    RhRegColor(hGiftB, (GiftBrooklyn ? RhB_Gift : RhB_ButtonOff), (GiftBrooklyn ? RhB_White : RhB_Text))
    RhRegColor(hGiftU, (GiftBurger ? RhB_Gift : RhB_ButtonOff), (GiftBurger ? RhB_White : RhB_Text))
    Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x14 y606 w330 h16 vRhGiftStatus HwndhRhGiftStatus +0x200, Подарунок: не вибрано
    RhRegColor(hRhGiftStatus, RhB_StatusSoft, RhB_Muted)

    ; ── Час готовності ───────────────────────────────────
    _rhH := "", _rhM := ""
    if (extractedTime != "" && InStr(extractedTime, ":")) {
        _rhP := StrSplit(extractedTime, ":")
        _rhH := _rhP[1], _rhM := _rhP[2]
    }
    Gui, Roll:Font, s15 bold c%RhC_Neon%, %RhFontName%
    Gui, Roll:Add, Text, x26 y626 w26 h30 +0x200 +BackgroundTrans, ⏱
    Gui, Roll:Font, s14 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x58 y626 w36 h28 Center Limit2 Number vReadyH gRhRefreshEnterPreview, %_rhH%
    Gui, Roll:Add, Text, x96 y626 w10 h28 +0x200 Center +BackgroundTrans, :
    Gui, Roll:Add, Edit, x108 y626 w36 h28 Center Limit2 Number vReadyM gRhRefreshEnterPreview, %_rhM%
    Gui, Roll:Font, s8 bold cFFFFFF, %RhFontName%
    Gui, Roll:Add, Button, x156 y628 w42 h24 HwndhQuickPickup gCalcPickup, СВ+40
    Gui, Roll:Add, Button, x202 y628 w40 h24 HwndhQuickDel60 gCalcDelivery, +60
    Gui, Roll:Add, Button, x246 y628 w40 h24 HwndhQuickDel90 gCalcDelivery90, +90
    Gui, Roll:Add, Button, x290 y628 w42 h24 HwndhQuickPickup20 gCalcPickup20, СВ+20
    RhRegColor(hQuickPickup, RhB_Blue, RhB_White)
    RhRegColor(hQuickDel60, RhB_Teal, RhB_White)
    RhRegColor(hQuickDel90, RhB_Orange, RhB_White)
    RhRegColor(hQuickPickup20, RhB_ButtonOff, RhB_Text)

    ; ── Прев'ю Enter-цепочки ─────────────────────────────────
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x14 y664 w330 h34 vRhEnterPreview +BackgroundTrans, Enter: готую цепочку...

    ; Внесення виконується клавішею Enter / NumpadEnter через hotkey нижче.

    Gui, Roll:Add, Edit, x0 y0 w1 h1 vClientCard +Hidden,


    Gui, Roll:Show, x%rollWinX% y%rollWinY%, RollHouse MEGA 3.0 (PLU)
    Gui, Roll:+LastFound
    RhRollHwnd := WinExist()
    GuiControlGet, _rhp, Roll:Pos, RhRawEdit
    RhRawTop   := _rhpy
    RhRawDelta := 0
    RhRawShown := 0
    rollExists := 1
    rollVisible := 1
    SetTimer, RhUpdatePultClock, 30000
    if (streetText != "" && !isPickup)
        SetTimer, RcCheckZone, -450
    if (extractedTime = "") {
        CalcType := isPickup ? 40 : 60
        GoSub, ProcessTimeCalc
    }
    GoSub, RhRefreshEnterPreview
return

RhUpdatePultClock:
    if (!rollExists)
        return
    FormatTime, _rhNow,, dd.MM.yyyy HH:mm
    GuiControl, Roll:, RhClockLbl, %_rhNow%
return



RhRefreshEnterPreview:
    if (!rollExists)
        return
    _preview := RhBuildEnterPreview()
    GuiControl, Roll:, RhEnterPreview, %_preview%
    _sivPreview := RhBuildSivPreview()
    GuiControl, Roll:, RhSivPreview, %_sivPreview%
    _giftStatus := RhBuildGiftStatus()
    GuiControl, Roll:, RhGiftStatus, %_giftStatus%
    if (hRhSivPreview) {
        RhRegColor(hRhSivPreview, RhB_StatusSoft, RhB_Text)
        DllCall("InvalidateRect", "Ptr", hRhSivPreview, "Ptr", 0, "Int", 1)
    }
    if (hRhGiftStatus) {
        RhRegColor(hRhGiftStatus, (GiftPepsi || GiftBrooklyn || GiftBurger) ? RhB_Gift : RhB_StatusSoft, (GiftPepsi || GiftBrooklyn || GiftBurger) ? RhB_White : RhB_Muted)
        DllCall("InvalidateRect", "Ptr", hRhGiftStatus, "Ptr", 0, "Int", 1)
    }
return

RhBuildSivPreview() {
    global itemX
    GuiControlGet, _sRolls, Roll:, VisRolls
    GuiControlGet, _sNorm, Roll:, VisNorm
    GuiControlGet, _sEdu, Roll:, VisEdu
    _sRolls := (_sRolls = "" ? 0 : _sRolls)
    _sNorm := (_sNorm = "" ? 0 : _sNorm)
    _sEdu := (_sEdu = "" ? 0 : _sEdu)
    if (_sRolls = 0 && _sNorm = 0 && _sEdu = 0)
        return "СІВ: нічого не пробиваємо"

    _soyQty := Floor((_sRolls + 1) / 2)
    _gwQty  := Floor((_sRolls + 3) / 4)
    if (_sRolls == 0) {
        _soyQty := 0
        _gwQty := 0
    }
    _totalSticks := _sNorm + _sEdu
    if (_totalSticks > 0) {
        _soyQty := (_soyQty > _totalSticks) ? _totalSticks : _soyQty
        _gwQty  := (_gwQty  > _totalSticks) ? _totalSticks : _gwQty
    }
    _txt := "СІВ піде: рол " . _sRolls . " · пал " . _sNorm . "/" . _sEdu . " · соус " . _soyQty . " · імб/вас " . _gwQty
    if (itemX = 0 || itemX = "ERROR")
        _txt .= " · !приціл 7"
    return _txt
}

RhBuildGiftStatus() {
    global GiftPepsi, GiftBrooklyn, GiftBurger
    _count := (GiftPepsi ? 1 : 0) + (GiftBrooklyn ? 1 : 0) + (GiftBurger ? 1 : 0)
    if (_count = 0)
        return "Подарунок: не вибрано"
    if (GiftBurger)
        _name := "Бургер"
    else if (GiftBrooklyn)
        _name := "Бруклін"
    else
        _name := "Пепсі"
    _txt := "✓ Подарунок: " . _name
    if (_count > 1)
        _txt .= " (обрано кілька, пробьється " . _name . ")"
    return _txt
}

RhBuildEnterPreview() {
    global DoAutoCash, DoAutoCard, GiftPepsi, GiftBrooklyn, GiftBurger, isPickup, itemX, itemRelX
    GuiControlGet, _pRolls, Roll:, VisRolls
    GuiControlGet, _pNorm, Roll:, VisNorm
    GuiControlGet, _pEdu, Roll:, VisEdu
    GuiControlGet, _pComment, Roll:, OrderComment
    GuiControlGet, _pKitchen, Roll:, ClientInfo
    GuiControlGet, _pAddress, Roll:, AddressNote
    GuiControlGet, _pH, Roll:, ReadyH
    GuiControlGet, _pM, Roll:, ReadyM

    _pRolls := (_pRolls = "" ? 0 : _pRolls)
    _pNorm := (_pNorm = "" ? 0 : _pNorm)
    _pEdu := (_pEdu = "" ? 0 : _pEdu)
    _txt := "Enter: "
    _sep := ""
    _sivStep := ""
    if (_pRolls != 0 || _pNorm != 0 || _pEdu != 0) {
        _sivStep := "СІВ " . _pRolls . "/" . _pNorm . "/" . _pEdu
        if (itemX = 0 || itemX = "ERROR")
            _sivStep .= " !приціл"
    }

    if (RhOneLine(_pComment) != "") {
        _txt .= _sep . "комент"
        _sep := " → "
    }
    if (RhOneLine(_pKitchen) != "") {
        _txt .= _sep . "кухня"
        _sep := " → "
    }
    if (RhOneLine(_pAddress) != "") {
        _txt .= _sep . "адреса"
        _sep := " → "
    }
    if (_pH != "" || _pM != "") {
        _txt .= _sep . "час " . Format("{:02}:{:02}", (_pH = "" ? 0 : _pH), (_pM = "" ? 0 : _pM))
        _sep := " → "
    }
    if (DoAutoCash || DoAutoCard) {
        _payStep := DoAutoCash ? "готівка" : "банк"
        if (!isPickup)
            _payStep .= " пропуск"
        _txt .= _sep . _payStep
        _sep := " → "
    }
    _gifts := ""
    if (GiftPepsi)
        _gifts .= (_gifts = "" ? "Пепсі" : "/Пепсі")
    if (GiftBrooklyn)
        _gifts .= (_gifts = "" ? "Бруклін" : "/Бруклін")
    if (GiftBurger)
        _gifts .= (_gifts = "" ? "Бургер" : "/Бургер")
    if (_gifts != "") {
        _txt .= _sep . "подарок " . _gifts
        _sep := " → "
    }

    if (_sep = "")
        _txt .= "внести замовлення"
    else {
        _txt .= _sep . "внести"
        _sep := " → "
    }
    if (_sivStep != "")
        _txt .= _sep . _sivStep
    if (StrLen(_txt) > 98)
        _txt := SubStr(_txt, 1, 95) . "..."
    return _txt
}


RhOneLine(txt) {
    txt := StrReplace(txt, "`r", " ")
    txt := StrReplace(txt, "`n", " ")
    return Trim(txt)
}



RhEnterPreflight:
    RhPreflightOk := 1
    _pf := ""
    GuiControlGet, _pfComment, Roll:, OrderComment
    GuiControlGet, _pfKitchen, Roll:, ClientInfo
    GuiControlGet, _pfAddress, Roll:, AddressNote
    GuiControlGet, _pfCard, Roll:, ClientCard
    GuiControlGet, _pfRolls, Roll:, VisRolls
    GuiControlGet, _pfNorm, Roll:, VisNorm
    GuiControlGet, _pfEdu, Roll:, VisEdu
    GuiControlGet, _pfH, Roll:, ReadyH
    GuiControlGet, _pfM, Roll:, ReadyM

    _pfHasSiv := ((_pfRolls != "" && _pfRolls != "0") || (_pfNorm != "" && _pfNorm != "0") || (_pfEdu != "" && _pfEdu != "0"))
    _pfHasTime := (_pfH != "" || _pfM != "")
    _pfHasGift := (GiftPepsi || GiftBrooklyn || GiftBurger)
    _pfHasPay := ((DoAutoCash || DoAutoCard) && isPickup)

    if (RhOneLine(_pfComment) != "" && !RhTargetReady(commX, commRelX))
        _pf .= "- Коментар: приціл 1 не налаштований`n"
    if (RhOneLine(_pfKitchen) != "" && !RhTargetReady(infoX, infoRelX))
        _pf .= "- Кухня: приціл 3 не налаштований`n"
    if (RhOneLine(_pfAddress) != "" && !RhTargetReady(addrX, addrRelX))
        _pf .= "- Адреса: приціл 4 не налаштований`n"
    if (RhOneLine(_pfCard) != "" && !RhTargetReady(cardX, cardRelX))
        _pf .= "- Карта клієнта: приціл 2 не налаштований`n"
    if (_pfHasTime && !RhTargetReady(timeX, timeRelX))
        _pf .= "- Час готовності: приціл 6 не налаштований`n"
    if ((_pfHasSiv || _pfHasGift) && !RhTargetReady(itemX, itemRelX))
        _pf .= "- Таблиця страв: приціл 7 не налаштований`n"
    if (_pfHasPay && !RhTargetReady(cashX, cashRelX))
        _pf .= "- Тип оплати: приціл 9 не налаштований`n"
    if (_pfHasPay && !RhTargetReady(crossX, crossRelX))
        _pf .= "- Хрестик оплати: приціл 8 не налаштований`n"
    if (DoAutoCash && isPickup && calcChange > 0 && !RhTargetReady(changeX, changeRelX))
        _pf .= "- Решта/сума готівки: приціл 10 не налаштований`n"

    if (_pf != "") {
        RhPreflightOk := 0
        MsgBox, 48, Enter зупинено, % "Перед запуском треба докалібрувати:`n`n" . _pf . "`nВідкрий ⚙ Налаштування → калібрування прицілів."
    }
return

RhTargetReady(absX, relX) {
    if (absX != "" && absX != 0 && absX != "ERROR")
        return 1
    if (relX != "" && relX != 0 && relX != "ERROR")
        return 1
    return 0
}

RhSaveEnterState:
    FormatTime, _stateTs,, yyyy-MM-dd HH:mm:ss
    _stateFile := BRAND_DIR . "\last_enter_state.ini"
    _historyFile := BRAND_DIR . "\enter_state_history.log"
    _statePreview := RhBuildEnterPreview()

    GuiControlGet, _stComment, Roll:, OrderComment
    GuiControlGet, _stKitchen, Roll:, ClientInfo
    GuiControlGet, _stAddress, Roll:, AddressNote
    GuiControlGet, _stRolls, Roll:, VisRolls
    GuiControlGet, _stNorm, Roll:, VisNorm
    GuiControlGet, _stEdu, Roll:, VisEdu
    GuiControlGet, _stReadyH, Roll:, ReadyH
    GuiControlGet, _stReadyM, Roll:, ReadyM
    GuiControlGet, _stClientCard, Roll:, ClientCard

    _stRolls := (_stRolls = "" ? 0 : _stRolls)
    _stNorm := (_stNorm = "" ? 0 : _stNorm)
    _stEdu := (_stEdu = "" ? 0 : _stEdu)
    _stReady := ""
    if (_stReadyH != "" || _stReadyM != "")
        _stReady := Format("{:02}:{:02}", (_stReadyH = "" ? 0 : _stReadyH), (_stReadyM = "" ? 0 : _stReadyM))

    _stPay := "none"
    if (DoAutoCash)
        _stPay := "cash"
    else if (DoAutoCard)
        _stPay := "card"
    _stPayWillRun := ((DoAutoCash || DoAutoCard) && isPickup) ? 1 : 0

    _stGifts := ""
    if (GiftPepsi)
        _stGifts .= (_stGifts = "" ? "Pepsi" : ",Pepsi")
    if (GiftBrooklyn)
        _stGifts .= (_stGifts = "" ? "Brooklyn" : ",Brooklyn")
    if (GiftBurger)
        _stGifts .= (_stGifts = "" ? "Burger" : ",Burger")
    if (_stGifts = "")
        _stGifts := "none"

    FileDelete, %_stateFile%
    IniWrite, %_stateTs%, %_stateFile%, Enter, Time
    IniWrite, %_statePreview%, %_stateFile%, Enter, Preview
    IniWrite, %BRAND%, %_stateFile%, Order, Brand
    IniWrite, %isPickup%, %_stateFile%, Order, IsPickup
    IniWrite, %orderSum%, %_stateFile%, Order, OrderSum
    IniWrite, %totalSum%, %_stateFile%, Order, TotalSum
    IniWrite, %deliveryCostStr%, %_stateFile%, Order, DeliveryCostText
    IniWrite, %_stPay%, %_stateFile%, Controls, PaymentSelected
    IniWrite, %_stPayWillRun%, %_stateFile%, Controls, PaymentWillRun
    IniWrite, %_stGifts%, %_stateFile%, Controls, Gifts
    IniWrite, %_stReady%, %_stateFile%, Controls, ReadyTime
    IniWrite, %_stRolls%, %_stateFile%, SIV, Rolls
    IniWrite, %_stNorm%, %_stateFile%, SIV, SticksNormal
    IniWrite, %_stEdu%, %_stateFile%, SIV, SticksEdu
    _stComment1 := RhOneLine(_stComment)
    _stKitchen1 := RhOneLine(_stKitchen)
    _stAddress1 := RhOneLine(_stAddress)
    _stClientCard1 := RhOneLine(_stClientCard)
    IniWrite, %_stComment1%, %_stateFile%, Fields, Comment
    IniWrite, %_stKitchen1%, %_stateFile%, Fields, Kitchen
    IniWrite, %_stAddress1%, %_stateFile%, Fields, Address
    IniWrite, %_stClientCard1%, %_stateFile%, Fields, ClientCard

    _hist := "[" . _stateTs . "] " . _statePreview . "`n"
    _hist .= "  payment=" . _stPay . " will_run=" . _stPayWillRun . " gifts=" . _stGifts . " ready=" . _stReady . " siv=" . _stRolls . "/" . _stNorm . "/" . _stEdu . "`n"
    _hist .= "  comment=" . _stComment1 . " | kitchen=" . _stKitchen1 . " | address=" . _stAddress1 . "`n`n"
    FileAppend, %_hist%, %_historyFile%
return

; ── Кольорові переключателі оплати / подарунків ──────────
RhTogCash:
    DoAutoCash := !DoAutoCash
    if (DoAutoCash)
        DoAutoCard := 0
    GoSub, RhPayPaint
return
RhTogCard:
    DoAutoCard := !DoAutoCard
    if (DoAutoCard)
        DoAutoCash := 0
    GoSub, RhPayPaint
return
RhPayPaint:
    RhRegColor(hPayCash, (DoAutoCash ? RhB_Cash : RhB_ButtonOff), (DoAutoCash ? RhB_White : RhB_Text))
    RhRegColor(hPayCard, (DoAutoCard ? RhB_Card : RhB_ButtonOff), (DoAutoCard ? RhB_White : RhB_Text))
    DllCall("InvalidateRect", "Ptr", hPayCash, "Ptr", 0, "Int", 1)
    DllCall("InvalidateRect", "Ptr", hPayCard, "Ptr", 0, "Int", 1)
    GoSub, RhRefreshEnterPreview
return
RhTogPepsi:
    GiftPepsi := !GiftPepsi
    if (GiftPepsi) {
        GiftBrooklyn := 0
        GiftBurger := 0
    }
    GoSub, RhGiftPaint
return
RhTogBrook:
    GiftBrooklyn := !GiftBrooklyn
    if (GiftBrooklyn) {
        GiftPepsi := 0
        GiftBurger := 0
    }
    GoSub, RhGiftPaint
return
RhTogBurg:
    GiftBurger := !GiftBurger
    if (GiftBurger) {
        GiftPepsi := 0
        GiftBrooklyn := 0
    }
    GoSub, RhGiftPaint
return
RhGiftPaint:
    GuiControl, Roll:, GiftPBtn, % (GiftPepsi ? "✓ Пепсі" : "Пепсі")
    GuiControl, Roll:, GiftBBtn, % (GiftBrooklyn ? "✓ Бруклін" : "Бруклін")
    GuiControl, Roll:, GiftUBtn, % (GiftBurger ? "✓ Бургер" : "Бургер")
    RhRegColor(hGiftP, (GiftPepsi ? RhB_Gift : RhB_ButtonOff), (GiftPepsi ? RhB_White : RhB_Text))
    RhRegColor(hGiftB, (GiftBrooklyn ? RhB_Gift : RhB_ButtonOff), (GiftBrooklyn ? RhB_White : RhB_Text))
    RhRegColor(hGiftU, (GiftBurger ? RhB_Gift : RhB_ButtonOff), (GiftBurger ? RhB_White : RhB_Text))
    DllCall("InvalidateRect", "Ptr", hGiftP, "Ptr", 0, "Int", 1)
    DllCall("InvalidateRect", "Ptr", hGiftB, "Ptr", 0, "Int", 1)
    DllCall("InvalidateRect", "Ptr", hGiftU, "Ptr", 0, "Int", 1)
    GoSub, RhRefreshEnterPreview
return

RhRegColor(hwnd, bg, tx) {
    global RhStaticColors
    RhStaticColors[hwnd] := {bg: bg, tx: tx}
}
WM_CTLCOLORSTATIC(wParam, lParam) {
    global RhStaticColors, RhStaticBrush
    if (!RhStaticColors.HasKey(lParam))
        return
    o := RhStaticColors[lParam]
    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", o.tx)
    DllCall("gdi32\SetBkColor",   "Ptr", wParam, "UInt", o.bg)
    if (!RhStaticBrush.HasKey(o.bg))
        RhStaticBrush[o.bg] := DllCall("gdi32\CreateSolidBrush", "UInt", o.bg, "Ptr")
    return RhStaticBrush[o.bg]
}

; ── Інлайн СІВ: читаємо Рол/Зв/Уч з пульта і пробиваємо (логіка еталону) ──
RhSivGo:
    GuiControlGet, VisRolls, Roll:, VisRolls
    GuiControlGet, VisNorm, Roll:, VisNorm
    GuiControlGet, VisEdu, Roll:, VisEdu
    RhPunchSivValues(VisRolls, VisNorm, VisEdu)
return

RhPunchSivValues(rolls, norm, edu) {
    global itemX, itemY, itemRelX, itemRelY, iikoWinExe, rollExists, rollVisible
    global pluSticksNorm, pluSticksEdu, pluSoy, pluGinger, pluWasabi
    if (rolls = "")
        rolls := 0
    if (norm = "")
        norm := 0
    if (edu = "")
        edu := 0
    if (rolls = 0 && norm = 0 && edu = 0)
        return 1

    soyQty := Floor((rolls + 1) / 2)
    gwQty  := Floor((rolls + 3) / 4)
    if (rolls == 0) {
        soyQty := 0
        gwQty  := 0
    }
    totalSticks := norm + edu
    if (totalSticks > 0) {
        soyQty := (soyQty > totalSticks) ? totalSticks : soyQty
        gwQty  := (gwQty  > totalSticks) ? totalSticks : gwQty
    }
    if (itemX = 0 || itemX = "ERROR") {
        MsgBox, 48, Помилка, Не задано приціл "Табл. Страв"! (Налаштування -> 7)
        return 0
    }

    MouseGetPos, _omx, _omy
    if (rollExists) {
        Gui, Roll:Hide
        rollVisible := 0
    }
    if (iikoWinExe != "" && iikoWinExe != "ERROR")
        WinActivate, ahk_exe %iikoWinExe%
    Sleep, % SpDly(120)
    IikoXY(itemRelX, itemRelY, itemX, itemY, _itX, _itY)
    if (norm > 0)
        PunchByPlu(pluSticksNorm, norm, _itX, _itY)
    if (edu > 0)
        PunchByPlu(pluSticksEdu, edu, _itX, _itY)
    if (soyQty > 0)
        PunchByPlu(pluSoy, soyQty, _itX, _itY)
    if (gwQty > 0) {
        PunchByPlu(pluGinger, gwQty, _itX, _itY)
        PunchByPlu(pluWasabi, gwQty, _itX, _itY)
    }
    ToolTip
    MouseMove, %_omx%, %_omy%, 0
    if (rollExists) {
        Gui, Roll:Show
        rollVisible := 1
    }
    return 1
}


; Зберегти поточну позицію головного вікна (щоб відкрити там само наступного разу)
SaveRollPos() {
    global rollWinX, rollWinY
    WinGetPos, _sx, _sy,,, RollHouse MEGA 3.0 (PLU) ahk_class AutoHotkeyGUI
    if (_sx != "" && _sy != "" && _sx > -2000 && _sy > -2000) {
        rollWinX := _sx
        rollWinY := _sy
        IniWrite, %_sx%, RkConfig.ini, Window, RollX
        IniWrite, %_sy%, RkConfig.ini, Window, RollY
    }
}

; ── Тогл «исходник» — розкривається на місці (Варіант Б) ──
RhToggleRaw:
    global RhRawShown
    if (!RhRawShown) {
        GuiControl, Roll:Hide, OrderComment
        GuiControl, Roll:Show, RhRawEdit
        GuiControl, Roll:, RhRawBtn, исходник ▲
        RhRawShown := 1
    } else {
        GuiControl, Roll:Hide, RhRawEdit
        GuiControl, Roll:Show, OrderComment
        GuiControl, Roll:, RhRawBtn, вихідний »
        RhRawShown := 0
    }
return

; Зсуває всі дочірні контроли вікна з clientY >= minY на delta пікселів по Y
RhShiftControls(hwndParent, minY, delta) {
    WinGet, _clist, ControlListHwnd, ahk_id %hwndParent%
    Loop, Parse, _clist, `n
    {
        hc := A_LoopField
        if (hc = "")
            continue
        VarSetCapacity(_rc, 16, 0)
        DllCall("GetWindowRect", "Ptr", hc, "Ptr", &_rc)
        _sx := NumGet(_rc,  0, "Int")
        _sy := NumGet(_rc,  4, "Int")
        _cw := NumGet(_rc,  8, "Int") - _sx
        _ch := NumGet(_rc, 12, "Int") - _sy
        VarSetCapacity(_pt, 8, 0)
        NumPut(_sx, _pt, 0, "Int")
        NumPut(_sy, _pt, 4, "Int")
        DllCall("ScreenToClient", "Ptr", hwndParent, "Ptr", &_pt)
        _cx := NumGet(_pt, 0, "Int")
        _cy := NumGet(_pt, 4, "Int")
        if (_cy >= minY)
            DllCall("MoveWindow", "Ptr", hc, "Int", _cx, "Int", _cy + delta, "Int", _cw, "Int", _ch, "Int", 0)
    }
    DllCall("InvalidateRect", "Ptr", hwndParent, "Ptr", 0, "Int", 1)
}

; ── Перемикання бренду: зберігаємо вибір і перезапускаємо ──
BrandChange:
    GuiControlGet, _bs, Roll:, BrandSel
    if (_bs = 2 || _bs = "Roll Club" || InStr(_bs, "Club"))
        _nb := "rollclub"
    else
        _nb := "rollhouse"
    if (_nb = "rollhouse") {
        GuiControl, Roll:Choose, BrandSel, 1
        return
    }
    IniWrite, rollclub, %APP_DIR%\settings.ini, App, Brand
    SaveRollPos()
    Run, "%A_AhkPath%" "%APP_DIR%\engine_rollclub.ahk"
    ExitApp
return



; ── Взаємовиключні чекбокси Готівка / Картка ──────────────────
OnCashToggle:
    GuiControl, Roll:, DoAutoCard, 0
return
OnCardToggle:
    GuiControl, Roll:, DoAutoCash, 0
return

; --- Перемикач глобальної швидкості скрипта ---
SpeedChange:
    GuiControlGet, SpeedChoice, Roll:
    if (SpeedChoice >= 1 && SpeedChoice <= 3) {
        speedMode := SpeedChoice
        IniWrite, %speedMode%, RkConfig.ini, Speed, Mode
    }
return

; --- Глобальна функція затримки за режимом швидкості ---
; baseMs — базова (повільна) затримка, повертає масштабовану.
; Не зменшуємо короткі (<80мс) — вони і так на межі.
SpDly(baseMs) {
    global speedMode
    if (baseMs < 80)
        return baseMs
    if (speedMode = 3)
        return Round(baseMs * 0.30)
    if (speedMode = 2)
        return Round(baseMs * 0.60)
    return baseMs
}

; --- ЛОГІКА ШАБЛОНІВ ---
EditTemplates:
    Run, notepad.exe RkTemplates.txt
return

InsertTemplate:
    GuiControlGet, btnText,, %A_GuiControl%
    GuiControlGet, currentComment,, OrderComment
    newComment := (currentComment != "") ? currentComment . " | " . btnText : btnText
    GuiControl, Roll:, OrderComment, %newComment%
    
    safeKey := RegExReplace(btnText, "[^\wА-Яа-яІіЄєЇїҐґЁё]", "")
    if (safeKey = "")
        return
    IniRead, count, RkConfig.ini, Usage, %safeKey%, 0
    count++
    IniWrite, %count%, RkConfig.ini, Usage, %safeKey%
return

; --- ВІКНО НАЛАШТУВАНЬ ---
OpenSettings:
    RhApplyTheme()
    Gui, Settings:Destroy
    Gui, Settings:+AlwaysOnTop +ToolWindow
    Gui, Settings:Color, %RhC_BG%, %RhC_Panel%
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Tab3, x6 y6 w348 h364 vSettTab, 🎯 Приціли|📞 Звонки|🎁 Подарунки|⌨️ Клавіші|🤖 Звіт F5

    ; ── Вкладка 1: Приціли форми замовлення ───────────────
    Gui, Settings:Tab, 1
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y36 w320 Section, Натисни кнопку → клікни цю точку в iiko:
    Gui, Settings:Add, Button, xs y+5 w158 h25 gSetCommTarget, 1. Коментар
    Gui, Settings:Add, Button, x+6 yp w158 h25 gSetCardTarget, 2. Карта клієнта
    Gui, Settings:Add, Button, xs y+4 w158 h25 gSetInfoTarget, 3. Кухня
    Gui, Settings:Add, Button, x+6 yp w158 h25 gSetAddrTarget, 4. Адреса
    Gui, Settings:Add, Button, xs y+4 w158 h25 gSetSumTarget, 5. Сума замовлення
    Gui, Settings:Add, Button, x+6 yp w158 h25 gSetTimeTarget, 6. Час готовності
    Gui, Settings:Add, Button, xs y+4 w158 h25 gSetItemTarget, 7. Табл. страв
    Gui, Settings:Add, Button, x+6 yp w158 h25 gSetCrossTarget, 8. Хрестик оплати
    Gui, Settings:Add, Button, xs y+4 w158 h25 gSetCashTarget, 9. Тип оплати
    Gui, Settings:Add, Button, x+6 yp w158 h25 gSetChangeTarget, 10. Сума/решта
    Gui, Settings:Add, Button, xs y+4 w158 h25 gSetStreetTarget, 11. Вулиця (зона KML)
    Gui, Settings:Add, Button, x+6 yp w158 h25 gSetPhoneTarget, 12. Телефон клієнта
    ; Слова для вибору типу оплати у списку iiko (друкуються для фільтра)
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, xs y+8 w322, Тип оплати обирається ДРУКОМ слова в списку iiko:
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, xs y+3 w74 h22 +0x200, 💵 Готівка:
    Gui, Settings:Add, Edit, x+2 yp w78 h22 vNewCashSearch, %paymentCashSearch%
    Gui, Settings:Add, Text, x+8 yp w58 h22 +0x200, 💳 Картка:
    Gui, Settings:Add, Edit, x+2 yp w78 h22 vNewCardSearch, %paymentCardSearch%
    Gui, Settings:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, xs y+8 w158 h28 gRecalibrateWizard, 🔄 Перекалібрувати всі
    Gui, Settings:Add, Button, x+6 yp w158 h28 gTestTargets, 🧪 Перевірити приціли
    Gui, Settings:Add, Button, xs y+6 w322 h28 gLoadKmlFile, 📍 Завантажити KML-зону (файл)

    ; ── Вкладка 2: Звонки (Aiko) ──────────────────────────
    Gui, Settings:Tab, 2
    Gui, Settings:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y38 w320 Section, Приціли набору в Aiko:
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, xs y+6 w158 h26 gSetAikoInputTarget, Поле номера
    Gui, Settings:Add, Button, x+6 yp w158 h26 gSetAikoCallTarget, Кнопка «Дзвонити»
    Gui, Settings:Add, Button, xs y+5 w158 h26 gSetAikoHangupTarget, Покласти трубку
    Gui, Settings:Add, Button, x+6 yp w158 h26 gSetCallTarget, Автоприйом вхідного
    Gui, Settings:Add, Button, xs y+5 w322 h26 gSetCallEndTarget, Зона «кінець дзвінка» (авто-перехід)
    Gui, Settings:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, xs y+12 w320, Клавіші режиму обзвону (F6):
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, xs y+8 w150 h22 +0x200, Наступний дзвінок:
    Gui, Settings:Add, Hotkey, x+6 yp w150 vNewHkCallNext, %hkCallNext%
    Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Покласти трубку:
    Gui, Settings:Add, Hotkey, x+6 yp w150 vNewHkCallHangup, %hkCallHangup%
    Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Пауза:
    Gui, Settings:Add, Hotkey, x+6 yp w150 vNewHkCallPause, %hkCallPause%
    Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Прийняти розмову:
    Gui, Settings:Add, Hotkey, x+6 yp w150 vNewHkAcceptTalk, %hkAcceptTalk%
    Gui, Settings:Font, s9 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, xs y+10 w316 h1 +0x10  ; лінія-роздільник
    Gui, Settings:Add, Text, xs y+6 w316, 🧊 Клавіші Soundpad (через | , напр. 1|x):
    Gui, Settings:Add, Edit, xs y+4 w316 h22 vNewSoundpadKeys, %soundpadKeys%
    Gui, Settings:Add, Text, xs y+2 w316 c%RhC_Muted%, Під час заморозки (F7) ці клавіші блокуються від Soundpad

    ; ── Вкладка 3: Подарунки ──────────────────────────────
    Gui, Settings:Tab, 3
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y44 w320 Section, Поріг суми замовлення для автоподарунка (грн):
    Gui, Settings:Add, Text, xs y+14 w150 h22 +0x200, 🥤 Пепсі від:
    Gui, Settings:Add, Edit, x+6 yp w100 h22 vNewGiftPepsi Center Number, %giftPepsiThreshold%
    Gui, Settings:Add, Text, xs y+8 w150 h22 +0x200, 🍦 Бруклін від:
    Gui, Settings:Add, Edit, x+6 yp w100 h22 vNewGiftBrooklyn Center Number, %giftBrooklynThreshold%
    Gui, Settings:Add, Text, xs y+8 w150 h22 +0x200, 🍔 Крабсбургер від:
    Gui, Settings:Add, Edit, x+6 yp w100 h22 vNewGiftBurger Center Number, %giftBurgerThreshold%

    ; ── Вкладка 4: Гарячі клавіші ─────────────────────────
    Gui, Settings:Tab, 4
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y44 w320 Section, Основні гарячі клавіші:
    Gui, Settings:Add, Text, xs y+14 w150 h22 +0x200, Головне меню (відкрити):
    Gui, Settings:Add, Hotkey, x+6 yp w150 vNewHkMain, %hkMain%
    Gui, Settings:Add, Text, xs y+8 w150 h22 +0x200, Швидкий СИВ:
    Gui, Settings:Add, Hotkey, x+6 yp w150 vNewHkSiv, %hkSiv%
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, xs y+14 w322, Підказка: за замовчуванням головне меню — клавіша ~ (тильда).
    _themeIdx := (uiTheme = "dark") ? 2 : 1
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, xs y+12 w150 h22 +0x200, Тема пульта:
    Gui, Settings:Add, DropDownList, x+6 yp w150 vNewUiTheme Choose%_themeIdx%, ☀ Light Premium|🌑 Neon Dark

    ; ── Вкладка 5: Звіт F5 ────────────────────────────────
    Gui, Settings:Tab, 5
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y44 w320 Section, Автозвіт у Telegram (клавіша F5):
    Gui, Settings:Add, Text, xs y+14 w90 h22 +0x200, Чат / група:
    Gui, Settings:Add, Edit, x+6 yp w216 h22 vNewTgGroup, %tgGroup%
    Gui, Settings:Add, Button, xs y+14 w322 h30 gSetupAutopilot, 🎬 Калібрування звіту (записати кліки)

    ; ── Загальна кнопка збереження (поза вкладками) ───────
    Gui, Settings:Tab
    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, x16 y378 w328 h34 gSaveSettings, 💾 Зберегти та перезапустити
    Gui, Settings:Show, w360, Налаштування PRO
return

SaveSettings:
    Gui, Settings:Submit
    IniWrite, %NewGiftPepsi%, RkConfig.ini, Gifts, PepsiThreshold
    IniWrite, %NewGiftBrooklyn%, RkConfig.ini, Gifts, BrooklynThreshold
    IniWrite, %NewGiftBurger%, RkConfig.ini, Gifts, BurgerThreshold
    IniWrite, %NewTgGroup%, RkConfig.ini, Autopilot, TgGroup
    IniWrite, %NewHkMain%, RkConfig.ini, Hotkeys, Main
    IniWrite, %NewHkSiv%, RkConfig.ini, Hotkeys, Siv
    if (NewHkCallNext != "")
        IniWrite, %NewHkCallNext%, RkConfig.ini, Hotkeys, CallNext
    if (NewHkCallHangup != "")
        IniWrite, %NewHkCallHangup%, RkConfig.ini, Hotkeys, CallHangup
    if (NewHkCallPause != "")
        IniWrite, %NewHkCallPause%, RkConfig.ini, Hotkeys, CallPause
    if (NewHkAcceptTalk != "")
        IniWrite, %NewHkAcceptTalk%, RkConfig.ini, Hotkeys, AcceptTalk
    if (NewSoundpadKeys != "")
        IniWrite, %NewSoundpadKeys%, RkConfig.ini, Hotkeys, SoundpadKeys
    if (NewCashSearch != "")
        IniWrite, %NewCashSearch%, RkConfig.ini, Payment, CashSearch
    if (NewCardSearch != "")
        IniWrite, %NewCardSearch%, RkConfig.ini, Payment, CardSearch
    uiThemeSave := InStr(NewUiTheme, "Dark") ? "dark" : "light"
    IniWrite, %uiThemeSave%, RkConfig.ini, UI, Theme
    MsgBox, 64, Збережено, Налаштування збережено! Скрипт буде перезапущено., 2
    Reload
return

SettingsGuiClose:
SettingsGuiEscape:
    Gui, Settings:Destroy
return

; --- ПЕРЕВІРКА ПРИЦІЛІВ: мишка об'їжджає всі маркери з підписами ---
TestTargets:
    Gui, Settings:Hide
    Sleep, 400
    if (iikoWinExe != "" && iikoWinExe != "ERROR")
        WinActivate, ahk_exe %iikoWinExe%
    Sleep, 250
    ToolTip, % "🧪 Перевірка прицілів. Дивись куди стрибає мишка.", 30, 30
    Sleep, 1200
    ShowTarget(commX, commY,     "1. Коментар")
    ShowTarget(cardX, cardY,     "2. Карта")
    ShowTarget(infoX, infoY,     "3. Кухня")
    ShowTarget(addrX, addrY,     "4. Адреса")
    ShowTarget(sumX, sumY,       "5. Сума")
    ShowTarget(timeX, timeY,     "6. Час")
    ShowTarget(itemX, itemY,     "7. Табл. страв")
    ShowTarget(crossX, crossY,   "8. Хрестик оплати")
    ShowTarget(cashX, cashY,     "9. Тип оплати")
    ShowTarget(changeX, changeY, "10. Сума/решта")
    ShowTarget(streetX, streetY, "11. Вулиця")
    ShowTarget(phoneX, phoneY,   "12. Телефон")
    ToolTip
    MsgBox, 64, Перевірка завершена, Перевірка прицілів завершена.`nЯкщо якийсь маркер стояв криво — перекалібруй його окремою кнопкою.
    Gui, Settings:Show
return

; --- МАЙСТЕР АВТОПІЛОТУ F5 ---
SetupAutopilot:
    Gui, Settings:Destroy
    MsgBox, 4160, Майстер Сценарію, Зараз ми запишемо алгоритм для F5.`nПісля кожного повідомлення просто наводь мишку і клікай ЛКМ.
    
    MsgBox, 4160, Крок 1/6, Закрий вікно (ОК).`nНаведи на заголовок колонки 'Точка' і натисни ЛКМ.
    KeyWait, LButton, Up
    KeyWait, LButton, Down
    MouseGetPos, p1X, p1Y
    
    MsgBox, 4160, Крок 2/6, Закрий вікно.`nНаведи на ПАНЕЛЬ ГРУПУВАННЯ і натисни ЛКМ.
    KeyWait, LButton, Up
    KeyWait, LButton, Down
    MouseGetPos, p2X, p2Y
    
    MsgBox, 4160, Крок 3/6, Закрий вікно.`nНаведи на фільтр 'Статус' і натисни ЛКМ.
    KeyWait, LButton, Up
    KeyWait, LButton, Down
    MouseGetPos, p3X, p3Y
    
    MsgBox, 4160, Крок 4/6, Закрий вікно.`nНаведи на 'Вибрати все' і натисни ЛКМ.
    KeyWait, LButton, Up
    KeyWait, LButton, Down
    MouseGetPos, p4X, p4Y
    
    MsgBox, 4160, Крок 5/6, Закрий вікно.`nНаведи на 'Отмененные' і натисни ЛКМ.
    KeyWait, LButton, Up
    KeyWait, LButton, Down
    MouseGetPos, p5X, p5Y
    
    MsgBox, 4160, Крок 6/6, Закрий вікно.`nНаведи на кнопку 'В Excel' і натисни ЛКМ.
    KeyWait, LButton, Up
    KeyWait, LButton, Down
    MouseGetPos, p6X, p6Y

    IniWrite, %p1X%, RkConfig.ini, Autopilot, P1X
    IniWrite, %p1Y%, RkConfig.ini, Autopilot, P1Y
    IniWrite, %p2X%, RkConfig.ini, Autopilot, P2X
    IniWrite, %p2Y%, RkConfig.ini, Autopilot, P2Y
    IniWrite, %p3X%, RkConfig.ini, Autopilot, P3X
    IniWrite, %p3Y%, RkConfig.ini, Autopilot, P3Y
    IniWrite, %p4X%, RkConfig.ini, Autopilot, P4X
    IniWrite, %p4Y%, RkConfig.ini, Autopilot, P4Y
    IniWrite, %p5X%, RkConfig.ini, Autopilot, P5X
    IniWrite, %p5Y%, RkConfig.ini, Autopilot, P5Y
    IniWrite, %p6X%, RkConfig.ini, Autopilot, P6X
    IniWrite, %p6Y%, RkConfig.ini, Autopilot, P6Y
    
    MsgBox, 64, Готово!, Сценарій успішно записано!
return

; --- ЛОКАЛЬНІ ГАРЯЧІ КЛАВІШІ ---
#IfWinActive RollHouse MEGA 3.0 (PLU)
Enter::GoSub, RollEnter
NumpadEnter::GoSub, RollEnter
+Enter::Send, {Enter}
+NumpadEnter::Send, {Enter}
#IfWinActive

RollEnter:
    ; Enter = фінальна дія пульта: бекап стану, внесення полів, потім СІВ останнім кроком.
    if (RhEnterBusy || (RhLastEnterTick && (A_TickCount - RhLastEnterTick < RhEnterCooldownMs))) {
        ToolTip, % "⏳ Цепочка вже виконується, Enter заблоковано на мить..."
        SetTimer, RemoveToolTip, -1200
        return
    }
    RhEnterBusy := 1
    RhLastEnterTick := A_TickCount
    GoSub, RhSaveEnterState
    GoSub, RhRefreshEnterPreview
    GoSub, RhEnterPreflight
    if (!RhPreflightOk) {
        RhEnterBusy := 0
        return
    }

    GuiControlGet, _enterRolls, Roll:, VisRolls
    GuiControlGet, _enterNorm,  Roll:, VisNorm
    GuiControlGet, _enterEdu,   Roll:, VisEdu
    _hasSivInput := ((_enterRolls != "" && _enterRolls != "0") || (_enterNorm != "" && _enterNorm != "0") || (_enterEdu != "" && _enterEdu != "0"))
    if (_hasSivInput && (itemX = 0 || itemX = "ERROR")) {
        MsgBox, 48, Помилка, Не задано приціл "Табл. Страв"! (Налаштування -> 7)
        RhEnterBusy := 0
        return
    }

    GoSub, ApplyRollclub
    if (_hasSivInput)
        RhPunchSivValues(_enterRolls, _enterNorm, _enterEdu)
    RhEnterBusy := 0
return

#IfWinActive СИВ (Модуль)
Enter::GoSub, SivVisApply
NumpadEnter::GoSub, SivVisApply
#IfWinActive

F2::
    if (callMode) {
        callMode := 0
        SetTimer, CheckCall, Off
        ToolTip, , , , 2
        return
    }

    if (callX = 0 || callX = "" || callX = "ERROR") {
        MsgBox, 48, Налаштування, Приціл дзвінка не встановлено!`nВідкриється вікно налаштувань.
        GoSub, OpenSettings
        return
    }

    callMode := 1
    SetTimer, CheckCall, 500
    GoSub, CheckCall
return

; --- МАГІЧНЕ ОЧИЩЕННЯ ---
SilentMagicClean:
    text := rawComment
    infoText := "", addrNote := "", extractedTime := "", clientChange := "", cardText := ""
    autoPromo := 0, autoPepsi := 0, autoBrooklyn := 0, autoBurger := 0, autoCash := 0, autoCard := 0
    paymentMethod := "", pickupPoint := ""
    parsedSticksNorm := "", parsedSticksEdu := ""
    
    ; 1. АНТИ-ПОПЕРЕДНІ ЗАМОВЛЕННЯ
    FormatTime, todayY, %A_Now%, yyyy
    FormatTime, todayM, %A_Now%, MM
    FormatTime, todayD, %A_Now%, dd
    FormatTime, todayDt, %A_Now%, yyyy-MM-dd
    isFutureDate := 0, warnReason := ""
    if RegExMatch(text, "(\d{4})-(\d{2})-(\d{2})", sysD) {
        ; Порівнюємо рядково: ISO дата "більше ніж сьогодні" = майб႑тню
        if ((sysD1 . "-" . sysD2 . "-" . sysD3) > todayDt) {
            isFutureDate := 1, warnReason := sysD3 . "." . sysD2 . "." . sysD1
        }
    }
    text := RegExReplace(text, "i)\d{4}-\d{2}-\d{2}", "")
    if (!isFutureDate && RegExMatch(text, "i)\b(завтра|послезавтра|післязавтра)\b", kw))
        isFutureDate := 1, warnReason := kw1
    if (!isFutureDate && RegExMatch(text, "(?<!\d)(0?[1-9]|[12]\d|3[01])[\./](0?[1-9]|1[012])[\./](20\d{2}|\d{2})(?!\d)", mFullD)) {
        cD := (StrLen(mFullD1) == 1) ? "0" . mFullD1 : mFullD1
        cM := (StrLen(mFullD2) == 1) ? "0" . mFullD2 : mFullD2
        if (cD != todayD || cM != todayM)
            isFutureDate := 1, warnReason := cD . "." . cM . "." . mFullD3
    }
    regexMonths := "i)(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)"
    if (!isFutureDate && RegExMatch(text, "i)((?:на\s*)?\d{1,2}\s*" . regexMonths . "|на\s*\d{1,2}\s*(число|числа))", matchMan))
        isFutureDate := 1, warnReason := matchMan1
    if (isFutureDate) {
        SoundBeep, 900, 400
        SoundBeep, 600, 400
        SoundBeep, 900, 600
        ; Яскраве попередження — окреме вікно що блокує поки не підтвердять
        Gui, WarnDate:Destroy
        Gui, WarnDate:+AlwaysOnTop +ToolWindow
        Gui, WarnDate:Color, FF0000
        Gui, WarnDate:Font, s18 bold cWhite, Segoe UI
        Gui, WarnDate:Add, Text, w440 Center y15, ⚠️ УВАГА! ЗАМОВЛЕННЯ НА ІНШИЙ ДЕНЬ!
        Gui, WarnDate:Font, s24 bold cFFFF00, Segoe UI
        Gui, WarnDate:Add, Text, w440 Center y+10, %warnReason%
        Gui, WarnDate:Font, s13 bold cWhite, Segoe UI
        Gui, WarnDate:Add, Text, w440 Center y+10, Перевір дату перед внесенням!
        Gui, WarnDate:Font, s11 bold c330000, Segoe UI
        Gui, WarnDate:Add, Button, w200 h40 x120 y+20 Default gWarnDateOk, ✅ Я БАЧУ, ПРОДОВЖИТИ
        Gui, WarnDate:Show, w460, 🚨 ЗАМОВЛЕННЯ НА ІНШИЙ ДЕНЬ!
        WinWaitClose, 🚨 ЗАМОВЛЕННЯ НА ІНШИЙ ДЕНЬ!
        infoText .= "!! ДАТА: " . warnReason . " !!"
    }

    ; 2. РОЗУМНИЙ ЧАС
    ; Підстраховка: люди часто пишуть час як "17.10", "17-10", "17 10", "на 17:10", "к 17.10" тощо.
    ;
    ; ВАЖЛИВО: Поле "Час: 2026-06-23 11:16" — це час СТВОРЕННЯ замовлення, не доставки!
    ; Якщо замовлення "Якомога швидше" — системний час ігноруємо,
    ; і шукаємо час тільки в коментарі клієнта (після "Коментар:").
    isAsap := RegExMatch(text, "i)Якомога швидше|Найближчим часом|Як можна скоріше|Как можно скорее")

    ; Якщо ASAP — вилучаємо весь блок "Час: HH:MM" зі схематичного тексту
    ; (дата вже видалена в кроці 1, залишається "Час:  11:16")
    if (isAsap)
        text := RegExReplace(text, "i)Час:\s*\d{1,2}:\d{2}", "")

    timeCandidate := ""
    if (RegExMatch(text, "i)(?:\b(?:на|к|до|в|час|время)\b\s*|Час:\s*|Время:\s*)?(?<!час:\s*)(?<!\d)([01]?\d|2[0-3])\s*[:\.\-]\s*([0-5]\d)(?!\d)", tCand))
        timeCandidate := Format("{:02}:{:02}", tCand1+0, tCand2+0)
    else if (RegExMatch(text, "i)(?:\b(?:на|к|до|в|час|время)\b\s*|Час:\s*|Время:\s*)?(?<!\d)([01]?\d|2[0-3])\s+([0-5]\d)(?!\d)", tCandSp))
        timeCandidate := Format("{:02}:{:02}", tCandSp1+0, tCandSp2+0)

    if RegExMatch(text, "i)(\d{1,2}):(\d{2})\s*PM", pmMatch) {
        hh := pmMatch1 + 0
        if (hh < 12)
            hh += 12
        extractedTime := Format("{:02}:{:02}", hh, pmMatch2)
    } else if RegExMatch(text, "i)(\d{1,2}):(\d{2})\s*AM", amMatch) {
        hh := amMatch1 + 0
        if (hh == 12)
            hh := 0
        extractedTime := Format("{:02}:{:02}", hh, amMatch2)
    } else if RegExMatch(text, "i)(?:На\s+|Час:\s*)(\d{1,2}:\d{2})", tMatch) {
        extractedTime := tMatch1
    } else if RegExMatch(text, "i)(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)", tMatch2) {
        extractedTime := Format("{:02}:{:02}", tMatch21+0, tMatch22+0)
    } else if RegExMatch(text, "i)Якомога швидше|Найближчим часом|Як можна скоріше|Как можно скорее") {
        ; ASAP — лишаємо порожнім; дефолт (+40/+60) виставиться в DrawRollclub
    }

    ; Якщо час в тексті знайдено, але шаблони вище не спрацювали — все одно підставити його.
    if (extractedTime = "" && timeCandidate != "")
        extractedTime := timeCandidate

    ; Вичистити час у різних форматах, щоб не дублювати в коментарі.
    text := RegExReplace(text, "i)(?:\b(?:на|к|до|в|час|время)\b\s*|Час:\s*|Время:\s*)?(?<!\d)([01]?\d|2[0-3])\s*[:\.\-]\s*([0-5]\d)(?!\d)(?:\s*(?:AM|PM))?", "")
    text := RegExReplace(text, "i)(?:\b(?:на|к|до|в|час|время)\b\s*|Час:\s*|Время:\s*)?(?<!\d)([01]?\d|2[0-3])\s+([0-5]\d)(?!\d)", "")
    text := RegExReplace(text, "i)\s*\(?Якомога швидше\)?|\s*\(?Найближчим часом\)?", "")

    ; 3. ОПЛАТА ТА НОМЕР
    orderNum := ""
    if RegExMatch(text, "i)Замовлення №(\d+)", mOrder)
        orderNum := " №" . mOrder1

    if RegExMatch(text, "i)(Готівкою|Готівка|Наличными)") {
        autoCash := 1, paymentMethod := "Готівка" . orderNum
    } else if RegExMatch(text, "i)(Картою онлайн|Карткою онлайн|картою на сайті|ОПЛАЧЕНО)") {
        paymentMethod := "ОПЛАЧЕНО" . orderNum
    } else if RegExMatch(text, "i)(Карткою у закладі|Картою в закладі|Банківська карта|Банківська картка|Термінал|Terminal)") {
        paymentMethod := "Термінал (При отриманні)" . orderNum
        autoCard := 1
    }

    ; 4. ПРИБОРИ
    text := RegExReplace(text, "i)\b(одного|одну)\b", "1")
    text := RegExReplace(text, "i)\b(двох|двоих)\b", "2")
    text := RegExReplace(text, "i)\b(трьох|троих)\b", "3")
    text := RegExReplace(text, "i)\b(чотирьох|четверых)\b", "4")

    if RegExMatch(text, "i)(\d+)\s*(?:звичай|обыч)|(?:Звичайні|Обычные).*?(\d+)", mNorm) {
        parsedSticksNorm := (mNorm1 != "") ? mNorm1 : mNorm2
        text := RegExReplace(text, "i)\d+\s*(?:звичай|обыч)[^\s,;]*|(?:Звичайні|Обычные)[^\d]*\d+", "")
    }
    if RegExMatch(text, "i)(\d+)\s*(?:пар\s*пал|персон|прибор|учбов|навчальн|палоч|палич)|(?:Учбові|Навчальні|Кількість приборів|Для).*?(\d+)", mEdu) {
        parsedSticksEdu := (mEdu1 != "") ? mEdu1 : mEdu2
        text := RegExReplace(text, "i)\d+\s*(?:пар\s*пал|персон|прибор|учбов|навчальн|палоч|палич)[^\s,;]*|(?:Учбові|Навчальні|Кількість приборів|Для)[^\d]*\d+", "")
    }

    ; 5. ПОДАРУНКИ ВІД СУМИ (не пробивати якщо є бонуси/знижки)
    hasBonuses := RegExMatch(text, "i)(бонус|бали|знижк|промокод|discount|cashback|кешбек)")
    if (orderSum > 0 && !hasBonuses) {
        if (orderSum >= giftBurgerThreshold && !autoBurger)
            autoBurger := 1
        else if (orderSum >= giftBrooklynThreshold && !autoBrooklyn && !autoBurger)
            autoBrooklyn := 1
        else if (orderSum >= giftPepsiThreshold && !autoPepsi && !autoBrooklyn && !autoBurger)
            autoPepsi := 1
    }

    ; 6. САМОВИВІЗ (потрібен ДО пошуку зони, щоб не списувати доставку при самовивозі)
    isPickup := 0
    if RegExMatch(text, "i)Точка закладу:\s*(.*?)(?=[;\r\n]|$)", mPoint) {
        isPickup := 1, pickupPoint := Trim(mPoint1)
        text := RegExReplace(text, "\Q" . mPoint0 . "\E", "")
    } else if RegExMatch(text, "i)(Мерефа\s*[-—]\s*Ігоря Савченка[,\s]*22|Чугу(?:ев|їв)\s*[-—]\s*Музейна[я]*\s*18а|Берестин\s*[-—]\s*вул[.\s]*Історична\s*60)", mLocPickup) {
        isPickup := 1
        if (InStr(mLocPickup1, "Мерефа"))
            pickupPoint := "Мерефа"
        else if (InStr(mLocPickup1, "Чугу"))
            pickupPoint := "Чугуїв"
        else if (InStr(mLocPickup1, "Берестин"))
            pickupPoint := "Берестин"
        text := RegExReplace(text, "\Q" . mLocPickup0 . "\E", "")
    } else if RegExMatch(text, "im)^[ \t]*(Берестин|Мерефа|Чугуїв|Чугуєв)[ \t.,]*$", mLoc) {
        isPickup := 1, pickupPoint := mLoc1
        text := RegExReplace(text, "im)^[ \t]*" . mLoc1 . "[ \t.,]*$\r?\n?", "")
    }

    ; ФОЛБЕК: перевіряємо вулицю в iiko напряму
    ; Якщо адреса порожня → самовивіз, незалежно від формату коментаря
    ; Порожнє поле вулиці → самовивіз (вулицю читаємо кліком, приціл 11)
    if (!isPickup && streetText = "") {
        isPickup := 1
        if RegExMatch(rawComment, "i)(Берестин|Мерефа|Чугуїв|Чугуєв)", _pcity)
            pickupPoint := _pcity1
    }

    ; 7. ПОШУК ЗОНИ ДОСТАВКИ (двопрохідний з пріоритетом конкретних зон)
    ; Основні міста (Мерефа/Чугуїв/Берестин) шукаємо ТІЛЬКИ якщо не знайшлось підзон.
    ; Інакше "г. Мерефа, вул. Першотравневе (УЧХОЗ)" знайде "Мерефа" замість "УЧХОЗ".
    deliveryCostStr := ""
    deliveryCostNum := 0
    if (!isPickup) {
        IfExist, DeliveryPrices.ini
        {
            oldCaseSense := A_StringCaseSense
            StringCaseSense, Locale
            FileRead, paramStr, DeliveryPrices.ini

            ; Назви, що ШУКАЮТЬСЯ ТІЛЬКИ В ОСТАННЮ ЧЕРГУ (основні міста)
            mainCitiesRegex := "i)^(Мерефа|Чугуїв|Чугуєв|Берестин)$"
            ; Технічний ключ для виключення (адреса ресторану)
            isTechKey := "i)^Мерефа\s*-\s*Ігоря Савченка"

            ; --- 1-й прохід: підзони у streetText ---
            if (streetText != "") {
                Loop, Parse, paramStr, `n, `r
                {
                    if (!InStr(A_LoopField, "="))
                        continue
                    arrOut := StrSplit(A_LoopField, "=")
                    dName := Trim(arrOut[1])
                    dPrice := Trim(arrOut[2])
                    if (dName = "" || RegExMatch(dName, mainCitiesRegex) || RegExMatch(dName, isTechKey))
                        continue
                    if (InStr(streetText, dName)) {
                        deliveryCostStr := "Доставка " . dName . " - " . dPrice . " грн"
                        deliveryCostNum := dPrice + 0
                        break
                    }
                }
            }
            ; --- 2-й прохід: підзони в rawComment ---
            if (deliveryCostStr = "") {
                Loop, Parse, paramStr, `n, `r
                {
                    if (!InStr(A_LoopField, "="))
                        continue
                    arrOut := StrSplit(A_LoopField, "=")
                    dName := Trim(arrOut[1])
                    dPrice := Trim(arrOut[2])
                    if (dName = "" || RegExMatch(dName, mainCitiesRegex) || RegExMatch(dName, isTechKey))
                        continue
                    if (InStr(rawComment, dName)) {
                        deliveryCostStr := "Доставка " . dName . " - " . dPrice . " грн"
                        deliveryCostNum := dPrice + 0
                        break
                    }
                }
            }
            ; --- 3-й прохід: основні міста (fallback) ---
            if (deliveryCostStr = "") {
                searchPool := (streetText != "") ? streetText . " " . rawComment : rawComment
                Loop, Parse, paramStr, `n, `r
                {
                    if (!InStr(A_LoopField, "="))
                        continue
                    arrOut := StrSplit(A_LoopField, "=")
                    dName := Trim(arrOut[1])
                    dPrice := Trim(arrOut[2])
                    if (dName = "" || !RegExMatch(dName, mainCitiesRegex))
                        continue
                    if (InStr(searchPool, dName)) {
                        deliveryCostStr := "Доставка " . dName . " - " . dPrice . " грн"
                        deliveryCostNum := dPrice + 0
                        break
                    }
                }
            }
            StringCaseSense, %oldCaseSense%
        }
    }

    ; 8. ФІНАНСИ (рахуємо решту від СУМА + ДОСТАВКА)
    if RegExMatch(text, "i)(?:підготувати\s*)?решт[уа]\s*з(?:[:\sз]*?)(\d+)", matchChange) {
        clientChange := matchChange1, autoCash := 1
    }
    ; Якщо є бонуси — сдача не потрібна
    if (hasBonuses)
        autoCash := 0
    totalSum := orderSum + deliveryCostNum
    if (clientChange != "")
        calcChange := clientChange
    else if (totalSum > 0)
        calcChange := Ceil(totalSum / 200) * 200
    else
        calcChange := 1000

    ; 8. КУХНЯ
    kitchenNote := ""
    if RegExMatch(text, "i)Напишіть свої побажання:\s*([^;\r\n]+)", mWish) {
        kitchenNote .= Trim(mWish1)
        text := StrReplace(text, mWish0, "")
    }
    ; Клієнтський коментар → в кухню (не в чек кур'єра)
    if RegExMatch(text, "i)(?:Коментар:|Комментарий к заказу:)\s*(.*?)(?=\r|\n|$)", matchComm) {
        commVal := Trim(matchComm1)
        if (commVal != "") {
            if (kitchenNote != "")
                kitchenNote .= " | "
            kitchenNote .= commVal
        }
        text := StrReplace(text, matchComm0, "")
    }
    Loop {
        if (!RegExMatch(text, "i)([^.,;!?\r\n]*(?:без\s+[а-яіїєґ]+|не\s+(?:додавати|додавайте|кладіть)|алерг|добре\s+просмаж)[^.,;!?\r\n]*)", kMatch))
            break
        if (kitchenNote != "")
            kitchenNote .= " | "
        kitchenNote .= Trim(kMatch1)
        text := StrReplace(text, kMatch1, "")
    }
    ; kitchenNote → поле «Кухня», не в коментар кур'єра

    ; 9. ВИДАЛЕННЯ СМІТТЯ
    text := RegExReplace(text, "i)(м\.|г\.)\s*(Мерефа|Берес\s*тин|Берес\s*тін|Чугуїв|Чугуєв|Харків).*?(дім\s*-|кв\.|буд\.|дом\b).*?(?=\r|\n|$)", "")
    text := RegExReplace(text, "i)(Адреса доставки:|Адреса:\s*|Адрес:\s*).*?((?=,\s*Оплата)|(?=[;\r\n]|$))", "")
    text := RegExReplace(text, "i)(Android v[\d\.]+|iOS v[\d\.]+)[,\s;]*", "")
    text := RegExReplace(text, "i)(Замовлення|Заказ) №\d+[ \r\n]*", "")
    text := RegExReplace(text, "i)(?:---ОПЛАЧЕНО---|УСПІШНО|УСПЕШНО)", "")
    text := RegExReplace(text, "i)(Тип оплати:|Тип оплаты:)\s*(.*?)(?=\r|\n|$)", "")
    text := RegExReplace(text, "i)Оплата:\s*(.*?)(?=[,\r\n;]|$)", "")
    text := RegExReplace(text, "i)(?:Коментар:|Комментарий к заказу:)\s*[^\r\n]*", "")  ; fallback
    text := RegExReplace(text, "i)(?:Передзвонити|Перетелефонувати|Подзв|зателефону|звонить|перезвонить)[^\r\n]*", "")
    text := RegExReplace(text, "i)(?:підготувати\s*|подготовить\s*)?(решт[уа]\s*з|сдача\s*с)(?:[:\sзс]*?)\d+(?:\s*грн)?\s*", "")
    text := RegExReplace(text, "i)\b(?:Час|Время):?\s*", "")
    text := RegExReplace(text, "i)(Карткою у закладі|Картой в заведении)", "")
    
    ; Видаляємо залишки дат формату 24.06 або 24.06.2026 (час 19:00 вже видалено вище)
    text := RegExReplace(text, "i)(?:\b(?:доставка|на|к|до|в)\b\s*)?(?<!\d)(0?[1-9]|[12]\d|3[01])[\./](0[1-9]|1[012])(?:[\./](20\d{2}|\d{2}))?(?!\d)\.?\s*", "")

    ; 10. АДРЕСА
    if RegExMatch(text, "i)(?:Коментар до адреси|Комментарий к адресу):\s*(.*?)(?=(Найближчим|\d{4}-\d{2}-|$|\n|\r))", matchAddr) {
        addrNote := Trim(matchAddr1)
        text := RegExReplace(text, "\Q" . matchAddr0 . "\E", "")
    }
    Loop {
        if (!RegExMatch(text, "i)([^.,;!?\r\n]*(?:домофон|під'їзд|подъезд|поверх\b|этаж|квартир[аи]|кв\s*\d|будинок|дом\b|шлагбаум|зустрін|встрет|вийду|выйду|консьєрж|ресепшн|охорон|заїзд|заїжджати|вхід|вход|корпус|фасад|кур'єр|курьер)[^.,;!?\r\n]*)", aMatch))
            break
        if (addrNote != "")
            addrNote .= " | "
        addrNote .= Trim(aMatch1)
        text := RegExReplace(text, "\Q" . aMatch1 . "\E", "")
    }

    ; 11. ЗБІРКА ЧИСТОГО КОМЕНТАРЯ
    text := RegExReplace(text, "[\r\n]+", " ") 
    text := RegExReplace(text, "[,;\.]{2,}", "") 
    text := RegExReplace(text, "\s*[,;]\s*[,;]\s*", " ")
    text := RegExReplace(text, "\s*;\s*,\s*|\s*,\s*;\s*", " ")
    text := RegExReplace(text, "^\s*[,;\.:\-]+\s*|\s*[,;\.:\-]+\s*$", "")
    text := RegExReplace(text, "\s{2,}", " ")
    cleanComment := Trim(text)

    ; Зону доставки вже знайдено вище у Кроці 7 (deliveryCostStr / deliveryCostNum)

    finalClean := ""
    if (paymentMethod != "")
        finalClean .= paymentMethod . " "
    if (deliveryCostStr != "")
        finalClean .= deliveryCostStr . " | "
    if (autoCash && totalSum > 0 && calcChange != "")
        finalClean .= "Решта з " . calcChange . " | "
    if (cleanComment != "")
        finalClean .= cleanComment . " "
    if (isPickup && pickupPoint != "") {
        ; не дублювати якщо точка вже є в тексті
        if (!InStr(finalClean, pickupPoint))
            finalClean .= "[" . pickupPoint . "]"
    }
    ; Якщо самовивіз і немає конкретного часу (не передзамовлення) — нагадати подзвонити
    if (isPickup && !isFutureDate && extractedTime = "")
        finalClean .= (Trim(finalClean) != "") ? " подзвонити по готовності" : "подзвонити по готовності"
        
    cleanComment := Trim(finalClean)

    ; Оновити палички у головному вікні (Щоб було як у F1)
    GuiControl, Roll:, VisNorm, %parsedSticksNorm%
    GuiControl, Roll:, VisEdu, %parsedSticksEdu%

return

; --- СИВ МОДУЛЬ (PLU-режим: одразу показуємо вікно вводу) ---
AddSivVisual:
    Gui, Roll:Hide
    rollVisible := 0
    Sleep, 150
    MouseGetPos, sivStartX, sivStartY

    RhApplyTheme()
    Gui, SivVis:Destroy
    Gui, SivVis:+AlwaysOnTop -MinimizeBox -MaximizeBox +ToolWindow
    Gui, SivVis:Color, %RhC_BG%, %RhC_Panel%
    Gui, SivVis:Add, Progress, x0 y0 w280 h36 -Theme c%RhC_Header%, 100
    Gui, SivVis:Add, Progress, x0 y0 w280 h3 -Theme c%RhC_Neon%, 100
    Gui, SivVis:Font, s10 bold c%RhC_HeaderText%, %RhFontName%
    Gui, SivVis:Add, Text, x10 y9 w260 +BackgroundTrans, 📌 ПРИБОРИ
    Gui, SivVis:Font, s10 norm c%RhC_Text%, %RhFontName%
    Gui, SivVis:Add, Text, x10 y45 w180, 🍣 Скільки РОЛІВ:
    Gui, SivVis:Add, Edit, x190 y43 w70 vVisRolls Number Center, 
    Gui, SivVis:Add, Text, x10 y75 w180, 🥢 ЗВИЧАЙНІ палички:
    Gui, SivVis:Add, Edit, x190 y73 w70 vVisNorm Number Center, %parsedSticksNorm%
    Gui, SivVis:Add, Text, x10 y105 w180, 🥢 УЧБОВІ палички:
    Gui, SivVis:Add, Edit, x190 y103 w70 vVisEdu Number Center, %parsedSticksEdu%
    
    Gui, SivVis:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, SivVis:Add, Button, x10 y145 w120 h30 Default gSivVisApply, ✔️ Пробити (Enter)
    Gui, SivVis:Font, s10 norm c%RhC_Text%, %RhFontName%
    Gui, SivVis:Add, Button, x140 y145 w120 h30 gSivVisCancel, ❌ Відміна
    Gui, SivVis:Show, x400 y200, СИВ (Модуль)
    
    MouseMove, 550, 240, 0 
return

SivVisCancel:
SivVisGuiClose:
SivVisGuiEscape:
    Gui, SivVis:Destroy
    Gui, Roll:Show
    rollVisible := 1
return

; ════════════════════════════════════════════════════════════
; СИВ через PLU-коди (нова версія, без ImageSearch)
; PLU: палички 00430, навчальні 005011, соєвий 00424, імбир 00428, васабі 00426
; Маршрут аналогічний подарункам: Click table → PgDn → Enter → PLU → Down → Enter
; ════════════════════════════════════════════════════════════
SivVisApply:
    Gui, SivVis:Submit
    Gui, SivVis:Destroy

    MouseGetPos, originalMouseX, originalMouseY
    Sleep, 200

    if (VisRolls = "")
        VisRolls := 0
    if (VisNorm = "")
        VisNorm := 0
    if (VisEdu = "")
        VisEdu := 0

    ; Формули: соєвий = ceil(roll/2), імбир/васабі = ceil(roll/4)
    soyQty := Floor((VisRolls + 1) / 2)
    gwQty  := Floor((VisRolls + 3) / 4)
    if (VisRolls == 0) {
        soyQty := 0
        gwQty  := 0
    }

    ; Запобіжник: соєвий/імбир не може бути більше ніж пар паличок (немає сенсу)
    TotalSticks := VisNorm + VisEdu
    if (TotalSticks > 0) {
        soyQty := (soyQty > TotalSticks) ? TotalSticks : soyQty
        gwQty  := (gwQty  > TotalSticks) ? TotalSticks : gwQty
    }

    if (itemX = 0 || itemX = "ERROR") {
        MsgBox, 48, Помилка, Не задано приціл "Табл. Страв"!`nВідкрий ⚙️ Налаштування → 7. Табл. Страв.
        Gui, Roll:Show
        rollVisible := 1
        return
    }

    ; Активуємо iiko один раз перед серією пробивань
    if (iikoWinExe != "" && iikoWinExe != "ERROR")
        WinActivate, ahk_exe %iikoWinExe%
    Sleep, % SpDly(120)

    ; Пробиваємо кожну позицію через PLU (один виклик = +1 шт, повторюємо qty разів)
    IikoXY(itemRelX, itemRelY, itemX, itemY, _itX, _itY)
    if (VisNorm > 0)
        PunchByPlu(pluSticksNorm, VisNorm, _itX, _itY)
    if (VisEdu > 0)
        PunchByPlu(pluSticksEdu, VisEdu, _itX, _itY)
    if (soyQty > 0)
        PunchByPlu(pluSoy, soyQty, _itX, _itY)
    if (gwQty > 0) {
        PunchByPlu(pluGinger, gwQty, _itX, _itY)
        PunchByPlu(pluWasabi, gwQty, _itX, _itY)
    }

    ToolTip   ; прибрати підказку СИВ
    MouseMove, %originalMouseX%, %originalMouseY%, 0
    Gui, Roll:Show
    rollVisible := 1
return

; --- Допоміжна функція: пробити блюдо по PLU + кількість ---
; PLU-послідовність проходить кілька різних контролів (tree → PLU-діалог → qty).
; Клікаємо в PLU-таблицю (миша повертається НЕГАЙНО після кліку),
; iiko стає активним → всі Send йдуть у потрібний контрол.
PunchByPlu(pluCode, qty, itX, itY) {
    global RH_SERVER_OK, iikoWinExe
    if (qty <= 0 || pluCode = "" || pluCode = "0000")
        return
    if (itX = 0 || itX = "ERROR")
        return   ; координати не налаштовані

    ; Видима підказка — оператор бачить, що саме пробивається
    ToolTip, % "🥢 СИВ: пробиваю PLU " . pluCode . "  ×" . qty, 30, 60
    ; Зберігаємо позицію миші
    MouseGetPos, _mx, _my
    ; Клік у PLU-таблицю → таблиця отримує клавіатурний фокус
    ; (iiko вже активований один раз у SivVisApply — повторно не активуємо, щоб не підвисало)
    Click, %itX%, %itY%
    Sleep, % SpDly(120)
    ; Негайно повертаємо мишу назад
    MouseMove, %_mx%, %_my%, 0

    Sleep, % SpDly(300)
    Send, {PgDn}
    Sleep, % SpDly(300)
    Send, {Enter}
    Sleep, % SpDly(400)
    Send, %pluCode%
    Sleep, % SpDly(300)
    Send, {Down}
    Sleep, % SpDly(250)
    Send, {Enter}
    Sleep, % SpDly(500)
    if (qty > 1) {
        Send, %qty%
        Sleep, % SpDly(200)
        Send, {Enter}
        Sleep, % SpDly(350)
    }
}

; ════════════════════════════════════════════════════════════
; СТАРА ВЕРСІЯ SivVisApply через ImageSearch (закоментована, для відкату)
; Якщо PLU не запрацює — раскоментуй цей блок і закоментуй новий вище.
; ════════════════════════════════════════════════════════════
/*
SivVisApply_LEGACY:
    Gui, SivVis:Submit
    Gui, SivVis:Destroy

    MouseGetPos, originalMouseX, originalMouseY
    Sleep, 200

    if (VisRolls = "")
        VisRolls := 0
    if (VisNorm = "")
        VisNorm := 0
    if (VisEdu = "")
        VisEdu := 0

    soyQty := Floor((VisRolls + 1) / 2)
    gwQty := Floor((VisRolls + 3) / 4)

    if (VisRolls == 0) {
        soyQty := 0
        gwQty := 0
    }

    TotalSticks := VisNorm + VisEdu
    if (TotalSticks > 0) {
        soyQty := (soyQty > TotalSticks) ? TotalSticks : soyQty
        gwQty := (gwQty > TotalSticks) ? TotalSticks : gwQty
    }

    if (VisNorm > 0 || VisEdu > 0) {
        ImageSearch, fX, fY, 0, 0, A_ScreenWidth, A_ScreenHeight, *60 img\item_sticks_norm.png
        errNorm := ErrorLevel
        ImageSearch, fX, fY, 0, 0, A_ScreenWidth, A_ScreenHeight, *60 img\item_sticks_edu.png
        errEdu := ErrorLevel

        if (errNorm && errEdu) {
            ImageSearch, foldX, foldY, 0, 0, A_ScreenWidth, A_ScreenHeight, *50 img\folder_sticks.png
            if (ErrorLevel == 0) {
                fClkX := foldX + 20
                fClkY := foldY + 5
                Click, %fClkX%, %fClkY%, 2
                Sleep, 900
                ImageSearch, fX, fY, 0, 0, A_ScreenWidth, A_ScreenHeight, *60 img\item_sticks_norm.png
                if (ErrorLevel != 0)
                    Sleep, 600
            } else {
                MsgBox, 48, СИВ - Папка, Не знайдено папку ПРИБОРИ (folder_sticks.png)!
            }
        }
    }

    if (soyQty > 0 || gwQty > 0) {
        ImageSearch, fX, fY, 0, 0, A_ScreenWidth, A_ScreenHeight, *60 img\item_soy.png
        errSoy := ErrorLevel
        ImageSearch, fX, fY, 0, 0, A_ScreenWidth, A_ScreenHeight, *60 img\item_wasabi.png
        errWas := ErrorLevel

        if (errSoy && errWas) {
            ImageSearch, foldX, foldY, 0, 0, A_ScreenWidth, A_ScreenHeight, *50 img\folder_siv.png
            if (ErrorLevel == 0) {
                fClkX := foldX + 20
                fClkY := foldY + 5
                Click, %fClkX%, %fClkY%, 2
                Sleep, 900
                ImageSearch, fX, fY, 0, 0, A_ScreenWidth, A_ScreenHeight, *60 img\item_soy.png
                if (ErrorLevel != 0)
                    Sleep, 600
            } else {
                MsgBox, 48, СИВ - Папка, Не знайдено папку ДОДАТКИ/СИВ (folder_siv.png)!
            }
        }
    }

    if (VisNorm > 0)
        ClickermannType("img\item_sticks_norm.png", VisNorm, 140)
    if (VisEdu > 0)
        ClickermannType("img\item_sticks_edu.png", VisEdu, 140)
    if (soyQty > 0)
        ClickermannType("img\item_soy.png", soyQty)
    if (gwQty > 0) {
        ClickermannType("img\item_ginger.png", gwQty)
        ClickermannType("img\item_wasabi.png", gwQty)
    }

    Loop, 50 {
        ImageSearch, savX, savY, 0, 0, A_ScreenWidth, A_ScreenHeight, *70 img\btn_save.png
        if (ErrorLevel == 0) {
            sClkX := savX + 10
            sClkY := savY + 5
            Click, %sClkX%, %sClkY%
            break
        }
        Sleep, 10
    }

    MouseMove, %originalMouseX%, %originalMouseY%, 0
    Gui, Roll:Show
return
*/

ClickermannType(imgFile, amount, specialOffsetX := "") {
    global SIVOffsetX, SIVOffsetY
    CurrentOffsetX := (specialOffsetX != "") ? specialOffsetX : SIVOffsetX
    OldBatchLines := A_BatchLines
    SetBatchLines, -1
    ScanStartX := A_ScreenWidth * 0.20
    ScanStartY := A_ScreenHeight * 0.15
    ScanEndX := A_ScreenWidth * 0.80
    ScanEndY := A_ScreenHeight * 0.85
    
    Loop, 100 {
        ImageSearch, fX, fY, %ScanStartX%, %ScanStartY%, %ScanEndX%, %ScanEndY%, *60 %imgFile%
        if (ErrorLevel == 0) {
            tX := fX + CurrentOffsetX 
            tY := fY + SIVOffsetY
            Click, %tX%, %tY%, 2 
            Sleep, 50
            SendInput, +{Home}
            Sleep, 20
            SendInput, {BackSpace}%amount%
            Sleep, 50
            SendInput, {Enter}
            Sleep, 150
            SendInput, {Enter} 
            Sleep, 50
            Send, {Ctrl Up}{Shift Up} 
            SetBatchLines, %OldBatchLines%
            return
        }
        Sleep, 10
    }
    SetBatchLines, %OldBatchLines% 
    MsgBox, 48, Помилка, Не знайшов %imgFile%
}

; --- КАЛКУЛЯТОР ЧАСУ ТА ВІДСТАНЕЙ ---
CalcPickup20:
    CalcType := 20
    GoSub, ProcessTimeCalc
return
CalcPickup:
    CalcType := 40
    GoSub, ProcessTimeCalc
return
CalcDelivery:
    CalcType := 60
    GoSub, ProcessTimeCalc
return
CalcDelivery90:
    CalcType := 90
    GoSub, ProcessTimeCalc
return
ProcessTimeCalc:
    HH := A_Hour, MM := A_Min
    MM += CalcType
    HH += Floor(MM / 60)
    MM := Mod(MM, 60)
    HH := Mod(HH, 24)
    ; Округлити до 5 хвилин у більшу сторону (до нуля або до п'ятірки)
    remainder := Mod(MM, 5)
    if (remainder != 0) {
        MM += (5 - remainder)
        if (MM >= 60) {
            MM -= 60
            HH := Mod(HH + 1, 24)
        }
    }
    GuiControl, Roll:, ReadyH, % Format("{:02}", HH)
    GuiControl, Roll:, ReadyM, % Format("{:02}", MM)
    GoSub, RhRefreshEnterPreview
return

; ════════════════════════════════════════════════════════════
; МАЙСТЕР КАЛІБРУВАННЯ — проходить по всіх 11 прицілах iiko
; ════════════════════════════════════════════════════════════
; --- Спільний крок майстра калібрування ---
; Використовує globals: _cwMsg, _cwKey, _cwAX, _cwAY, _cwRX, _cwRY, _cwFirst
_CalibStep:
    MsgBox, 4160, Крок %_cwMsg%, Клікни в iiko на:%_cwMsg%
    KeyWait, LButton, Down
    MouseGetPos, _cX, _cY, _cWin
    IniWrite, %_cX%, RkConfig.ini, Targets, %_cwKey%X
    IniWrite, %_cY%, RkConfig.ini, Targets, %_cwKey%Y
    %_cwAX% := _cX
    %_cwAY% := _cY
    WinGetPos, _wX, _wY,,, ahk_id %_cWin%
    if (!ErrorLevel) {
        _rX := _cX - _wX
        _rY := _cY - _wY
        IniWrite, %_rX%, RkConfig.ini, TargetsRel, %_cwKey%X
        IniWrite, %_rY%, RkConfig.ini, TargetsRel, %_cwKey%Y
        %_cwRX% := _rX
        %_cwRY% := _rY
    }
    if (_cwFirst) {
        WinGet, iikoWinExe, ProcessName, ahk_id %_cWin%
        IniWrite, %iikoWinExe%, RkConfig.ini, Targets, IikoWinExe
        ; Зберегти розмір вікна iiko — щоб відновлювати перед автоматизацією
        WinGetPos,,, _wW, _wH, ahk_id %_cWin%
        iikoWinW := _wW
        iikoWinH := _wH
        IniWrite, %_wW%, RkConfig.ini, Targets, IikoWinW
        IniWrite, %_wH%, RkConfig.ini, Targets, IikoWinH
        _cwFirst := 0
    }
return

RecalibrateWizard:
    Gui, Settings:Destroy
    MsgBox, 4160, 🔄 Майстер калібрування, Налаштуємо всі 13 прицілів iiko за раз.`nПісля КОЖНОГО кроку: закрий це вікно → клікни ЛКМ точно на вказаному місці в iiko.`n`n⚠️ Не міняй розмір вікна iiko під час калібрування.`n⚠️ Кроки 9/10/11 — це РІЗНІ місця в блоці ГОТІВКА!
    _cwFirst := 1

    _cwMsg := " 1/11  КОМЕНТАР замовлення"
    _cwKey := "Comm", _cwAX := "commX", _cwAY := "commY", _cwRX := "commRelX", _cwRY := "commRelY"
    GoSub, _CalibStep

    _cwMsg := " 2/13  АДРЕСА (примітка до адреси)"
    _cwKey := "Addr", _cwAX := "addrX", _cwAY := "addrY", _cwRX := "addrRelX", _cwRY := "addrRelY"
    GoSub, _CalibStep

    _cwMsg := " 3/13  ЧАС готовності (поле часу)"
    _cwKey := "Time", _cwAX := "timeX", _cwAY := "timeY", _cwRX := "timeRelX", _cwRY := "timeRelY"
    GoSub, _CalibStep

    _cwMsg := " 4/13  ТАБЛИЦЯ СТРАВ (для PLU/СИВ — клікни в будь-який рядок страви)"
    _cwKey := "Item", _cwAX := "itemX", _cwAY := "itemY", _cwRX := "itemRelX", _cwRY := "itemRelY"
    GoSub, _CalibStep

    _cwMsg := " 5/13  СУМА замовлення (поле де показана загальна сума)"
    _cwKey := "Sum", _cwAX := "sumX", _cwAY := "sumY", _cwRX := "sumRelX", _cwRY := "sumRelY"
    GoSub, _CalibStep

    _cwMsg := " 6/13  ВУЛИЦЯ (адресна стрічка — поле вулиці)"
    _cwKey := "Street", _cwAX := "streetX", _cwAY := "streetY", _cwRX := "streetRelX", _cwRY := "streetRelY"
    GoSub, _CalibStep

    _cwMsg := " 7/13  ТЕЛЕФОН клієнта (поле з номером телефону)"
    _cwKey := "Phone", _cwAX := "phoneX", _cwAY := "phoneY", _cwRX := "phoneRelX", _cwRY := "phoneRelY"
    GoSub, _CalibStep

    _cwMsg := " 8/13  АВТОПРИЙОМ ДЗВІНКА (кнопка відповіді на виклик)"
    _cwKey := "Call", _cwAX := "callX", _cwAY := "callY", _cwRX := "callRelX", _cwRY := "callRelY"
    GoSub, _CalibStep

    _cwMsg := " 9/13  ХРЕСТИК × ВИДАЛЕННЯ ОПЛАТИ`n(в рядку Готівка клікни на значок ×)"
    _cwKey := "Cross", _cwAX := "crossX", _cwAY := "crossY", _cwRX := "crossRelX", _cwRY := "crossRelY"
    GoSub, _CalibStep

    _cwMsg := " 10/13  РЯДОК ГОТІВКА`n(клікни на назву 'Готівка' — не на ×, а на саму назву)"
    _cwKey := "Cash", _cwAX := "cashX", _cwAY := "cashY", _cwRX := "cashRelX", _cwRY := "cashRelY"
    GoSub, _CalibStep

    _cwMsg := " 11/13  КОМІРКА 'РЕШТА З...'`n(у рядку Готівка клікни на суму — наприклад 1620 — у колонці 'Сума')"
    _cwKey := "Change", _cwAX := "changeX", _cwAY := "changeY", _cwRX := "changeRelX", _cwRY := "changeRelY"
    GoSub, _CalibStep

    _cwMsg := " 12/13  КНОПКА КІНЕЦЬ ДЗВІНКА"
    _cwKey := "CallEnd", _cwAX := "callEndX", _cwAY := "callEndY", _cwRX := "callRelX", _cwRY := "callRelY"
    GoSub, _CalibStep

    _cwMsg := " 13/13  ТЕЛЕФОН Aiko (поле введення номера для набору)"
    _cwKey := "AikoInput", _cwAX := "aikoInputX", _cwAY := "aikoInputY", _cwRX := "phoneRelX", _cwRY := "phoneRelY"
    GoSub, _CalibStep

    MsgBox, 64, ✅ Готово!, Всі 13 прицілів збережено і прив'язані до вікна iiko.`nТепер вікно iiko можна рухати — прицілі слідкуватимуть автоматично.`n`n⚡ Особливо важливо: кроки 9/10/11 — це РІЗНІ точки!`n  9 = значок ×  10 = назва Готівка  11 = поле суми/сдачі
    GoSub, OpenSettings
return

SetCardTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле 2. КАРТА КЛІЄНТА.
    KeyWait, LButton, Down
    MouseGetPos, cardX, cardY, _whWin
    IniWrite, %cardX%, RkConfig.ini, Targets, CardX
    IniWrite, %cardY%, RkConfig.ini, Targets, CardY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    cardRelX := cardX - _wx,  cardRelY := cardY - _wy
    IniWrite, %cardRelX%, RkConfig.ini, TargetsRel, CardX
    IniWrite, %cardRelY%, RkConfig.ini, TargetsRel, CardY
    Gui, Settings:Show
return
SetCommTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле 1. КОМЕНТАР.
    KeyWait, LButton, Down
    MouseGetPos, commX, commY, _whWin
    IniWrite, %commX%, RkConfig.ini, Targets, CommX
    IniWrite, %commY%, RkConfig.ini, Targets, CommY
    WinGet, iikoWinExe, ProcessName, ahk_id %_whWin%
    IniWrite, %iikoWinExe%, RkConfig.ini, Targets, IikoWinExe
    WinGetPos, _wx, _wy, _wW, _wH, ahk_id %_whWin%
    iikoWinW := _wW,  iikoWinH := _wH
    IniWrite, %_wW%, RkConfig.ini, Targets, IikoWinW
    IniWrite, %_wH%, RkConfig.ini, Targets, IikoWinH
    commRelX := commX - _wx,  commRelY := commY - _wy
    IniWrite, %commRelX%, RkConfig.ini, TargetsRel, CommX
    IniWrite, %commRelY%, RkConfig.ini, TargetsRel, CommY
    Gui, Settings:Show
return
SetTimeTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в ГОДИННИК поля часу.
    KeyWait, LButton, Down
    MouseGetPos, timeX, timeY, _whWin
    IniWrite, %timeX%, RkConfig.ini, Targets, TimeX
    IniWrite, %timeY%, RkConfig.ini, Targets, TimeY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    timeRelX := timeX - _wx,  timeRelY := timeY - _wy
    IniWrite, %timeRelX%, RkConfig.ini, TargetsRel, TimeX
    IniWrite, %timeRelY%, RkConfig.ini, TargetsRel, TimeY
    Gui, Settings:Show
return
SetInfoTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле 3. КУХНЯ.
    KeyWait, LButton, Down
    MouseGetPos, infoX, infoY, _whWin
    IniWrite, %infoX%, RkConfig.ini, Targets, InfoX
    IniWrite, %infoY%, RkConfig.ini, Targets, InfoY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    infoRelX := infoX - _wx,  infoRelY := infoY - _wy
    IniWrite, %infoRelX%, RkConfig.ini, TargetsRel, InfoX
    IniWrite, %infoRelY%, RkConfig.ini, TargetsRel, InfoY
    Gui, Settings:Show
return
SetAddrTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле 4. АДРЕСА.
    KeyWait, LButton, Down
    MouseGetPos, addrX, addrY, _whWin
    IniWrite, %addrX%, RkConfig.ini, Targets, AddrX
    IniWrite, %addrY%, RkConfig.ini, Targets, AddrY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    addrRelX := addrX - _wx,  addrRelY := addrY - _wy
    IniWrite, %addrRelX%, RkConfig.ini, TargetsRel, AddrX
    IniWrite, %addrRelY%, RkConfig.ini, TargetsRel, AddrY
    Gui, Settings:Show
return
SetSumTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле СУМИ (для Ctrl-C).
    KeyWait, LButton, Down
    MouseGetPos, sumX, sumY, _whWin
    IniWrite, %sumX%, RkConfig.ini, Targets, SumX
    IniWrite, %sumY%, RkConfig.ini, Targets, SumY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    sumRelX := sumX - _wx,  sumRelY := sumY - _wy
    IniWrite, %sumRelX%, RkConfig.ini, TargetsRel, SumX
    IniWrite, %sumRelY%, RkConfig.ini, TargetsRel, SumY
    Gui, Settings:Show
return
SetCrossTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни на ХРЕСТИК оплати.
    KeyWait, LButton, Down
    MouseGetPos, crossX, crossY, _whWin
    IniWrite, %crossX%, RkConfig.ini, Targets, CrossX
    IniWrite, %crossY%, RkConfig.ini, Targets, CrossY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    crossRelX := crossX - _wx,  crossRelY := crossY - _wy
    IniWrite, %crossRelX%, RkConfig.ini, TargetsRel, CrossX
    IniWrite, %crossRelY%, RkConfig.ini, TargetsRel, CrossY
    Gui, Settings:Show
return
SetGotivkaTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Відкрий dropdown типу оплати в iiko`nі клікни на пункт "Готівка" у списку.
    KeyWait, LButton, Down
    MouseGetPos, gotivkaX, gotivkaY
    IniWrite, %gotivkaX%, RkConfig.ini, Targets, GotivkaX
    IniWrite, %gotivkaY%, RkConfig.ini, Targets, GotivkaY
    Gui, Settings:Show
return
SetCardTermTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Відкрий dropdown типу оплати в iiko`nі клікни на пункт "Банківська картка/Термінал" у списку.
    KeyWait, LButton, Down
    MouseGetPos, cardTermX, cardTermY
    IniWrite, %cardTermX%, RkConfig.ini, Targets, CardTermX
    IniWrite, %cardTermY%, RkConfig.ini, Targets, CardTermY
    Gui, Settings:Show
return
SetCashTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни на НАЗВУ 'Готівка' в рядку оплати`n(не на ×, а на саму назву типу оплати).
    KeyWait, LButton, Down
    MouseGetPos, cashX, cashY, _whWin
    IniWrite, %cashX%, RkConfig.ini, Targets, CashX
    IniWrite, %cashY%, RkConfig.ini, Targets, CashY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    cashRelX := cashX - _wx,  cashRelY := cashY - _wy
    IniWrite, %cashRelX%, RkConfig.ini, TargetsRel, CashX
    IniWrite, %cashRelY%, RkConfig.ini, TargetsRel, CashY
    Gui, Settings:Show
return
SetChangeTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни на СУМУ у рядку Готівка`n(число типу 1620 у колонці 'Сума').`n`nСаме ця комірка → дабл-клік → вводиться "решта з..."
    KeyWait, LButton, Down
    MouseGetPos, changeX, changeY, _whWin
    IniWrite, %changeX%, RkConfig.ini, Targets, ChangeX
    IniWrite, %changeY%, RkConfig.ini, Targets, ChangeY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    changeRelX := changeX - _wx,  changeRelY := changeY - _wy
    IniWrite, %changeRelX%, RkConfig.ini, TargetsRel, ChangeX
    IniWrite, %changeRelY%, RkConfig.ini, TargetsRel, ChangeY
    Gui, Settings:Show
return
SetItemTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни строго в ТАБЛИЦЮ СТРАВ (для PgDn).
    KeyWait, LButton, Down
    MouseGetPos, itemX, itemY, _whWin
    IniWrite, %itemX%, RkConfig.ini, Targets, ItemX
    IniWrite, %itemY%, RkConfig.ini, Targets, ItemY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    itemRelX := itemX - _wx,  itemRelY := itemY - _wy
    IniWrite, %itemRelX%, RkConfig.ini, TargetsRel, ItemX
    IniWrite, %itemRelY%, RkConfig.ini, TargetsRel, ItemY
    Gui, Settings:Show
return

SetCallTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни на кнопку АВТОПРИНЯТИЕ ЗВОНКА.
    KeyWait, LButton, Down
    MouseGetPos, callX, callY, _whWin
    IniWrite, %callX%, RkConfig.ini, Targets, CallX
    IniWrite, %callY%, RkConfig.ini, Targets, CallY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    callRelX := callX - _wx,  callRelY := callY - _wy
    IniWrite, %callRelX%, RkConfig.ini, TargetsRel, CallX
    IniWrite, %callRelY%, RkConfig.ini, TargetsRel, CallY
    Gui, Settings:Show
return

SetStreetTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле ВУЛИЦЯ (адресна стрічка).
    KeyWait, LButton, Down
    MouseGetPos, streetX, streetY, _whWin
    IniWrite, %streetX%, RkConfig.ini, Targets, StreetX
    IniWrite, %streetY%, RkConfig.ini, Targets, StreetY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    streetRelX := streetX - _wx,  streetRelY := streetY - _wy
    IniWrite, %streetRelX%, RkConfig.ini, TargetsRel, StreetX
    IniWrite, %streetRelY%, RkConfig.ini, TargetsRel, StreetY
    Gui, Settings:Show
return

SetPhoneTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле ТЕЛЕФОН клієнта в iiko.`n`n(Поле де показано номер телефону замовника)
    KeyWait, LButton, Down
    MouseGetPos, phoneX, phoneY, _whWin
    IniWrite, %phoneX%, RkConfig.ini, Targets, PhoneX
    IniWrite, %phoneY%, RkConfig.ini, Targets, PhoneY
    WinGetPos, _wx, _wy,,, ahk_id %_whWin%
    phoneRelX := phoneX - _wx,  phoneRelY := phoneY - _wy
    IniWrite, %phoneRelX%, RkConfig.ini, TargetsRel, PhoneX
    IniWrite, %phoneRelY%, RkConfig.ini, TargetsRel, PhoneY
    Gui, Settings:Show
return

SetAikoInputTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле ВВОДУ НОМЕРА в Aiko.
    KeyWait, LButton, Down
    MouseGetPos, aikoInputX, aikoInputY
    IniWrite, %aikoInputX%, RkConfig.ini, Targets, AikoInputX
    IniWrite, %aikoInputY%, RkConfig.ini, Targets, AikoInputY
    Gui, Settings:Show
return

SetAikoCallTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни на кнопку ДЗВОНИТИ в Aiko.
    KeyWait, LButton, Down
    MouseGetPos, aikoCallX, aikoCallY
    IniWrite, %aikoCallX%, RkConfig.ini, Targets, AikoCallX
    IniWrite, %aikoCallY%, RkConfig.ini, Targets, AikoCallY
    Gui, Settings:Show
return

SetAikoHangupTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни на кнопку ПОКЛАСТИ ТРУБКУ в Aiko.
    KeyWait, LButton, Down
    MouseGetPos, aikoHangupX, aikoHangupY
    IniWrite, %aikoHangupX%, RkConfig.ini, Targets, AikoHangupX
    IniWrite, %aikoHangupY%, RkConfig.ini, Targets, AikoHangupY
    Gui, Settings:Show
return

SetCallEndTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в ЦЕНТР ЗОНИ де шукати кінець дзвінка.`n`nПісля цього поклади файл img\call_end.png`n(скріншот стану "дзвінок завершено") у папку img\.`n`nПошук буде у квадраті ±200 px від точки.
    KeyWait, LButton, Down
    MouseGetPos, callEndX, callEndY
    IniWrite, %callEndX%, RkConfig.ini, Targets, CallEndX
    IniWrite, %callEndY%, RkConfig.ini, Targets, CallEndY
    Gui, Settings:Show
return

; --- ВНЕСЕННЯ ДАНИХ В IIKO ---
ApplyRollclub:
    Gui, Roll:Submit
    ; зібрати час готовності з двох полів [ЧЧ]:[ММ]
    if (ReadyH != "" || ReadyM != "")
        ReadyTime := Format("{:02}:{:02}", (ReadyH = "" ? 0 : ReadyH), (ReadyM = "" ? 0 : ReadyM))
    else
        ReadyTime := ""
    SaveRollPos()
    Gui, Roll:Destroy
    SetTimer, RhUpdatePultClock, Off
    rollExists := 0
    rollVisible := 0

    IikoRestore()   ; відновити розмір iiko до каліброваного, активувати
    MouseGetPos, originalMouseX, originalMouseY
    Sleep, % SpDly(200)

    ; ── Поля пишемо КЛІКАМИ по прицілах (кожен прицел керує своїм полем) ──
    ; Так передбачувано: «Кухня» йде туди, куди ти поставив маркер «3. Кухня», і т.д.
    ; Побажання на кухню (kitchenNote) додаємо в поле «Кухня», щоб не загубити.
    if (kitchenNote != "")
        ClientInfo := Trim(ClientInfo . ((ClientInfo != "") ? "  " : "") . kitchenNote)

    IikoPaste(commRelX, commRelY, commX, commY, OrderComment)   ; 1. Коментар
    IikoPaste(infoRelX, infoRelY, infoX, infoY, ClientInfo)     ; 3. Кухня
    IikoPaste(addrRelX, addrRelY, addrX, addrY, AddressNote)    ; 4. Адреса
    IikoPaste(cardRelX, cardRelY, cardX, cardY, ClientCard)     ; 2. Карта

    ; ── Час: клік у поле часу (приціл 6) + клавіатура ──
    if (ReadyTime != "" && (timeX != 0 || timeRelX != 0)) {
        IikoXY(timeRelX, timeRelY, timeX, timeY, _tX, _tY)
        IikoClickAt(_tX, _tY)
        Sleep, % SpDly(250)
        timeParts := StrSplit(ReadyTime, ":")
        part1 := timeParts[1]
        part2 := timeParts[2]
        Send, {Home}
        Sleep, % SpDly(100)
        Send, {Del}{Del}{Del}
        Sleep, % SpDly(100)
        Send, %part1%
        Sleep, % SpDly(200)
        Send, {Right}
        Sleep, % SpDly(150)
        Send, %part2%
        Sleep, % SpDly(300)
        Send, {Tab}
        Sleep, % SpDly(200)
    }

    ; ── ГОТІВКА: тільки для САМОВИВОЗУ ──────────────────────────
    ; Для ДОСТАВКИ: "Решта з X" вже пишеться в чистий коментар (рядок вище)
    ; Для САМОВИВОЗУ: додатково вводимо суму в поле оплати iiko
    ;
    ; Уточнюємо isPickup: якщо поле вулиці в iiko порожнє → самовивіз
    ; (це надійніше ніж парсинг коментаря; вулицю тепер читаємо кліком)
    if (streetText = "")
        isPickup := 1

    if (DoAutoCash == 1 && isPickup) {
        Sleep, % SpDly(400)
        ; 1/4 — видалити поточний тип оплати (хрестик, приціл 8)
        if (crossX > 0 || crossRelX > 0)
            IikoClickRelV(crossRelX, crossRelY, crossX, crossY, "Готівка 1/4: видаляю тип")
        Sleep, % Max(1000, SpDly(1500))
        ; 2/4 — клік у клітинку «Тип оплати» (приціл 9) → відкриваємо редактор
        if (cashX > 0 || cashRelX > 0) {
            IikoClickRelV(cashRelX, cashRelY, cashX, cashY, "Готівка 2/4: тип оплати")
            Sleep, % Max(250, SpDly(400))
            IikoClickRelV(cashRelX, cashRelY, cashX, cashY, "Готівка 2/4: тип оплати")
            Sleep, % Max(700, SpDly(900))
        }
        ; 3/4 — ДРУКУЄМО слово пошуку → список фільтрується → Enter обирає
        _ttGx := 30, _ttGy := 30
        ToolTip, % "Готівка 3/4: друкую «" . paymentCashSearch . "»", %_ttGx%, %_ttGy%
        Send, %paymentCashSearch%
        Sleep, % Max(500, SpDly(700))
        Send, {Enter}
        Sleep, % Max(350, SpDly(500))
        ; 4/4 — поле «решта з…» (приціл 10): подвійний клік → сума → Enter
        if (changeX > 0 || changeRelX > 0) {
            IikoClickRelV(changeRelX, changeRelY, changeX, changeY, "Готівка 4/4: вводжу решту", 1)
            Sleep, % SpDly(300)
            Send, %calcChange%
            Sleep, % SpDly(300)
            Send, {NumpadEnter}
            Sleep, % SpDly(500)
        }
        ToolTip
    } else if (DoAutoCard == 1 && isPickup) {
    ; ── КАРТКА/ТЕРМІНАЛ: тільки для САМОВИВОЗУ ──────────────────
        Sleep, % SpDly(400)
        ; 1/3 — видалити поточний тип оплати (хрестик, приціл 8)
        if (crossX > 0 || crossRelX > 0)
            IikoClickRelV(crossRelX, crossRelY, crossX, crossY, "Картка 1/3: видаляю тип")
        Sleep, % Max(1000, SpDly(1500))
        ; 2/3 — клік у клітинку «Тип оплати» (приціл 9) → відкриваємо редактор
        if (cashX > 0 || cashRelX > 0) {
            IikoClickRelV(cashRelX, cashRelY, cashX, cashY, "Картка 2/3: тип оплати")
            Sleep, % Max(250, SpDly(400))
            IikoClickRelV(cashRelX, cashRelY, cashX, cashY, "Картка 2/3: тип оплати")
            Sleep, % Max(700, SpDly(900))
        }
        ; 3/3 — ДРУКУЄМО слово пошуку → список фільтрується → Enter обирає
        _ttCx := 30, _ttCy := 30
        ToolTip, % "Картка 3/3: друкую «" . paymentCardSearch . "»", %_ttCx%, %_ttCy%
        Send, %paymentCardSearch%
        Sleep, % Max(500, SpDly(700))
        Send, {Enter}
        Sleep, % Max(350, SpDly(500))
        Send, {Enter}
        Sleep, % SpDly(400)
        ToolTip
    } else if ((DoAutoCash || DoAutoCard) && !isPickup) {
        ; Оплата стоїть галочкою, але замовлення НЕ визнане самовивозом → пропускаємо.
        ; Показуємо причину явно, щоб не «мовчало».
        _whyPay := "ℹ️ Оплату пропущено: не самовивіз. Поле вулиці прочитане як: «" . SubStr(streetText,1,40) . "». Якщо це самовивіз — перевір приціл 11 (Вулиця)."
        ToolTip, %_whyPay%
        SetTimer, RemoveToolTip, -7000
    }

    ; Подарунок пробиваємо ТІЛЬКИ якщо задано приціл «7. Табл. страв»:
    ; без кліку в таблицю PLU летить у неправильне поле (баг з оплатою/СИВ).
    if ((GiftPepsi || GiftBurger || GiftBrooklyn) && (itemX != 0 || itemRelX != 0)) {
        if (GiftBurger) {
            GoSub, NewGiftMacro
            Send, %pluBurger%           ; Send — іде в активне вікно (не ControlSend)
            GoSub, FinishGiftMacro
        } else if (GiftBrooklyn) {
            GoSub, NewGiftMacro
            Send, %pluBrooklyn%
            GoSub, FinishGiftMacro
        } else if (GiftPepsi) {
            GoSub, NewGiftMacro
            Send, %pluPepsi%
            GoSub, FinishGiftMacro
        }
        ToolTip   ; прибрати підказку подарунка
    }

    ; ── CRM: зберегти клієнта і залогувати замовлення ──
    _ahkLog2 := A_ScriptDir . "\ahk_debug.log"
    FileAppend, % "[" . A_Now . "] ApplyRollclub: RH_SERVER_OK=" . RH_SERVER_OK . "  clientPhone=" . clientPhone . "  orderSum=" . orderSum . "`n", %_ahkLog2%
    if (RH_SERVER_OK && clientPhone != "") {
        _giftStr := ""
        if (GiftBrooklyn) _giftStr .= "Brooklyn "
        if (GiftBurger)   _giftStr .= "Burger "
        if (GiftPepsi)    _giftStr .= "Pepsi "

        ; Тип оплати
        _payType := ""
        if (DoAutoCash)
            _payType := "Готівка"
        else if (DoAutoCard)
            _payType := "Картка/Термінал"
        else
            _payType := paymentMethod

        ; Повна адреса = вулиця + будинок (з iiko) + примітка
        _fullAddr := ""
        if (streetText != "")
            _fullAddr .= streetText
        if (houseText != "")
            _fullAddr .= ", " . houseText
        if (AddressNote != "")
            _fullAddr .= ((_fullAddr != "") ? " (" . AddressNote . ")" : AddressNote)
        if (isPickup)
            _fullAddr := "САМОВИВІЗ" . (pickupPoint != "" ? " " . pickupPoint : "")

        ; Екрануємо поля для JSON (лапки → апостроф, переноси → пробіл)
        _cmt  := RegExReplace(RegExReplace(OrderComment, """", "'"), "`n|`r", " ")
        _addr := RegExReplace(RegExReplace(_fullAddr,    """", "'"), "`n|`r", " ")
        _pay  := RegExReplace(_payType, """", "'")

        _orderJson := "{""phone"":""" . RegExReplace(clientPhone,"[\s\-\(\)\+]","") . ""","
            . """amount"":" . orderSum . ","
            . """comment"":""" . _cmt . ""","
            . """address"":""" . _addr . ""","
            . """ready_time"":""" . ReadyTime . ""","
            . """payment_type"":""" . _pay . ""","
            . """gift"":""" . Trim(_giftStr) . """}"
        FileAppend, % "[" . A_Now . "] SENDING /api/order: " . SubStr(_orderJson,1,120) . "`n", %_ahkLog2%
        _orderResp := RhPost("/api/order", _orderJson)
        FileAppend, % "[" . A_Now . "] /api/order response: " . SubStr(_orderResp,1,80) . "`n", %_ahkLog2%
    }
return

NewGiftMacro:
    ; Клік у таблицю страв (приціл 7) — гарантує, що PLU піде в таблицю,
    ; а не в поле оплати/інше. Без цього кліку був баг «летить не туди».
    ToolTip, % "🎁 Подарунок: відкриваю таблицю страв", 30, 60
    if (iikoWinExe != "" && iikoWinExe != "ERROR")
        WinActivate, ahk_exe %iikoWinExe%
    Sleep, % SpDly(80)
    IikoClickRel(itemRelX, itemRelY, itemX, itemY)
    Sleep, % SpDly(300)
    Send, {PgDn}
    Sleep, % SpDly(300)
    Send, {Enter}
    Sleep, % SpDly(400)
return

FinishGiftMacro:
    Sleep, % SpDly(400)
    Send, {Down}
    Sleep, % SpDly(300)
    Send, {Enter}
    Sleep, % SpDly(500)
return

WarnDateOk:
    Gui, WarnDate:Destroy
return

; ══════════════════════════════════════════════════════════════
;  КАРТКА КЛІЄНТА (CRM)
; ══════════════════════════════════════════════════════════════
OpenCrmCard:
    _norm := RhNormalizePhone(clientPhone)
    if (_norm = "") {
        MsgBox, 48, CRM, Номер телефону не вказано.
        return
    }
    if (!RH_SERVER_OK) {
        MsgBox, 48, CRM, Сервер не запущено.`nЗапустіть server\start.bat
        return
    }
    Run, http://127.0.0.1:5000/card?phone=%_norm%
return

SaveCrmCard:
    Gui, CrmCard:Submit, NoHide
    if (!RH_SERVER_OK) {
        MsgBox, 48, Помилка, Сервер не запущено!
        return
    }
    ; Формуємо JSON вручну
    _vip  := CrmVip     + 0
    _prob := CrmProblem + 0
    _n    := RegExReplace(CrmName,   """", "'")
    _nt   := RegExReplace(CrmNotes,  """", "'")
    _bd   := RegExReplace(CrmBday,   """", "'")
    _phone := RegExReplace(clientPhone, "[\s\-\(\)\+]", "")
    _json := "{""phone"":""" . _phone . ""","
           . """name"":""" . _n . ""","
           . """notes"":""" . _nt . ""","
           . """birthday"":""" . _bd . ""","
           . """vip"":" . _vip . ","
           . """problem"":" . _prob . "}"
    _r := RhPost("/api/customer", _json)
    ; Скидаємо кеш для цього номера (щоб бейдж оновився)
    norm := RhNormalizePhone(clientPhone)
    crmCache[norm]   := ""
    crmCacheTs[norm] := 0
    ; Оновлюємо бейдж в головному вікні
    SetTimer, AsyncCrmLookupMain, -100
    Gui, CrmCard:Destroy
    GuiControl, Roll:, CrmBadgeLbl, ✅ Збережено
return

CrmCardClose:
CrmCardGuiClose:
CrmCardGuiEscape:
    Gui, CrmCard:Destroy
return

RollGuiClose:
RollGuiEscape:
    SaveRollPos()
    Gui, Roll:Destroy
    SetTimer, RhUpdatePultClock, Off
    rollExists := 0
    rollVisible := 0
return

; Авто-сховання: вікно втратило фокус (клік повз нього) → ховаємо, дані лишаються.
; Не закриваємо, якщо активне інше НАШЕ вікно (СИВ, Налаштування, попап).
RollMaybeHide:
    if (!rollExists || !rollVisible)
        return
    if WinActive("RollHouse MEGA 3.0 (PLU) ahk_class AutoHotkeyGUI")
        return
    if (WinActive("СИВ (Модуль)") || WinActive("Налаштування PRO") || WinActive("Вихідний текст"))
        return
    SaveRollPos()
    Gui, Roll:Hide
    rollVisible := 0
return

; ── ~ : відкрити/підняти ВЕБ-пульт (єдиний пульт) ──
TriggerMainWeb:
    if WinExist("RollHelper ahk_exe msedge.exe") {
        WinActivate
        Sleep, 150
        Send, ^r
    } else {
        GoSub, OpenWebPult
    }
return

; ── RollHelper: відкрити ВЕБ-пульт у вікні Edge (бета) ──
^vkC0::
    if WinExist("RollHelper ahk_exe msedge.exe") {
        WinActivate
        Sleep, 200
        Send, ^r  ; Оновити сторінку (запускає читання з iiko)
    } else {
        GoSub, OpenWebPult
    }
return

OpenWebPult:
    _wpUrl := "http://127.0.0.1:5000/pult?brand=rollhouse"
    Run, msedge.exe --app=%_wpUrl% --window-size=384,780, , UseErrorLevel
    if (ErrorLevel)
        Run, %_wpUrl%   ; фолбек — у браузері за замовчуванням
return

; --- Асинхронний CRM lookup після відкриття GUI (phone з iiko) ---
AsyncCrmLookupMain:
    if (!WinExist("RollHouse MEGA 3.0 (PLU)") || clientPhone = "")
        return
    _badge := RhCustomerBadge(clientPhone)
    GuiControl, Roll:, CrmBadgeLbl, % _badge = "" ? "🆕 Новий клієнт" : _badge
return

; --- CRM: зміна поля телефону (debounce 500мс) ---
OnPhoneChange:
    Gui, Roll:Submit, NoHide
    clientPhone := ClientPhone
    _digits := RegExReplace(clientPhone, "[^\d]", "")
    if (StrLen(_digits) < 9)
        return
    GuiControl, Roll:, CrmBadgeLbl, ⏳
    SetTimer, DebouncedCrmLookup, -500   ; скасовує попередній і стартує новий
return

DebouncedCrmLookup:
    if (!RH_SERVER_OK || clientPhone = "")
        return
    ; Отримуємо badge (враховує fuzzy match)
    resp := RhGetCustomer(clientPhone)
    if (resp = "") {
        GuiControl, Roll:, CrmBadgeLbl, ⚠️ Сервер не відповідає
        return
    }
    exists := InStr(resp, """exists"": true") || InStr(resp, """exists"":true")
    fuzzy  := InStr(resp, """fuzzy_match"": true") || InStr(resp, """fuzzy_match"":true")
    if (exists && fuzzy) {
        ; Дублікат з іншим форматом — показуємо попередження
        RegExMatch(resp, """phone""\s*:\s*""([^""]*)", mP)
        RegExMatch(resp, """name""\s*:\s*""([^""]*)", mN)
        RegExMatch(resp, """total_orders""\s*:\s*(\d+)", mO)
        _dupMsg := "⚠️ Схожий номер: " . mP1
        if (mN1 != "")
            _dupMsg .= " (" . mN1 . ")"
        _dupMsg .= "  📦 " . mO1 . " зам."
        GuiControl, Roll:, CrmBadgeLbl, %_dupMsg%
    } else {
        _badge := RhCustomerBadge(clientPhone)
        GuiControl, Roll:, CrmBadgeLbl, % _badge = "" ? "🆕 Новий клієнт" : _badge
    }
return

; --- CRM: кнопка відкриває картку клієнта ---
LookupCrmBtn:
    Gui, Roll:Submit, NoHide
    clientPhone := ClientPhone
    if (clientPhone = "") {
        GuiControl, Roll:, CrmBadgeLbl, ⚠️ Введіть номер телефону
        return
    }
    if (!RH_SERVER_OK) {
        GuiControl, Roll:, CrmBadgeLbl, ⚠️ Сервер не запущено
        return
    }
    GoSub, OpenCrmCard
return

; --- РОБОТ-БУХГАЛТЕР F5 ---
F5::
    if (p1X = 0 || tgGroup = "") {
        MsgBox, 4144, Помилка, Сценарій не налаштовано!`nВідкрий Налаштування (⚙️) і натисни [🎬 Калібрування Звіту].
        return
    }

    MouseClickDrag, Left, %p1X%, %p1Y%, %p2X%, %p2Y%, 10
    Sleep, 800
    
    Click, %p3X%, %p3Y%
    Sleep, 500
    
    Click, %p4X%, %p4Y%
    Sleep, 300
    
    Click, %p5X%, %p5Y%
    Sleep, 300
    
    Send, {Esc}
    Sleep, 500
    
    Click, %p6X%, %p6Y%
    
    WinWaitActive, ahk_exe EXCEL.EXE,, 10
    if (ErrorLevel) {
        MsgBox, 4144, Помилка, Excel не відкрився.
        return
    }
    Sleep, 1500
    
    Send, ^{Home}
    Sleep, 300
    Send, ^+{End}
    Sleep, 300
    
    Clipboard := ""
    Send, ^c
    ClipWait, 3
    Sleep, 500
    
    text := Clipboard
    totalCount := 0, totalSum := 0, chCount := 0, chSum := 0, berCount := 0, berSum := 0, merCount := 0, merSum := 0, currentCity := ""

    Loop, Parse, text, `n, `r
    {
        line := A_LoopField

        if (InStr(line, "Точка:")) {
            RegExMatch(line, "\(Итого:\s*(\d+)\)", match)
            if (InStr(line, "Чугуїв")) {
                currentCity := "Чугуїв"
                chCount := match1
            } else if (InStr(line, "Берестин")) {
                currentCity := "Берестин"
                berCount := match1
            } else if (InStr(line, "Мерефа")) {
                currentCity := "Мерефа"
                merCount := match1
            }
        }
        else if (currentCity != "" && RegExMatch(line, "Итого:\s*([\d\s]+,\d{2})", match)) {
            sum := RegExReplace(match1, ",00$", "")
            sum := RegExReplace(sum, "\s+", " ")    
            if (currentCity == "Чугуїв")
                chSum := sum
            else if (currentCity == "Берестин")
                berSum := sum
            else if (currentCity == "Мерефа")
                merSum := sum
            currentCity := "" 
        }
        else if (InStr(line, "Всего:") && RegExMatch(line, "Всего:\s*(\d+)", match)) {
            totalCount := match1
            if RegExMatch(line, "Итого:\s*([\d\s]+,\d{2})", matchSum) {
                totalSum := RegExReplace(matchSum1, ",00$", "")
                totalSum := RegExReplace(totalSum, "\s+", " ")
            }
        }
    }

    if (totalCount == 0 && chCount == 0 && merCount == 0 && berCount == 0) {
        MsgBox, 4112, Помилка Парсингу, Скрипт не знайшов цифри!
        return
    }

    report := "Ролл Хаус:`nВСЬОГО: " . totalCount . " / " . totalSum . "`n`nБерестин: " . berCount . " / " . berSum . "`nМерефа: " . merCount . " / " . merSum . "`nЧугуїв: " . chCount . " / " . chSum
    Clipboard := report

    WinActivate, ahk_exe Telegram.exe
    WinWaitActive, ahk_exe Telegram.exe,, 3
    if (ErrorLevel) {
        MsgBox, 4144, Увага, Telegram не відкрито!
        return
    }
    
    Sleep, 300
    Send, {Esc} 
    Sleep, 200
    Send, ^f 
    Sleep, 300
    SendInput, %tgGroup%
    Sleep, 1000 
    Send, {Enter} 
    Sleep, 500
    
    Send, ^v
    Sleep, 300
    Send, {Enter}
return

; --- АВТОПРИНЯТИЕ ЗВОНКА ---
SetTimer, CheckCall, 500  ; Проверять каждые 500 мс
CheckCall:
    if (!callMode || callX = 0 || callY = 0) {
        ToolTip, , , , 2
        return
    }

    IikoXY(callRelX, callRelY, callX, callY, _callAbsX, _callAbsY)
    cYOffset := _callAbsY + 50
    ToolTip, 📞 Автоприйом дзвінка...`nНатисни F2 для зупинки., %_callAbsX%, %cYOffset%, 2

    ; Ищем изображение в области вокруг прицела (±150 пикселей)
    cX1 := _callAbsX - 150
    cY1 := _callAbsY - 150
    cX2 := _callAbsX + 150
    cY2 := _callAbsY + 150
    if (cX1 < 0)
        cX1 := 0
    if (cY1 < 0)
        cY1 := 0
    if (cX2 > A_ScreenWidth)
        cX2 := A_ScreenWidth
    if (cY2 > A_ScreenHeight)
        cY2 := A_ScreenHeight

    ImageSearch, foundCallX, foundCallY, %cX1%, %cY1%, %cX2%, %cY2%, *30 img\call_button.png
    if (ErrorLevel = 0) {
        clkX := foundCallX + 10
        clkY := foundCallY + 10
        Click, %clkX%, %clkY%, 2
        Sleep, 100
        Click, %clkX%, %clkY%, 2

        callMode := 0
        SetTimer, CheckCall, Off
        ToolTip, 🟢 ДЗВІНОК ПРИЙНЯТО!, %foundCallX%, % foundCallY - 30

        logFile := A_ScriptDir "\siv_debug.log"
        FileAppend, `n[DEBUG] %A_Now% - Event: Call Found and Answered at %foundCallX%x%foundCallY%`n, %logFile%

        SetTimer, RemoveCallToolTip, -3000
    }
return

RemoveCallToolTip:
    ToolTip
return

; ════════════════════════════════════════════════════════════
; РЕЖИМ ОБЗВОНУ (F6 toggle, Space = наступний дзвінок)
; - F6 вмикає/вимикає режим
; - При ввімкненні: читаємо стовпчик K активного Excel-листа в callList
; - Кожен Space у будь-якому вікні (поки режим активний): вставити
;   наступний номер у поле Aiko, натиснути "Подзвонити"
; ════════════════════════════════════════════════════════════
F6::
    if (callListMode) {
        ; --- ВИМКНУТИ режим ---
        GoSub, CallStopMode
        return
    }
    ; --- УВІМКНУТИ режим ---
    if (aikoInputX = 0 || aikoCallX = 0) {
        MsgBox, 48, Обзвон, Не задано приціли Aiko!`nВідкрий Налаштування → 12. Aiko - поле № та 13. Aiko - Дзвонити.
        return
    }
    if (!LoadCallList()) {
        return
    }
    if (callListCount = 0) {
        MsgBox, 48, Обзвон, У стовпчику K активного Excel-листа немає номерів.
        return
    }
    callListMode := 1
    ; Активуємо налаштовані хоткеї тільки на час режиму
    Hotkey, %hkCallNext%, CallNextNumber, On UseErrorLevel
    if (ErrorLevel) {
        MsgBox, 48, Обзвон, Не вдалось зареєструвати хоткей "%hkCallNext%" для наступного дзвінка. Зміни в Налаштуваннях.
    }
    if (hkCallHangup != "") {
        Hotkey, %hkCallHangup%, CallHangUp, On UseErrorLevel
    }
    if (hkCallPause != "") {
        Hotkey, %hkCallPause%, CallPauseToggle, On UseErrorLevel
    }
    GoSub, ShowCallProgress
return

; F7 — ЗАМОРОЗИТИ / РОЗМОРОЗИТИ обзвон (зберігає прогрес, вимикає хоткеї)
F7::
    if (!callListMode)
        return
    if (callFrozen)
        GoSub, CallUnfreezeMode
    else
        GoSub, CallFreezeMode
return


; --- Завантаження списку зі стовпчика K активного Excel ---
LoadCallList() {
    global callList, callListCount, callListIdx, callNoAnswer, callDialing
    callList := []
    callListIdx := 0
    callListCount := 0
    callNoAnswer := 0
    callDialing := 0
    try {
        xl := ComObjActive("Excel.Application")
    } catch e {
        MsgBox, 48, Обзвон, Excel не запущено або файл не відкрито.
        return 0
    }
    try {
        sheet := xl.ActiveSheet
        ; xlUp = -4162. Шукаємо останню заповнену комірку в стовпчику K (11).
        lastRow := sheet.Cells(sheet.Rows.Count, 11).End(-4162).Row
        Loop, % lastRow {
            val := sheet.Cells(A_Index, 11).Value
            if (val = "" || val = 0)
                continue
            ; Прибираємо все крім цифр та "+"
            cleanNum := RegExReplace(val, "[^\d+]", "")
            if (StrLen(cleanNum) >= 7)
                callList.Push(cleanNum)
        }
        callListCount := callList.Length()
        return 1
    } catch e {
        MsgBox, 48, Обзвон, Помилка читання Excel:`n%e%
        return 0
    }
}

; --- Міні-вікно прогресу обзвону ---
ShowCallProgress:
    RhApplyTheme()
    Gui, CallGui:Destroy
    Gui, CallGui:+AlwaysOnTop +ToolWindow -MaximizeBox
    Gui, CallGui:Color, %RhC_BG%, %RhC_Panel%
    Gui, CallGui:Add, Progress, x0 y0 w280 h42 -Theme c%RhC_Header%, 100
    Gui, CallGui:Add, Progress, x0 y0 w280 h3 -Theme c%RhC_Neon%, 100
    Gui, CallGui:Font, s10 bold c%RhC_HeaderText%, %RhFontName%
    Gui, CallGui:Add, Text, x10 y10 w260 Center +BackgroundTrans, 📞 РЕЖИМ ОБЗВОНУ
    Gui, CallGui:Font, s9 norm c%RhC_Muted%, %RhFontName%
    hintLine := hkCallNext . " = наст  |  " . hkCallPause . " = пауза"
    if (hkCallHangup != "")
        hintLine .= "  |  " . hkCallHangup . " = покласти"
    Gui, CallGui:Add, Text, x10 y+4 w260 Center, %hintLine%
    ; Лічильник
    Gui, CallGui:Font, s11 bold c%RhC_Text%, %RhFontName%
    progressTxt := callListIdx . " з " . callListCount
    Gui, CallGui:Add, Text, x10 y+8 w260 Center vCallProgressLbl, %progressTxt%
    ; Поточний номер
    Gui, CallGui:Font, s13 bold c%RhC_Neon%, %RhFontName%
    Gui, CallGui:Add, Text, x10 y+4 w260 Center vCallCurrentNum, —
    ; Статус
    Gui, CallGui:Font, s10 norm c%RhC_Muted%, %RhFontName%
    Gui, CallGui:Add, Text, x10 y+6 w260 Center vCallStatusLbl, ⏳ Очікування...
    ; CRM-бейдж клієнта
    Gui, CallGui:Font, s8 norm c%RhC_SoftText%, %RhFontName%
    Gui, CallGui:Add, Text, x10 y+4 w260 Center vCallCrmLbl, —
    ; Лічильник без відповіді
    Gui, CallGui:Font, s9 bold cFF6666, %RhFontName%
    Gui, CallGui:Add, Text, x10 y+4 w260 Center vCallNoAnswerLbl, 📵 Не відповіли: 0
    ; Пауза
    Gui, CallGui:Font, s10 bold c141A22, %RhFontName%
    Gui, CallGui:Add, Button, x10 y+10 w260 h30 vCallPauseBtn gCallPauseToggle, ⏸ ПАУЗА (відгук)
    Gui, CallGui:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, CallGui:Font, s10 bold c2563EB, %RhFontName%
    Gui, CallGui:Add, Button, x10 y+6 w260 h30 gCallFreezeMode, 🧊 ЗАМРОЗИТИ (пробити замовлення)
    Gui, CallGui:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, CallGui:Add, Button, x10 y+6 w125 h26 gCallResetCounter, ↺ Скинути
    Gui, CallGui:Add, Button, x+10 yp w125 h26 gCallStopMode, ⏹ Стоп
    Gui, CallGui:Show, x20 y200 w280, Обзвон
return

; --- Оновити колір та статус CallGui ---
UpdateCallGuiState(state) {
    if (!WinExist("Обзвон"))
        return
    if (state = "talking") {
        Gui, CallGui:Color, 0d3020
        GuiControl, CallGui:, CallStatusLbl, 🟢 Розмова...
    } else if (state = "paused") {
        Gui, CallGui:Color, 2e2000
        GuiControl, CallGui:, CallStatusLbl, ⏸ Пауза
    } else if (state = "dialing") {
        Gui, CallGui:Color, 141428
        GuiControl, CallGui:, CallStatusLbl, 📲 Набираємо...
    } else {
        Gui, CallGui:Color, 1a1a2a
        GuiControl, CallGui:, CallStatusLbl, ⏳ Очікування...
    }
}

CallResetCounter:
    callListIdx := 0
    GuiControl, CallGui:, CallProgressLbl, % callListIdx . " з " . callListCount
    GuiControl, CallGui:, CallCurrentNum, —
    UpdateCallGuiState("idle")
return

CallPauseToggle:
    if (!callListMode)
        return
    if (!callPaused) {
        callPaused := 1
        GuiControl, CallGui:, CallPauseBtn, ▶ ПРОДОВЖИТИ
        UpdateCallGuiState("paused")
        ToolTip, ⏸ ПАУЗА — авто-перехід зупинено, 10, 10, 5
    } else {
        callPaused := 0
        GuiControl, CallGui:, CallPauseBtn, ⏸ ПАУЗА (відгук)
        UpdateCallGuiState("talking")
        ToolTip, , , , 5
    }
return

CallStopMode:
CallGuiClose:
CallGuiEscape:
    callListMode := 0
    callFrozen := 0
    callAutoNext := 0
    callPaused := 0
    callDialing := 0
    SetTimer, WaitForCallEnd, Off
    SetTimer, AutoDialNext, Off
    SetTimer, WaitForTalkStart, Off
    Hotkey, %hkCallNext%, CallNextNumber, Off UseErrorLevel
    if (hkCallHangup != "")
        Hotkey, %hkCallHangup%, CallHangUp, Off UseErrorLevel
    if (hkCallPause != "")
        Hotkey, %hkCallPause%, CallPauseToggle, Off UseErrorLevel
    UnblockSoundpadKeys()
    Gui, CallGui:Destroy
    Gui, UnfreezeGui:Destroy
    ToolTip, Режим обзвону ВИМКНЕНО, , , 4
    SetTimer, RemoveCallProgressTip, -2000
return

; --- ЗАМОРОЗКА: сховати вікно + вимкнути хоткеї, але зберегти прогрес ---
CallFreezeMode:
    if (!callListMode)
        return
    ; Зупиняємо таймери та паузимо
    callFrozen := 1
    callPaused := 1
    callAutoNext := 0
    callDialing := 0
    SetTimer, WaitForCallEnd, Off
    SetTimer, AutoDialNext, Off
    SetTimer, WaitForTalkStart, Off
    ; Вимикаємо хоткеї обзвону
    Hotkey, %hkCallNext%, CallNextNumber, Off UseErrorLevel
    if (hkCallHangup != "")
        Hotkey, %hkCallHangup%, CallHangUp, Off UseErrorLevel
    if (hkCallPause != "")
        Hotkey, %hkCallPause%, CallPauseToggle, Off UseErrorLevel
    ; Ховаємо вікно і показуємо маленьку кнопку розморозки
    Gui, CallGui:Hide
    Gui, UnfreezeGui:Destroy
    Gui, UnfreezeGui:+AlwaysOnTop +ToolWindow -Caption -MaximizeBox
    Gui, UnfreezeGui:Color, 2563EB
    Gui, UnfreezeGui:Font, s11 bold cFFFFFF, %RhFontName%
    Gui, UnfreezeGui:Add, Button, x0 y0 w280 h35 gCallUnfreezeMode, ▶ РОЗМОРОЗИТИ (або F7)
    Gui, UnfreezeGui:Show, x20 y200 w280 h35, Unfreeze
    ; Блокуємо клавіші Soundpad (вони будуть проходити нормально, але Soundpad їх не отримає)
    BlockSoundpadKeys()
    ToolTip, 🧊 Обзвон ЗАМОРОЖЕНО (%callListIdx%/%callListCount%) — натисни кнопку або F7 щоб відновити, 10, 10, 4
    SetTimer, RemoveCallProgressTip, -3000
return

; --- РОЗМОРОЗКА: відновити вікно + хоткеї ---
CallUnfreezeMode:
    if (!callListMode || !callFrozen)
        return
    callFrozen := 0
    callPaused := 0
    Gui, UnfreezeGui:Destroy
    ; Знімаємо блокування Soundpad
    UnblockSoundpadKeys()
    ; Відновлюємо хоткеї обзвону
    Hotkey, %hkCallNext%, CallNextNumber, On UseErrorLevel
    if (hkCallHangup != "")
        Hotkey, %hkCallHangup%, CallHangUp, On UseErrorLevel
    if (hkCallPause != "")
        Hotkey, %hkCallPause%, CallPauseToggle, On UseErrorLevel
    ; Оновлюємо та показуємо вікно
    GuiControl, CallGui:, CallProgressLbl, % callListIdx . " з " . callListCount
    GuiControl, CallGui:, CallPauseBtn, ⏸ ПАУЗА (відгук)
    UpdateCallGuiState("idle")
    Gui, CallGui:Show
    ToolTip, ▶ Обзвон ВІДНОВЛЕНО з позиції %callListIdx%, 10, 10, 4
    SetTimer, RemoveCallProgressTip, -2000
return

; --- Блокування клавіш Soundpad (AHK перехоплює їх і просто пропускає напів, Soundpad їх не бачить) ---
BlockSoundpadKeys() {
    global soundpadKeys
    if (soundpadKeys = "" || soundpadKeys = "ERROR")
        return
    Loop, Parse, soundpadKeys, |
    {
        k := Trim(A_LoopField)
        if (k = "")
            continue
        Hotkey, $%k%, SoundpadPassthrough, On UseErrorLevel
    }
}

UnblockSoundpadKeys() {
    global soundpadKeys
    if (soundpadKeys = "" || soundpadKeys = "ERROR")
        return
    Loop, Parse, soundpadKeys, |
    {
        k := Trim(A_LoopField)
        if (k = "")
            continue
        Hotkey, $%k%, SoundpadPassthrough, Off UseErrorLevel
    }
}

; Просто пропускає клавішу напів без змін
SoundpadPassthrough:
    key := A_ThisHotkey
    ; видаляємо префікс "$"
    StringReplace, key, key, $
    Send, {%key%}
return

RemoveCallProgressTip:
    ToolTip, , , , 4
return

; --- Наступний дзвінок (вішається на hkCallNext тільки коли callListMode=1) ---
CallNextNumber:
    if (!callListMode)
        return
    ; Скидаємо авто-очікування та паузу
    callAutoNext := 0
    callPaused := 0
    SetTimer, WaitForCallEnd, Off
    SetTimer, AutoDialNext, Off
    GuiControl, CallGui:, CallPauseBtn, ⏸ ПАУЗА (відгук)
    UpdateCallGuiState("idle")
    if (callListIdx >= callListCount) {
        ToolTip, Список закінчився (%callListCount%), , , 4
        SetTimer, RemoveCallProgressTip, -2500
        return
    }
    callListIdx++
    num := callList[callListIdx]

    ; Запам'ятати буфер обміну, щоб не зіпсувати робочий вміст
    prevClip := ClipboardAll
    Clipboard := num
    ClipWait, 0.5

    ; Клік у поле, очистити, вставити
    Click, %aikoInputX%, %aikoInputY%
    Sleep, % SpDly(150)
    Send, ^a
    Sleep, 50
    Send, ^v
    Sleep, % SpDly(180)

    ; Дзвонити (клік по кнопці)
    Click, %aikoCallX%, %aikoCallY%

    ; Відновити буфер
    Sleep, 100
    Clipboard := prevClip
    prevClip := ""

    ; Оновити лічильник та поточний номер у міні-вікні
    GuiControl, CallGui:, CallProgressLbl, % callListIdx . " з " . callListCount
    GuiControl, CallGui:, CallCurrentNum, %num%
    GuiControl, CallGui:, CallCrmLbl, % RH_SERVER_OK ? "⏳ Шукаємо..." : "—"
    callDialing := 1
    UpdateCallGuiState("dialing")
    ; CRM lookup (асинхронно через одноразовий таймер)
    SetTimer, CrmLookupTimer, -200

    ; --- Запустити автодетект розмови (макс 30 сек) ---
    ; Працює якщо є картинка img\call_start.png і задано хоткей "Прийняти розмову"
    if (hkAcceptTalk != "" && FileExist("img\call_start.png")) {
        callWaitDeadline := A_TickCount + 30000
        SetTimer, WaitForTalkStart, 300
    }
return

; --- Таймер: коли побачив img\call_start.png — надсилає клавішу hkAcceptTalk ---
WaitForTalkStart:
    if (!callListMode) {
        SetTimer, WaitForTalkStart, Off
        ToolTip, , , , 5
        return
    }
    if (callPaused) {
        SetTimer, WaitForTalkStart, Off
        ToolTip, , , , 5
        return
    }
    if (A_TickCount > callWaitDeadline) {
        SetTimer, WaitForTalkStart, Off
        ToolTip, , , , 5
        ; Клієнт не відповів — кладемо трубку і йдемо далі
        if (aikoHangupX > 0)
            Click, %aikoHangupX%, %aikoHangupY%
        callDialing := 0
        callNoAnswer++
        GuiControl, CallGui:, CallNoAnswerLbl, 📵 Не відповіли: %callNoAnswer%
        ToolTip, 📵 Не відповів. Наступний..., 10, 10, 5
        SetTimer, AutoDialNext, -2000
        return
    }
    ImageSearch, fX, fY, 0, 0, A_ScreenWidth, A_ScreenHeight, *60 img\call_start.png
    if (ErrorLevel = 0) {
        SetTimer, WaitForTalkStart, Off
        ; Надсилаємо налаштовану клавішу — натискає кнопку "Розмова" в Aiko
        Send, {%hkAcceptTalk%}
        callDialing := 0   ; відповіли — більше не "без відповіді"
        ToolTip, 🟢 Розмова почалась!, 10, 10, 5
        SetTimer, RemoveTalkTip, -2000
        UpdateCallGuiState("talking")
        ; --- АВТО-ПЕРЕХІД: запускаємо моніторинг кінця розмови ---
        if (FileExist("img\call_end.png")) {
            callAutoNext := 1
            SetTimer, WaitForCallEnd, 1000
        }
    } else {
        secLeft := Round((callWaitDeadline - A_TickCount) / 1000)
        ToolTip, Чекаю розмову... %secLeft%с, 10, 10, 5
    }
return

RemoveTalkTip:
    ToolTip, , , , 5
return

; --- Таймер: чекаємо кінець розмови → авто-набираємо наступний ---
WaitForCallEnd:
    if (!callListMode || !callAutoNext) {
        SetTimer, WaitForCallEnd, Off
        return
    }
    if (callPaused)   ; пауза — чекаємо, нічого не робимо
        return
    ; Область пошуку: ±200 px від прицела 15, або весь екран якщо не задано
    if (callEndX > 0) {
        ceX1 := callEndX - 200
        ceY1 := callEndY - 200
        ceX2 := callEndX + 200
        ceY2 := callEndY + 200
        if (ceX1 < 0)
            ceX1 := 0
        if (ceY1 < 0)
            ceY1 := 0
        if (ceX2 > A_ScreenWidth)
            ceX2 := A_ScreenWidth
        if (ceY2 > A_ScreenHeight)
            ceY2 := A_ScreenHeight
    } else {
        ceX1 := 0
        ceY1 := 0
        ceX2 := A_ScreenWidth
        ceY2 := A_ScreenHeight
    }
    ImageSearch, ceFoundX, ceFoundY, %ceX1%, %ceY1%, %ceX2%, %ceY2%, *40 img\call_end.png
    if (ErrorLevel = 0) {
        SetTimer, WaitForCallEnd, Off
        callAutoNext := 0
        ToolTip, ✅ Розмова завершена. Набираю наступний..., 10, 10, 5
        UpdateCallGuiState("idle")
        SetTimer, AutoDialNext, -2000   ; 2 сек паузи перед автонабором
    }
return

; --- CRM lookup таймер (запускається після набору номера) ---
CrmLookupTimer:
    _curNum := callList[callListIdx]
    if (_curNum != "" && RH_SERVER_OK) {
        ShowCrmPopup(_curNum)
        ; Якщо новий — зберегти в базу (без даних, просто зафіксувати номер)
        RhSaveCustomer(_curNum)
        ; Залогувати дзвінок
        RhLogCall(_curNum, 0, 0)
    }
return

AutoDialNext:
    ToolTip, , , , 5
    GoSub, CallNextNumber
return

; --- Покласти трубку (hkCallHangup, тільки коли callListMode=1) ---
CallHangUp:
    if (!callListMode)
        return
    if (aikoHangupX = 0) {
        ToolTip, Не задано приціл "Покласти трубку" (Налаштування → 14), , , 4
        SetTimer, RemoveCallProgressTip, -2500
        return
    }
    Click, %aikoHangupX%, %aikoHangupY%

    ; Зупиняємо таймер очікування — не чекаємо 30 сек
    SetTimer, WaitForTalkStart, Off
    ToolTip, , , , 5

    ; Якщо ще не відповіли (дзвонили) — рахуємо як "не відповів"
    if (callDialing) {
        callDialing := 0
        callNoAnswer++
        GuiControl, CallGui:, CallNoAnswerLbl, 📵 Не відповіли: %callNoAnswer%
    }

    ; Одразу до наступного (1 сек пауза)
    UpdateCallGuiState("idle")
    SetTimer, AutoDialNext, -1000
return

; ═══════════════════════════════════════════════════════════
; АВТО-ВИЗНАЧЕННЯ ЗОНИ ДОСТАВКИ (RollClub)
; Щоб оновити карту — просто замініть файл:
;   brands\rollclub\zones.kml
; Кеш скинеться при перезапуску скрипта.
; ═══════════════════════════════════════════════════════════

; ── Таймер: запускається через 450мс після відкриття GUI ──
LoadKmlFile:
    FileSelectFile, _kmlSel, 3,, Виберіть KML-файл зони, KML (*.kml)
    if (_kmlSel = "")
        return
    _kmlDst := A_ScriptDir . "\brands\rollclub\zones.kml"
    FileCopy, %_kmlSel%, %_kmlDst%, 1
    if (ErrorLevel) {
        MsgBox, 48, KML, Не вдалось скопіювати KML-файл.
        return
    }
    RcZonesOk := 0
    RcZones := []
    MsgBox, 64, KML, Зону завантажено. Діє з наступного замовлення.
return

RcCheckZone:
    global streetText, isPickup, RcZones, RcZonesOk, deliveryCostNum
    SetTimer, RcCheckZone, Off

    addr := Trim(streetText)
    if (addr = "" || isPickup)
        return

    ; Очищаємо адресу від квартир, поверхів, під'їздів перед геокодуванням (ігноруємо 'empty', який надсилає iiko)
    addr := RegExReplace(addr, "i)[,\s]+(эт|поверх|кв|квартира|под|під|п|к|парадна|корп|корпус)\.?\s*(\d+|empty).*$", "")
    ; Також видаляємо ізольоване слово empty, якщо воно залишилось
    addr := RegExReplace(addr, "i)\bempty\b", "")
    ; Видаляємо назву міста з початку адреси, якщо вона там є
    addr := RegExReplace(addr, "i)^(Днепр|Дніпро|Харьков|Харків|Одесса|Одеса|Киев|Київ|Львов|Львів|Винница|Вінниця|Рівне|Ровно)[,\s]+", "")
    
    ; Виправлення проблемних мікрорайонів (особливо для Дніпра), бо Nominatim погано шукає російські назви
    addr := RegExReplace(addr, "i)Тополь[\-\s]*(\d)", "Тополя-$1")
    addr := RegExReplace(addr, "i)Победа[\-\s]*(\d)", "Перемога-$1")
    addr := RegExReplace(addr, "i)Сокол[\-\s]*(\d)", "Сокіл-$1")
    addr := RegExReplace(addr, "i)Красный Камень", "Червоний Камінь")
    addr := RegExReplace(addr, "i)Коммунар", "Покровський")
    
    addr := Trim(addr)

    ; Формуємо список спроб для геокодера
    attempts := [addr]
    if RegExMatch(addr, "i)^(Мерефа|Берестин|Чугуїв|Чугуєв|Харків)[,\s]+(.*)$", m)
        attempts.Push(Trim(m2))

    lat := "", lng := ""
    for idx, a in attempts {
        resp := RcHttpGet("https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&q=" . RcUriEncode(a), 6000)
        if (resp = "") {
            GuiControl, Roll:, MapSearch, ❓ Мережа недоступна
            return
        }
        if (RegExMatch(resp, """lat"":""([^""]+)""", mLat) && RegExMatch(resp, """lon"":""([^""]+)""", mLon)) {
            lat := mLat1, lng := mLon1
            break
        }
        ; Запасний варіант — прибираємо номер будинку (все після останньої коми)
        if (InStr(a, ",")) {
            addrNoHouse := Trim(RegExReplace(a, ",[^,]+$", ""))
            resp2 := RcHttpGet("https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&q=" . RcUriEncode(addrNoHouse), 6000)
            if (RegExMatch(resp2, """lat"":""([^""]+)""", mLat) && RegExMatch(resp2, """lon"":""([^""]+)""", mLon)) {
                resp := resp2
                lat := mLat1, lng := mLon1
                break
            }
        }
    }

    if (lat = "") {
        GuiControl, Roll:, MapSearch, ❓ Адресу не знайдено
        return
    }

    lat += 0
    lng += 0

    ; Завантажити KML якщо ще не завантажено (кеш зберігається до перезапуску)
    kmlPath := A_ScriptDir "\brands\rollclub\zones.kml"
    if (!RcZonesOk && FileExist(kmlPath))
        RcLoadKml(kmlPath)

    ; Визначення зони
    if (RcZonesOk && RcZones.MaxIndex() > 0) {
        zone := RcFindZone(lng, lat)
        result := (zone != "") ? ("📍 " . zone) : "⚠️ Поза зонами доставки"
    } else {
        ; KML немає або порожній — показуємо display_name з геокодера
        if RegExMatch(resp, """display_name"":""([^""]+)""", mD)
            result := "📍 " . SubStr(mD1, 1, 55)
        else
            result := "📍 " . lat . ", " . lng
    }
    
    if (deliveryCostNum > 0 && result != "⚠️ Поза зонами доставки")
        result .= " (" . deliveryCostNum . " грн)"

    GuiControl, Roll:, MapSearch, %result%
return

; ── HTTP GET (синхронний, з таймаутом) ──
RcHttpGet(url, timeoutMs := 6000) {
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, false)
        whr.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
        whr.SetRequestHeader("User-Agent", "RollHelper/3.0 (AHK)")
        whr.Send()
        return whr.ResponseText
    } catch {
        return ""
    }
}

; ── URI-encode рядка для Nominatim ──
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

; ── Завантажити KML → заповнити RcZones ──
; Підтримує: Polygon всередині Folder (по містах) та на верхньому рівні.
; Point-маркери (кухні/ресторани) ігноруються.
RcLoadKml(kmlPath) {
    global RcZones, RcZonesOk
    RcZones   := []
    RcZonesOk := 0

    xml := ComObjCreate("MSXML2.DOMDocument.6.0")
    xml.async := false
    if (!xml.load(kmlPath)) {
        return
    }

    try {
        xml.setProperty("SelectionLanguage", "XPath")
        xml.setProperty("SelectionNamespaces", "xmlns:k='http://www.opengis.net/kml/2.2'")
        placemarks := xml.selectNodes("//k:Placemark[.//k:Polygon]")
    } catch {
        placemarks := xml.selectNodes("//Placemark")
    }

    Loop % placemarks.length {
        pm := placemarks.item(A_Index - 1)

        try {
            nameNode := pm.selectSingleNode(".//k:name")
        } catch {
            nameNode := pm.getElementsByTagName("name").item(0)
        }
        
        if (nameNode) {
            zoneName := Trim(nameNode.text)
        } else {
            zoneName := "Зона " . A_Index
        }
        
        zoneName := RegExReplace(zoneName, "[\r\n]+", " ")
        zoneName := Trim(zoneName)

        try {
            coordNode := pm.selectSingleNode(".//k:Polygon//k:coordinates")
        } catch {
            coordNode := ""
        }
        
        if (!coordNode) {
            try {
                coordNode := pm.selectSingleNode(".//k:coordinates")
            } catch {
                coordNode := pm.getElementsByTagName("coordinates").item(0)
            }
        }
        
        if (!coordNode) {
            continue
        }

        coords := []
        rawCoords := Trim(coordNode.text)
        Loop, Parse, rawCoords, `n, `r
        {
            lf := Trim(A_LoopField)
            if (lf != "") {
                parts := StrSplit(lf, ",")
                if (parts.MaxIndex() >= 2) {
                    coords.Push([parts[1] + 0, parts[2] + 0])
                }
            }
        }
        
        if (coords.MaxIndex() >= 3) {
            RcZones.Push({name: zoneName, coords: coords})
        }
    }

    if (RcZones.MaxIndex() > 0) {
        RcZonesOk := 1
    } else {
        RcZonesOk := 0
    }
}

; ── Point-in-polygon (ray casting algorithm) ──
RcInPolygon(lng, lat, coords) {
    inside := 0
    n := coords.MaxIndex()
    j := n
    Loop % n {
        i  := A_Index
        xi := coords[i][1],  yi := coords[i][2]
        xj := coords[j][1],  yj := coords[j][2]
        if ((yi > lat) != (yj > lat))
            if (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)
                inside := !inside
        j := i
    }
    return inside
}

; ── Знайти зону за координатами (перебір всіх полігонів) ──
RcFindZone(lng, lat) {
    global RcZones
    for i, z in RcZones {
        if RcInPolygon(lng, lat, z.coords)
            return z.name
    }
    return ""
}

  












