; RollHelper operation coordinator.
; Stage 1 runs in observe mode: it records overlaps and durations but never blocks work.

global OpCoord_Mode := "observe"
global OpCoord_Brand := ""
global OpCoord_LogPath := ""
global OpCoord_Sequence := 0
global OpCoord_Open := {}

OpCoord_Init(brand, appDir) {
    global OpCoord_Mode, OpCoord_Brand, OpCoord_LogPath, OpCoord_Open

    OpCoord_Brand := brand
    OpCoord_Open := {}
    _opLogDir := appDir . "\logs"
    FileCreateDir, %_opLogDir%
    OpCoord_LogPath := _opLogDir . "\operation_coordinator.log"

    if !FileExist(OpCoord_LogPath)
        FileAppend, timestamp`tbrand`tmode`tevent`toperation`tsource`ttoken`tduration_ms`tdetails`n, %OpCoord_LogPath%

    OpCoord_Write("init", "Idle", "bootstrap", "", "", "coordinator_started")
}

OpCoord_Event(operation, event := "trigger", source := "", details := "") {
    OpCoord_Write(event, operation, source, "", "", details)
}

OpCoord_Begin(operation, source := "", details := "") {
    global OpCoord_Sequence, OpCoord_Open, OpCoord_Brand

    OpCoord_Sequence += 1
    _opToken := OpCoord_Brand . "-" . A_TickCount . "-" . OpCoord_Sequence
    _opOverlap := OpCoord_Open.Count()
    OpCoord_Open[_opToken] := {operation: operation, source: source, started: A_TickCount}
    _opDetails := "open_before=" . _opOverlap
    if (details != "")
        _opDetails .= ";" . details
    OpCoord_Write("begin", operation, source, _opToken, "", _opDetails)
    return _opToken
}

OpCoord_End(token, result := "ok", details := "") {
    global OpCoord_Open

    if (token = "" || !IsObject(OpCoord_Open) || !OpCoord_Open.HasKey(token)) {
        OpCoord_Write("end_without_begin", "Unknown", "coordinator", token, "", "result=" . result . ";" . details)
        return 0
    }

    _opInfo := OpCoord_Open[token]
    _opDuration := A_TickCount - _opInfo.started
    if (_opDuration < 0)
        _opDuration += 4294967296
    OpCoord_Open.Delete(token)

    _opDetails := "result=" . result
    if (details != "")
        _opDetails .= ";" . details
    OpCoord_Write("end", _opInfo.operation, _opInfo.source, token, _opDuration, _opDetails)
    return 1
}

OpCoord_CanStart(operation, source := "", details := "") {
    global OpCoord_Mode, OpCoord_Open

    _opOpen := IsObject(OpCoord_Open) ? OpCoord_Open.Count() : 0
    OpCoord_Write("decision_allow", operation, source, "", "", "mode=" . OpCoord_Mode . ";open=" . _opOpen . ";" . details)
    return 1
}

OpCoord_Write(event, operation, source, token := "", duration := "", details := "") {
    global OpCoord_Mode, OpCoord_Brand, OpCoord_LogPath

    if (OpCoord_LogPath = "")
        return

    FormatTime, _opNow,, yyyy-MM-dd HH:mm:ss
    _opNow .= "." . A_MSec
    _opEvent := OpCoord_Clean(event)
    _opOperation := OpCoord_Clean(operation)
    _opSource := OpCoord_Clean(source)
    _opTokenClean := OpCoord_Clean(token)
    _opDurationClean := OpCoord_Clean(duration)
    _opDetailsClean := OpCoord_Clean(details)
    _opLine := _opNow . "`t" . OpCoord_Brand . "`t" . OpCoord_Mode . "`t" . _opEvent . "`t" . _opOperation . "`t" . _opSource . "`t" . _opTokenClean . "`t" . _opDurationClean . "`t" . _opDetailsClean . "`n"
    FileAppend, %_opLine%, %OpCoord_LogPath%
}

OpCoord_Clean(value) {
    value := StrReplace(value, "`r", " ")
    value := StrReplace(value, "`n", " ")
    value := StrReplace(value, "`t", " ")
    return Trim(value)
}
