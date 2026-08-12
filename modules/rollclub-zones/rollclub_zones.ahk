#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%
FileEncoding, UTF-8

global ZonesUserDir := RcZonesUserDataDir()
RcZonesEnsureDefaults()
RcZonesShow()
return

RcZonesShow() {
    global ZonesUserDir

    Gui, Zones:Destroy
    Gui, Zones:+AlwaysOnTop +ToolWindow
    Gui, Zones:Color, F5F6F8
    Gui, Zones:Font, s10 bold c1F2937, Segoe UI
    Gui, Zones:Add, Text, x16 y14 w420 h24, Зони доставки RollClub
    Gui, Zones:Font, s8 norm c667085, Segoe UI
    Gui, Zones:Add, Text, x16 y40 w470 h34, Дані зберігаються окремо від версії RollClub і не затираються при оновленні.

    status := RcZonesStatusText()
    Gui, Zones:Font, s9 norm c1F2937, Consolas
    Gui, Zones:Add, Edit, x16 y82 w488 h130 ReadOnly -Wrap vZonesStatus, %status%

    Gui, Zones:Font, s9 bold c1F2937, Segoe UI
    Gui, Zones:Add, Button, x16 y226 w150 h34 gRcZonesLoadKml, Завантажити KML
    Gui, Zones:Add, Button, x176 y226 w150 h34 gRcZonesSyncGoogle, Синхронізувати Google
    Gui, Zones:Add, Button, x336 y226 w168 h34 gRcZonesOpenFolder, Відкрити папку зон
    Gui, Zones:Add, Button, x16 y272 w150 h34 gRcZonesOpenKitchens, Відкрити кухні
    Gui, Zones:Add, Button, x176 y272 w150 h34 gRcZonesRefresh, Оновити статус
    Gui, Zones:Add, Button, x336 y272 w168 h34 gRcZonesClose, Закрити

    Gui, Zones:Show, w520 h326, Зони доставки RollClub
}

RcZonesRefresh:
    GuiControl, Zones:, ZonesStatus, % RcZonesStatusText()
return

RcZonesLoadKml:
    global ZonesUserDir
    FileSelectFile, src, 3, , Оберіть KML-файл зон доставки, KML-файл (*.kml)
    if (src = "")
        return
    dst := ZonesUserDir . "\zones.kml"
    FileCopy, %src%, %dst%, 1
    if (ErrorLevel) {
        MsgBox, 16, Зони доставки, Не вдалося скопіювати KML.
        return
    }
    GuiControl, Zones:, ZonesStatus, % RcZonesStatusText()
    MsgBox, 64, Зони доставки, KML завантажено.`nПерезапустіть RollClub, щоб карта перечиталась., 2
return

RcZonesSyncGoogle:
    global ZonesUserDir
    serverDir := RcZonesFindRollclubServerDir()
    if (serverDir = "") {
        MsgBox, 48, Зони доставки, Не знайшов встановлений RollClub або серверний скрипт синхронізації.
        return
    }
    EnvSet, ROLLHELPER_ROLLCLUB_USERDATA, %ZonesUserDir%
    pythonExe := StrReplace(serverDir, "\server", "\runtime\python\python.exe")
    if !FileExist(pythonExe)
        pythonExe := "python"
    syncCmd := """" . pythonExe . """ sync_rollclub_kitchens.py --quiet"
    RunWait, %ComSpec% /c %syncCmd%, %serverDir%, Hide UseErrorLevel
    if (ErrorLevel) {
        MsgBox, 16, Зони доставки, Синхронізація Google не виконалась.
        return
    }
    GuiControl, Zones:, ZonesStatus, % RcZonesStatusText()
    MsgBox, 64, Зони доставки, Кухні оновлено.`nПерезапустіть RollClub, щоб він перечитав дані., 2
return

RcZonesOpenFolder:
    global ZonesUserDir
    Run, explorer.exe "%ZonesUserDir%"
return

RcZonesOpenKitchens:
    global ZonesUserDir
    path := ZonesUserDir . "\RkKitchens.ini"
    if !FileExist(path) {
        MsgBox, 48, Зони доставки, Файл RkKitchens.ini ще не створено.
        return
    }
    Run, notepad.exe "%path%"
return

RcZonesClose:
ZonesGuiClose:
ZonesGuiEscape:
    ExitApp
return

RcZonesProgramRoot() {
    EnvGet, programRoot, ROLLHELPER_PROGRAM_ROOT
    if (programRoot != "")
        return programRoot
    EnvGet, localAppData, LOCALAPPDATA
    if (localAppData = "")
        localAppData := A_AppData
    return localAppData . "\Programs\RollHelper"
}

RcZonesUserDataDir() {
    dir := RcZonesProgramRoot() . "\UserData\rollclub"
    FileCreateDir, %dir%
    return dir
}

RcZonesEnsureDefaults() {
    global ZonesUserDir
    FileCreateDir, %ZonesUserDir%
    for _, name in ["RkKitchens.ini", "RkPresets.txt", "zones.kml", "zones_map.ini"] {
        src := A_ScriptDir . "\data\" . name
        dst := ZonesUserDir . "\" . name
        if (!FileExist(dst) && FileExist(src))
            FileCopy, %src%, %dst%, 0
    }
}

RcZonesStatusText() {
    global ZonesUserDir
    out := "Папка: " . ZonesUserDir . "`r`n`r`n"
    out .= RcZonesFileLine("zones.kml", "KML")
    out .= RcZonesFileLine("zones_map.ini", "Карта зон")
    out .= RcZonesFileLine("RkKitchens.ini", "Кухні")
    out .= RcZonesFileLine("RkPresets.txt", "Пресети")
    return out
}

RcZonesFileLine(fileName, label) {
    global ZonesUserDir
    path := ZonesUserDir . "\" . fileName
    if !FileExist(path)
        return label . ": немає файлу`r`n"
    FileGetSize, size, %path%
    FileGetTime, mod, %path%, M
    FormatTime, modText, %mod%, yyyy-MM-dd HH:mm
    extra := ""
    if (fileName = "zones.kml")
        extra := " · зон: " . RcZonesCountKml(path)
    return label . ": OK · " . size . " байт · " . modText . extra . "`r`n"
}

RcZonesCountKml(path) {
    FileRead, text, *P65001 %path%
    if (ErrorLevel || text = "")
        return 0
    pos := 1
    count := 0
    while (pos := InStr(text, "<Placemark", false, pos)) {
        count += 1
        pos += 10
    }
    return count
}

RcZonesFindRollclubServerDir() {
    root := RcZonesProgramRoot()
    statePath := root . "\State\packages.json"
    if !FileExist(statePath)
        return ""
    FileRead, json, %statePath%
    quote := Chr(34)
    if !RegExMatch(json, "is)" . quote . "rollclub" . quote . "\s*:\s*\{(.*?)\}", pkg)
        return ""
    if !RegExMatch(pkg1, "i)" . quote . "Version" . quote . "\s*:\s*" . quote . "([^" . quote . "]+)" . quote, ver)
        return ""
    serverDir := root . "\Packages\rollclub\" . ver1 . "\server"
    if FileExist(serverDir . "\sync_rollclub_kitchens.py")
        return serverDir
    return ""
}
