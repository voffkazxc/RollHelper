#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
FileEncoding, UTF-8
SetBatchLines, -1
SetTitleMatchMode, 2
#Include *i %A_ScriptDir%\lib\UIA_Interface.ahk
#Include *i %A_ScriptDir%\..\..\lib\UIA_Interface.ahk

global ReportUia := ""
global ReportText := ""
global ReportStatus := ""
global ReportLogPath := A_LocalAppData . "\RollHelper\Logs\report_load.log"
global ReportLastStats := {}
global ReportLastOrder := []

FileCreateDir, % A_LocalAppData . "\RollHelper\Logs"
if (IsObject(A_Args) && A_Args[1] = "--parse-test") {
    FileRead, _testInput, % A_Args[2]
    _testOutput := Report_Build(_testInput, _testError)
    if (_testOutput != "" && A_Args[4] = "--manager")
        _testOutput := Report_BuildManager()
    if (_testOutput = "")
        _testOutput := "ERROR: " . _testError
    FileDelete, % A_Args[3]
    FileAppend, %_testOutput%, % A_Args[3], UTF-8
    ExitApp
}
if (IsObject(A_Args) && A_Args[1] = "--live-test") {
    _liveTable := Report_CopyDeliveriesGrid(_liveError)
    _liveOutput := _liveTable = "" ? "ERROR: " . _liveError : Report_Build(_liveTable, _liveError)
    if (_liveOutput = "")
        _liveOutput := "ERROR: " . _liveError
    FileDelete, % A_Args[2]
    FileAppend, %_liveOutput%, % A_Args[2], UTF-8
    ExitApp, % (_liveTable = "" || SubStr(_liveOutput, 1, 6) = "ERROR:") ? 1 : 0
}
Report_CreateGui()
SetTimer, ReportInitialRefresh, -20
return

ReportInitialRefresh:
    Report_Refresh()
return

ReportRefresh:
    Report_Refresh()
return

ReportCopy:
    if (ReportText = "")
        return
    Clipboard := ReportText
    ClipWait, 1
    GuiControl, Report:, ReportStatusLabel, Скопійовано в буфер обміну
return

ReportManager:
    _managerReport := Report_BuildManager()
    if (_managerReport = "") {
        GuiControl, Report:, ReportStatusLabel, Спочатку натисніть «Оновити»
        return
    }
    ReportText := _managerReport
    GuiControl, Report:, ReportOutput, %ReportText%
    GuiControl, Report:, ReportStatusLabel, Звіт для керівника готовий
return

ReportClose:
ReportGuiClose:
ReportGuiEscape:
    ExitApp
return

Report_CreateGui() {
    global ReportOutput, ReportStatusLabel

    Gui, Report:New, +AlwaysOnTop +ToolWindow +Resize +MinSize500x340, Звіт — навантаження
    Gui, Report:Color, F5F6F8, FFFFFF
    Gui, Report:Font, s15 Bold c1F2937, Segoe UI
    Gui, Report:Add, Text, x20 y16 w460 h30, Звіт — навантаження
    Gui, Report:Font, s9 Norm c6B7280, Segoe UI
    Gui, Report:Add, Text, x20 y50 w460 h20, Дані з відкритої таблиці «Доставки» у Syrve
    Gui, Report:Font, s10 Norm c1F2937, Segoe UI
    Gui, Report:Add, Edit, x20 y80 w460 h190 vReportOutput ReadOnly -Wrap +VScroll
    Gui, Report:Font, s9 Norm c6B7280, Segoe UI
    Gui, Report:Add, Text, x20 y278 w460 h20 vReportStatusLabel, Зчитую таблицю…
    Gui, Report:Font, s9 Norm c1F2937, Segoe UI
    Gui, Report:Add, Button, x20 y306 w109 h32 gReportRefresh, Оновити
    Gui, Report:Add, Button, x137 y306 w109 h32 gReportManager, Для керівника
    Gui, Report:Add, Button, x254 y306 w109 h32 gReportCopy, Копіювати
    Gui, Report:Add, Button, x371 y306 w109 h32 gReportClose, Закрити
    Gui, Report:Show, w500 h358
}

ReportGuiSize:
    if (A_EventInfo = 1)
        return
    _contentW := A_GuiWidth - 40
    _editH := A_GuiHeight - 168
    _statusY := A_GuiHeight - 80
    _buttonY := A_GuiHeight - 52
    _buttonW := Floor((_contentW - 24) / 4)
    GuiControl, Report:Move, ReportOutput, % "w" . _contentW . " h" . _editH
    GuiControl, Report:Move, ReportStatusLabel, % "y" . _statusY . " w" . _contentW
    GuiControl, Report:Move, Button1, % "x20 y" . _buttonY . " w" . _buttonW
    GuiControl, Report:Move, Button2, % "x" . (20 + _buttonW + 8) . " y" . _buttonY . " w" . _buttonW
    GuiControl, Report:Move, Button3, % "x" . (20 + (_buttonW + 8) * 2) . " y" . _buttonY . " w" . _buttonW
    GuiControl, Report:Move, Button4, % "x" . (20 + (_buttonW + 8) * 3) . " y" . _buttonY . " w" . _buttonW
return

Report_Refresh() {
    global ReportText

    GuiControl, Report:, ReportStatusLabel, Зчитую таблицю…
    _tableText := Report_CopyDeliveriesGrid(_error)
    if (_tableText = "") {
        ReportText := ""
        GuiControl, Report:, ReportOutput, %_error%
        GuiControl, Report:, ReportStatusLabel, Дані не отримано
        Report_Log("read_error", _error)
        return
    }

    _report := Report_Build(_tableText, _error)
    if (_report = "") {
        ReportText := ""
        GuiControl, Report:, ReportOutput, %_error%
        GuiControl, Report:, ReportStatusLabel, Не вдалося розібрати таблицю
        Report_Log("parse_error", _error)
        return
    }

    ReportText := _report
    GuiControl, Report:, ReportOutput, %ReportText%
    GuiControl, Report:, ReportStatusLabel, Готово. Натисніть «Копіювати»
    Report_Log("report_ready", RegExReplace(ReportText, "[\r\n]+", " | "))
}

Report_CopyDeliveriesGrid(ByRef errorText) {
    global ReportUia

    errorText := ""
    WinGet, _syrveHwnd, ID, ahk_exe BackOffice.exe
    if (!_syrveHwnd) {
        errorText := "Syrve Office не запущено.`r`n`r`nЗапустіть Syrve та відкрийте вкладку «Доставки»."
        return ""
    }

    if (!IsObject(ReportUia)) {
        try ReportUia := UIA_Interface()
        catch e {
            errorText := "Не вдалося запустити UIA.`r`n" . e.Message
            return ""
        }
    }

    try _window := ReportUia.ElementFromHandle(_syrveHwnd)
    catch e {
        errorText := "Не вдалося підключитися до вікна Syrve.`r`n" . e.Message
        return ""
    }

    try _grid := _window.FindFirstBy("AutomationId=gridDeliveries")
    catch e
        _grid := ""
    if (!IsObject(_grid)) {
        errorText := "Не бачу таблицю «Доставки».`r`n`r`nВідкрийте у Syrve вкладку зі списком доставок і натисніть «Оновити»."
        return ""
    }

    _clipboardBackup := ClipboardAll
    Clipboard := ""
    WinActivate, ahk_id %_syrveHwnd%
    try _grid.SetFocus()
    catch e {
        Clipboard := _clipboardBackup
        errorText := "Не вдалося активувати таблицю «Доставки»."
        return ""
    }

    Sleep, 100
    SendInput, ^a
    Sleep, 80
    SendInput, ^c
    ClipWait, 1.5
    _copiedText := Clipboard
    Clipboard := _clipboardBackup
    VarSetCapacity(_clipboardBackup, 0)
    Gui, Report:Show

    if (_copiedText = "") {
        errorText := "Syrve не передав дані таблиці.`r`n`r`nПеревірте, що список доставок не порожній, і натисніть «Оновити»."
        return ""
    }
    return Report_NormalizeGridCopy(_copiedText, _grid, errorText)
}

Report_NormalizeGridCopy(copiedText, grid, ByRef errorText) {
    _firstLine := StrSplit(StrReplace(copiedText, "`r", ""), "`n")[1]
    if (Report_FindHeader(StrSplit(_firstLine, A_Tab), "точка"))
        return copiedText

    _groups := []
    Loop, Parse, copiedText, `n, `r
    {
        _line := Trim(A_LoopField)
        if RegExMatch(_line, "i)^Точка:\s*(.*?)\s*\(Итого:\s*(\d+)\)\s*$", _groupMatch)
            _groups.Push({point: Trim(_groupMatch1), count: _groupMatch2 + 0})
    }
    if (_groups.MaxIndex() = "") {
        errorText := "Syrve передав невідомий формат таблиці.`r`n`r`nОновіть список доставок і повторіть спробу."
        return ""
    }

    _groupSums := []
    try _sumElements := grid.FindAllBy("Name=Сумма к оплате", 4)
    catch e
        _sumElements := ""
    if IsObject(_sumElements) {
        for _index, _element in _sumElements {
            _value := ""
            try _value := Trim(_element.CurrentValue)
            if RegExMatch(_value, "i)^Итого:\s*(.+)$", _sumMatch)
                _groupSums.Push(Trim(_sumMatch1))
        }
    }

    if (_groupSums.MaxIndex() < _groups.MaxIndex()) {
        errorText := "Не вдалося зчитати суми згрупованих точок через UIA.`r`n`r`nНатисніть «Оновити» у Syrve і повторіть спробу."
        return ""
    }

    _normalized := "Точка`tКоличество`tСумма к оплате"
    for _index, _group in _groups
        _normalized .= "`r`n" . _group.point . A_Tab . _group.count . A_Tab . _groupSums[_index]
    return _normalized
}

Report_Build(tableText, ByRef errorText) {
    global ReportLastStats, ReportLastOrder

    errorText := ""
    _lines := StrSplit(StrReplace(tableText, "`r", ""), "`n")
    if (_lines.MaxIndex() < 2) {
        errorText := "У таблиці немає рядків для звіту."
        return ""
    }

    _headers := StrSplit(_lines[1], A_Tab)
    _pointIndex := Report_FindHeader(_headers, "точка")
    _statusIndex := Report_FindHeader(_headers, "статус")
    _countIndex := Report_FindHeader(_headers, "количество|кількість")
    _sumIndex := Report_FindHeader(_headers, "сумма к оплате|сума до сплати")
    if (!_pointIndex || !_sumIndex) {
        errorText := "Не знайдено колонки «Точка» або «Сума до сплати».`r`n`r`nПереконайтеся, що відкрито звичайну таблицю «Доставки»."
        return ""
    }

    _stats := {}
    _order := []
    _totalCount := 0
    _totalSum := 0
    _cancelled := 0

    Loop, % _lines.MaxIndex() - 1 {
        _line := _lines[A_Index + 1]
        if (Trim(_line) = "")
            continue
        _cells := StrSplit(_line, A_Tab)
        if (_cells.MaxIndex() < _sumIndex)
            continue

        _point := Trim(_cells[_pointIndex], " `t" . Chr(34))
        _status := _statusIndex && _cells.MaxIndex() >= _statusIndex ? Trim(_cells[_statusIndex]) : ""
        if (RegExMatch(_status, "i)отмен|скасован")) {
            _cancelled++
            continue
        }
        if (_point = "" || RegExMatch(_point, "i)^(точка|всего|усього|итого|підсумок)"))
            continue

        _sum := Report_ParseAmount(_cells[_sumIndex])
        _rowCount := _countIndex && _cells.MaxIndex() >= _countIndex ? Round(Report_ParseAmount(_cells[_countIndex])) : 1
        if (_rowCount < 1)
            continue
        _pointName := Report_PointName(_point)
        if (!_stats.HasKey(_pointName)) {
            _stats[_pointName] := {count: 0, sum: 0}
            _order.Push(_pointName)
        }
        _entry := _stats[_pointName]
        _entry.count += _rowCount
        _entry.sum += _sum
        _stats[_pointName] := _entry
        _totalCount += _rowCount
        _totalSum += _sum
    }

    if (_totalCount = 0) {
        errorText := "У таблиці не знайдено активних замовлень для звіту."
        return ""
    }

    _displayOrder := Report_DisplayOrder(_stats, _order)
    ReportLastStats := _stats
    ReportLastOrder := _displayOrder

    _result := "Ролл Хаус`r`n`r`n"
    _result .= "ВСЬОГО: " . _totalCount . " / " . Report_FormatAmount(_totalSum) . "`r`n`r`n"
    for _index, _pointName in _displayOrder {
        _entry := _stats[_pointName]
        _result .= _pointName . ": " . _entry.count . " / " . Report_FormatAmount(_entry.sum) . "`r`n"
    }
    if (_cancelled > 0)
        _result .= "`r`nСкасовані не враховано: " . _cancelled
    return RTrim(_result, "`r`n")
}

Report_DisplayOrder(stats, sourceOrder) {
    _result := []
    _preferred := ["Берестин", "Мерефа", "Чугуїв"]
    for _index, _pointName in _preferred {
        if (stats.HasKey(_pointName))
            _result.Push(_pointName)
    }
    for _index, _pointName in sourceOrder {
        if (_pointName != "Берестин" && _pointName != "Мерефа" && _pointName != "Чугуїв")
            _result.Push(_pointName)
    }
    return _result
}

Report_BuildManager() {
    global ReportLastStats, ReportLastOrder

    if (!IsObject(ReportLastStats) || !IsObject(ReportLastOrder) || ReportLastOrder.MaxIndex() = "")
        return ""

    _result := ""
    for _index, _pointName in ReportLastOrder {
        _entry := ReportLastStats[_pointName]
        if (_index > 1)
            _result .= "`r`n`r`n"
        _result .= _pointName . "`r`n"
        _result .= Report_ManagerPhrase(_pointName, _entry.count) . "`r`n"
        _result .= "Виконано: " . _entry.count . " / " . Report_FormatAmount(_entry.sum) . " грн`r`n"
        _result .= "Середній чек: " . Round(_entry.sum / _entry.count) . " грн"
    }
    return _result
}

Report_ManagerPhrase(pointName, count) {
    if (pointName = "Берестин") {
        if (count <= 20)
            return "Замовлень було небагато, зміна пройшла спокійно."
        if (count <= 35)
            return "Зміна пройшла спокійно, замовлення надходили без різких піків."
        if (count <= 55)
            return "Робота йшла у стабільному темпі, навантаження було помірним."
        return "Замовлень було багато, точка працювала з високим навантаженням."
    }
    if (pointName = "Мерефа") {
        if (count <= 20)
            return "День був спокійним, замовлень було небагато."
        if (count <= 35)
            return "Замовлення надходили рівномірно, зміна працювала без поспіху."
        if (count <= 55)
            return "На точці був рівний робочий темп із помірним навантаженням."
        return "Точка відпрацювала насичену зміну з великою кількістю замовлень."
    }
    if (pointName = "Чугуїв") {
        if (count <= 20)
            return "Навантаження було невисоким, зміна пройшла у спокійному режимі."
        if (count <= 35)
            return "Зміна йшла рівно, без значних піків у роботі."
        if (count <= 55)
            return "Замовлення йшли стабільно, темп протягом зміни був робочим."
        return "Потік замовлень був інтенсивним, зміна відпрацювала з високим навантаженням."
    }
    if (count <= 20)
        return "Замовлень було небагато, робота йшла у спокійному темпі."
    if (count <= 55)
        return "Замовлення надходили стабільно, без різких змін навантаження."
    return "Зміна була насиченою, точка працювала з високим навантаженням."
}

Report_FindHeader(headers, patterns) {
    for _index, _header in headers {
        StringLower, _normalized, _header
        _normalized := Trim(_normalized, " `t" . Chr(34))
        if RegExMatch(_normalized, "i)^(" . patterns . ")$")
            return _index
    }
    return 0
}

Report_ParseAmount(rawValue) {
    _value := RegExReplace(rawValue, "[^0-9,.-]")
    if (InStr(_value, ",") && InStr(_value, "."))
        _value := StrReplace(_value, ".", "")
    _value := StrReplace(_value, ",", ".")
    return _value + 0
}

Report_PointName(point) {
    if (InStr(point, "Чугуїв") || InStr(point, "Чугуев"))
        return "Чугуїв"
    if (InStr(point, "Берестин"))
        return "Берестин"
    if (InStr(point, "Мерефа"))
        return "Мерефа"
    _clean := RegExReplace(point, "i)^RH\s*", "")
    return Trim(_clean)
}

Report_FormatAmount(value) {
    _centsTotal := Round(value * 100)
    _sign := _centsTotal < 0 ? "-" : ""
    _centsTotal := Abs(_centsTotal)
    _whole := Floor(_centsTotal / 100)
    _cents := Mod(_centsTotal, 100)
    _text := _whole . ""
    while RegExMatch(_text, "^(-?\d+)(\d{3})", _match)
        _text := _match1 . " " . _match2
    if (_cents = 0)
        return _sign . _text
    return _sign . _text . "," . Format("{:02}", _cents)
}

Report_Log(eventName, details := "") {
    global ReportLogPath
    FormatTime, _now,, yyyy-MM-dd HH:mm:ss
    FileAppend, % _now . "`t" . eventName . "`t" . details . "`n", %ReportLogPath%, UTF-8
}
