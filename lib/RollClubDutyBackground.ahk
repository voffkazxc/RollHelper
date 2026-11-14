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
    global RcDutyBgGeneration, RcDutyBgRunGeneration
    Sleep, -1  ; dispatch a pending stop/manual hotkey before the next UIA action
    if (kcStop || !dutyOn || rhPunchBusy || _inDutyTake || RcDutyBgGeneration != RcDutyBgRunGeneration)
        throw Exception("STOP")
    if (!DllCall("IsWindow", "Ptr", hwnd))
        throw Exception("Вікно Syrve закрито. Запустіть його знову.")
    WinGet, state, MinMax, ahk_id %hwnd%
    if (state != -1)
        throw Exception("Syrve більше не згорнуто. Перезапустіть дежурство Ctrl+F4.")
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
            pattern.Invoke()
            return true
        }
    }
    try {
        pattern := element.GetCurrentPatternAs("LegacyIAccessible")
        action := pattern.CurrentDefaultAction
        if (RegExMatch(action, "i)(open|edit|press|click|откр|редакт|наж|відкр|натис)")) {
            pattern.DoDefaultAction()
            return true
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
    grid := RcDutyBgFindId(window, "gridDeliveries")
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
    ; Find the tab control that actually contains this delivery grid. This is a
    ; bounded ancestor walk once per attachment, not a whole-window tree scan.
    parent := grid
    tabControl := ""
    Loop, 12 {
        parent := IikoDriver_UiaInstance.ControlViewWalker.GetParentElement(parent)
        if (!IsObject(parent) || parent.CurrentProcessId != pid)
            break
        RcDutyBgLog("ancestor", "id=" . parent.CurrentAutomationId . " type=" . parent.CurrentControlType . " class=" . parent.CurrentClassName)
        if (parent.CurrentControlType = 50018) {
            tabControl := parent
            break
        }
    }
    current := "", alternate := ""
    if IsObject(tabControl) {
        for _, tab in tabControl.FindAllBy("ControlType=TabItem", 2) {
            try {
                pattern := tab.GetCurrentPatternAs("SelectionItem")
                if (pattern.CurrentIsSelected)
                    current := tab
                else if (tab.CurrentIsEnabled && !IsObject(alternate))
                    alternate := tab
            }
        }
    }
    if (!IsObject(current) || !IsObject(alternate))
        throw Exception("Syrve не надає фонове перемикання вкладок UIA. Деталі: rollclub_duty_background.log.")
    cached := {hwnd: hwnd, pid: pid, window: window, grid: grid, panel: panel, current: current, alternate: alternate}
    RcDutyBgLog("attached", "hwnd=" . hwnd . " pid=" . pid . " tab=" . current.CurrentName)
    return cached
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
    if IsObject(RcDutyBgFindId(context.window, "DeliveryOrderEditControl"))
        throw Exception("У Syrve відкрита картка. Закрийте її перед дежурством.")
    if (RcDutyBgConflict(hwnd))
        throw Exception("У Syrve відкрито підтвердження. Закрийте його перед дежурством.")
    ; Same refresh as Ctrl+Tab twice, using selection patterns without keys.
    if (!context.current.GetCurrentPatternAs("SelectionItem").CurrentIsSelected)
        throw Exception("Вкладку Syrve змінено. Відкрийте Доставки і повторіть.")
    RcDutyBgCheck(hwnd)
    context.alternate.GetCurrentPatternAs("SelectionItem").Select()
    ; Always return to Deliveries even if stop arrived between selections.
    Sleep, 220
    context.current.GetCurrentPatternAs("SelectionItem").Select()
    RcDutyBgWait(hwnd, 330)
    context := RcDutyBgAttach(hwnd)
    response := RcDutyBgRead(hwnd)
    orderNo := RcDutyBgNumber(response, "take_no")
    if (!orderNo)
        return 0
    ; Resolve the exact row after the refresh; do not filter or use first-row XY.
    response := RcDutyBgRead(hwnd)
    if (RcDutyBgNumber(response, "take_no") != orderNo)
        return 0  ; eligibility changed before opening: no action
    target := RcDutyBgRow(context.panel, orderNo)
    if (!IsObject(target))
        throw Exception("Рядок замовлення змінився. Перезапустіть дежурство.")
    RcDutyBgCheck(hwnd)
    if (!RcDutyBgInvoke(target.cell) && !RcDutyBgInvoke(target.row))
        throw Exception("Syrve не надає відкриття рядка через UIA. Деталі: rollclub_duty_background.log.")
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
        card := RcDutyBgFindId(context.window, "DeliveryOrderEditControl")
        if IsObject(card)
            break
        RcDutyBgWait(hwnd, 100)
    }
    if (!IsObject(card))
        throw Exception("Картка не відкрилася. Бронювання не підтверджено.")
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
    close := RcDutyBgFindId(card, "buttonClose", 8)
    RcDutyBgCheck(hwnd)
    if (!IsObject(close) || !RcDutyBgInvoke(close))
        throw Exception("Не вдалося закрити картку через UIA. Перевірте Syrve.")
    deadline := A_TickCount + 3500
    while (A_TickCount < deadline) {
        RcDutyBgWait(hwnd, 100)
        if (!IsObject(RcDutyBgFindId(context.window, "DeliveryOrderEditControl"))) {
            ; No search filter was entered, so none needs clearing.
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
