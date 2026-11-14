; Ctrl+F4 for a minimized Syrve. Never use screen input in this file.
; UIA objects belong to the main AHK process; the module marker starts no worker.

RcDutyBgHwnd() {
    ; Deliberately do not use the generic driver's foreground-window fallback.
    WinGet, windows, List, ahk_exe BackOffice.exe
    found := 0
    Loop, %windows% {
        hwnd := windows%A_Index%
        WinGetTitle, title, ahk_id %hwnd%
        if (!RegExMatch(title, "i)(syrve|iiko).*office"))
            continue
        if (found)
            return -1  ; ambiguous: never guess between two offices
        found := hwnd
    }
    return RcDutyBgHandleNumber(found)
}

RcDutyBgHandleNumber(hwnd) {
    ; WinGet returns hexadecimal strings; the HTTP/JSON contract is decimal.
    return Format("{:d}", hwnd + 0)
}

RcDutyBgLog(event, detail := "") {
    FileAppend, % "[" . A_Now . "] " . event . " " . detail . "`n", %A_ScriptDir%\rollclub_duty_background.log, UTF-8
}

RcDutyBgCheck(hwnd) {
    global kcStop, dutyOn, rhPunchBusy, _inDutyTake
    global RcDutyBgGeneration, RcDutyBgRunGeneration, RcDutyBgWasMinimized
    Sleep, -1  ; dispatch a pending stop/manual hotkey before the next UIA action
    if (kcStop || !dutyOn || rhPunchBusy || _inDutyTake || RcDutyBgGeneration != RcDutyBgRunGeneration)
        throw Exception("STOP")
    if (!DllCall("IsWindow", "Ptr", hwnd))
        throw Exception("Вікно Syrve закрито. Запустіть його знову.")
    WinGet, state, MinMax, ahk_id %hwnd%
    if (state = -1)
        RcDutyBgWasMinimized := true
    else if (RcDutyBgWasMinimized)
        throw Exception("Syrve було розгорнуто. Фонове дежурство зупинено.")
}

RcDutyBgWait(hwnd, milliseconds) {
    end := A_TickCount + milliseconds
    while (A_TickCount < end) {
        RcDutyBgCheck(hwnd)
        Sleep, 30
    }
    RcDutyBgCheck(hwnd)
}

RcDutyBgFindId(root, id, maxDepth := 12, ByRef budget := "") {
    if (budget = "")
        budget := 800
    if (!IsObject(root) || maxDepth < 0 || budget-- <= 0)
        return ""
    aid := root.CurrentAutomationId
    if (aid = id)
        return root
    ; Never walk delivery rows while searching the surrounding application UI.
    if (aid = "gridDeliveries")
        return ""
    for _, child in root.FindAllBy("TrueCondition", 2) {
        if IsObject(found := RcDutyBgFindId(child, id, maxDepth - 1, budget))
            return found
    }
    return ""
}

RcDutyBgValue(element) {
    for _, patternName in ["Value", "LegacyIAccessible"] {
        try {
            value := Trim(element.GetCurrentPatternAs(patternName).CurrentValue)
            if (value != "")
                return value
        }
    }
    return ""
}

RcDutyBgRow(panel, orderNo) {
    ; Reacquire rows each time: filtering/refresh changes row identities.
    for _, row in panel.FindAllBy("TrueCondition", 2) {
        name := row.CurrentName
        if RegExMatch(name, "i)(фильтр|фільтр|filter|заголов|header|scroll|скролл)")
            continue
        for _, cell in row.FindAllBy("TrueCondition", 2) {
            column := RegExReplace(cell.CurrentName, "i) (row|рядок|строка) .*", "")
            if (!RegExMatch(column, "i)^(№|номер|number)"))
                continue
            ; Exact equality, not substring matching against JSON or row names.
            if (RcDutyBgValue(cell) == orderNo)
                return {row: row, cell: cell}
        }
    }
    return ""
}

RcDutyBgInvoke(element) {
    ; Selection alone does not open an order. Do not use generic Click(), which
    ; may select rather than open a grid row. Never fall back to screen clicks.
    if (!element.CurrentIsEnabled)
        return false
    try {
        pattern := element.GetCurrentPatternAs("Invoke")
        if IsObject(pattern) {
            if (pattern.Invoke())
                return true
        }
    }
    try {
        pattern := element.GetCurrentPatternAs("LegacyIAccessible")
        action := pattern.CurrentDefaultAction
        if (RegExMatch(action, "i)(open|edit|press|click|откр|редакт|наж|відкр|натис)")) {
            return pattern.DoDefaultAction() ? true : false
        }
    }
    RcDutyBgLog("unsupported_action", "id=" . element.CurrentAutomationId . " name=" . element.CurrentName . " default=" . action)
    return false
}

RcDutyBgAttach(hwnd) {
    global IikoDriver_UiaInstance
    static cached := ""
    WinGet, pid, PID, ahk_id %hwnd%
    if (IsObject(cached) && cached.hwnd = hwnd && cached.pid = pid) {
        try {
            if (cached.grid.CurrentProcessId = pid && cached.panel.FindAllBy("TrueCondition", 2).MaxIndex())
                return cached
        }
    }
    cached := ""
    if (!IikoDriver_InitEngine())
        throw Exception("UI Automation недоступна.")
    window := IikoDriver_UiaInstance.ElementFromHandle(hwnd)
    ; One native cold lookup; a generic bounded walk may exhaust its budget on
    ; unrelated controls before reaching the actual delivery workspace.
    grid := window.FindFirstBy("AutomationId=gridDeliveries")
    if (!IsObject(grid))
        throw Exception("Відкрийте вкладку Доставки перед згортанням Syrve.")
    panel := ""
    for _, child in grid.FindAllBy("TrueCondition", 2) {
        if RegExMatch(child.CurrentName, "i)(данных|даних|data)") {
            panel := child
            break
        }
    }
    if (!IsObject(panel))
        throw Exception("Syrve не надає таблицю згорнутого вікна через UIA.")
    workspace := window.FindFirstBy("AutomationId=tabControlMain")
    if (!IsObject(workspace))
        throw Exception("Не знайдено робочу область Syrve tabControlMain.")
    cached := {hwnd: hwnd, pid: pid, window: window, grid: grid, panel: panel, workspace: workspace}
    RcDutyBgLog("attached", "hwnd=" . hwnd . " pid=" . pid . " mode=native_scenario")
    return cached
}

RcDutyBgTabSnapshot(workspace) {
    snapshot := ""
    for _, pane in workspace.FindAllBy("TrueCondition", 2) {
        name := Trim(pane.CurrentName)
        if (name != "")
            snapshot .= name . "|"
    }
    if (snapshot = "")
        throw Exception("Syrve не надав стан активної вкладки.")
    return snapshot
}

RcDutyBgCtrlTab(tabHwnd) {
    ; The entrypoint sets -1/-1 for foreground SendInput. ControlSend uses
    ; these settings too, but DevExpress loses the Ctrl+Tab key event when
    ; the whole posted sequence is delivered with no press duration/delay.
    previousDelay := A_KeyDelay, previousDuration := A_KeyDuration
    try {
        SetKeyDelay, 30, 30
        ControlSend, ahk_parent, {Ctrl down}{Tab}{Ctrl up}, ahk_id %tabHwnd%
        if (ErrorLevel)
            throw Exception("Не вдалося надіслати фоновий Ctrl+Tab у Syrve.")
        RcDutyBgLog("ctrl_tab_sent", "tab=" . tabHwnd . " delay=30 duration=30 previous=" . previousDelay . "/" . previousDuration)
    } finally {
        SetKeyDelay, %previousDelay%, %previousDuration%
    }
}

RcDutyBgRefresh(hwnd, workspace) {
    RcDutyBgCheck(hwnd)
    tabHwnd := workspace.CurrentNativeWindowHandle
    if (!tabHwnd || !DllCall("IsChild", "Ptr", hwnd, "Ptr", tabHwnd))
        throw Exception("Не знайдено нативний tabControlMain для оновлення.")
    beforeTab := RcDutyBgTabSnapshot(workspace)
    RcDutyBgLog("refresh_begin", "hwnd=" . hwnd . " tab=" . tabHwnd . " page=" . beforeTab)
    ; Explicit modifiers are addressed messages, not global Ctrl presses.
    RcDutyBgCtrlTab(tabHwnd)
    ; Complete the round trip even if stop arrives after the first tab.
    Sleep, 220
    middleTab := ""
    try middleTab := RcDutyBgTabSnapshot(workspace)
    RcDutyBgCtrlTab(tabHwnd)
    RcDutyBgWait(hwnd, 330)
    afterTab := RcDutyBgTabSnapshot(workspace)
    RcDutyBgLog("refresh_result", "before=" . beforeTab . " middle=" . middleTab . " after=" . afterTab)
    if (middleTab = "" || middleTab = beforeTab || afterTab != beforeTab)
        throw Exception("Фоновий Ctrl+Tab не підтверджено. Перевірте журнал refresh_result.")
    RcDutyBgLog("refresh_complete", "hwnd=" . hwnd)
}

RcDutyBgClientPoint(element, controlHwnd) {
    previousDpi := DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    try {
        rect := element.CurrentBoundingRectangle
        if (rect.r <= rect.l || rect.b <= rect.t)
            throw Exception("Syrve не надав геометрію елемента згорнутого вікна.")
        VarSetCapacity(point, 8, 0)
        NumPut(Floor((rect.l + rect.r) / 2), point, 0, "Int")
        NumPut(Floor((rect.t + rect.b) / 2), point, 4, "Int")
        if (!DllCall("ScreenToClient", "Ptr", controlHwnd, "Ptr", &point))
            throw Exception("Не вдалося визначити координати всередині таблиці.")
        VarSetCapacity(client, 16, 0)
        if (!DllCall("GetClientRect", "Ptr", controlHwnd, "Ptr", &client))
            throw Exception("Таблиця Syrve недоступна.")
        x := NumGet(point, 0, "Int"), y := NumGet(point, 4, "Int")
        if (x < 0 || y < 0 || x >= NumGet(client, 8, "Int") || y >= NumGet(client, 12, "Int"))
            throw Exception("Координати поза таблицею. Фоновий клік скасовано.")
        return {x: x, y: y, packed: (x & 0xFFFF) | ((y & 0xFFFF) << 16)}
    } finally {
        if (previousDpi)
            DllCall("SetThreadDpiAwarenessContext", "Ptr", previousDpi, "Ptr")
    }
}

RcDutyBgMouseMessage(controlHwnd, point, doubleClick := false) {
    ; Exact native click/double-click sequence; no desktop cursor movement.
    messages := doubleClick ? [0x201, 0x202, 0x203, 0x202] : [0x201, 0x202]
    for _, message in messages {
        buttons := (message = 0x201 || message = 0x203) ? 1 : 0
        if (!DllCall("PostMessage", "Ptr", controlHwnd, "UInt", message, "Ptr", buttons, "Ptr", point.packed))
            throw Exception("Syrve відхилив фонову команду миші.")
    }
}

RcDutyBgEditorContains(editorHwnd, gridHwnd, point) {
    previousDpi := DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    try {
        VarSetCapacity(rect, 16)
        if (!DllCall("GetWindowRect", "Ptr", editorHwnd, "Ptr", &rect))
            return false
        DllCall("MapWindowPoints", "Ptr", 0, "Ptr", gridHwnd, "Ptr", &rect, "UInt", 2)
        return point.x >= NumGet(rect, 0, "Int") && point.x < NumGet(rect, 8, "Int")
            && point.y >= NumGet(rect, 4, "Int") && point.y < NumGet(rect, 12, "Int")
    } finally {
        if (previousDpi)
            DllCall("SetThreadDpiAwarenessContext", "Ptr", previousDpi, "Ptr")
    }
}

RcDutyBgFilter(hwnd, context, value) {
    gridHwnd := context.grid.CurrentNativeWindowHandle
    if (!gridHwnd || !DllCall("IsChild", "Ptr", hwnd, "Ptr", gridHwnd))
        throw Exception("Не знайдено нативну таблицю Syrve.")
    filter := ""
    for _, row in context.panel.FindAllBy("TrueCondition", 2) {
        if (!RegExMatch(row.CurrentName, "i)(фильтр|фільтр|filter)"))
            continue
        for _, cell in row.FindAllBy("TrueCondition", 2) {
            if RegExMatch(cell.CurrentName, "i)^(№|номер|number)") {
                filter := cell
                break
            }
        }
        break
    }
    if (!IsObject(filter))
        throw Exception("Не знайдено фільтр номера замовлення.")
    point := RcDutyBgClientPoint(filter, gridHwnd)
    RcDutyBgCheck(hwnd)
    RcDutyBgMouseMessage(gridHwnd, point)
    RcDutyBgWait(hwnd, 150)
    editorHwnd := 0
    for _, editor in context.grid.FindAllBy("ControlType=Edit") {
        candidate := editor.CurrentNativeWindowHandle
        if (!candidate || !editor.CurrentIsEnabled || !DllCall("IsChild", "Ptr", gridHwnd, "Ptr", candidate))
            continue
        ; Test the editor's own visible style, not IsOffscreen or parent state.
        if (!(DllCall("GetWindowLong", "Ptr", candidate, "Int", -16, "UInt") & 0x10000000))
            continue
        if (!RcDutyBgEditorContains(candidate, gridHwnd, point))
            continue
        if (editorHwnd) {
            ; DevExpress can expose both a wrapper and its native inner Edit.
            if (DllCall("IsChild", "Ptr", candidate, "Ptr", editorHwnd))
                continue
            if (!DllCall("IsChild", "Ptr", editorHwnd, "Ptr", candidate))
                throw Exception("Неоднозначний редактор фільтра. Введення скасовано.")
        }
        editorHwnd := candidate
    }
    if (!editorHwnd)
        throw Exception("Syrve не відкрив нативний редактор фільтра.")
    RcDutyBgCheck(hwnd)
    ControlSetText,, %value%, ahk_id %editorHwnd%
    if (ErrorLevel)
        throw Exception("Не вдалося змінити фільтр номера.")
    ControlSend, ahk_parent, {Enter}, ahk_id %editorHwnd%
    if (ErrorLevel)
        throw Exception("Не вдалося застосувати фільтр номера.")
    RcDutyBgWait(hwnd, 200)
    RcDutyBgLog("filter_applied", "number=" . value . " editor=" . editorHwnd)
}

RcDutyBgRead(hwnd) {
    global RH_SERVER
    hwnd := RcDutyBgHandleNumber(hwnd)
    RcDutyBgCheck(hwnd)
    ; Async HTTP keeps Ctrl+F4/manual hotkeys responsive during a cold UIA read.
    request := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    request.Open("GET", RH_SERVER . "/api/iiko/kc-list?background_hwnd=" . hwnd, true)
    request.SetProxy(1)
    request.SetTimeouts(1500, 1500, 12000, 12000)
    request.Send()
    deadline := A_TickCount + 12500
    try {
        while (!request.WaitForResponse(0)) {
            RcDutyBgCheck(hwnd)
            if (A_TickCount >= deadline)
                throw Exception("Сервер не відповів. Перезапустіть RollClub через лаунчер.")
            Sleep, 30
        }
        response := request.ResponseText
    } catch error {
        request.Abort()
        throw error
    }
    RcDutyBgCheck(hwnd)
    if (!RegExMatch(response, """background_hwnd""\s*:\s*" . hwnd . "\s*[,}]"))
        throw Exception("Сервер не підтвердив фонове читання Syrve. Оновіть пакет RollClub.")
    if (!RegExMatch(response, """ok""\s*:\s*true"))
        throw Exception("Не вдалося прочитати згорнутий Syrve. Відкрийте вкладку Доставки і повторіть.")
    return response
}

RcDutyBgNumber(response, key) {
    RegExMatch(response, """" . key . """\s*:\s*(\d+)", match)
    return match1 + 0
}

RcDutyBgConflict(hwnd) {
    WinGet, targetPid, PID, ahk_id %hwnd%
    WinGet, dialogs, List, ahk_class #32770 ahk_pid %targetPid%
    Loop, %dialogs% {
        dialog := dialogs%A_Index%
        WinGetTitle, title, ahk_id %dialog%
        WinGetText, text, ahk_id %dialog%
        if (RegExMatch(title, "i)^(Подтверждение|Підтвердження)$") || RegExMatch(text, "is)(доставка|замовлення|заказ).{0,240}(обрабатыва|обробля|оператор)"))
            return dialog
    }
    return 0
}

RcDutyBgRejectConflict(dialog) {
    global IikoDriver_UiaInstance
    root := IikoDriver_UiaInstance.ElementFromHandle(dialog)
    for _, button in root.FindAllBy("ControlType=Button") {
        if (RegExMatch(button.CurrentName, "i)^(&?Нет|&?Ні|&?No)$") && RcDutyBgInvoke(button))
            return true
    }
    return false
}

RcDutyBgCycle(hwnd, ByRef bookedNo) {
    global IikoDriver_UiaInstance
    RcDutyBgCheck(hwnd)
    context := RcDutyBgAttach(hwnd)
    if IsObject(context.workspace.FindFirstBy("AutomationId=DeliveryOrderEditControl"))
        throw Exception("У Syrve відкрита картка. Закрийте її перед дежурством.")
    if (RcDutyBgConflict(hwnd))
        throw Exception("У Syrve відкрито підтвердження. Закрийте його перед дежурством.")
    RcDutyBgRefresh(hwnd, context.workspace)
    context := RcDutyBgAttach(hwnd)
    response := RcDutyBgRead(hwnd)
    orderNo := RcDutyBgNumber(response, "take_no")
    RcDutyBgLog("scan", "hwnd=" . hwnd . " take_no=" . orderNo)
    if (!orderNo)
        return 0
    RcDutyBgFilter(hwnd, context, orderNo)
    ; Preserve the original filter-and-verify barrier before opening anything.
    deadline := A_TickCount + 2500
    while (A_TickCount < deadline) {
        response := RcDutyBgRead(hwnd)
        if (RcDutyBgNumber(response, "count") = 1 && RcDutyBgNumber(response, "take_no") = orderNo)
            break
        RcDutyBgWait(hwnd, 150)
    }
    response := RcDutyBgRead(hwnd)
    if (RcDutyBgNumber(response, "count") != 1 || RcDutyBgNumber(response, "take_no") != orderNo)
    {
        RcDutyBgFilter(hwnd, context, "")
        throw Exception("Список не звузився до потрібного номера. Замовлення не відкриваю.")
    }
    target := RcDutyBgRow(context.panel, orderNo)
    if (!IsObject(target))
        throw Exception("Рядок замовлення змінився. Перезапустіть дежурство.")
    RcDutyBgCheck(hwnd)
    RcDutyBgLog("opening", "order=" . orderNo . " hwnd=" . hwnd)
    gridHwnd := context.grid.CurrentNativeWindowHandle
    point := RcDutyBgClientPoint(target.cell, gridHwnd)
    RcDutyBgLog("double_click", "grid=" . gridHwnd . " x=" . point.x . " y=" . point.y)
    RcDutyBgMouseMessage(gridHwnd, point, true)
    RcDutyBgLog("open_requested", "order=" . orderNo)
    deadline := A_TickCount + 4000
    card := ""
    while (A_TickCount < deadline) {
        RcDutyBgCheck(hwnd)
        dialog := RcDutyBgConflict(hwnd)
        if (dialog) {
            rejected := RcDutyBgRejectConflict(dialog)
            RcDutyBgLog("operator_conflict", "order=" . orderNo . " rejected=" . rejected)
            throw Exception("Замовлення зайняв інший оператор. Дежурство зупинено.")
        }
        card := context.workspace.FindFirstBy("AutomationId=DeliveryOrderEditControl")
        if IsObject(card)
            break
        RcDutyBgWait(hwnd, 100)
    }
    if (!IsObject(card)) {
        RcDutyBgLog("card_timeout", "order=" . orderNo)
        RcDutyBgFilter(hwnd, context, "")
        throw Exception("Відкриття картки не підтверджено. Перевірте Syrve.")
    }
    ; Give the operator-conflict dialog the same grace period as the legacy path.
    deadline := A_TickCount + 2000
    while (A_TickCount < deadline) {
        RcDutyBgWait(hwnd, 80)
        if (dialog := RcDutyBgConflict(hwnd)) {
            rejected := RcDutyBgRejectConflict(dialog)
            RcDutyBgLog("operator_conflict", "order=" . orderNo . " rejected=" . rejected)
            throw Exception("Замовлення зайняв інший оператор. Дежурство зупинено.")
        }
    }
    close := card.FindFirstBy("AutomationId=buttonClose")
    RcDutyBgCheck(hwnd)
    RcDutyBgLog("closing", "order=" . orderNo . " hwnd=" . hwnd)
    if (!IsObject(close) || !RcDutyBgInvoke(close))
        throw Exception("Не вдалося закрити картку через UIA. Перевірте Syrve.")
    deadline := A_TickCount + 3500
    filterCleared := false
    while (A_TickCount < deadline) {
        RcDutyBgWait(hwnd, 100)
        if (!IsObject(context.workspace.FindFirstBy("AutomationId=DeliveryOrderEditControl"))) {
            if (!filterCleared) {
                RcDutyBgFilter(hwnd, context, "")
                filterCleared := true
                RcDutyBgLog("filter_cleared", "order=" . orderNo)
            }
            target := RcDutyBgRow(context.panel, orderNo)
            if (IsObject(target)) {
                for _, cell in target.row.FindAllBy("TrueCondition", 2) {
                    if (RegExMatch(cell.CurrentName, "i)^(оператор|operator)") && RcDutyBgValue(cell) != "") {
                        bookedNo := orderNo
                        RcDutyBgLog("booked_verified", "order=" . orderNo)
                        return 1
                    }
                }
            }
        }
    }
    throw Exception("Бронювання №" . orderNo . " не підтверджено в таблиці. Перевірте Syrve.")
}
