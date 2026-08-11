#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
FileEncoding, UTF-8
#Include %A_ScriptDir%\lib\UIA_Interface.ahk
#Include %A_ScriptDir%\core\orchestration\OperationCoordinator.ahk
#Include %A_ScriptDir%\core\modules\ModuleRegistry.ahk

; ══════════════════════════════════════════════════════════════
;  RollHelper — брендовый пакет RollHouse
;  RollClub запускается своим entrypoint engine_rollclub.ahk.
;  Выбор бренда выполняет лаунчер, а не рабочий пульт.
; ══════════════════════════════════════════════════════════════
global APP_DIR := A_ScriptDir
global BRAND := "rollhouse"
global BRAND_DIR := APP_DIR . "\brands\rollhouse"
global UIA_MAP_CONFIG := BRAND_DIR . "\RkConfig.ini"
global RhEnterBusy := 0
global RhLastEnterTick := 0
global RhEnterCooldownMs := 2500
global RhFinishBusy := 0
global RhLocalUIA := ""
OpCoord_Init("rollhouse", APP_DIR)
ModuleRegistry_Init(APP_DIR, "rollhouse", "mvp")
SetWorkingDir, %BRAND_DIR%
OnExit, ExitRoutine

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

RhLaunchServer() {
    global APP_DIR
    serverDir := APP_DIR . "\..\server"
    embeddedPython := APP_DIR . "\..\runtime\python\pythonw.exe"
    if FileExist(embeddedPython) {
        Run, "%embeddedPython%" "%serverDir%\app.py", %serverDir%, Hide
        return
    }
    Run, pythonw "%serverDir%\app.py", %serverDir%, Hide
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
IniRead, noChangeX, RkConfig.ini, Targets, NoChangeX, 0
IniRead, noChangeY, RkConfig.ini, Targets, NoChangeY, 0
IniRead, noChangeRelX, RkConfig.ini, TargetsRel, NoChangeX, 0
IniRead, noChangeRelY, RkConfig.ini, TargetsRel, NoChangeY, 0
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
IniRead, hkAcceptTalk,  RkConfig.ini, Hotkeys, AcceptTalk,  1
IniRead, soundpadKeys,  RkConfig.ini, Hotkeys, SoundpadKeys, 1|x
IniRead, callListenEnabled, RkConfig.ini, CallListen, AutoEnabled, 1
IniRead, callListenEngine, RkConfig.ini, CallListen, Engine, whisper
IniRead, callListenAdvisorOnly, RkConfig.ini, CallListen, AdvisorOnly, 1
IniRead, callGreetingDelayMs, RkConfig.ini, CallListen, GreetingDelayMs, 6000
IniRead, callListenDevice, RkConfig.ini, CallListen, Device, 0
IniRead, callListenRmsThreshold, RkConfig.ini, CallListen, RmsThreshold, 10
IniRead, callListenModel, RkConfig.ini, CallListen, Model, base
IniRead, callListenBeamSize, RkConfig.ini, CallListen, BeamSize, 5
IniRead, callListenPrompt, RkConfig.ini, CallListen, Prompt,
; soundpadKeys — клавіші Soundpad через "|" (напр. "1|x|F9")
; Під час заморозки AHK блокує ці клавіші від Soundpad
global callWaitDeadline := 0  ; час (ms тіки) до якого чекаємо появу картинки розмови

; --- Режим обзвону ---
global callListMode := 0    ; 0=вимкнено, 1=ввімкнено
global callList := []       ; масив номерів
global callListIdx := 0     ; індекс наступного для дзвінка (1-based, 0=ще не дзвонили)
global callListCount := 0   ; всього в списку
global callDuplicateCount := 0 ; скільки дублів пропущено при завантаженні
global callMode := 0
global callAutoNext := 0    ; 1 = чекаємо кінця розмови для авто-переходу до наступного
global callPaused := 0      ; 1 = пауза, не переходимо до наступного
global callNoAnswer := 0    ; лічильник "не відповів / зайнято / скинув"
global callDialing := 0     ; 1 = зараз дзвонимо (ще не відповіли)
global callFrozen := 0      ; 1 = заморожено (вікно приховано, хоткеї вимкнено, прогрес збережено)
global callAutoListenBusy := 0
global callDiagMode := 0
global callManualGoodbyeTick := 0
global callLastArchiveId := ""
global callLastArchiveNum := ""
global callListenRmsThreshold
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
; Локальний UIA/WinAPI-шар RollHouse.
; Пробуємо працювати напряму з Syrve-контролами без Python-сервера.
; Старі координати лишаються fallback нижче.
; ──────────────────────────────────────────────────────────────
RhUiaInit() {
    global RhLocalUIA
    if (IsObject(RhLocalUIA))
        return 1
    try {
        RhLocalUIA := UIA_Interface()
        return IsObject(RhLocalUIA)
    } catch e {
        RhLocalUIA := ""
        return 0
    }
}

RhUiaWindow() {
    global RhLocalUIA, iikoWinExe
    if (!RhUiaInit())
        return ""
    hwnd := WinExist("ahk_exe " . iikoWinExe)
    if (!hwnd)
        return ""
    try return RhLocalUIA.ElementFromHandle(hwnd)
    catch e
        return ""
}

RhUiaRoot() {
    win := RhUiaWindow()
    if (!IsObject(win))
        return ""
    try root := win.FindFirstBy("AutomationId=DeliveryOrderEditControl")
    catch e
        root := ""
    return IsObject(root) ? root : win
}

RhUiaFind(role, defaultAid:="") {
    IniRead, _mapped, RkConfig.ini, UiaMap, %role%, %A_Space%
    if (_mapped != "" && _mapped != "ERROR") {
        aid := _mapped
    } else {
        aid := defaultAid != "" ? defaultAid : role
    }
    
    if (SubStr(aid, 1, 5) = "Name=") {
        return RhUiaFindByName(SubStr(aid, 6))
    }
    
    root := RhUiaRoot()
    if (!IsObject(root) || aid = "")
        return ""
    try el := root.FindFirstBy("AutomationId=" . aid)
    catch e
        el := ""
    if (IsObject(el))
        return el
    win := RhUiaWindow()
    if (!IsObject(win))
        return ""
    try return win.FindFirstBy("AutomationId=" . aid)
    catch e
        return ""
}

RhUiaFindByName(name) {
    root := RhUiaRoot()
    if (!IsObject(root) || name = "")
        return ""
    try el := root.FindFirstBy("Name=" . name)
    catch e
        el := ""
    if (IsObject(el))
        return el
    win := RhUiaWindow()
    if (!IsObject(win))
        return ""
    try return win.FindFirstBy("Name=" . name)
    catch e
        return ""
}

RhUiaGetValue(aid) {
    el := RhUiaFind(aid)
    if (!IsObject(el))
        return ""
    val := ""
    try val := el.CurrentValue
    catch e
        val := ""
    if (val != "")
        return val
    try val := el.CurrentValuePattern.Value
    catch e
        val := ""
    if (val != "")
        return val
    try val := el.CurrentName
    catch e
        val := ""
    return val
}

RhUiaClick(aid) {
    el := RhUiaFind(aid)
    if (!IsObject(el))
        return 0
    IikoRestore()
    try {
        el.Click()
        Sleep, % SpDly(150)
        return 1
    } catch e {
        return 0
    }
}

; Быстрый клик по элементу верхнего уровня окна iiko.
; Для кнопок завершения заказа не ищем сначала дерево таблицы блюд:
; это убирает лишний полный проход UIA после СИВ.
RhUiaClickWindowOnly(aid) {
    win := RhUiaWindow()
    if (!IsObject(win) || aid = "")
        return 0
    try el := win.FindFirstBy("AutomationId=" . aid)
    catch e
        el := ""
    if (!IsObject(el))
        return 0
    try {
        el.Click()
        Sleep, % SpDly(120)
        return 1
    } catch e2 {
        return 0
    }
}

RhUiaFocus(aid) {
    el := RhUiaFind(aid)
    if (!IsObject(el))
        return 0
    IikoRestore()
    try {
        el.SetFocus()
        Sleep, % SpDly(120)
        return 1
    } catch e {
        try {
            el.Click()
            Sleep, % SpDly(120)
            return 1
        } catch e2 {
            return 0
        }
    }
}

RhUiaSetValue(aid, text) {
    if (text = "")
        return 1
    el := RhUiaFind(aid)
    if (!IsObject(el))
        return 0
    IikoRestore()
    
    ; Фокус
    try el.SetFocus()
    catch e
        try el.Click()

    Sleep, % SpDly(120)
    Clipboard := text
    ClipWait, 1
    Send, ^a
    Sleep, 60
    Send, ^v
    Sleep, % SpDly(150)
    
    return 1
}

RhUiaDoublePaste(aid, text, verify := 1) {
    if (text = "")
        return 1
    el := RhUiaFind(aid)
    if (!IsObject(el))
        return 0
    IikoRestore()
    try rect := el.CurrentBoundingRectangle
    catch e
        return 0
    x := Round((rect.l + rect.r) / 2)
    y := Round((rect.t + rect.b) / 2)
    if (!x || !y)
        return 0
    MouseGetPos, mx, my
    Click, %x%, %y%, 2
    Sleep, % SpDly(220)
    Clipboard := text
    ClipWait, 1
    Send, ^a
    Sleep, 60
    Send, ^v
    Sleep, % SpDly(180)
    Send, {Tab}
    Sleep, % SpDly(220)
    MouseMove, %mx%, %my%, 0
    if (!verify)
        return 1
    got := RhUiaGetValue(aid)
    return InStr(got, text) ? 1 : 0
}

RhUiaClickPaymentTypeRow() {
    root := RhUiaFind("ТаблицяОплат", "gridPaymentItems")
    if (IsObject(root)) {
        try children := root.FindAllBy("TrueCondition")
        catch e
            children := ""
        if (IsObject(children)) {
            Loop, % children.MaxIndex() {
                el := children[A_Index]
                try name := el.CurrentName
                catch e
                    name := ""
                if (InStr(name, "row 0")) {
                    IikoRestore()
                    try {
                        el.Click()
                        Sleep, % SpDly(150)
                        return 1
                    } catch e2 {
                    }
                }
            }
        }
    }
    return RhUiaClick("gridPaymentItems")
}

RhUiaClickPaymentSumRow() {
    root := RhUiaFind("ТаблицяОплат", "gridPaymentItems")
    if (!IsObject(root))
        return 0
    try el := root.FindFirstBy("Name=Сумма row 0")
    catch e
        el := ""
    if (!IsObject(el)) {
        try el := root.FindFirstBy("Name=Сума row 0")
        catch e2
            el := ""
    }
    if (!IsObject(el))
        return 0
    IikoRestore()
    try {
        el.Click()
        Sleep, % SpDly(150)
        return 1
    } catch e3 {
        return 0
    }
}

RhUiaClickFirstOrderRow() {
    root := RhUiaFind("ТаблицяСтрав", "treeListItems")
    if (!IsObject(root))
        return 0
    try children := root.FindAllBy("TrueCondition")
    catch e
        return 0
    if (!IsObject(children))
        return 0
    best := ""
    Loop, % children.MaxIndex() {
        el := children[A_Index]
        try name := el.CurrentName
        catch e1
            name := ""
        try val := el.CurrentValue
        catch e2
            val := ""
        if (InStr(name, "Блюдо row") && val != "") {
            best := el
            break
        }
    }
    if (!IsObject(best))
        return 0
    IikoRestore()
    try {
        best.Click()
        Sleep, % SpDly(180)
        return 1
    } catch e3 {
        return 0
    }
}

RhApplyPaymentUIA(mode, changeAmount, noChangeFlag) {
    global paymentCashSearch, paymentCardSearch
    if (mode = "" && !noChangeFlag)
        return 1
    ok := 1
    if (!RhUiaClick("buttonDeletePaymentItem"))
        ok := 0
    Sleep, % SpDly(160)
    if (mode != "") {
        if (!RhUiaClickPaymentTypeRow())
            ok := 0
        Sleep, % SpDly(90)
        if (!RhUiaClickPaymentTypeRow())
            ok := 0
        Sleep, % SpDly(180)
        s := (mode = "cash") ? paymentCashSearch : paymentCardSearch
        Send, %s%
        Sleep, % SpDly(180)
        Send, {Enter}
        Sleep, % SpDly(220)
    }
    if (mode = "cash" && changeAmount != "" && changeAmount > 0) {
        if (!RhUiaClickPaymentSumRow())
            ok := 0
        Sleep, % SpDly(80)
        Send, %changeAmount%
        Sleep, % SpDly(80)
        Send, {NumpadEnter}
    } else if (noChangeFlag) {
        if (!RhUiaClick("buttonNoChange"))
            ok := 0
    }
    return ok
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
IikoFocusPaste(role, text) {
    global RH_SERVER_OK, iikoWinExe
    if (!RH_SERVER_OK || text = "")
        return
    
    IniRead, _mapped, RkConfig.ini, UiaMap, %role%, %A_Space%
    autoId := (_mapped != "" && _mapped != "ERROR") ? _mapped : role
    ; Python server expects standard ID, if it's Name=... we need to encode it properly.
    ; For now we just pass autoId as is.
    
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
IikoFocusField(role) {
    global RH_SERVER_OK, iikoWinExe
    if (!RH_SERVER_OK)
        return 0
        
    IniRead, _mapped, RkConfig.ini, UiaMap, %role%, %A_Space%
    autoId := (_mapped != "" && _mapped != "ERROR") ? _mapped : role
    
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
IniRead, giftPepsiEnabled, RkConfig.ini, Gifts, PepsiEnabled, 1
IniRead, giftBrooklynEnabled, RkConfig.ini, Gifts, BrooklynEnabled, 1
IniRead, giftBurgerEnabled, RkConfig.ini, Gifts, BurgerEnabled, 1
IniRead, giftPepsiName, RkConfig.ini, Gifts, PepsiName, Пепсі
IniRead, giftBrooklynName, RkConfig.ini, Gifts, BrooklynName, Бруклін
IniRead, giftBurgerName, RkConfig.ini, Gifts, BurgerName, Крабсбургер
giftPepsiEnabled := giftPepsiEnabled ? 1 : 0
giftBrooklynEnabled := giftBrooklynEnabled ? 1 : 0
giftBurgerEnabled := giftBurgerEnabled ? 1 : 0

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

global rawComment := "", infoText := "", addrNote := "", cleanComment := "", extractedTime := "", clientChange := "", cardText := "", streetText := "", bonusNote := ""
global clientPhone := ""   ; номер телефону поточного клієнта
global autoPromo := 0, autoPepsi := 0, autoBrooklyn := 0, autoBurger := 0, orderSum := 0, autoCash := 0, autoCard := 0, calcChange := 0
global noPayChange := 0   ; 1 = списання бонусів: оплату, хрестик і решту не чіпаємо
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

; MVP: базовая обработка + СІВ. Остальные модули остаются в коде,
; но не регистрируют хоткеи, таймеры и фоновые процессы.
ModuleRegistry_ApplyRollHouseMvpPolicy()

TrayTip, RollHouse, ✅ Запущено (режим %speedMode%), 2, 1

; --- RollHelper: відкрити ВЕБ-пульт у вікні Edge (бета) ---
Menu, Tray, Add
Menu, Tray, Add, ⚙ Налаштування, OpenSettings
Menu, Tray, Add, 🔄 Перезапустити сервер, RestartPythonServer
if (Module_IsEnabled("web_pult"))
    Menu, Tray, Add, 🌐 Веб-пульт (бета), OpenWebPult

; --- Запуск Python-сервера (читає поля iiko «по іменах», надійніше за прицели) ---
; У дистрибутиві Python лежить у APP_DIR\..\runtime\python.
; У робочій копії зберігаємо сумісність із Python, встановленим у Windows.
if (!RhPing()) {
    RhLaunchServer()
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
    RhLaunchServer()
return

; --- ГОЛОВНИЙ ТРИГЕР ПАРСИНГУ ---
TriggerMain:
    OpCoord_Event("ReadingOrder", "trigger", "TriggerMain", "rollExists=" . rollExists . ";rollVisible=" . rollVisible . ";dutyOn=" . dutyOn)
    ; --- ЗАХИСТ ДЕЖУРСТВА: будь-яка ручна дія оператора → зупиняємо авто-режим ---
    dutyOn := 0
    kcStop := 1
    kcBusy := 0
    _punchUntil := A_TickCount + 30000
    SetTimer, KcDutyTick, Off
    SetTimer, KcMonitor, Off
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
    ; --- SMART TIME LOGIC ---
    ; Якщо в коментарі немає чіткого часу (ASAP або порожньо), перевіряємо час, який вже стоїть в iiko
    if (extractedTime = "" && _iikoTime != "" && !isFutureDate) {
        _iikoParts := StrSplit(_iikoTime, ":")
        _iHH := _iikoParts[1] + 0, _iMM := _iikoParts[2] + 0
        _nowHH := A_Hour + 0, _nowMM := A_Min + 0
        
        _nowTotal := _nowHH * 60 + _nowMM
        _iikoTotal := _iHH * 60 + _iMM
        
        _diffMins := _iikoTotal - _nowTotal
        if (_diffMins < -720)
            _diffMins += 1440
            
        _threshold := isPickup ? 40 : 60
        
        if (_diffMins >= _threshold)
            extractedTime := _iikoTime
        else
            extractedTime := "" ; Спрацює авто-калькуляція +40/+60
    }
    GoSub, DrawRollclub
    ; CRM lookup у фон — GUI вже відкрито, badge підтягнеться через ~300мс
    if (clientPhone != "" && RH_SERVER_OK)
        SetTimer, AsyncCrmLookupMain, -300
return

RemoveToolTip:
    ToolTip
return

TriggerSiv:
    OpCoord_Event("PunchingSiv", "trigger", "TriggerSiv", "dutyOn=" . dutyOn)

    ; --- ЗАХИСТ ДЕЖУРСТВА (F1/SIV) ---

    dutyOn := 0

    kcStop := 1

    SetTimer, KcDutyTick, Off


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
    _brandName := "Roll House"
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

    ; ── Пошук адреси / зони ──────────────────────────────
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y104 w200 h18 +BackgroundTrans, 🔎 Адреса / зона
    Gui, Roll:Font, s10 norm c%RhC_Text%, %RhFontName%
    _mapInit := (streetText != "" && !isPickup) ? "Визначаю зону..." : "Зона / точка на карті..."
    Gui, Roll:Add, Edit, x26 y126 w306 h26 vMapSearch, %_mapInit%

    ; ── Карта замовлення: зона / сума / тип ──────────────
    if (isPickup)
        _zoneTxt := "Самовивіз " . pickupPoint
    else if (deliveryCostNum > 0)
        _zoneTxt := deliveryCostStr
    else
        _zoneTxt := "Зона не визначена"
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x34 y175 w80 h14 Center +BackgroundTrans, статус
    Gui, Roll:Add, Text, x140 y175 w80 h14 Center +BackgroundTrans, сума
    Gui, Roll:Add, Text, x246 y175 w78 h14 Center +BackgroundTrans, разом
    Gui, Roll:Font, s9 bold c%RhC_SoftText%, %RhFontName%
    Gui, Roll:Add, Text, x34 y192 w80 h18 Center +BackgroundTrans, %_orderType%
    Gui, Roll:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x140 y192 w80 h18 Center +BackgroundTrans, %orderSum% грн
    Gui, Roll:Font, s10 bold c%RhC_Neon%, %RhFontName%
    Gui, Roll:Add, Text, x246 y192 w78 h18 Center +BackgroundTrans vRhTotalLbl, %totalSum% грн
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x26 y216 w306 h14 Center +BackgroundTrans, 📍 %_zoneTxt%

    ; ── Оплата ───────────────────────────────────────────
    DoAutoCash := noPayChange ? 0 : autoCash
    DoAutoCard := noPayChange ? 0 : autoCard
    Gui, Roll:Font, s10 bold cFFFFFF, %RhFontName%
    Gui, Roll:Add, Button, x14 y246 w160 h36 HwndhPayCash gRhTogCash, 💵 Готівка
    Gui, Roll:Add, Button, x184 y246 w160 h36 HwndhPayCard gRhTogCard, 💳 Картка
    RhRegColor(hPayCash, (DoAutoCash ? RhB_Cash : RhB_ButtonOff), (DoAutoCash ? RhB_White : RhB_Text))
    RhRegColor(hPayCard, (DoAutoCard ? RhB_Card : RhB_ButtonOff), (DoAutoCard ? RhB_White : RhB_Text))

    ; ── Коментар ─────────────────────────────────────────
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y302 w94 h18 +BackgroundTrans, 📝 Коментар
    Gui, Roll:Font, s8 norm c%RhC_Neon%, %RhFontName%
    Gui, Roll:Add, Button, x124 y300 w96 h22 gRhNoChange, Без сдачі
    Gui, Roll:Add, Button, x224 y300 w108 h22 vRhRawBtn gRhToggleRaw, вихідний »
    Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x26 y326 w306 r3 vOrderComment gRhRefreshEnterPreview, %cleanComment%
    Gui, Roll:Add, Edit, x26 y326 w306 r3 vRhRawEdit ReadOnly +Hidden, %rawComment%

    ; ── Кухня / адреса ───────────────────────────────────
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y402 w62 h22 +0x200 +BackgroundTrans, 🍳 Кухня
    Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x92 y402 w240 h22 r1 vClientInfo gRhRefreshEnterPreview, %infoText%
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y434 w62 h22 +0x200 +BackgroundTrans, 🏠 Адреса
    Gui, Roll:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x92 y434 w240 h22 r1 vAddressNote gRhRefreshEnterPreview, %addrNote%

    ; ── Інлайн СІВ ───────────────────────────────────────
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x26 y495 w36 h24 +0x200 +BackgroundTrans, 🥣
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x62 y495 w22 h24 +0x200 +BackgroundTrans, Рол
    Gui, Roll:Add, Edit, x86 y496 w34 h22 vVisRolls gRhRefreshEnterPreview Center Number,
    Gui, Roll:Add, Text, x126 y495 w18 h24 +0x200 +BackgroundTrans, Зв
    Gui, Roll:Add, Edit, x146 y496 w34 h22 vVisNorm gRhRefreshEnterPreview Center Number,
    Gui, Roll:Add, Text, x186 y495 w18 h24 +0x200 +BackgroundTrans, Уч
    Gui, Roll:Add, Edit, x206 y496 w34 h22 vVisEdu gRhRefreshEnterPreview Center Number,
    Gui, Roll:Font, s9 bold cFFFFFF, %RhFontName%
    Gui, Roll:Add, Button, x250 y494 w82 h26 HwndhSivGo gRhSivGo, Пробити
    RhRegColor(hSivGo, RhB_Siv, RhB_White)
    Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x26 y524 w306 h18 vRhSivPreview HwndhRhSivPreview +0x200, СІВ: введи Рол/Зв/Уч — покажу соус/імбир/васабі
    RhRegColor(hRhSivPreview, RhB_StatusSoft, RhB_Text)

    ; ── Подарунки ────────────────────────────────────────
    GiftPepsi := giftPepsiEnabled ? autoPepsi : 0
    GiftBrooklyn := giftBrooklynEnabled ? autoBrooklyn : 0
    GiftBurger := giftBurgerEnabled ? autoBurger : 0
    Gui, Roll:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Text, x14 y548 w86 h30 +0x200, 🎁 Подарунок
    Gui, Roll:Font, s9 bold cFFFFFF, %RhFontName%
    _giftPText := (GiftPepsi ? "✓ " : "") . giftPepsiName
    Gui, Roll:Add, Button, x104 y548 w74 h30 vGiftPBtn HwndhGiftP gRhTogPepsi, %_giftPText%
    _giftBText := (GiftBrooklyn ? "✓ " : "") . giftBrooklynName
    Gui, Roll:Add, Button, x184 y548 w74 h30 vGiftBBtn HwndhGiftB gRhTogBrook, %_giftBText%
    _giftUText := (GiftBurger ? "✓ " : "") . giftBurgerName
    Gui, Roll:Add, Button, x264 y548 w80 h30 vGiftUBtn HwndhGiftU gRhTogBurg, %_giftUText%
    if (!giftPepsiEnabled)
        GuiControl, Roll:Disable, GiftPBtn
    if (!giftBrooklynEnabled)
        GuiControl, Roll:Disable, GiftBBtn
    if (!giftBurgerEnabled)
        GuiControl, Roll:Disable, GiftUBtn
    RhRegColor(hGiftP, (GiftPepsi ? RhB_Gift : RhB_ButtonOff), (GiftPepsi ? RhB_White : RhB_Text))
    RhRegColor(hGiftB, (GiftBrooklyn ? RhB_Gift : RhB_ButtonOff), (GiftBrooklyn ? RhB_White : RhB_Text))
    RhRegColor(hGiftU, (GiftBurger ? RhB_Gift : RhB_ButtonOff), (GiftBurger ? RhB_White : RhB_Text))
    Gui, Roll:Font, s8 bold c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x14 y582 w330 h16 vRhGiftStatus HwndhRhGiftStatus +0x200, Подарунок: не вибрано
    RhRegColor(hRhGiftStatus, RhB_StatusSoft, RhB_Muted)

    ; ── Час готовності ───────────────────────────────────
    _rhH := "", _rhM := ""
    if (extractedTime != "" && InStr(extractedTime, ":")) {
        _rhP := StrSplit(extractedTime, ":")
        _rhH := _rhP[1], _rhM := _rhP[2]
    }
    Gui, Roll:Font, s15 bold c%RhC_Neon%, %RhFontName%
    Gui, Roll:Add, Text, x26 y602 w26 h30 +0x200 +BackgroundTrans, ⏱
    Gui, Roll:Font, s14 bold c%RhC_Text%, %RhFontName%
    Gui, Roll:Add, Edit, x58 y602 w36 h28 Center Limit2 Number vReadyH gRhRefreshEnterPreview, %_rhH%
    Gui, Roll:Add, Text, x96 y602 w10 h28 +0x200 Center +BackgroundTrans, :
    Gui, Roll:Add, Edit, x108 y602 w36 h28 Center Limit2 Number vReadyM gRhRefreshEnterPreview, %_rhM%
    Gui, Roll:Font, s8 bold cFFFFFF, %RhFontName%
    Gui, Roll:Add, Button, x156 y604 w42 h24 HwndhQuickPickup gCalcPickup, СВ+40
    Gui, Roll:Add, Button, x202 y604 w40 h24 HwndhQuickDel60 gCalcDelivery, +60
    Gui, Roll:Add, Button, x246 y604 w40 h24 HwndhQuickDel90 gCalcDelivery90, +90
    Gui, Roll:Add, Button, x290 y604 w42 h24 HwndhQuickPickup20 gCalcPickup20, СВ+20
    RhRegColor(hQuickPickup, RhB_Blue, RhB_White)
    RhRegColor(hQuickDel60, RhB_Teal, RhB_White)
    RhRegColor(hQuickDel90, RhB_Orange, RhB_White)
    RhRegColor(hQuickPickup20, RhB_ButtonOff, RhB_Text)

    ; ── Прев'ю Enter-цепочки ─────────────────────────────────
    Gui, Roll:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Roll:Add, Text, x14 y640 w330 h34 vRhEnterPreview +BackgroundTrans, Enter: готую цепочку...

    ; Внесення виконується клавішею Enter / NumpadEnter через hotkey нижче.

    Gui, Roll:Add, Edit, x0 y0 w1 h1 vClientCard +Hidden,


    Gui, Roll:Show, x%rollWinX% y%rollWinY%, RollHouse MEGA 3.0 (PLU)
    Gui, Roll:+LastFound
    RhRollHwnd := WinExist()
    ; примусова перерисовка всіх дітей — інакше кольори з'являються лише з 2-го показу (баг №2)
    DllCall("RedrawWindow", "Ptr", RhRollHwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
    GuiControlGet, _rhp, Roll:Pos, RhRawEdit
    RhRawTop   := _rhpy
    RhRawDelta := 0
    RhRawShown := 0
    rollExists := 1
    rollVisible := 1
    SetTimer, RhUpdatePultClock, 30000
    if (streetText != "" && !isPickup)
        SetTimer, RcCheckZone, -450
    FileAppend, % "[" A_Now "] TIMEDBG isPickup=" isPickup " ext=[" extractedTime "] future=" isFutureDate " asap=" isAsap " street=[" streetText "] iikoTime=[" _iikoTime "]`n", %A_ScriptDir%\ahk_debug.log
    if (extractedTime = "" && !isFutureDate) {
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
    Gui, Roll:Submit, NoHide
    if (A_GuiControl != "OrderComment") {
        _freshPay := DoAutoCard ? "card" : (DoAutoCash ? "cash" : (InStr(paymentMethod, "ОПЛАЧЕНО") ? "paid" : (InStr(paymentMethod, "Термінал") ? "card" : (InStr(paymentMethod, "Готівка") ? "cash" : ""))))
        _freshComment := RhBuildCommentFromControls(_freshPay, calcChange, 0, OrderComment, ReadyH, ReadyM)
        if (_freshComment != "" && _freshComment != OrderComment) {
            GuiControl, Roll:, OrderComment, %_freshComment%
            OrderComment := _freshComment
        }
    }
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
    if ((itemX = 0 || itemX = "ERROR") && !IsObject(RhUiaFind("ТаблицяСтрав", "treeListItems")))
        _txt .= " · !приціл 7"
    return _txt
}

RhBuildGiftStatus() {
    global GiftPepsi, GiftBrooklyn, GiftBurger, giftPepsiName, giftBrooklynName, giftBurgerName
    _count := (GiftPepsi ? 1 : 0) + (GiftBrooklyn ? 1 : 0) + (GiftBurger ? 1 : 0)
    if (_count = 0)
        return "Подарунок: не вибрано"
    if (GiftBurger)
        _name := giftBurgerName
    else if (GiftBrooklyn)
        _name := giftBrooklynName
    else
        _name := giftPepsiName
    _txt := "✓ Подарунок: " . _name
    if (_count > 1)
        _txt .= " (обрано кілька, пробьється " . _name . ")"
    return _txt
}

RhBuildEnterPreview() {
    global DoAutoCash, DoAutoCard, GiftPepsi, GiftBrooklyn, GiftBurger, giftPepsiName, giftBrooklynName, giftBurgerName, isPickup, itemX, itemRelX
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
    if (DoAutoCash || DoAutoCard || paymentMethod != "") {
        _payStep := DoAutoCash ? "готівка" : (DoAutoCard ? "банк" : "онлайн")
        _txt .= _sep . _payStep
        _sep := " → "
    }
    _gifts := ""
    if (GiftPepsi)
        _gifts .= (_gifts = "" ? giftPepsiName : "/" . giftPepsiName)
    if (GiftBrooklyn)
        _gifts .= (_gifts = "" ? giftBrooklynName : "/" . giftBrooklynName)
    if (GiftBurger)
        _gifts .= (_gifts = "" ? giftBurgerName : "/" . giftBurgerName)
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

RhStripPayBits(text) {
    global deliveryCostStr
    text := RhOneLine(text)
    cleaned := ""
    Loop, Parse, text, |
    {
        part := Trim(A_LoopField)
        if (part = "")
            continue
        part := RegExReplace(part, "i)(Готівкою|Готівка|Наличными|Термінал\s*\(При отриманні\)|Термінал|Terminal|Банківська\s+карта|Банківська\s+картка|Банковская\s+карта|Карткою\s+у\s+закладі|Картою\s+в\s+закладі|Картой\s+в\s+заведении|Карт(?:ою|кою|кой|ой)\s+(?:онлайн|online|на\s+сайт[іе])|Безнал\s*сайт|ОПЛАЧЕНО|оплачено)", "")
        if (deliveryCostStr != "")
            part := StrReplace(part, deliveryCostStr, "")
        part := RegExReplace(part, "i)Доставк[а-яіїєґ]*\s+[^|]*?\s*-\s*\d+\s*грн", "")
        part := RegExReplace(part, "i)(набрати|набрать|подзвонити|позвонить|дзвонити|звонить)\s+по\s+готовності", "")
        part := RegExReplace(part, "i)(?:підготувати\s*|подготовить\s*)?(решт[уа]\s*з|сдача\s*с)(?:[:\sзс]*?)\d+(?:\s*грн)?", "")
        part := RegExReplace(part, "i)(без\s*здач[іи]|без\s*сдач[иі]|без\s*решт[иі])", "")
        part := RegExReplace(part, "\s{2,}", " ")
        part := Trim(part, " `t,;:-")
        if (part = "")
            continue
        cleaned .= (cleaned != "" ? " | " : "") . part
    }
    return Trim(cleaned)
}

RhNormalizeZoneText(text) {
    text := StrReplace(text, "ё", "е")
    text := StrReplace(text, "Ё", "Е")
    text := RegExReplace(text, "i)песчанка|пищанка", "піщанка")
    text := RegExReplace(text, "i)берестін", "берестин")
    text := RegExReplace(text, "[^0-9A-Za-zА-Яа-яІЇЄҐіїєґ'’ ]", " ")
    text := RegExReplace(text, "\s+", " ")
    StringLower, text, text
    return Trim(text)
}

RhLookupManualZone(value, ByRef zoneName, ByRef zonePrice) {
    global BRAND_DIR
    zoneName := ""
    zonePrice := 0
    value := Trim(value)
    if (value = "" || InStr(value, "Зона / точка") || InStr(value, "Визначаю зону"))
        return 0

    explicitPrice := 0
    if RegExMatch(value, "(\d+)\s*(?:грн|₴)", mExplicit)
        explicitPrice := mExplicit1 + 0
    searchValue := RhNormalizeZoneText(value)
    if (searchValue = "")
        return 0

    pricesFile := BRAND_DIR . "\DeliveryPrices.ini"
    if !FileExist(pricesFile)
        return 0
    FileRead, pricesText, %pricesFile%
    bestLen := 0
    bestName := ""
    bestPrice := 0
    Loop, Parse, pricesText, `n, `r
    {
        if (!InStr(A_LoopField, "="))
            continue
        pair := StrSplit(A_LoopField, "=", , 2)
        candidateName := Trim(pair[1], " `t" . Chr(160))
        candidatePrice := Trim(pair[2], " `t" . Chr(160)) + 0
        candidateKey := RhNormalizeZoneText(candidateName)
        if (candidateKey = "" || !InStr(searchValue, candidateKey))
            continue
        if (StrLen(candidateKey) > bestLen) {
            bestLen := StrLen(candidateKey)
            bestName := candidateName
            bestPrice := candidatePrice
        }
    }
    if (bestName = "")
        return 0
    zoneName := bestName
    zonePrice := explicitPrice > 0 ? explicitPrice : bestPrice
    return zonePrice > 0 ? 1 : 0
}

RhApplyManualZoneOverride() {
    global deliveryCostStr, deliveryCostNum, totalSum, orderSum, calcChange
    global clientChange, clientNoChange, noPayChange, autoCash, isPickup, paymentMethod
    global DoAutoCash, DoAutoCard, OrderComment, ReadyH, ReadyM
    GuiControlGet, manualZoneValue, Roll:, MapSearch
    if (!RhLookupManualZone(manualZoneValue, manualZoneName, manualZonePrice))
        return 0

    previousDelivery := deliveryCostStr
    deliveryCostNum := manualZonePrice
    deliveryCostStr := "Доставка " . manualZoneName . " - " . manualZonePrice . " грн"
    totalSum := orderSum + deliveryCostNum
    if (clientChange != "")
        calcChange := clientChange
    else if (clientNoChange || noPayChange)
        calcChange := 0
    else if (autoCash && totalSum > 0)
        calcChange := Ceil(totalSum / 200) * 200
    else
        calcChange := 0

    GuiControl, Roll:, MapSearch, % "📍 " . deliveryCostStr
    GuiControl, Roll:, RhTotalLbl, % totalSum " грн"
    GuiControlGet, currentComment, Roll:, OrderComment
    if (previousDelivery != "")
        currentComment := StrReplace(currentComment, previousDelivery, "")
    currentComment := RegExReplace(currentComment, "i)Доставк[а-яіїєґ]*\s+[^|\r\n]+?\s*-\s*\d+\s*грн", "")
    currentComment := RegExReplace(currentComment, "\s*\|\s*", " | ")
    currentComment := Trim(currentComment, " `t|:-")
    payMode := DoAutoCard ? "card" : (DoAutoCash ? "cash" : (InStr(paymentMethod, "ОПЛАЧЕНО") ? "paid" : (InStr(paymentMethod, "Термінал") ? "card" : (InStr(paymentMethod, "Готівка") ? "cash" : ""))))
    currentComment := RhStripPayBits(currentComment)
    currentComment := RhBuildCommentFromControls(payMode, calcChange, noPayChange, currentComment, ReadyH, ReadyM)
    GuiControl, Roll:, OrderComment, %currentComment%
    FileAppend, % "[" A_Now "] MANUAL_ZONE zone=[" manualZoneName "] price=" manualZonePrice " previous=[" previousDelivery "]`n", %A_ScriptDir%\ahk_debug.log
    return 1
}

RhPickupReadyNeedsCall(h, m) {
    if (h = "" && m = "")
        return 0
    h += 0
    m += 0
    nowMin := (A_Hour + 0) * 60 + (A_Min + 0)
    readyMin := h * 60 + m
    diff := readyMin - nowMin
    if (diff < 0)
        diff += 1440
    return diff < 45
}

RhBuildCommentFromControls(payMode, changeAmount, noChangeFlag, body, h, m) {
    global deliveryCostStr, isPickup
    prefix := ""
    if (payMode = "cash")
        prefix := "Готівка"
    else if (payMode = "card")
        prefix := "Термінал"
    else if (payMode = "paid")
        prefix := "ОПЛАЧЕНО"
    if (deliveryCostStr != "")
        prefix .= (prefix != "" ? " " : "") . deliveryCostStr
    if (!noChangeFlag && payMode = "cash" && changeAmount != "" && changeAmount > 0)
        prefix .= (prefix != "" ? " " : "") . "решта з " . changeAmount
    if (isPickup && RhPickupReadyNeedsCall(h, m))
        prefix .= (prefix != "" ? " " : "") . "подзвонити по готовності"
    body := RhStripPayBits(body)
    return Trim(prefix . (prefix != "" && body != "" ? " | " : "") . body)
}

RhRefreshCommentFromControls(noChangeFlag := 0) {
    global DoAutoCash, DoAutoCard, calcChange, OrderComment, ReadyH, ReadyM, totalSum, paymentMethod
    Gui, Roll:Submit, NoHide
    _pay := DoAutoCard ? "card" : (DoAutoCash ? "cash" : (InStr(paymentMethod, "ОПЛАЧЕНО") ? "paid" : (InStr(paymentMethod, "Термінал") ? "card" : (InStr(paymentMethod, "Готівка") ? "cash" : ""))))
    _body := RhStripPayBits(OrderComment)
    if (noChangeFlag)
        calcChange := ""
    else if (_pay = "cash" && (calcChange = "" || calcChange = 0) && totalSum > 0)
        calcChange := Ceil(totalSum / 200) * 200
    _next := RhBuildCommentFromControls(_pay, calcChange, noChangeFlag, _body, ReadyH, ReadyM)
    GuiControl, Roll:, OrderComment, %_next%
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
    _pfHasPay := (DoAutoCash || DoAutoCard || paymentMethod != "")

    if (RhOneLine(_pfComment) != "" && !RhTargetReady(commX, commRelX) && !IsObject(RhUiaFind("Коментар", "memoEditDeliveryComment")))
        _pf .= "- Коментар: приціл 1 не налаштований`n"
    if ((RhOneLine(_pfKitchen) != "" || RhOneLine(_pfCard) != "") && !RhTargetReady(infoX, infoRelX) && !IsObject(RhUiaFind("Кухня", "memoEditCustomerComment")))
        _pf .= "- Кухня: приціл 3 не налаштований`n"
    if (RhOneLine(_pfAddress) != "" && !RhTargetReady(addrX, addrRelX) && !IsObject(RhUiaFind("Адреса", "memoEditDeliveryAddressComment")))
        _pf .= "- Адреса: приціл 4 не налаштований`n"
    if (_pfHasTime && !RhTargetReady(timeX, timeRelX) && !IsObject(RhUiaFind("ЧасГотовності", "timeEditDeliveryTime")))
        _pf .= "- Час готовності: приціл 6 не налаштований`n"
    if ((_pfHasSiv || _pfHasGift) && !RhTargetReady(itemX, itemRelX) && !IsObject(RhUiaFind("ТаблицяСтрав", "treeListItems")))
        _pf .= "- Таблиця страв: приціл 7 не налаштований`n"
    if (_pfHasPay && !RhTargetReady(cashX, cashRelX) && !IsObject(RhUiaFind("ТаблицяОплат", "gridPaymentItems")))
        _pf .= "- Тип оплати: приціл 9 не налаштований`n"
    if (_pfHasPay && !RhTargetReady(crossX, crossRelX) && !IsObject(RhUiaFind("ХрестикОплати", "buttonDeletePaymentItem")))
        _pf .= "- Хрестик оплати: приціл 8 не налаштований`n"
    if (DoAutoCash && isPickup && calcChange > 0 && !RhTargetReady(changeX, changeRelX) && !IsObject(RhUiaFind("ТаблицяОплат", "gridPaymentItems")))
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
    _stPayWillRun := (DoAutoCash || DoAutoCard || paymentMethod != "") ? 1 : 0

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
    RhRefreshCommentFromControls(0)
    GoSub, RhPayPaint
return
RhTogCard:
    DoAutoCard := !DoAutoCard
    if (DoAutoCard) {
        DoAutoCash := 0
        calcChange := ""
    }
    RhRefreshCommentFromControls(0)
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
    if (!giftPepsiEnabled)
        return
    GiftPepsi := !GiftPepsi
    if (GiftPepsi) {
        GiftBrooklyn := 0
        GiftBurger := 0
    }
    GoSub, RhGiftPaint
return
RhTogBrook:
    if (!giftBrooklynEnabled)
        return
    GiftBrooklyn := !GiftBrooklyn
    if (GiftBrooklyn) {
        GiftPepsi := 0
        GiftBurger := 0
    }
    GoSub, RhGiftPaint
return
RhTogBurg:
    if (!giftBurgerEnabled)
        return
    GiftBurger := !GiftBurger
    if (GiftBurger) {
        GiftPepsi := 0
        GiftBrooklyn := 0
    }
    GoSub, RhGiftPaint
return
RhGiftPaint:
    GuiControl, Roll:, GiftPBtn, % (GiftPepsi ? "✓ " : "") . giftPepsiName
    GuiControl, Roll:, GiftBBtn, % (GiftBrooklyn ? "✓ " : "") . giftBrooklynName
    GuiControl, Roll:, GiftUBtn, % (GiftBurger ? "✓ " : "") . giftBurgerName
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
    if (lParam < 0)
        lParam += 0x100000000      ; 32-біт AHK дає hwnd зі знаком → інакше покраска "через раз"
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
    _opSivToken := OpCoord_Begin("PunchingSiv", "RhPunchSivValues", "rolls=" . rolls . ";norm=" . norm . ";edu=" . edu)
    if (rolls = "")
        rolls := 0
    if (norm = "")
        norm := 0
    if (edu = "")
        edu := 0
    if (rolls = 0 && norm = 0 && edu = 0) {
        OpCoord_End(_opSivToken, "skip", "empty_values")
        return 1
    }

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
    if ((itemX = 0 || itemX = "ERROR") && !IsObject(RhUiaFind("ТаблицяСтрав", "treeListItems"))) {
        MsgBox, 48, Помилка, Не задано приціл "Табл. Страв"! (Налаштування -> 7)
        OpCoord_End(_opSivToken, "error", "items_control_not_found")
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
    _pluJobs := []
    RhAddPluJob(_pluJobs, pluSticksNorm, norm)
    RhAddPluJob(_pluJobs, pluSticksEdu, edu)
    RhAddPluJob(_pluJobs, pluSoy, soyQty)
    RhAddPluJob(_pluJobs, pluGinger, gwQty)
    RhAddPluJob(_pluJobs, pluWasabi, gwQty)
    _sivStartTick := A_TickCount
    _sivOk := RhPunchPluSeries(_pluJobs, _itX, _itY)
    FileAppend, % "[" A_Now "] SIV_DONE ok=" _sivOk " ms=" (A_TickCount - _sivStartTick) " rolls=" rolls " norm=" norm " edu=" edu " soy=" soyQty " gw=" gwQty "`n", %A_ScriptDir%\ahk_debug.log
    /*
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
    */
    ToolTip
    MouseMove, %_omx%, %_omy%, 0
    if (rollExists) {
        Gui, Roll:Show
        rollVisible := 1
    }
    OpCoord_End(_opSivToken, _sivOk ? "ok" : "error", "jobs=" . _pluJobs.Length())
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

; Кнопка «Без сдачі»: прибрати «Решта з X» з коментаря і поставити «Без сдачі»
RhNoChange:
    RhRefreshCommentFromControls(1)
    GoSub, RhRefreshEnterPreview
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
    Gui, Settings:+AlwaysOnTop +ToolWindow +OwnDialogs +HwndSettingsHwnd
    Gui, Settings:Color, %RhC_BG%, %RhC_Panel%
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    _settingsTabs := "🚀 WinAPI"
    _settingsWinApiTab := 1
    _settingsNextTab := 2
    _settingsCallingTab := 0
    _settingsReportTab := 0
    if (Module_IsEnabled("calling")) {
        _settingsCallingTab := _settingsNextTab
        _settingsNextTab += 1
        _settingsTabs .= "|📞 Звонки"
    }
    _settingsGiftsTab := _settingsNextTab
    _settingsNextTab += 1
    _settingsTabs .= "|🎁 Подарунки"
    _settingsSivTab := _settingsNextTab
    _settingsNextTab += 1
    _settingsTabs .= "|🥢 СІВ"
    _settingsHotkeysTab := _settingsNextTab
    _settingsNextTab += 1
    _settingsTabs .= "|⌨️ Клавіші"
    if (Module_IsEnabled("reports")) {
        _settingsReportTab := _settingsNextTab
        _settingsTabs .= "|🤖 Звіт F5"
    }
    Gui, Settings:Add, Tab3, x6 y6 w348 h364 vSettTab, %_settingsTabs%

    ; ── Вкладка 1: WinAPI Сканер ───────────────
    Gui, Settings:Tab, %_settingsWinApiTab%
    Gui, Settings:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y36 w320 Section, Збережені WinAPI елементи (UIA):
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, ListView, xs y+6 w322 h170 vUiaListView gUiaListClick Grid, Назва (Роль)|Шлях/ID (AutomationId/Name)
    
    ; Заповнюємо ListView з RkConfig.ini
    Gui, Settings:Default
    Gui, ListView, UiaListView
    LV_ModifyCol(1, 120)
    LV_ModifyCol(2, 198)
    GoSub, LoadUiaMapToListView
    
    Gui, Settings:Font, s9 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, xs y+8 w156 h32 gLaunchScanner, 🎯 Додати елемент
    Gui, Settings:Add, Button, x+10 yp w156 h32 gDeleteSelectedUiaBinding, 🗑 Видалити вибране
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, xs y+6 w322, Виберіть рядок і натисніть «Видалити». Подвійний клік також працює.
    
    ; ── Опциональна вкладка: Звонки (Aiko) ────────────────
    if (_settingsCallingTab) {
        Gui, Settings:Tab, %_settingsCallingTab%
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
        Gui, Settings:Add, Edit, x+6 yp w150 vNewHkCallNext, %hkCallNext%
        Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Покласти трубку:
        Gui, Settings:Add, Edit, x+6 yp w150 vNewHkCallHangup, %hkCallHangup%
        Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Пауза:
        Gui, Settings:Add, Edit, x+6 yp w150 vNewHkCallPause, %hkCallPause%
        Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Прийняти розмову:
        Gui, Settings:Add, Edit, x+6 yp w150 vNewHkAcceptTalk, %hkAcceptTalk%
        Gui, Settings:Font, s9 norm c%RhC_Muted%, %RhFontName%
        Gui, Settings:Add, Text, xs y+10 w316 h1 +0x10
        Gui, Settings:Add, Text, xs y+6 w316, 🧊 Клавіші Soundpad (через | , напр. 1|x):
        Gui, Settings:Add, Edit, xs y+4 w316 h22 vNewSoundpadKeys, %soundpadKeys%
        Gui, Settings:Add, Text, xs y+2 w316 c%RhC_Muted%, Під час заморозки (F7) ці клавіші блокуються від Soundpad
        Gui, Settings:Add, Text, xs y+10 w316 h1 +0x10
        Gui, Settings:Add, Checkbox, xs y+8 w316 h22 vNewCallListenEnabled Checked%callListenEnabled%, Автослух після привітання
        _callEngineIdx := (callListenEngine = "sherpa_stream") ? 3 : ((callListenEngine = "sherpa") ? 2 : 1)
        Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Движок слуху:
        Gui, Settings:Add, DropDownList, x+6 yp w150 vNewCallListenEngine Choose%_callEngineIdx%, Whisper|Sherpa|Sherpa Stream
        Gui, Settings:Add, Checkbox, xs y+6 w316 h22 vNewCallListenAdvisorOnly Checked%callListenAdvisorOnly%, Радник без натискання X
        Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Затримка після «1», мс:
        Gui, Settings:Add, Edit, x+6 yp w150 h22 Number vNewCallGreetingDelayMs, %callGreetingDelayMs%
        Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Аудіо-пристрій (0=авто):
        Gui, Settings:Add, Edit, x+6 yp w150 h22 Number vNewCallListenDevice, %callListenDevice%
        Gui, Settings:Add, Text, xs y+6 w150 h22 +0x200, Поріг слуху RMS:
        Gui, Settings:Add, Edit, x+6 yp w150 h22 Number vNewCallListenRmsThreshold, %callListenRmsThreshold%
    }

    ; ── Вкладка: Подарунки ─────────────────────────────────
    Gui, Settings:Tab, %_settingsGiftsTab%
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y44 w320 Section, Автоподарунки: поріг суми та PLU-код
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, xs y+10 w22 h18 Center, ✓
    Gui, Settings:Add, Text, x42 yp w102 h18 Center, Назва
    Gui, Settings:Add, Text, x150 yp w76 h18 Center, Від суми
    Gui, Settings:Add, Text, x238 yp w94 h18 Center, PLU-код
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Checkbox, xs y+4 w22 h22 vNewGiftPepsiEnabled Checked%giftPepsiEnabled%
    Gui, Settings:Add, Edit, x42 yp w102 h22 vNewGiftPepsiName, %giftPepsiName%
    Gui, Settings:Add, Edit, x150 yp w76 h22 vNewGiftPepsi Center Number, %giftPepsiThreshold%
    Gui, Settings:Add, Edit, x238 yp w94 h22 vNewPluPepsi Center Limit10, %pluPepsi%
    Gui, Settings:Add, Checkbox, xs y+8 w22 h22 vNewGiftBrooklynEnabled Checked%giftBrooklynEnabled%
    Gui, Settings:Add, Edit, x42 yp w102 h22 vNewGiftBrooklynName, %giftBrooklynName%
    Gui, Settings:Add, Edit, x150 yp w76 h22 vNewGiftBrooklyn Center Number, %giftBrooklynThreshold%
    Gui, Settings:Add, Edit, x238 yp w94 h22 vNewPluBrooklyn Center Limit10, %pluBrooklyn%
    Gui, Settings:Add, Checkbox, xs y+8 w22 h22 vNewGiftBurgerEnabled Checked%giftBurgerEnabled%
    Gui, Settings:Add, Edit, x42 yp w102 h22 vNewGiftBurgerName, %giftBurgerName%
    Gui, Settings:Add, Edit, x150 yp w76 h22 vNewGiftBurger Center Number, %giftBurgerThreshold%
    Gui, Settings:Add, Edit, x238 yp w94 h22 vNewPluBurger Center Limit10, %pluBurger%
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, xs y+10 w316, PLU вводиться повністю, разом із нулями на початку.

    ; ── Вкладка: СІВ / палички ──────────────────────────────
    Gui, Settings:Tab, %_settingsSivTab%
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y44 w320 Section, PLU-коди паличок, соусу, імбиру та васабі
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, xs y+10 w190 h18, Позиція
    Gui, Settings:Add, Text, x224 yp w108 h18 Center, PLU-код
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, xs y+4 w190 h22 +0x200, Звичайні палички
    Gui, Settings:Add, Edit, x224 yp w108 h22 vNewPluSticksNorm Center Limit10, %pluSticksNorm%
    Gui, Settings:Add, Text, xs y+8 w190 h22 +0x200, Навчальні палички
    Gui, Settings:Add, Edit, x224 yp w108 h22 vNewPluSticksEdu Center Limit10, %pluSticksEdu%
    Gui, Settings:Add, Text, xs y+8 w190 h22 +0x200, Соєвий соус
    Gui, Settings:Add, Edit, x224 yp w108 h22 vNewPluSoy Center Limit10, %pluSoy%
    Gui, Settings:Add, Text, xs y+8 w190 h22 +0x200, Імбир
    Gui, Settings:Add, Edit, x224 yp w108 h22 vNewPluGinger Center Limit10, %pluGinger%
    Gui, Settings:Add, Text, xs y+8 w190 h22 +0x200, Васабі
    Gui, Settings:Add, Edit, x224 yp w108 h22 vNewPluWasabi Center Limit10, %pluWasabi%
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, xs y+12 w316, Не прибирайте нулі на початку PLU-коду.

    ; ── Вкладка: Гарячі клавіші ────────────────────────────
    Gui, Settings:Tab, %_settingsHotkeysTab%
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, x16 y44 w320 Section, Основні гарячі клавіші:
    _hkMainDisplay := (hkMain = "vkC0") ? "~" : hkMain
    Gui, Settings:Add, Text, xs y+14 w150 h22 +0x200, Відкрити пульт:
    Gui, Settings:Add, Edit, x+6 yp w150 vNewHkMain, %_hkMainDisplay%
    Gui, Settings:Add, Text, xs y+8 w150 h22 +0x200, Швидкий СИВ:
    Gui, Settings:Add, Edit, x+6 yp w150 vNewHkSiv, %hkSiv%
    Gui, Settings:Font, s8 norm c%RhC_Muted%, %RhFontName%
    Gui, Settings:Add, Text, xs y+14 w322, Підказка: ~ — клавіша тильди поруч із цифрою 1.
    _themeIdx := (uiTheme = "dark") ? 2 : 1
    Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Text, xs y+12 w150 h22 +0x200, Тема пульта:
    Gui, Settings:Add, DropDownList, x+6 yp w150 vNewUiTheme Choose%_themeIdx%, ☀ Light Premium|🌑 Neon Dark

    ; ── Опциональна вкладка: Звіт F5 ───────────────────────
    if (_settingsReportTab) {
        Gui, Settings:Tab, %_settingsReportTab%
        Gui, Settings:Font, s9 norm c%RhC_Text%, %RhFontName%
        Gui, Settings:Add, Text, x16 y44 w320 Section, Автозвіт у Telegram (клавіша F5):
        Gui, Settings:Add, Text, xs y+14 w90 h22 +0x200, Чат / група:
        Gui, Settings:Add, Edit, x+6 yp w216 h22 vNewTgGroup, %tgGroup%
        Gui, Settings:Add, Button, xs y+14 w322 h30 gSetupAutopilot, 🎬 Калібрування звіту (записати кліки)
    }

    ; ── Загальна кнопка збереження (поза вкладками) ───────
    Gui, Settings:Tab
    Gui, Settings:Font, s10 bold c%RhC_Text%, %RhFontName%
    Gui, Settings:Add, Button, x16 y378 w328 h34 gSaveSettings, 💾 Зберегти та перезапустити
    Gui, Settings:Show, w360, Налаштування RollHouse
return

SaveSettings:
    Gui, Settings:Submit
    if (NewHkMain = "~")
        NewHkMain := "vkC0"
    NewGiftPepsiName := Trim(NewGiftPepsiName)
    NewGiftBrooklynName := Trim(NewGiftBrooklynName)
    NewGiftBurgerName := Trim(NewGiftBurgerName)
    if (NewGiftPepsiName = "")
        NewGiftPepsiName := giftPepsiName
    if (NewGiftBrooklynName = "")
        NewGiftBrooklynName := giftBrooklynName
    if (NewGiftBurgerName = "")
        NewGiftBurgerName := giftBurgerName
    IniWrite, %NewGiftPepsi%, RkConfig.ini, Gifts, PepsiThreshold
    IniWrite, %NewGiftBrooklyn%, RkConfig.ini, Gifts, BrooklynThreshold
    IniWrite, %NewGiftBurger%, RkConfig.ini, Gifts, BurgerThreshold
    IniWrite, %NewGiftPepsiEnabled%, RkConfig.ini, Gifts, PepsiEnabled
    IniWrite, %NewGiftBrooklynEnabled%, RkConfig.ini, Gifts, BrooklynEnabled
    IniWrite, %NewGiftBurgerEnabled%, RkConfig.ini, Gifts, BurgerEnabled
    IniWrite, %NewGiftPepsiName%, RkConfig.ini, Gifts, PepsiName
    IniWrite, %NewGiftBrooklynName%, RkConfig.ini, Gifts, BrooklynName
    IniWrite, %NewGiftBurgerName%, RkConfig.ini, Gifts, BurgerName
    if (NewPluPepsi != "")
        IniWrite, %NewPluPepsi%, RkConfig.ini, PLU, Pepsi
    if (NewPluBrooklyn != "")
        IniWrite, %NewPluBrooklyn%, RkConfig.ini, PLU, Brooklyn
    if (NewPluBurger != "")
        IniWrite, %NewPluBurger%, RkConfig.ini, PLU, Burger
    if (NewPluSticksNorm != "")
        IniWrite, %NewPluSticksNorm%, RkConfig.ini, PLU_SIV, SticksNorm
    if (NewPluSticksEdu != "")
        IniWrite, %NewPluSticksEdu%, RkConfig.ini, PLU_SIV, SticksEdu
    if (NewPluSoy != "")
        IniWrite, %NewPluSoy%, RkConfig.ini, PLU_SIV, Soy
    if (NewPluGinger != "")
        IniWrite, %NewPluGinger%, RkConfig.ini, PLU_SIV, Ginger
    if (NewPluWasabi != "")
        IniWrite, %NewPluWasabi%, RkConfig.ini, PLU_SIV, Wasabi
    if (Module_IsEnabled("reports"))
        IniWrite, %NewTgGroup%, RkConfig.ini, Autopilot, TgGroup
    IniWrite, %NewHkMain%, RkConfig.ini, Hotkeys, Main
    IniWrite, %NewHkSiv%, RkConfig.ini, Hotkeys, Siv
    if (Module_IsEnabled("calling")) {
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
        IniWrite, %NewCallListenEnabled%, RkConfig.ini, CallListen, AutoEnabled
        _callEngineSave := InStr(NewCallListenEngine, "Stream") ? "sherpa_stream" : (InStr(NewCallListenEngine, "Sherpa") ? "sherpa" : "whisper")
        IniWrite, %_callEngineSave%, RkConfig.ini, CallListen, Engine
        IniWrite, %NewCallListenAdvisorOnly%, RkConfig.ini, CallListen, AdvisorOnly
        if (NewCallGreetingDelayMs != "")
            IniWrite, %NewCallGreetingDelayMs%, RkConfig.ini, CallListen, GreetingDelayMs
        if (NewCallListenDevice != "")
            IniWrite, %NewCallListenDevice%, RkConfig.ini, CallListen, Device
        if (NewCallListenRmsThreshold != "")
            IniWrite, %NewCallListenRmsThreshold%, RkConfig.ini, CallListen, RmsThreshold
    }
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
^Enter::GoSub, RhFinishOrder
^+Enter::GoSub, RhFinishOrder
^NumpadEnter::GoSub, RhFinishOrder
^+NumpadEnter::GoSub, RhFinishOrder
#IfWinActive

#IfWinActive ahk_exe BackOffice.exe
^Enter::GoSub, RhFinishOrder
^+Enter::GoSub, RhFinishOrder
^NumpadEnter::GoSub, RhFinishOrder
^+NumpadEnter::GoSub, RhFinishOrder
#IfWinActive

RhFinishOrder:
    if (RhFinishBusy) {
        ToolTip, % "⏳ Фініш вже виконується..."
        SetTimer, RemoveToolTip, -900
        return
    }
    _opFinishToken := OpCoord_Begin("FinishingOrder", "RhFinishOrder", "hotkey=Ctrl+Enter")
    RhFinishBusy := 1
    _finishStart := A_TickCount
    FileAppend, % "[" . A_Now . "] RH_FINISH start Ctrl+Enter`n", %A_ScriptDir%\ahk_debug.log

    IikoRestore()
    FileAppend, % "[" . A_Now . "] RH_FINISH iiko_ready ms=" . (A_TickCount - _finishStart) . "`n", %A_ScriptDir%\ahk_debug.log
    _finishOk := 1
    _confirmStart := A_TickCount
    if (!RhUiaClickWindowOnly("buttonDeliveryConfirmation")) {
        _finishOk := 0
        ToolTip, % "⚠️ Не знайшов/не натиснув Подтвердить"
        FileAppend, % "[" . A_Now . "] RH_FINISH confirm failed ms=" . (A_TickCount - _confirmStart) . "`n", %A_ScriptDir%\ahk_debug.log
        Sleep, % SpDly(700)
    } else {
        FileAppend, % "[" . A_Now . "] RH_FINISH confirm ok ms=" . (A_TickCount - _confirmStart) . "`n", %A_ScriptDir%\ahk_debug.log
        Sleep, % SpDly(350)
    }

    _saveStart := A_TickCount
    if (!RhUiaClickWindowOnly("buttonSaveAndClose")) {
        _finishOk := 0
        ToolTip, % "⚠️ Не знайшов/не натиснув Сохранить на точку"
        FileAppend, % "[" . A_Now . "] RH_FINISH save failed ms=" . (A_TickCount - _saveStart) . "`n", %A_ScriptDir%\ahk_debug.log
        Sleep, % SpDly(900)
    } else {
        ToolTip, % "✅ Підтверджено + збережено на точку"
        FileAppend, % "[" . A_Now . "] RH_FINISH save ok ms=" . (A_TickCount - _saveStart) . "`n", %A_ScriptDir%\ahk_debug.log
        Sleep, % SpDly(500)
    }
    FileAppend, % "[" . A_Now . "] RH_FINISH done ok=" . _finishOk . " total_ms=" . (A_TickCount - _finishStart) . "`n", %A_ScriptDir%\ahk_debug.log
    SetTimer, RemoveToolTip, -1200
    RhFinishBusy := 0
    OpCoord_End(_opFinishToken, _finishOk ? "ok" : "error", "total_ms=" . (A_TickCount - _finishStart))
return

RollEnter:
    ; Enter = фінальна дія пульта: бекап стану, внесення полів, потім СІВ останнім кроком.
    if (RhEnterBusy || (RhLastEnterTick && (A_TickCount - RhLastEnterTick < RhEnterCooldownMs))) {
        ToolTip, % "⏳ Цепочка вже виконується, Enter заблоковано на мить..."
        SetTimer, RemoveToolTip, -1200
        return
    }
    _opEnterToken := OpCoord_Begin("EditingOrder", "RollEnter", "hotkey=Enter")
    RhEnterBusy := 1
    RhLastEnterTick := A_TickCount
    RhApplyManualZoneOverride()
    GoSub, RhSaveEnterState
    GoSub, RhRefreshEnterPreview
    GoSub, RhEnterPreflight
    if (!RhPreflightOk) {
        RhEnterBusy := 0
        OpCoord_End(_opEnterToken, "blocked", "preflight_failed")
        return
    }

    GuiControlGet, _enterRolls, Roll:, VisRolls
    GuiControlGet, _enterNorm,  Roll:, VisNorm
    GuiControlGet, _enterEdu,   Roll:, VisEdu
    _hasSivInput := ((_enterRolls != "" && _enterRolls != "0") || (_enterNorm != "" && _enterNorm != "0") || (_enterEdu != "" && _enterEdu != "0"))
    if (_hasSivInput && (itemX = 0 || itemX = "ERROR") && !IsObject(RhUiaFind("ТаблицяСтрав", "treeListItems"))) {
        MsgBox, 48, Помилка, Не задано приціл "Табл. Страв"! (Налаштування -> 7)
        RhEnterBusy := 0
        return
    }

    GoSub, ApplyRollclub
    if (_hasSivInput)
        RhPunchSivValues(_enterRolls, _enterNorm, _enterEdu)
    RhEnterBusy := 0
    OpCoord_End(_opEnterToken, "ok", "has_siv=" . _hasSivInput)
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
    noPayChange := 0
    
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
    isAsap := RegExMatch(text, "i)Якомога швидше|Найближчим часом|Найближчий час|На найближчий час|Як можна скоріше|Как можно скорее")

    ; Якщо ASAP — вилучаємо весь блок "Час: HH:MM" зі схематичного тексту
    ; (дата вже видалена в кроці 1, залишається "Час:  11:16")
    if (isAsap)
        text := RegExReplace(text, "i)Час:\s*\d{1,2}:\d{2}", "")

    timeSearchText := text
    timeSearchText := RegExReplace(timeSearchText, "i)(?:Час|Время):\s*\d{4}-\d{2}-\d{2}\s+\d{1,2}:\d{2}(?:\s*\([^)]*\))?", " ")
    timeSearchText := RegExReplace(timeSearchText, "i)Android\s+v[\d\.]+[^,\r\n;]*,\s*(?:Час|Время):\s*\d{1,2}:\d{2}", " ")
    timeSearchText := RegExReplace(timeSearchText, "i)\b(?:вчера|учора|вчора)[^,\r\n;]{0,90}\d{1,2}\s*[:\.\-]\s*\d{2}[^,\r\n;]{0,90}", " ")
    timeSearchText := RegExReplace(timeSearchText, "i)\d{1,2}[\./]\d{1,2}\s+\d{1,2}:\d{2}\s*\((?:Якомога швидше|Как можно скорее|Як можна скоріше|Найближчим часом)\)", " ")

    timeCandidate := ""
    if (RegExMatch(timeSearchText, "i)(?:\b(?:на|к|до|в|о|час|время|забрати|заберу|доставити|доставить|привезти)\b\s*)[^\d\r\n;]{0,24}(?<!\d)([01]?\d|2[0-3])\s*[:\.\-]\s*([0-5]\d)(?!\d)", tPref))
        timeCandidate := Format("{:02}:{:02}", tPref1+0, tPref2+0)
    else if (RegExMatch(timeSearchText, "i)(?:\b(?:на|к|до|в|о|час|время)\b\s*|Час:\s*|Время:\s*)?(?<!\d)([01]?\d|2[0-3])\s*[:\.\-]\s*([0-5]\d)(?!\d)", tCand))
        timeCandidate := Format("{:02}:{:02}", tCand1+0, tCand2+0)
    else if (RegExMatch(timeSearchText, "i)(?:\b(?:на|к|до|в|о|час|время)\b\s*|Час:\s*|Время:\s*)?(?<!\d)([01]?\d|2[0-3])\s+([0-5]\d)(?!\d)", tCandSp))
        timeCandidate := Format("{:02}:{:02}", tCandSp1+0, tCandSp2+0)

    if RegExMatch(timeSearchText, "i)(\d{1,2}):(\d{2})\s*PM", pmMatch) {
        hh := pmMatch1 + 0
        if (hh < 12)
            hh += 12
        extractedTime := Format("{:02}:{:02}", hh, pmMatch2)
    } else if RegExMatch(timeSearchText, "i)(\d{1,2}):(\d{2})\s*AM", amMatch) {
        hh := amMatch1 + 0
        if (hh == 12)
            hh := 0
        extractedTime := Format("{:02}:{:02}", hh, amMatch2)
    } else if RegExMatch(timeSearchText, "i)(?:На\s+|Час:\s*)(\d{1,2}:\d{2})", tMatch) {
        extractedTime := tMatch1
    } else if RegExMatch(timeSearchText, "i)(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)", tMatch2) {
        extractedTime := Format("{:02}:{:02}", tMatch21+0, tMatch22+0)
    } else if RegExMatch(text, "i)Якомога швидше|Найближчим часом|Як можна скоріше|Как можно скорее") {
        ; ASAP — лишаємо порожнім; дефолт (+40/+60) виставиться в DrawRollclub
    }

    ; Якщо час в тексті знайдено, але шаблони вище не спрацювали — все одно підставити його.
    if (extractedTime = "" && timeCandidate != "")
        extractedTime := timeCandidate

    ; Передзамовлення на ІНШИЙ ДЕНЬ (як у Roll Club): час НЕ ставимо взагалі —
    ; лишаємо поле порожнім, оператор виставить дату/час сам після червоного попередження.
    if (isFutureDate)
        extractedTime := ""

    ; ASAP («Якомога швидше») = ПОТОЧНИЙ заказ: час у коментарі — це час СТВОРЕННЯ,
    ; а не доставки. Ігноруємо його → дефолт (+40 самовивіз / +60 доставка, кратно 5)
    ; виставиться в DrawRollclub.
    if (isAsap)
        extractedTime := ""

    ; Вичистити час у різних форматах, щоб не дублювати в коментарі.
    text := RegExReplace(text, "i)(?:\b(?:на|к|до|в|час|время)\b\s*|Час:\s*|Время:\s*)?(?<!\d)([01]?\d|2[0-3])\s*[:\.\-]\s*([0-5]\d)(?!\d)(?:\s*(?:AM|PM))?", "")
    text := RegExReplace(text, "i)(?:\b(?:на|к|до|в|час|время)\b\s*|Час:\s*|Время:\s*)?(?<!\d)([01]?\d|2[0-3])\s+([0-5]\d)(?!\d)", "")
    text := RegExReplace(text, "i)\s*\(?Якомога швидше\)?|\s*\(?Найближчим часом\)?|\s*\(?Найближчий час\)?|\s*\(?На найближчий час\)?", "")

    ; 3. ОПЛАТА ТА НОМЕР
    orderNum := ""
    if RegExMatch(text, "i)Замовлення №(\d+)", mOrder)
        orderNum := " №" . mOrder1

    if RegExMatch(text, "i)(Карт(?:ою|кою|кой|ой)\s+(?:онлайн|online|на\s+сайт[іе])|Безнал\s*сайт|ОПЛАЧЕНО|оплачено)") {
        paymentMethod := "ОПЛАЧЕНО" . orderNum
    } else if RegExMatch(text, "i)(Карткою у закладі|Картою в закладі|Картой в заведении|Банківська карта|Банківська картка|Банковская карта|Термінал|Terminal)") {
        paymentMethod := "Термінал (При отриманні)" . orderNum
        autoCard := 1
    } else if RegExMatch(text, "i)(Готівкою|Готівка|Наличными)") {
        autoCash := 1, paymentMethod := "Готівка" . orderNum
    } else {
        autoCash := 1
        paymentMethod := "Готівка" . orderNum
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
    if RegExMatch(text, "i)(\d+)\s*(?:пар\s*пал|персон|прибор|учбов|навчальн|палоч|палич)|(?:Учбові|Навчальні|Кількість приборів|Количество приборов|Для).*?(\d+)", mEdu) {
        parsedSticksEdu := (mEdu1 != "") ? mEdu1 : mEdu2
        text := RegExReplace(text, "i)\d+\s*(?:пар\s*пал|персон|прибор|учбов|навчальн|палоч|палич)[^\s,;]*|(?:Учбові|Навчальні|Кількість приборів|Количество приборов|Для)[^\d]*\d+", "")
    }

    ; 5. ПОДАРУНКИ ВІД СУМИ (не пробивати якщо є бонуси/знижки)
    bonusWriteoff := RegExMatch(text, "i)(списат[ьи]|списати|списання|бонус|бонусами|бон\.|бали|баллы)") ? 1 : 0
    bonusNote := ""
    if (bonusWriteoff) {
        if RegExMatch(text, "i)(списат[ьи]|списання|бонус|бонусами|бон\.|бали|баллы)([^,;|\r\n]*)", mBonus)
            bonusNote := Trim(mBonus1 . mBonus2)
    }
    hasBonuses := bonusWriteoff || RegExMatch(text, "i)(знижк|промокод|discount|cashback|кешбек)")
    noPayChange := bonusWriteoff ? 1 : 0
    FileAppend, % "[" A_Now "] BONUSDBG noPayChange=" noPayChange " txt=[" SubStr(text,1,160) "]`n", %A_ScriptDir%\ahk_debug.log
    if (orderSum > 0 && !hasBonuses) {
        if (giftBurgerEnabled && orderSum >= giftBurgerThreshold && !autoBurger)
            autoBurger := 1
        else if (giftBrooklynEnabled && orderSum >= giftBrooklynThreshold && !autoBrooklyn && !autoBurger)
            autoBrooklyn := 1
        else if (giftPepsiEnabled && orderSum >= giftPepsiThreshold && !autoPepsi && !autoBrooklyn && !autoBurger)
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

            ; --- ЄДИНИЙ ПРОХІД: матч назви зони по тексту адреси (streetText + коментар),
            ;     з МЕЖАМИ СЛОВА, НАЙДОВША назва = найточніша. Підзона важливіша за головне місто.
            ;     (перевірено на 1000 реальних адрес: ~96% влучань, геокод не потрібен)
            ;
            ; Систематична перевірка 820 реальних адрес (Мерефа/Чугуїв/Берестин) виявила
            ; ще 3 класи проблем, яких цей прохід сам по собі НЕ ловив — виправлено нижче,
            ; дзеркально до server/pult_rollhouse_zones.py:
            ;   (1) написання міста (Чугуев/Чугуєв) і одруківки району (Зачуговка/
            ;       Коробочкине/Приображенка/Наталино/латиниця KOMAPІBKA) — нормалізуємо
            ;       ПОШУКОВИЙ текст ДО матчингу, назви в ini/вивід лишаються як є.
            ;   (2) Дружба/Березівка/Леб'яже існують ДВІЧІ в ini з однаковою назвою, але
            ;       різною ціною (різні села в різних головних містах) — простий
            ;       "найдовша перемагає" тут не розрізняє, бере перший запис завжди.
            ;       Розв'язуємо по вже впізнаному в тексті головному місту.
            ;   (3) якщо за головним містом іде РАЙОН, якого немає в ini взагалі
            ;       (напр. "Мерефа, Борки, ...") — раніше тихо підставлялась ціна
            ;       головного міста (Мерефа=100), хоча Борки це окреме село під
            ;       Нова Водолага. Тепер такий випадок лишається без ціни (0),
            ;       а не вгадується навмання.
            rawSearchPool := streetText . " " . rawComment
            searchPool := rawSearchPool
            searchPool := RegExReplace(searchPool, "i)Чугуев", "Чугуїв")
            searchPool := RegExReplace(searchPool, "i)Чугуєв", "Чугуїв")
            searchPool := RegExReplace(searchPool, "i)Зачуговка", "Зачугівка")
             searchPool := RegExReplace(searchPool, "i)Коробочкине", "Коробчине")
             searchPool := RegExReplace(searchPool, "i)Приображенка", "Преображенка")
             searchPool := RegExReplace(searchPool, "i)Наталино", "Наталине")
             searchPool := RegExReplace(searchPool, "i)KOMAP[IІ]BKA", "Комарівка")
            searchPool := RegExReplace(searchPool, "i)Песчанка|Пищанка", "Піщанка")
            priorityZoneName := ""
            priorityZonePrice := 0
            if (RegExMatch(rawComment, "i)(?<!не\s)(?:м\.?\s*)?(Песчанка|Пищанка|Піщанка)", mPriorityZone))
                RhLookupManualZone("Піщанка", priorityZoneName, priorityZonePrice)

            ; Яке головне місто вже впізнано в тексті (для розв'язання неоднозначних
            ; назв нижче і для запобіжника невідомого району).
            cityHint := ""
            if (RegExMatch(searchPool, "i)берестин\w*")) {
                cityHint := "берестин"
            } else if (RegExMatch(searchPool, "i)чугу[іеє]?в\w*")) {
                cityHint := "чугуїв"
            } else if (RegExMatch(searchPool, "i)мереф\w*")) {
                cityHint := "мерефа"
            }

            _bestSubN := ""
            _bestSubP := 0
            _bestSubLen := 0
            _bestCityN := ""
            _bestCityP := 0
            _bestCityLen := 0
            knownNames := {}
            Loop, Parse, paramStr, `n, `r
            {
                if (!InStr(A_LoopField, "=")) {
                    continue
                }
                arrOut := StrSplit(A_LoopField, "=")
                ; Trim() за замовчуванням прибирає тільки пробіл/таб, НЕ
                ; невидиму нерозривну пробільну (U+00A0, Chr(160)) — а вона є
                ; в 9 рядках ini (Ольховатка, Щебетуни, Печеніги, Леб'яже=800,
                ; Пролісне, Іванівка, Балки, Дружба=570, Верхня Ланна).
                ; Без явного прибирання ці зони НІКОЛИ не матчились: dName
                ; лишався з приліпленим невидимим символом і InStr завжди
                ; повертав 0. Python-модуль цього бага не мав — .strip() там
                ; прибирає U+00A0 за замовчуванням.
                dName := Trim(arrOut[1], " `t" . Chr(160))
                dPrice := Trim(arrOut[2], " `t" . Chr(160))
                if (dName = "") {
                    continue
                }
                StringLower, _dNameLow, dName
                knownNames[_dNameLow] := true
                if (RegExMatch(dName, isTechKey)) {
                    continue
                }
                ; Дружба/Березівка/Леб'яже: та сама назва в кількох головних містах з
                ; різною ціною. Якщо в тексті вже впізнано місто — пропускаємо той
                ; запис-дублікат, чия ціна відповідає ІНШОМУ місту.
                StringLower, dNameNorm, dName
                if (cityHint != "" && (dNameNorm = "дружба" || dNameNorm = "березівка" || dNameNorm = "леб'яже" || dNameNorm = "леб’яже")) {
                    dPriceNum := dPrice + 0
                    if (dNameNorm = "дружба") {
                        wantCity := (dPriceNum = 570) ? "берестин" : "чугуїв"
                    } else if (dNameNorm = "березівка") {
                        wantCity := (dPriceNum = 820) ? "берестин" : "мерефа"
                    } else {
                        wantCity := (dPriceNum = 700) ? "берестин" : "чугуїв"
                    }
                    if (wantCity != cityHint) {
                        continue
                    }
                }
                _pos := InStr(searchPool, dName)
                if (!_pos) {
                    continue
                }
                _bch := " "
                if (_pos > 1) {
                    _bch := SubStr(searchPool, _pos - 1, 1)
                }
                _ach := SubStr(searchPool, _pos + StrLen(dName), 1)
                if (RegExMatch(_bch, "[А-Яа-яІЇЄҐіїєґ]")) {
                    continue
                }
                if (RegExMatch(_ach, "[А-Яа-яІЇЄҐіїєґ]")) {
                    continue
                }
                if (RegExMatch(dName, mainCitiesRegex)) {
                    if (StrLen(dName) > _bestCityLen) {
                        _bestCityN := dName
                        _bestCityP := dPrice + 0
                        _bestCityLen := StrLen(dName)
                    }
                } else {
                    if (StrLen(dName) > _bestSubLen) {
                        _bestSubN := dName
                        _bestSubP := dPrice + 0
                        _bestSubLen := StrLen(dName)
                    }
                }
            }

            ; Запобіжник: підзона не знайдена, залишається тільки здогадка "головне
            ; місто" — перевіряємо, чи одразу за містом не йде НЕВІДОМИЙ район
            ; (кома раніше за номер будинку/слово "вулиця"). Якщо так — це чесна
            ; прогалина покриття, а не привід вгадувати ціну міста.
            if (_bestSubN = "" && _bestCityN != "" && cityHint != "") {
                if (RegExMatch(searchPool, "i)(мереф\w*|чугу[іеє]?в\w*|берестин\w*)(.*)$", mCityRest)) {
                    _rest := RegExReplace(mCityRest2, "^[\s,]+", "")
                    _commaPos := InStr(_rest, ",")
                    if (_commaPos) {
                        _beforeComma := SubStr(_rest, 1, _commaPos - 1)
                        _hasDigit := RegExMatch(_beforeComma, "\d")
                        _hasStreetWord := RegExMatch(_beforeComma, "i)(вулиц\w*|вул\.|провулок|площ\w*|бульвар|в['’]?їзд|проспект|мікрорайон|узвіз|перевулок|заїзд)")
                        if (!_hasDigit && !_hasStreetWord) {
                            _candidate := Trim(_beforeComma, " ,")
                            StringLower, _candLow, _candidate
                            if (StrLen(_candidate) >= 2 && !knownNames.HasKey(_candLow)) {
                                _bestCityN := ""
                                _bestCityP := 0
                                FileAppend, % "[" A_Now "] ZONE unresolved_district candidate=[" _candidate "] pool=[" SubStr(searchPool, 1, 80) "]`n", %A_ScriptDir%\ahk_debug.log
                            }
                        }
                    }
                }
            }

            if (priorityZoneName != "") {
                deliveryCostStr := "Доставка " . priorityZoneName . " - " . priorityZonePrice . " грн"
                deliveryCostNum := priorityZonePrice
            } else if (_bestSubN != "") {
                deliveryCostStr := "Доставка " . _bestSubN . " - " . _bestSubP . " грн"
                deliveryCostNum := _bestSubP
            } else {
                if (_bestCityN != "") {
                    deliveryCostStr := "Доставка " . _bestCityN . " - " . _bestCityP . " грн"
                    deliveryCostNum := _bestCityP
                }
            }
            StringCaseSense, %oldCaseSense%
        }
    }

    ; 8. ФІНАНСИ (рахуємо решту від СУМА + ДОСТАВКА)
    clientNoChange := RegExMatch(text, "i)(без\s*здач[іи]|без\s*сдач[иі]|без\s*решт[иі])") ? 1 : 0
    if RegExMatch(text, "i)(?:підготувати\s*)?решт[уа]\s*з(?:[:\sз]*?)(\d+)", matchChange) {
        clientChange := matchChange1, autoCash := 1
    }
    totalSum := orderSum + deliveryCostNum
    if (clientChange != "")
        calcChange := clientChange
    else if (clientNoChange)
        calcChange := 0
    else if (autoCash && !noPayChange && totalSum > 0)
        calcChange := Ceil(totalSum / 200) * 200
    else
        calcChange := 0

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
        if (!RegExMatch(text, "i)([^.,;!?\r\n]*(?:без\s+[а-яіїєґ]+|не\s+(?:додавати|додавайте|кладіть|класть|ложить|гріти|греть)|не\s+треба\s+гріти|не\s+надо\s+греть|потрібна\s+холодна|нужна\s+холодная|алерг|добре\s+просмаж)[^.,;!?\r\n]*)", kMatch))
            break
        if (kitchenNote != "")
            kitchenNote .= " | "
        kitchenNote .= Trim(kMatch1)
        text := StrReplace(text, kMatch1, "")
    }
    ; kitchenNote → поле «Кухня», не в коментар кур'єра

    ; 9. ВИДАЛЕННЯ СМІТТЯ
    if RegExMatch(text, "i)((?:Адреса\s+доставки:\s*)?(?:Песчанка|Пищанка|Піщанка)\s*,\s*(?:вул\s*\.?|ул\s*\.?|вулиця|улица)\s*[^;\r\n]*?)(?=\s*,\s*(?:Списат|Бонус|Решт|Оплат|Карт|Переказ|Перевод)|[;\r\n]|$)", mLooseAddr) {
        addrNote := Trim(RegExReplace(mLooseAddr1, "i)^Адреса\s+доставки:\s*", ""))
        text := StrReplace(text, mLooseAddr0, "")
    }
    text := RegExReplace(text, "i)(м\.|г\.)\s*(Мерефа|Берес\s*тин|Берес\s*тін|Чугуїв|Чугуєв|Харків).*?(дім\s*-|кв\.|буд\.|дом\b).*?(?=\r|\n|$)", "")
    text := RegExReplace(text, "i)(Адреса доставки:|Адреса:\s*|Адрес:\s*).*?((?=,\s*Оплата)|(?=[;\r\n]|$))", "")
    text := RegExReplace(text, "i)(Android v[\d\.]+|iOS v[\d\.]+)[,\s;]*", "")
    text := RegExReplace(text, "i)(Замовлення|Заказ) №\d+[ \r\n]*", "")
    text := RegExReplace(text, "i)(?:---ОПЛАЧЕНО---|УСПІШНО|УСПЕШНО)", "")
    text := RegExReplace(text, "i)(Тип оплати:|Тип оплаты:)\s*(.*?)(?=\r|\n|$)", "")
    text := RegExReplace(text, "i)Оплата:\s*(.*?)(?=[,\r\n;]|$)", "")
    text := RegExReplace(text, "i)(?:Коментар:|Комментарий к заказу:)\s*[^\r\n]*", "")  ; fallback
    text := RegExReplace(text, "i)(?:Передзвонити|Перетелефонувати|Подзв|зателефону|звонить|перезвонить)[^\r\n]*", "")
    text := RegExReplace(text, "i)(без\s*здач[іи]|без\s*сдач[иі]|без\s*решт[иі])", "")
    text := RegExReplace(text, "i)(?:підготувати\s*|подготовить\s*)?(решт[уа]\s*з|сдача\s*с)(?:[:\sзс]*?)\d+(?:\s*грн)?\s*", "")
    text := RegExReplace(text, "i)\b(?:Час|Время):?\s*", "")
    text := RegExReplace(text, "i)(Карткою у закладі|Картою в закладі|Картой в заведении)", "")
    
    ; Видаляємо залишки дат формату 24.06 або 24.06.2026 (час 19:00 вже видалено вище)
    text := RegExReplace(text, "i)(?:\b(?:доставка|на|к|до|в)\b\s*)?(?<!\d)(0?[1-9]|[12]\d|3[01])[\./](0[1-9]|1[012])(?:[\./](20\d{2}|\d{2}))?(?!\d)\.?\s*", "")

    ; 9.5 ІДЕМПОТЕНТНІСТЬ: зняти вже зібрані НАМИ фрагменти, щоб повторний парс не дублював коментар
    text := RegExReplace(text, "i)Доставк[а-яіїєґ]*\s+[^|\r\n]+?\s*-\s*\d+\s*грн", " ")   ; наш формат вартості доставки
    text := RegExReplace(text, "i)Готівка(?=[\s|№]|$)", " ")                              ; наш paymentMethod
    text := RegExReplace(text, "i)ОПЛАЧЕНО(?=[\s|№]|$)", " ")
    text := RegExReplace(text, "i)Термінал\s*\(При отриманні\)", " ")
    text := RegExReplace(text, "\s*\|\s*", " ")                                            ; наші роздільники

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
    addrNote := RegExReplace(addrNote, "i)(?:підготувати\s*|подготовить\s*)?(решт[уа]\s*з|сдача\s*с)\s*\d+(?:[.,]\d+)?\s*(?:грн|₴)?", "")
    addrNote := RegExReplace(addrNote, "i)(Готівк(?:а|ою)|Наличными|Термінал(?:\s*\(При отриманні\))?|ОПЛАЧЕНО)", "")
    addrNote := Trim(RegExReplace(addrNote, "\s*(?:\||,|;)\s*", " "))

    ; 11. ЗБІРКА ЧИСТОГО КОМЕНТАРЯ
    text := RegExReplace(text, "[\r\n]+", " ") 
    text := RegExReplace(text, "[,;\.]{2,}", "") 
    text := RegExReplace(text, "\s*[,;]\s*[,;]\s*", " ")
    text := RegExReplace(text, "\s*;\s*,\s*|\s*,\s*;\s*", " ")
    text := RegExReplace(text, "^\s*[,;\.:\-]+\s*|\s*[,;\.:\-]+\s*$", "")
    text := RegExReplace(text, "\s{2,}", " ")
    cleanComment := Trim(text)
    if (bonusNote != "" && !InStr(cleanComment, bonusNote))
        cleanComment .= (cleanComment != "" ? " | " : "") . bonusNote

    ; Зону доставки вже знайдено вище у Кроці 7 (deliveryCostStr / deliveryCostNum)

    finalClean := ""
    if (paymentMethod != "")
        finalClean .= paymentMethod . " "
    if (deliveryCostStr != "")
        finalClean .= deliveryCostStr . " | "
    if (autoCash && totalSum > 0 && calcChange > 0)
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

    if ((itemX = 0 || itemX = "ERROR") && !IsObject(RhUiaFind("ТаблицяСтрав", "treeListItems"))) {
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
    _pluJobs := []
    RhAddPluJob(_pluJobs, pluSticksNorm, VisNorm)
    RhAddPluJob(_pluJobs, pluSticksEdu, VisEdu)
    RhAddPluJob(_pluJobs, pluSoy, soyQty)
    RhAddPluJob(_pluJobs, pluGinger, gwQty)
    RhAddPluJob(_pluJobs, pluWasabi, gwQty)
    RhPunchPluSeries(_pluJobs, _itX, _itY)
    /*
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
    */

    ToolTip   ; прибрати підказку СИВ
    MouseMove, %originalMouseX%, %originalMouseY%, 0
    Gui, Roll:Show
    rollVisible := 1
return

; --- Допоміжна функція: пробити блюдо по PLU + кількість ---
RhAddPluJob(ByRef jobs, pluCode, qty) {
    if (qty <= 0 || pluCode = "" || pluCode = "0000")
        return
    jobs.Push({plu: pluCode, qty: qty})
}

RhPunchPluSeries(jobs, itX, itY) {
    if (!IsObject(jobs) || jobs.MaxIndex() = "")
        return 1
    if ((itX = 0 || itX = "ERROR") && !IsObject(RhUiaFind("ТаблицяСтрав", "treeListItems")))
        return 0

    MouseGetPos, _mx, _my
    if (!RhUiaClickFirstOrderRow() && itX != 0 && itX != "ERROR")
        Click, %itX%, %itY%
    Sleep, % SpDly(120)
    MouseMove, %_mx%, %_my%, 0

    ; Перший вхід у PLU-рядок: таблиця → PgDn → Enter.
    Sleep, % SpDly(300)
    Send, {PgDn}
    Sleep, % SpDly(300)
    Send, {Enter}
    Sleep, % SpDly(400)

    Loop, % jobs.MaxIndex() {
        job := jobs[A_Index]
        _jobTick := A_TickCount
        if (A_Index > 1) {
            ; Після попереднього Ctrl+A/C і Enter рядок вже закомічений.
            ; Другий Enter відкриває наступний пустий PLU-ввід без нового PgDn.
            Send, {Enter}
            Sleep, % SpDly(350)
        }
        RhPunchPluInOpenEditor(job.plu, job.qty)
        FileAppend, % "[" A_Now "] SIV_JOB plu=" job.plu " qty=" job.qty " ms=" (A_TickCount - _jobTick) "`n", %A_ScriptDir%\ahk_debug.log
    }
    return 1
}

RhPunchPluInOpenEditor(pluCode, qty) {
    ToolTip, % "🥢 СИВ: пробиваю PLU " . pluCode . "  ×" . qty, 30, 60
    Send, %pluCode%
    Sleep, % SpDly(300)
    Send, {Down}
    Sleep, % SpDly(250)
    Send, {Enter}
    Sleep, % SpDly(500)

    Send, %qty%
    Sleep, % SpDly(200)

    ; Ctrl+A / Ctrl+C — це перевірка фактично введеної кількості.
    Clipboard := ""
    Send, ^a
    Sleep, 50
    Send, ^c
    ClipWait, 0.5

    copiedQty := RegExReplace(Clipboard, "[^\d,.]", "")
    copiedNum := StrSplit(copiedQty, ",")[1]
    copiedNum := StrSplit(copiedNum, ".")[1]

    if (copiedNum != qty) {
        SoundBeep, 1200, 150
        SoundBeep, 800, 150
        SoundBeep, 1200, 150
    }

    ; Перший Enter після перевірки — закомітити поточну позицію.
    Send, {Enter}
    Sleep, % SpDly(350)
}

; PLU-послідовність проходить кілька різних контролів (tree → PLU-діалог → qty).
; Клікаємо в PLU-таблицю (миша повертається НЕГАЙНО після кліку),
; iiko стає активним → всі Send йдуть у потрібний контрол.
PunchByPlu(pluCode, qty, itX, itY) {
    global RH_SERVER_OK, iikoWinExe
    if (qty <= 0 || pluCode = "" || pluCode = "0000")
        return
    if ((itX = 0 || itX = "ERROR") && !IsObject(RhUiaFind("ТаблицяСтрав", "treeListItems")))
        return   ; координати не налаштовані

    ; Видима підказка — оператор бачить, що саме пробивається
    ToolTip, % "🥢 СИВ: пробиваю PLU " . pluCode . "  ×" . qty, 30, 60
    ; Зберігаємо позицію миші
    MouseGetPos, _mx, _my
    ; Клік у PLU-таблицю → таблиця отримує клавіатурний фокус.
    ; Спочатку UIA/WinAPI, координати лишаються fallback.
    if (!RhUiaClickFirstOrderRow() && itX != 0 && itX != "ERROR")
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
    
    Send, %qty%
    Sleep, % SpDly(200)
    
    ; Перевірка того, що ввелось по факту
    Clipboard := ""
    Send, ^a
    Sleep, 50
    Send, ^c
    ClipWait, 0.5
    
    copiedQty := RegExReplace(Clipboard, "[^\d,.]", "")
    copiedNum := StrSplit(copiedQty, ",")[1]
    copiedNum := StrSplit(copiedNum, ".")[1]
    
    if (copiedNum != qty) {
        SoundBeep, 1200, 150
        SoundBeep, 800, 150
        SoundBeep, 1200, 150
    }
    
    Send, {Enter}
    Sleep, % SpDly(350)
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

    if (!RhUiaSetValue("memoEditDeliveryComment", OrderComment))
        IikoPaste(commRelX, commRelY, commX, commY, OrderComment)   ; 1. Коментар

    _rhCustomerInfo := Trim(ClientInfo . ((ClientInfo != "" && ClientCard != "") ? " | " : "") . ClientCard)
    if (_rhCustomerInfo != "") {
        if (!RhUiaDoublePaste("memoEditCustomerComment", _rhCustomerInfo))
            IikoPaste(infoRelX, infoRelY, infoX, infoY, _rhCustomerInfo) ; 3. Кухня/карта
    }

    if (!RhUiaSetValue("memoEditDeliveryAddressComment", AddressNote))
        IikoPaste(addrRelX, addrRelY, addrX, addrY, AddressNote)    ; 4. Адреса

    ; ── Час: клік у поле часу (приціл 6) + клавіатура ──
    if (ReadyTime != "") {
        _rhTimeOk := 0
        if (RhUiaSetValue("timeEditDeliveryTime", ReadyTime)) {
            Sleep, % SpDly(180)
            _gotTime := RhUiaGetValue("timeEditDeliveryTime")
            _rhTimeOk := InStr(_gotTime, ReadyTime) ? 1 : 0
        }
        if (!_rhTimeOk && (timeX != 0 || timeRelX != 0)) {
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
    }

    ; ── ГОТІВКА: тільки для САМОВИВОЗУ ──────────────────────────
    ; Для ДОСТАВКИ: "Решта з X" вже пишеться в чистий коментар (рядок вище)
    ; Для САМОВИВОЗУ: додатково вводимо суму в поле оплати iiko
    ;
    ; Уточнюємо isPickup: якщо поле вулиці в iiko порожнє → самовивіз
    ; (це надійніше ніж парсинг коментаря; вулицю тепер читаємо кліком)
    if (streetText = "")
        isPickup := 1

    ; ── КРОК 1: Подарунок (СПОЧАТКУ — бо ціна зростає після пробиття) ──
    _isGiftPunched := 0
    ; Пробиваємо ТІЛЬКИ якщо задано приціл «7. Табл. страв».
    if ((GiftPepsi || GiftBurger || GiftBrooklyn) && (itemX != 0 || itemRelX != 0)) {
        _isGiftPunched := 1
        if (GiftBurger) {
            GoSub, NewGiftMacro
            Send, %pluBurger%
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
        ; Пауза — iiko має перерахувати суму замовлення після пробиття подарунка
        Sleep, % Max(600, SpDly(1500))
    }

    ; ── КРОК 2: Оплата (ПІСЛЯ подарунка) ──
    ; При списанні бонусів оплату в Syrve не чіпаємо взагалі: ні тип, ні хрестик, ні решту.
    if (!noPayChange && (DoAutoCash || DoAutoCard || paymentMethod != "")) {
        _paySearch := ""
        if (DoAutoCash)
            _paySearch := paymentCashSearch
        else if (DoAutoCard)
            _paySearch := paymentCardSearch
        else if (InStr(paymentMethod, "ОПЛАЧЕНО"))
            _paySearch := ""
        else if (InStr(paymentMethod, "Готівка"))
            _paySearch := paymentCashSearch
        else if (InStr(paymentMethod, "Термінал"))
            _paySearch := paymentCardSearch
        _payMode := (DoAutoCard || InStr(paymentMethod, "Термінал")) ? "card" : ((DoAutoCash || InStr(paymentMethod, "Готівка")) ? "cash" : "")
        _payNoChange := (_payMode != "" && !(_payMode = "cash" && isPickup && !noPayChange && calcChange > 0)) ? 1 : 0
        if (!RhApplyPaymentUIA(_payMode, (_payMode = "cash" && isPickup && !noPayChange) ? calcChange : "", _payNoChange)) {
            Sleep, % SpDly(180)
            ; 1/4 — видалити поточний тип оплати (хрестик, приціл 8)
            if (crossX > 0 || crossRelX > 0)
                IikoClickRelV(crossRelX, crossRelY, crossX, crossY, "Оплата: видаляю тип")
            Sleep, % Max(250, SpDly(900))
            
            ; 2/4 — клік у клітинку «Тип оплати» (приціл 9) → відкриваємо редактор
            if (cashX > 0 || cashRelX > 0) {
                IikoClickRelV(cashRelX, cashRelY, cashX, cashY, "Оплата: тип оплати")
                Sleep, % Max(100, SpDly(250))
                IikoClickRelV(cashRelX, cashRelY, cashX, cashY, "Оплата: тип оплати")
                Sleep, % Max(180, SpDly(600))
            }
            
            ; 3/4 — ДРУКУЄМО слово пошуку → Enter обирає
            if (_paySearch != "") {
                _ttGx := 30, _ttGy := 30
                ToolTip, % "Оплата: друкую «" . _paySearch . "»", %_ttGx%, %_ttGy%
                Send, %_paySearch%
                Sleep, % Max(120, SpDly(450))
                Send, {Enter}
                Sleep, % Max(180, SpDly(550))
            }

            ; 4/4 — Сдача або Без сдачи
            if (isPickup && !noPayChange && (DoAutoCash || (!DoAutoCard && InStr(paymentMethod, "Готівка"))) && calcChange > 0 && (changeX > 0 || changeRelX > 0)) {
                ; Тільки самовивіз + готівка -> вводимо здачу
                IikoClickRelV(changeRelX, changeRelY, changeX, changeY, "Оплата: вводжу решту", 1)
                Sleep, % SpDly(100)
                Send, %calcChange%
                Sleep, % SpDly(100)
                Send, {NumpadEnter}
                Sleep, % SpDly(180)
            } else if (_payNoChange && (noChangeX > 0 || noChangeRelX > 0)) {
                ; Доставка, картка або готівка без реальної решти -> Без сдачи
                IikoClickRelV(noChangeRelX, noChangeRelY, noChangeX, noChangeY, "Оплата: Без сдачи")
                Sleep, % SpDly(180)
            }
        }
        ToolTip
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
    if (!RhUiaClickFirstOrderRow())
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
    if (WinActive("СИВ (Модуль)") || WinActive("Налаштування RollHouse") || WinActive("Вихідний текст"))
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


RestartPythonServer:
    ToolTip, Перезапускаю сервер...
    SetTimer, RemoveToolTip, -2000
    _serverDir := APP_DIR . "\..\server"
    Run, cmd /c start.bat, %_serverDir%, Hide
    Sleep, 2000
    if (RhPing())
        TrayTip, RollHouse, 🟢 Сервер успішно перезапущено!, 2, 1
    else
        TrayTip, RollHouse, ⚠️ Помилка: Сервер не відповідає, 3, 2
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

    report := "Ролл Хаус`n`nВСЬОГО: " . totalCount . " / " . totalSum . "`n`nБерестин: " . berCount . " / " . berSum . "`nМерефа: " . merCount . " / " . merSum . "`nЧугуїв: " . chCount . " / " . chSum
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
; - Кожен Space у будь-якому вікні (ки режим активний): вставити
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
    Hotkey, $x, CallManualGoodbye, On UseErrorLevel
    GoSub, ShowCallProgress
    GoSub, CallWarmListenServer
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
    global callList, callListCount, callListIdx, callNoAnswer, callDialing, callDuplicateCount
    callList := []
    callListIdx := 0
    callListCount := 0
    callDuplicateCount := 0
    callNoAnswer := 0
    callDialing := 0
    seenPhones := {}
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
            dedupKey := NormalizeCallPhoneKey(cleanNum)
            if (StrLen(cleanNum) >= 7 && dedupKey != "") {
                if (seenPhones.HasKey(dedupKey)) {
                    callDuplicateCount++
                    continue
                }
                seenPhones[dedupKey] := 1
                callList.Push(cleanNum)
            }
        }
        callListCount := callList.Length()
        return 1
    } catch e {
        MsgBox, 48, Обзвон, Помилка читання Excel:`n%e%
        return 0
    }
}

NormalizeCallPhoneKey(phone) {
    digits := RegExReplace(phone, "\D", "")
    len := StrLen(digits)
    if (len < 7)
        return ""
    if (len >= 12 && SubStr(digits, 1, 3) = "380")
        return SubStr(digits, 4)
    if (len = 10 && SubStr(digits, 1, 1) = "0")
        return SubStr(digits, 2)
    if (len >= 9) {
        startPos := len - 8
        return SubStr(digits, startPos)
    }
    return digits
}

; --- Міні-вікно прогресу обзвону ---
ShowCallProgress:
    RhApplyTheme()
    Gui, CallGui:Destroy
    Gui, CallGui:+AlwaysOnTop +ToolWindow -MaximizeBox
    Gui, CallGui:Color, 1a1a2a, %RhC_Panel%   ; тёмный фон постоянно (стани теж тёмні) — щоб текст не зникав
    Gui, CallGui:Add, Progress, x0 y0 w280 h42 -Theme c%RhC_Header%, 100
    Gui, CallGui:Add, Progress, x0 y0 w280 h3 -Theme c%RhC_Neon%, 100
    Gui, CallGui:Font, s10 bold c%RhC_HeaderText%, %RhFontName%
    Gui, CallGui:Add, Text, x10 y10 w260 Center +BackgroundTrans, 📞 РЕЖИМ ОБЗВОНУ
    Gui, CallGui:Font, s9 norm cAAB4C0, %RhFontName%
    hintLine := hkCallNext . " = наст  |  " . hkCallPause . " = пауза"
    if (hkCallHangup != "")
        hintLine .= "  |  " . hkCallHangup . " = покласти"
    Gui, CallGui:Add, Text, x10 y+4 w260 Center, %hintLine%
    ; Лічильник
    Gui, CallGui:Font, s11 bold cF0F4F8, %RhFontName%
    progressTxt := callListIdx . " з " . callListCount
    Gui, CallGui:Add, Text, x10 y+8 w260 Center vCallProgressLbl, %progressTxt%
    if (callDuplicateCount > 0) {
        Gui, CallGui:Font, s8 norm c9AA4B0, %RhFontName%
        Gui, CallGui:Add, Text, x10 y+2 w260 Center vCallDupLbl, % "дублі пропущено: " . callDuplicateCount
    }
    ; Поточний номер
    Gui, CallGui:Font, s13 bold c%RhC_Neon%, %RhFontName%
    Gui, CallGui:Add, Text, x10 y+4 w260 Center vCallCurrentNum, —
    ; Статус
    Gui, CallGui:Font, s10 norm cAAB4C0, %RhFontName%
    Gui, CallGui:Add, Text, x10 y+6 w260 Center vCallStatusLbl, ⏳ Очікування...
    ; CRM-бейдж клієнта
    Gui, CallGui:Font, s8 norm c9AA4B0, %RhFontName%
    Gui, CallGui:Add, Text, x10 y+4 w260 Center vCallCrmLbl, —
    ; Лічильник без відповіді
    Gui, CallGui:Font, s9 bold cFF6666, %RhFontName%
    Gui, CallGui:Add, Text, x10 y+4 w260 Center vCallNoAnswerLbl, 📵 Не відповіли: 0
    ; Пауза
    Gui, CallGui:Font, s10 bold c141A22, %RhFontName%
    Gui, CallGui:Add, Button, x10 y+10 w260 h30 vCallPauseBtn gCallPauseToggle, ⏸ ПАУЗА (відгук)
    Gui, CallGui:Font, s9 bold c141A22, %RhFontName%
    Gui, CallGui:Add, Button, x10 y+6 w125 h28 gCallDetectChannel, 🔊 Канал
    Gui, CallGui:Add, Button, x+10 yp w125 h28 gCallListenTest, 🎧 Тест
    Gui, CallGui:Add, Button, x10 y+6 w260 h28 gCallProbeLiveChannels, 🧪 Канал у дзвінку
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
        CallSetStatus("🟢 Розмова...", "39FF88", "0d3020")
    } else if (state = "paused") {
        Gui, CallGui:Color, 2e2000
        CallSetStatus("⏸ Пауза", "FFD166", "2e2000")
    } else if (state = "dialing") {
        Gui, CallGui:Color, 141428
        CallSetStatus("📲 Набираємо...", "8AB4FF", "141428")
    } else {
        Gui, CallGui:Color, 1a1a2a
        CallSetStatus("⏳ Очікування...", "AAB4C0", "1a1a2a")
    }
}

CallSetStatus(text, color := "AAB4C0", bg := "") {
    if (!WinExist("Обзвон"))
        return
    if (bg != "")
        Gui, CallGui:Color, %bg%
    GuiControl, CallGui:+c%color%, CallStatusLbl
    GuiControl, CallGui:, CallStatusLbl, %text%
}

CallSetInfo(text, color := "9AA4B0") {
    if (!WinExist("Обзвон"))
        return
    GuiControl, CallGui:+c%color%, CallCrmLbl
    GuiControl, CallGui:, CallCrmLbl, %text%
}

CallDecisionText(decision) {
    if (decision = "positive")
        return "Позитив"
    if (decision = "manual")
        return "Ручний режим"
    if (decision = "empty")
        return "Слова не прочитані"
    if (decision = "recorded")
        return "Записано"
    if (decision = "error")
        return "Помилка"
    return decision
}

CallReasonText(reason, peak := "") {
    if (InStr(reason, "text_empty"))
        return (peak != "" && peak >= 80) ? "звук був, але текст не розпізнано" : "канал тихий або клієнт мовчав"
    if (InStr(reason, "unknown"))
        return "немає впевненого позитиву"
    if (InStr(reason, "positive_short"))
        return "короткий позитив"
    if (InStr(reason, "positive_with_problem_tail"))
        return "є «але/крім» — потрібен оператор"
    if (InStr(reason, "positive_but_long"))
        return "довгий відгук — потрібен оператор"
    if (InStr(reason, "negative_or_problem"))
        return "можлива скарга"
    if (reason = "")
        return ""
    return "потрібна ручна перевірка"
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

CallListenTest:
    GoSub, CallDiagnosticGuardOn
    CallSetStatus("🎧 Тест слуху...", "8AB4FF", "141428")
    _deviceArg := ""
    if (callListenDevice > 0)
        _deviceArg := " --device " . callListenDevice
    _listenCmd := ComSpec . " /c cd /d """ . A_ScriptDir . """ && python ""tools\call_listener\call_listen_client.py""" . _deviceArg . " --engine " . callListenEngine . " --model " . callListenModel . " --language uk --prompt """ . callListenPrompt . """ --beam-size " . callListenBeamSize . " --until-silence --seconds 6 --start-timeout 4 --min-speech-seconds 1.1 --silence-seconds 0.75 --relative-silence-ratio 0.25 --max-speech-seconds 3.2 --rms-threshold " . callListenRmsThreshold . " --kind test"
    RunWait, %_listenCmd%, %A_ScriptDir%, Hide
    _listenIni := A_ScriptDir . "\data\call_listener\last_result.ini"
    if FileExist(_listenIni) {
        IniRead, _decision, %_listenIni%, CallListen, Decision,
        IniRead, _reason, %_listenIni%, CallListen, Reason,
        IniRead, _text, %_listenIni%, CallListen, Text,
        IniRead, _devIndex, %_listenIni%, CallListen, DeviceIndex,
        IniRead, _devName, %_listenIni%, CallListen, DeviceName,
        IniRead, _peakRms, %_listenIni%, CallListen, VadPeakRms, 0
        _testColor := (_decision = "positive") ? "39FF88" : ((_decision = "empty") ? "FFD166" : "AAB4C0")
        CallSetStatus("🎧 " . CallDecisionText(_decision), _testColor)
        _testInfo := "peak " . _peakRms . " · " . CallReasonText(_reason, _peakRms)
        if (_text != "")
            _testInfo := SubStr(_text, 1, 44)
        CallSetInfo(_testInfo)
    } else {
        CallSetStatus("❌ Тест не створив результат", "FF6666", "301818")
        CallSetInfo("перевір listener-сервер", "FFB4B4")
    }
    GoSub, CallDiagnosticGuardOff
return

CallProbeLiveChannels:
    GoSub, CallDiagnosticGuardOn
    CallSetStatus("🧪 Слухаю всі канали...", "8AB4FF", "141428")
    CallSetInfo("говорити має саме клієнт 8с", "9AA4B0")
    _probeCmd := ComSpec . " /c cd /d """ . A_ScriptDir . """ && python ""tools\call_listener\probe_live_call_channels.py"" --seconds 8 --prefer-name Gaming"
    RunWait, %_probeCmd%, %A_ScriptDir%, Hide
    _probeIni := A_ScriptDir . "\data\call_listener\live_channel_probe.ini"
    IniRead, _probeIndex, %_probeIni%, LiveProbe, BestIndex,
    IniRead, _probeName, %_probeIni%, LiveProbe, BestName,
    IniRead, _probePeak, %_probeIni%, LiveProbe, BestPeakRms, 0
    IniRead, _probeRms, %_probeIni%, LiveProbe, BestRms, 0
    if (_probeIndex != "" && _probeIndex != "ERROR" && _probePeak >= 80 && InStr(_probeName, "Gaming")) {
        CallSetStatus("✅ У дзвінку чутно [" . _probeIndex . "] peak " . _probePeak, "39FF88", "0d3020")
        CallSetInfo(SubStr(_probeName, 1, 42), "BEECCF")
    } else {
        CallSetStatus("🟡 Game не підтверджено · peak " . _probePeak, "FFD166", "2e2000")
        CallSetInfo("звіт: data\call_listener\live_channel_probe.txt", "FFB4B4")
    }
    GoSub, CallDiagnosticGuardOff
return

CallDetectChannel:
    GoSub, CallDiagnosticGuardOn
    CallSetStatus("🔊 Перевіряю канал...", "8AB4FF", "141428")
    CallSetInfo("увімкни звук на 3 сек", "9AA4B0")
    _detectCmd := ComSpec . " /c cd /d """ . A_ScriptDir . """ && python ""tools\call_listener\scan_loopbacks.py"" --seconds 3 --prefer-name Gaming"
    RunWait, %_detectCmd%, %A_ScriptDir%, Hide
    _scanIni := A_ScriptDir . "\data\call_listener\last_channel_scan.ini"
    IniRead, _devIndex, %_scanIni%, ChannelScan, BestIndex,
    IniRead, _devName, %_scanIni%, ChannelScan, BestName,
    IniRead, _peakRms, %_scanIni%, ChannelScan, BestPeakRms, 0
    if (_devIndex != "" && _devIndex != "ERROR" && _peakRms >= 80 && InStr(_devName, "Gaming")) {
        callListenDevice := _devIndex
        callListenRmsThreshold := Round(_peakRms * 0.45)
        if (callListenRmsThreshold < 12)
            callListenRmsThreshold := 12
        if (callListenRmsThreshold > 80)
            callListenRmsThreshold := 80
        IniWrite, %callListenDevice%, RkConfig.ini, CallListen, Device
        IniWrite, %callListenRmsThreshold%, RkConfig.ini, CallListen, RmsThreshold
        CallSetStatus("✅ Канал знайдено · peak " . _peakRms, "39FF88", "0d3020")
        CallSetInfo(SubStr(_devName, 1, 42), "BEECCF")
    } else {
        CallSetStatus("🟡 Game не знайдено · не зберіг", "FFD166", "2e2000")
        CallSetInfo("поточний бойовий канал лишився без змін", "FFB4B4")
    }
    GoSub, CallDiagnosticGuardOff
return

CallDiagnosticGuardOn:
    callDiagMode := 1
    callDiagWasPaused := callPaused
    callPaused := 1
    callAutoNext := 0
    SetTimer, WaitForCallEnd, Off
    SetTimer, AutoDialNext, Off
    SetTimer, WaitForTalkStart, Off
    SetTimer, CallAutoListenAfterGreeting, Off
    Hotkey, %hkCallNext%, CallNextNumber, Off UseErrorLevel
return

CallDiagnosticGuardOff:
    callPaused := callDiagWasPaused
    callDiagMode := 0
    if (callListMode && !callFrozen) {
        Hotkey, %hkCallNext%, CallNextNumber, On UseErrorLevel
        if (!callPaused) {
            if (callDialing)
                SetTimer, WaitForTalkStart, 500
            if (callAutoNext)
                SetTimer, WaitForCallEnd, 1000
        }
    }
return

CallWarmListenServer:
    _deviceArg := ""
    if (callListenDevice > 0)
        _deviceArg := " --device " . callListenDevice
    _warmEngineArg := (callListenEngine = "sherpa_stream") ? " --engine sherpa_stream" : ((callListenEngine = "sherpa") ? " --engine sherpa" : " --engine whisper --model base")
    _warmCmd := ComSpec . " /c cd /d """ . A_ScriptDir . """ && python ""tools\call_listener\call_listen_client.py""" . _warmEngineArg . " --warm-model-only"
    Run, %_warmCmd%, %A_ScriptDir%, Hide
return

CallStopMode:
CallGuiClose:
CallGuiEscape:
    callListMode := 0
    callFrozen := 0
    callAutoNext := 0
    callPaused := 0
    callDialing := 0
    callAutoListenBusy := 0
    callManualGoodbyeTick := 0
    SetTimer, WaitForCallEnd, Off
    SetTimer, AutoDialNext, Off
    SetTimer, WaitForTalkStart, Off
    SetTimer, CallAutoListenAfterGreeting, Off
    callAutoListenBusy := 0
    SetTimer, CallAutoListenAfterGreeting, Off
    Hotkey, %hkCallNext%, CallNextNumber, Off UseErrorLevel
    if (hkCallHangup != "")
        Hotkey, %hkCallHangup%, CallHangUp, Off UseErrorLevel
    if (hkCallPause != "")
        Hotkey, %hkCallPause%, CallPauseToggle, Off UseErrorLevel
    Hotkey, $x, CallManualGoodbye, Off UseErrorLevel
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
    Hotkey, $x, CallManualGoodbye, Off UseErrorLevel
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
    Hotkey, $x, CallManualGoodbye, On UseErrorLevel
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

CallLogEvent(event, details := "") {
    global callListIdx, callListCount, callList
    num := ""
    if (IsObject(callList) && callListIdx > 0 && callListIdx <= callListCount)
        num := callList[callListIdx]
    FileCreateDir, %A_ScriptDir%\data\call_listener
    line := A_Now . "`tidx=" . callListIdx . "/" . callListCount . "`tnum=" . num . "`tevent=" . event . "`t" . details . "`n"
    FileAppend, %line%, %A_ScriptDir%\data\call_listener\call_events.log, UTF-8
}

CallSafeFilePart(text) {
    text := RegExReplace(text, "[^\w\+\-]+", "_")
    text := RegExReplace(text, "_+", "_")
    return Trim(text, "_")
}

CallAppendOperatorLabel(reason := "manual_x") {
    global callListIdx, callListCount, callList, callLastArchiveId
    num := ""
    if (IsObject(callList) && callListIdx > 0 && callListIdx <= callListCount)
        num := callList[callListIdx]
    FileCreateDir, %A_ScriptDir%\data\call_listener\customer_calls
    labelLine := A_Now . "`tarchive_id=" . callLastArchiveId . "`tidx=" . callListIdx . "/" . callListCount . "`tnum=" . num . "`tlabel=operator_positive`treason=" . reason . "`n"
    FileAppend, %labelLine%, %A_ScriptDir%\data\call_listener\customer_calls\labels.tsv, UTF-8
}

CallArchiveCustomerResult(decision, reason, text, peak, speechMs, silenceMs, totalMs, deviceIndex, deviceName, operatorPositive := 0) {
    global callListIdx, callListCount, callList, callListenEngine, callListenAdvisorOnly, callLastArchiveId, callLastArchiveNum
    num := ""
    if (IsObject(callList) && callListIdx > 0 && callListIdx <= callListCount)
        num := callList[callListIdx]
    safeNum := CallSafeFilePart(num)
    if (safeNum = "")
        safeNum := "no_number"
    archiveId := A_Now . "_" . safeNum . "_idx" . callListIdx
    archiveDir := A_ScriptDir . "\data\call_listener\customer_calls"
    FileCreateDir, %archiveDir%
    FileCopy, %A_ScriptDir%\data\call_listener\last_call.wav, %archiveDir%\%archiveId%.wav, 1
    FileCopy, %A_ScriptDir%\data\call_listener\last_result.json, %archiveDir%\%archiveId%.json, 1
    FileCopy, %A_ScriptDir%\data\call_listener\last_result.txt, %archiveDir%\%archiveId%.txt, 1
    label := operatorPositive ? "operator_positive" : ((decision = "positive") ? "system_positive" : "unlabeled")
    labelLine := A_Now . "`tarchive_id=" . archiveId . "`tidx=" . callListIdx . "/" . callListCount . "`tnum=" . num . "`tlabel=" . label . "`tdecision=" . decision . "`treason=" . reason . "`tpeak=" . peak . "`tspeechMs=" . speechMs . "`tsilenceMs=" . silenceMs . "`ttotalMs=" . totalMs . "`tengine=" . callListenEngine . "`tadvisorOnly=" . callListenAdvisorOnly . "`tdevice=" . deviceIndex . "`tdeviceName=" . deviceName . "`ttext=" . SubStr(text, 1, 160) . "`n"
    FileAppend, %labelLine%, %archiveDir%\labels.tsv, UTF-8
    callLastArchiveId := archiveId
    callLastArchiveNum := num
    return archiveId
}

CallManualGoodbye:
    callManualGoodbyeTick := A_TickCount
    GuiControl, CallGui:, CallStatusLbl, 👤 X вручну — авто-X скасовано
    CallLogEvent("manual_x", "tick=" . callManualGoodbyeTick)
    CallAppendOperatorLabel("manual_x")
    Send, {x}
return

RemoveCallProgressTip:
    ToolTip, , , , 4
return

; --- Наступний дзвінок (вішається на hkCallNext тільки коли callListMode=1) ---
CallNextNumber:
    if (!callListMode)
        return
    if (callDiagMode)
        return
    ; Скидаємо авто-очікування та паузу
    callAutoNext := 0
    callPaused := 0
    callManualGoodbyeTick := 0
    callLastArchiveId := ""
    callLastArchiveNum := ""
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
        callWaitDeadline := A_TickCount + 25000
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
        CallLogEvent("accept_talk", "key=" . hkAcceptTalk . "`tgreetingDelayMs=" . callGreetingDelayMs)
        callDialing := 0   ; відповіли — більше не "без відповіді"
        callManualGoodbyeTick := 0
        UpdateCallGuiState("talking")
        if (callListenEnabled) {
            _autoListenDelay := 0 - callGreetingDelayMs
            SetTimer, CallAutoListenAfterGreeting, %_autoListenDelay%
        }
        ; --- АВТО-ПЕРЕХІД: запускаємо моніторинг кінця розмови ---
        if (FileExist("img\call_end.png")) {
            callAutoNext := 1
            SetTimer, WaitForCallEnd, 1000
        }
    } else {
        secLeft := Round((callWaitDeadline - A_TickCount) / 1000)
        GuiControl, CallGui:, CallStatusLbl, % "⏳ Чекаю розмову... " . secLeft . "с"
    }
return

RemoveTalkTip:
    ToolTip, , , , 5
return

CallAutoListenAfterGreeting:
    if (!callListenEnabled || !callListMode || callPaused || callFrozen)
        return
    if (callAutoListenBusy)
        return
    callAutoListenBusy := 1
    SetTimer, WaitForCallEnd, Off
    SetTimer, AutoDialNext, Off
    if (hkCallNext != "")
        Hotkey, %hkCallNext%, CallNextNumber, Off UseErrorLevel
    _listenStartTick := A_TickCount
    CallLogEvent("listen_start", "engine=" . callListenEngine . "`tadvisorOnly=" . callListenAdvisorOnly . "`tmodel=base`tthreshold=" . callListenRmsThreshold)
    CallSetStatus("🎧 Слухаю клієнта...", "8AB4FF", "141428")
    _deviceArg := ""
    if (callListenDevice > 0)
        _deviceArg := " --device " . callListenDevice
    _listenSeconds := (callListenEngine = "sherpa_stream") ? "7" : "5"
    _listenStartTimeout := (callListenEngine = "sherpa_stream") ? "4.8" : "3.5"
    _listenMinSpeech := (callListenEngine = "sherpa_stream") ? "0.6" : "1.1"
    _listenSilence := (callListenEngine = "sherpa_stream") ? "0.55" : "0.75"
    _listenMaxSpeech := (callListenEngine = "sherpa_stream") ? "3.4" : "3.2"
    _encPrompt := RcUriEncode(callListenPrompt)
    _listenUrl := "http://127.0.0.1:8765/listen?device=" . callListenDevice . "&engine=" . callListenEngine . "&model=" . callListenModel . "&language=uk&prompt=" . _encPrompt . "&beam_size=" . callListenBeamSize . "&until_silence=1&seconds=" . _listenSeconds . "&start_timeout=" . _listenStartTimeout . "&min_speech_seconds=" . _listenMinSpeech . "&silence_seconds=" . _listenSilence . "&relative_silence_ratio=0.25&max_speech_seconds=" . _listenMaxSpeech . "&rms_threshold=" . callListenRmsThreshold . "&kind=customer"
    _listenCmd := ComSpec . " /c curl.exe -fsS """ . _listenUrl . """ >nul"
    RunWait, %_listenCmd%, %A_ScriptDir%, Hide
    if (ErrorLevel) {
        CallLogEvent("listen_curl_failed", "errorLevel=" . ErrorLevel)
        _listenCmd := ComSpec . " /c cd /d """ . A_ScriptDir . """ && python ""tools\call_listener\call_listen_client.py""" . _deviceArg . " --engine " . callListenEngine . " --model " . callListenModel . " --language uk --prompt """ . callListenPrompt . """ --beam-size " . callListenBeamSize . " --until-silence --seconds " . _listenSeconds . " --start-timeout " . _listenStartTimeout . " --min-speech-seconds " . _listenMinSpeech . " --silence-seconds " . _listenSilence . " --relative-silence-ratio 0.25 --max-speech-seconds " . _listenMaxSpeech . " --rms-threshold " . callListenRmsThreshold . " --kind customer"
        RunWait, %_listenCmd%, %A_ScriptDir%, Hide
    }
    _listenIni := A_ScriptDir . "\data\call_listener\last_result.ini"
    FileCopy, %A_ScriptDir%\data\call_listener\last_result.ini, %A_ScriptDir%\data\call_listener\last_customer_result.ini, 1
    FileCopy, %A_ScriptDir%\data\call_listener\last_result.txt, %A_ScriptDir%\data\call_listener\last_customer_result.txt, 1
    FileCopy, %A_ScriptDir%\data\call_listener\last_result.json, %A_ScriptDir%\data\call_listener\last_customer_result.json, 1
    FileCopy, %A_ScriptDir%\data\call_listener\last_call.wav, %A_ScriptDir%\data\call_listener\last_customer_call.wav, 1
    IniRead, _decision, %_listenIni%, CallListen, Decision,
    IniRead, _reason, %_listenIni%, CallListen, Reason,
    IniRead, _text, %_listenIni%, CallListen, Text,
    IniRead, _vadReason, %_listenIni%, CallListen, VadReason,
    IniRead, _speechMs, %_listenIni%, CallListen, VadSpeechMs,
    IniRead, _silenceMs, %_listenIni%, CallListen, VadSilenceMs,
    IniRead, _peakRms, %_listenIni%, CallListen, VadPeakRms, 0
    IniRead, _devIndex, %_listenIni%, CallListen, DeviceIndex,
    IniRead, _devName, %_listenIni%, CallListen, DeviceName,
    _listenTotalMs := A_TickCount - _listenStartTick
    CallLogEvent("listen_done", "totalMs=" . _listenTotalMs . "`tdecision=" . _decision . "`treason=" . _reason . "`tspeechMs=" . _speechMs . "`tsilenceMs=" . _silenceMs . "`tpeak=" . _peakRms . "`ttext=" . SubStr(_text, 1, 80))
    _operatorPositive := (callManualGoodbyeTick > 0) ? 1 : 0
    _archiveId := CallArchiveCustomerResult(_decision, _reason, _text, _peakRms, _speechMs, _silenceMs, _listenTotalMs, _devIndex, _devName, _operatorPositive)
    CallLogEvent("customer_archived", "archiveId=" . _archiveId . "`toperatorPositive=" . _operatorPositive)
    if (_decision = "positive") {
        if (callManualGoodbyeTick > 0) {
            CallSetStatus("✅ Позитив · X вже натиснуто", "39FF88", "0d3020")
            CallSetInfo(SubStr(_text, 1, 48), "BEECCF")
            CallLogEvent("auto_positive_skipped_manual_x", "reason=" . _reason . "`ttext=" . SubStr(_text, 1, 80))
            SetTimer, RemoveCallProgressTip, -2500
            goto, CallAutoListenCleanup
        }
        CallSetInfo(SubStr(_text, 1, 48), "BEECCF")
        if (callListenAdvisorOnly) {
            CallSetStatus("💡 Позитив · натисни X", "39FF88", "0d3020")
            CallLogEvent("advisor_positive", "engine=" . callListenEngine . "`treason=" . _reason . "`ttext=" . SubStr(_text, 1, 80))
            SetTimer, RemoveCallProgressTip, -2500
            goto, CallAutoListenCleanup
        }
        CallSetStatus("✅ Позитив → прощання X", "39FF88", "0d3020")
        CallLogEvent("auto_x", "reason=" . _reason . "`ttext=" . SubStr(_text, 1, 80))
        Send, {x}
        Sleep, 3500
        CallSetStatus("👂 Чекаю тишу після X...", "8AB4FF", "141428")
        _byeCmd := ComSpec . " /c cd /d """ . A_ScriptDir . """ && python ""tools\call_listener\call_listen_client.py""" . _deviceArg . " --model tiny --until-silence --seconds 3 --start-timeout 1 --min-speech-seconds 0.4 --silence-seconds 1.0 --relative-silence-ratio 0.25 --rms-threshold " . callListenRmsThreshold . " --no-transcribe --kind bye"
        RunWait, %_byeCmd%, %A_ScriptDir%, Hide
        IniRead, _byeVad, %_listenIni%, CallListen, VadReason,
        IniRead, _byeSpeech, %_listenIni%, CallListen, VadSpeechMs,
        _canHangupTest := 0
        if (_byeVad = "start_timeout")
            _canHangupTest := 1
        if (_byeVad = "silence_after_speech")
            _canHangupTest := 1
        if (_canHangupTest) {
            CallSetStatus("✅ Можна класти трубку", "39FF88", "0d3020")
        } else {
            CallSetStatus("⚠️ Після X є звук", "FFD166", "2e2000")
        }
    } else if (_decision = "empty" && _vadReason = "start_timeout") {
        CallSetStatus("🟡 Не дочекався відповіді", "FFD166", "2e2000")
        CallSetInfo("можливо старт слуху був пізно · якщо відповів — вручну", "FFE0A3")
    } else if (_decision = "empty" && _peakRms < 80) {
        CallSetStatus("🔇 Не чую клієнта · peak " . _peakRms, "FF6666", "301818")
        CallSetInfo("натисни 🔊 Канал або перевір звук", "FFB4B4")
    } else if (_decision = "empty") {
        CallSetStatus("🟡 Слова не прочитані", "FFD166", "2e2000")
        CallSetInfo("звук є · " . CallReasonText(_reason, _peakRms) . " · peak " . _peakRms, "FFE0A3")
    } else {
        CallSetStatus("👤 Ручний режим", "FFD166", "2e2000")
        _manualInfo := CallReasonText(_reason, _peakRms)
        if (_text != "")
            _manualInfo := SubStr(_text, 1, 48)
        CallSetInfo(_manualInfo, "FFE0A3")
    }
CallAutoListenCleanup:
    callAutoListenBusy := 0
    if (callListMode && !callFrozen && hkCallNext != "")
        Hotkey, %hkCallNext%, CallNextNumber, On UseErrorLevel
    if (callListMode && callAutoNext && !callPaused && !callFrozen)
        SetTimer, WaitForCallEnd, 1000
    SetTimer, RemoveCallProgressTip, -3500
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
    _kmlDst := A_ScriptDir . "\brands\" . BRAND . "\zones.kml"
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
    global streetText, isPickup, RcZones, RcZonesOk, deliveryCostNum, deliveryCostStr, orderSum, totalSum, BRAND
    SetTimer, RcCheckZone, Off

    ; Зона вже знайдена по назві (текстовий пошук по DeliveryPrices.ini, крок 7
    ; вище, ~96% влучань) — не лізти в Nominatim заради самого лише індикатора
    ; на екрані. Раніше цей індикатор ліз у мережу БЕЗУМОВНО і показував
    ; "не знайдено", навіть коли ціна вже правильно визначена — оператор бачив
    ; тривожний ❓ і думав, що нічого не спрацювало.
    if (deliveryCostNum > 0) {
        GuiControl, Roll:, MapSearch, % "📍 " . deliveryCostStr
        return
    }

    FileAppend, % "[" A_Now "] ZONEDBG START street=[" streetText "] pickup=" isPickup " brand=" BRAND " zonesOk=" RcZonesOk "`n", %A_ScriptDir%\ahk_debug.log
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
            FileAppend, % "[" A_Now "] ZONEDBG NET-FAIL addr=[" a "]`n", %A_ScriptDir%\ahk_debug.log
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
        FileAppend, % "[" A_Now "] ZONEDBG NOT-FOUND addr=[" addr "] resp=[" SubStr(resp,1,90) "]`n", %A_ScriptDir%\ahk_debug.log
        GuiControl, Roll:, MapSearch, ❓ Адресу не знайдено
        return
    }

    lat += 0
    lng += 0
    FileAppend, % "[" A_Now "] ZONEDBG GEO-OK addr=[" addr "] lat=" lat " lng=" lng " zonesOk=" RcZonesOk " count=" RcZones.MaxIndex() "`n", %A_ScriptDir%\ahk_debug.log

    ; Завантажити KML якщо ще не завантажено (кеш зберігається до перезапуску)
    kmlPath := A_ScriptDir "\brands\" . BRAND . "\zones.kml"
    if (!RcZonesOk && FileExist(kmlPath))
        RcLoadKml(kmlPath)

    ; Визначення зони
    if (RcZonesOk && RcZones.MaxIndex() > 0) {
        z := RcFindZone(lng, lat)
        if (IsObject(z)) {
            result := "📍 " . z.name
            ; ЦІНА З KML-гео — тільки якщо name-match нічого не знайшов (name-match надійніший, 96%)
            if (z.price > 0 && deliveryCostNum <= 0) {
                deliveryCostNum := z.price
                deliveryCostStr := "Доставка " . z.name . " - " . z.price . " грн"
                totalSum := orderSum + deliveryCostNum
                GuiControl, Roll:, RhTotalLbl, % totalSum . " грн"
                ; оновити коментар: замінити стару "Доставка ... грн" або вставити нашу
                GuiControlGet, _oc, Roll:, OrderComment
                if (RegExMatch(_oc, "i)Доставк[а-яіїєґ]*\s+[^|\r\n]+?-\s*\d+\s*грн"))
                    _oc := RegExReplace(_oc, "i)Доставк[а-яіїєґ]*\s+[^|\r\n]+?-\s*\d+\s*грн", deliveryCostStr)
                else
                    _oc := deliveryCostStr . " | " . _oc
                GuiControl, Roll:, OrderComment, %_oc%
            }
        } else {
            result := "⚠️ Поза зонами доставки"
        }
    } else {
        ; KML немає або порожній — показуємо display_name з геокодера
        if RegExMatch(resp, """display_name"":""([^""]+)""", mD)
            result := "📍 " . SubStr(mD1, 1, 55)
        else
            result := "📍 " . lat . ", " . lng
    }

    if (deliveryCostNum > 0 && result != "⚠️ Поза зонами доставки")
        result .= " (" . deliveryCostNum . " грн)"

    FileAppend, % "[" A_Now "] ZONEDBG RESULT result=[" result "] deliveryCostNum=" deliveryCostNum "`n", %A_ScriptDir%\ahk_debug.log
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
    global RcZones, RcZonesOk, BRAND
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
        
        ; Ціна + відсічка часу з опису зони (перше число = ціна; "до HH:MM" = відсічка)
        zPrice := 0, zCut := ""
        try {
            descNode := pm.selectSingleNode(".//k:description")
        } catch {
            descNode := pm.getElementsByTagName("description").item(0)
        }
        if (descNode) {
            dTxt := descNode.text
            if RegExMatch(dTxt, "(\d+)", _mP)
                zPrice := _mP1 + 0
            if RegExMatch(dTxt, "i)до\s*(\d{1,2}:\d{2})", _mC)
                zCut := _mC1
        }
        if (coords.MaxIndex() >= 3) {
            RcZones.Push({name: zoneName, coords: coords, price: zPrice, cutoff: zCut})
        }
    }

    if (RcZones.MaxIndex() > 0) {
        RcZonesOk := 1
    } else {
        RcZonesOk := 0
    }

    ; ── ФОЛБЕК = ЕТАЛОН: перегенерувати DeliveryPrices.ini з KML при кожному завантаженні ──
    ; Так таблиця name-match ЗАВЖДИ відповідає KML. Якщо KML не завантажився — не чіпаємо (щоб не втратити старе).
    if (RcZonesOk) {
        _dp := ""
        _seen := {}
        for i, z in RcZones {
            if (z.price + 0 <= 0)
                continue
            _n := RegExReplace(z.name, "\(.*?\)", "")
            _n := RegExReplace(_n, "i)^\s*(с|м|смт)\.\s*", "")
            _n := RegExReplace(_n, ",.*$", "")
            for _, _alt in StrSplit(_n, "/") {
                _alt := Trim(_alt)
                if (StrLen(_alt) < 3)
                    continue
                if (!_seen.HasKey(_alt)) {
                    _seen[_alt] := 1
                    _dp .= _alt . "=" . z.price . "`n"
                }
            }
        }
        if (_dp != "") {
            _dpPath := A_ScriptDir . "\brands\" . BRAND . "\DeliveryPrices.ini"
            FileDelete, %_dpPath%
            FileAppend, %_dp%, %_dpPath%, UTF-8
        }
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
            return z
    }
    return ""
}

  














ExitRoutine:
    killCmd := "wmic process where \""name='pythonw.exe' and commandline like '%app.py%'\"" call terminate"
    Run, %ComSpec% /c "%killCmd%", , Hide
    ExitApp




    IfWinExist, MicroSIP Assistant
    {
        WinActivate
        Run, C:\Users\voffk\AppData\Local\Programs\Python\Python313\python.exe "%A_ScriptDir%\tools\call_listener\udp_trigger.py" EXCEL_LOAD
    }
    else
    {
        Run, C:\Users\voffk\AppData\Local\Programs\Python\Python313\python.exe "%A_ScriptDir%\tools\call_listener\microsip_assistant.py", %A_ScriptDir%
    }
return



^F6::
    IfWinExist, MicroSIP Assistant
    {
        WinActivate
        Run, C:\Users\voffk\AppData\Local\Programs\Python\Python313\python.exe "%A_ScriptDir%\tools\call_listener\udp_trigger.py" EXCEL_LOAD,, Hide
    }
    else
    {
        Run, C:\Users\voffk\AppData\Local\Programs\Python\Python313\python.exe "%A_ScriptDir%\tools\call_listener\microsip_assistant.py", %A_ScriptDir%
        WinWait, MicroSIP Assistant,, 15
        if (ErrorLevel = 0)
        {
            WinActivate
            Sleep, 1500
            Run, C:\Users\voffk\AppData\Local\Programs\Python\Python313\python.exe "%A_ScriptDir%\tools\call_listener\udp_trigger.py" EXCEL_LOAD,, Hide
        }
    }
return



; --- АВТО-ВЗЯТИЕ ЗАКАЗОВ (ПЕРЕНЕСЕНО С ROLLCLUB) ---
global dutyOn := 0
global kcStop := 0
global kcBusy := 0
global kcTook := 0
global kcForce := 0
global kcPaused := 0
global _punchUntil := 0
global _inDutyTake := 0
global rhPunchBusy := 0
global AUTO_KC_ENABLED := 1
global autoMode := 1

IniRead, poiskX, RkConfig.ini, Targets, PoiskX, 0
IniRead, poiskY, RkConfig.ini, Targets, PoiskY, 0
IniRead, rowX,   RkConfig.ini, Targets, RowX,   0
IniRead, rowY,   RkConfig.ini, Targets, RowY,   0

^F4::GoSub, KcDutyToggle

KcDutyToggle:
    OpCoord_Event("DutyScanning", "toggle", "KcDutyToggle", "was_dutyOn=" . dutyOn . ";punchBusy=" . rhPunchBusy . ";inDutyTake=" . _inDutyTake)
    ; Ctrl+F4: дежурство — сам ловить перший вільний годний заказ, бере і зупиняється з гучним сигналом
    FileAppend, % "[" . A_Now . "] Ctrl+F4-TOGGLE (was dutyOn=" . dutyOn . ")`n", %A_ScriptDir%\parse_debug.log
    if (rhPunchBusy || _inDutyTake)
    {
        dutyOn := 0
        kcStop := 1
        SetTimer, KcDutyTick, Off
        SetTimer, KcMonitor, Off
        FileAppend, % "[" . A_Now . "] Ctrl+F4 BLOCKED — punchBusy=" . rhPunchBusy . " inTake=" . _inDutyTake . "`n", %A_ScriptDir%\parse_debug.log
        ToolTip, Ctrl+F4 заблоковано: йде пробиття
        SetTimer, RemoveToolTip, -1500
        return
    }
    if (A_TickCount < _punchUntil)
    {
        FileAppend, % "[" . A_Now . "] Ctrl+F4 IGNORED — під час пробиття (спрацював не фізичний Ctrl+F4?)`n", %A_ScriptDir%\parse_debug.log
        return
    }
    dutyOn := !dutyOn
    if (dutyOn)
    {
        kcStop := 0
        kcTook := 0
        ToolTip, ⏳ Дежурю по заказах... (Ctrl+F4 — стоп)
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
        SoundPlay, *-1
    }
return

LoudAlarm:
    Loop, 6
    {
        SoundPlay, *-1
        Sleep, 10
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
        ToolTip, Ctrl+F4: вікно РК (Syrve Office) не знайдено — відкрий Доставки
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
    Send, ^{Tab}                   ; ОНОВИТИ СПИСОК (перемкнути вкладку туди-сюди)
    Sleep, 300
    Send, ^+{Tab}
    Sleep, 600
    ; 1) список свіжий — тепер питаємо сервер (+ серверний таймінг у bridge.log)
    if (kcStop)
    {
        kcBusy := 0
        ToolTip, Стоп (Ctrl+F4)
        SetTimer, RemoveToolTip, -1500
        return
    }
    ; 2) список свіжий — тепер питаємо сервер (+ серверний таймінг у bridge.log)
    ToolTip, Ctrl+F4: питаю сервер про годний заказ...
    listResp := RhGet("/api/iiko/kc-list?brand=rollhouse", 12000)
    if InStr(listResp, "ACTIVE_ORDER_CARD")
    {
        ToolTip, Ctrl+F4: активна карточка — переходжу на Доставки...
        Send, {Esc}
        Sleep, 180
        Send, ^{Tab}
        Sleep, 700
        listResp := RhGet("/api/iiko/kc-list?brand=rollhouse", 12000)
    }
    if InStr(listResp, "ACTIVE_ORDER_CARD")
    {
        kcBusy := 0
        ToolTip, Ctrl+F4: досі карточка заказа — відкрий вкладку Доставки
        SetTimer, RemoveToolTip, -6000
        return
    }
    Sleep, 30                       ; дати шанс Ctrl+F4-стопу під час блокуючого запиту
    if (kcStop)
    {
        kcBusy := 0
        ToolTip, Стоп (Ctrl+F4) — заказ не чіпаю
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
        ToolTip, % "Ctrl+F4: нема вільних для взяття`n" . _reason
        SetTimer, RemoveToolTip, -8000
        kcBusy := 0
        return
    }
    ToolTip, Ctrl+F4: беру заказ №%takeNo%...
    ; 3) тільки зараз можна чіпати поле Поиск: сервер підтвердив, що активний список Доставки.

    if (kcStop || rhPunchBusy)
    {
        kcBusy := 0
        ToolTip, Стоп (Ctrl+F4) — заказ не чіпаю
        SetTimer, RemoveToolTip, -1500
        return
    }
    ; --- capture: Poisk -> open first row ---
    if (RhUiaSetValue("ФільтрНомера", takeNo))
    {
        ToolTip, Ctrl+F4: ввів номер %takeNo% через WinAPI
        Sleep, 600
    }
    else if (poiskX != 0)
    {
        Click, %poiskX%, %poiskY%
        Sleep, 200
        Send, ^a
        Sleep, 50
        Send, {Delete}          ; примусово стерти старий № перед вводом
        Sleep, 80
        SendInput, %takeNo%
        Sleep, 800
    }
    ; --- ПЕРЕВІРКА перед пробиттям: список має звузитись РІВНО до нашого № ---
    ; якщо ні (ми не на Доставках / фільтр не спрацював) — НЕ пробиваємо, пропускаємо цей круг.
    _chk := RhGet("/api/iiko/kc-list?brand=rollhouse", 6000)
    _cnt := ""
    RegExMatch(_chk, "count""\s*:\s*(\d+)", _cM)
    _cnt := _cM1
    if (_cnt != "1" || !InStr(_chk, takeNo))
    {
        ToolTip, % "Ctrl+F4: список не звузився до №" . takeNo . " — НЕ пробиваю (не на Доставках?)"
        SetTimer, RemoveToolTip, -5000
        kcBusy := 0
        return
    }
    ToolTip                     ; прибрати підказку — вона перекривала рядок, клік потрапляв у неї
    Sleep, 60
    if (kcStop)
    {
        kcBusy := 0
        ToolTip, Стоп (Ctrl+F4) — заказ не відкриваю
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
        ToolTip, Стоп (Ctrl+F4) — не пробиваю
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
    ; 1) Натискаємо Enter
    Send, {Enter}
    Sleep, 800
    ; 2) Натискаємо кнопку Дзвонити в Aiko/MicroSIP (за координатами)
    if (aikoCallX != 0 && aikoCallX != "ERROR")
    {
        Click, %aikoCallX%, %aikoCallY%
        Sleep, 500
    }
    _inDutyTake := 0
    Sleep, 500
    SoundPlay, *-1
    kcTook := 1
    ToolTip, ✅ ВЗЯВ №%takeNo% — перевір і натисни Ctrl+Enter
    SetTimer, RemoveToolTip, -15000
    kcPaused := 1
    kcBusy := 0
return



; ══════════════════════════════════════════════════════════════
;  WINAPI SCANNER LOGIC
; ══════════════════════════════════════════════════════════════

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
        _name := Trim(_pair[1])
        _id := Trim(_pair[2])
        LV_Add("", _name, _id)
    }
return

UiaListClick:
    if (A_GuiEvent = "DoubleClick") {
        GoSub, DeleteSelectedUiaBinding
    }
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
    MsgBox, 292, Видалення WinAPI елемента, Видалити прив'язку?`n`nРоль: %_delName%`nID: %_delValue%`n`nВона буде прибрана з RkConfig.ini і більше не використовуватиметься AHK.
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
    MsgBox, 64, Видалено, Прив'язку "%_delName%" повністю видалено.
return

LaunchScanner:
    Gui, Settings:Hide
    Sleep, 200
    MsgBox, 4160, WinAPI Сканер, Сканер активовано!`n`nНаведіть мишу на потрібну кнопку в iiko/Syrve і натисніть ліву кнопку миші (клік).
    
    ; Чекаємо кліку миші
    KeyWait, LButton, Down
    MouseGetPos, _mx, _my, _mHwnd
    
    ; Використовуємо UIA_Interface для зчитування
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
            MsgBox, 48, Помилка, Не вдалося знайти AutomationId або Name для цього елемента.
            Gui, Settings:Show
            return
        }
        
        InputBox, _newName, Збереження WinAPI елемента, Знайдено елемент: %_saveVal%`n`nВведіть назву (роль) для цього елемента (напр. 'Коментар', 'КнопкаПодзвонити'):,,,,,,,,
        if (ErrorLevel = 0 && _newName != "") {
            IniWrite, %_saveVal%, %UIA_MAP_CONFIG%, UiaMap, %_newName%
            MsgBox, 64, Збережено, Елемент "%_newName%" успішно збережено як "%_saveVal%".
        }
    } catch _ex {
        MsgBox, 48, Помилка UIA, Сталася помилка при зчитуванні елемента:`n%_ex%
    }
    
    GoSub, OpenSettings
return

; --- Restored Aiko/Call Targets ---
SetAikoInputTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в поле номера.
    KeyWait, LButton, Down
    MouseGetPos, aikoInputX, aikoInputY
    IniWrite, %aikoInputX%, RkConfig.ini, Targets, AikoInputX
    IniWrite, %aikoInputY%, RkConfig.ini, Targets, AikoInputY
    Gui, Settings:Show
return

SetAikoCallTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в кнопку Дзвонити.
    KeyWait, LButton, Down
    MouseGetPos, aikoCallX, aikoCallY
    IniWrite, %aikoCallX%, RkConfig.ini, Targets, AikoCallX
    IniWrite, %aikoCallY%, RkConfig.ini, Targets, AikoCallY
    Gui, Settings:Show
return

SetAikoHangupTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в кнопку Покласти трубку.
    KeyWait, LButton, Down
    MouseGetPos, aikoHangupX, aikoHangupY
    IniWrite, %aikoHangupX%, RkConfig.ini, Targets, AikoHangupX
    IniWrite, %aikoHangupY%, RkConfig.ini, Targets, AikoHangupY
    Gui, Settings:Show
return

SetCallTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в кнопку Автоприйом вхідного.
    KeyWait, LButton, Down
    MouseGetPos, callX, callY
    IniWrite, %callX%, RkConfig.ini, Targets, CallX
    IniWrite, %callY%, RkConfig.ini, Targets, CallY
    Gui, Settings:Show
return

SetCallEndTarget:
    Gui, Settings:Hide
    Sleep, 300
    MsgBox, 4160, Налаштування, Клікни в зону кінця дзвінка.
    KeyWait, LButton, Down
    MouseGetPos, callEndX, callEndY
    IniWrite, %callEndX%, RkConfig.ini, Targets, CallEndX
    IniWrite, %callEndY%, RkConfig.ini, Targets, CallEndY
    Gui, Settings:Show
return
