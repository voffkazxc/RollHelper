#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
SendMode, Input
SetWorkingDir, %A_ScriptDir%
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
FileEncoding, UTF-8
SetTitleMatchMode, 2
#Include %A_ScriptDir%\..\lib\UIA_Interface.ahk

; RollHouse Lite — AHK-only пульт без сервера/OCR/Telegram/CRM.
; Нужен только AutoHotkey v1.1 и открытый Syrve/BackOffice.

configFile := A_ScriptDir . "\RkConfig.ini"
deliveryPricesFile := A_ScriptDir . "\DeliveryPrices.ini"
zonesFile := A_ScriptDir . "\zones.kml"
global configFile
global deliveryPricesFile
global zonesFile

global iikoWinExe, iikoWinW, iikoWinH
global hkMain, hkSiv, speedMode
global commX, commY, infoX, infoY, addrX, addrY, cardX, cardY, timeX, timeY, itemX, itemY
global crossX, crossY, cashX, cashY, changeX, changeY, noChangeX, noChangeY
global commRelX, commRelY, infoRelX, infoRelY, addrRelX, addrRelY, cardRelX, cardRelY, timeRelX, timeRelY, itemRelX, itemRelY
global crossRelX, crossRelY, cashRelX, cashRelY, changeRelX, changeRelY, noChangeRelX, noChangeRelY
global pluPepsi, pluBrooklyn, pluBurger, pluSticksNorm, pluSticksEdu, pluSoy, pluGinger, pluWasabi
global paymentCashSearch, paymentCardSearch
global giftPepsiThreshold, giftBrooklynThreshold, giftBurgerThreshold
global tgGroup, p1X, p1Y, p2X, p2Y, p3X, p3Y, p4X, p4Y, p5X, p5Y, p6X, p6Y
global LiteRawComment := "", LiteOrderSum := 0, LiteStreetText := "", LiteHouseText := "", LiteIikoTime := ""
global LiteAutoCash := 0, LiteAutoCard := 0, LiteNoPayChange := 0, LiteIsPickup := 0, LitePaymentMethod := ""
global LiteCalcChange := 0, LiteDeliveryCostNum := 0, LiteDeliveryCostStr := "", LiteKitchenNote := ""
global LiteCommentBody := ""
global LiteReadyTime := ""
global GiftPepsi := 0, GiftBrooklyn := 0, GiftBurger := 0, PayMode := ""
global LiteBusy := 0
global LiteUIA := ""
global RhlZones := [], RhlZonesOk := 0

LoadConfig()
Hotkey, %hkMain%, OpenLitePult, On, UseErrorLevel
if (ErrorLevel) {
    hkMain := "vkC0"
    IniWrite, %hkMain%, %configFile%, Hotkeys, Main
    Hotkey, %hkMain%, OpenLitePult, On
}
Hotkey, %hkSiv%, OpenSivOnly, On, UseErrorLevel
if (ErrorLevel) {
    hkSiv := "F1"
    IniWrite, %hkSiv%, %configFile%, Hotkeys, Siv
    Hotkey, %hkSiv%, OpenSivOnly, On
}
Hotkey, F5, RhlRunReportAutopilot, On
Hotkey, +F5, RhlExcelReportFromSelection, On
Menu, Tray, Tip, RollHouse Lite
Menu, Tray, Add, Відкрити пульт, OpenLitePult
Menu, Tray, Add, F5 автозвіт, RhlRunReportAutopilot
Menu, Tray, Add, Записати маршрут F5, SetupReportAutopilot
Menu, Tray, Add, Shift+F5 з виділеного Excel, RhlExcelReportFromSelection
Menu, Tray, Add, Налаштування, OpenLiteSettings
Menu, Tray, Add
Menu, Tray, Add, Вихід, LiteExit
return

LoadConfig() {
    global
    IniRead, iikoWinExe, %configFile%, Targets, IikoWinExe, BackOffice.exe
    IniRead, iikoWinW, %configFile%, Targets, IikoWinW, 1936
    IniRead, iikoWinH, %configFile%, Targets, IikoWinH, 1048
    IniRead, hkMain, %configFile%, Hotkeys, Main, vkC0
    IniRead, hkSiv, %configFile%, Hotkeys, Siv, F1
    IniRead, speedMode, %configFile%, Speed, Mode, 2
    IniRead, paymentCashSearch, %configFile%, Payment, CashSearch, гот
    IniRead, paymentCardSearch, %configFile%, Payment, CardSearch, банк
    IniRead, tgGroup, %configFile%, Autopilot, TgGroup,
    IniRead, p1X, %configFile%, Autopilot, P1X, 0
    IniRead, p1Y, %configFile%, Autopilot, P1Y, 0
    IniRead, p2X, %configFile%, Autopilot, P2X, 0
    IniRead, p2Y, %configFile%, Autopilot, P2Y, 0
    IniRead, p3X, %configFile%, Autopilot, P3X, 0
    IniRead, p3Y, %configFile%, Autopilot, P3Y, 0
    IniRead, p4X, %configFile%, Autopilot, P4X, 0
    IniRead, p4Y, %configFile%, Autopilot, P4Y, 0
    IniRead, p5X, %configFile%, Autopilot, P5X, 0
    IniRead, p5Y, %configFile%, Autopilot, P5Y, 0
    IniRead, p6X, %configFile%, Autopilot, P6X, 0
    IniRead, p6Y, %configFile%, Autopilot, P6Y, 0
    IniRead, giftPepsiThreshold, %configFile%, Gifts, PepsiThreshold, 699
    IniRead, giftBrooklynThreshold, %configFile%, Gifts, BrooklynThreshold, 899
    IniRead, giftBurgerThreshold, %configFile%, Gifts, BurgerThreshold, 1299
    giftPepsiThreshold += 0
    giftBrooklynThreshold += 0
    giftBurgerThreshold += 0

    IniRead, commX, %configFile%, Targets, CommX, 0
    IniRead, commY, %configFile%, Targets, CommY, 0
    IniRead, infoX, %configFile%, Targets, InfoX, 0
    IniRead, infoY, %configFile%, Targets, InfoY, 0
    IniRead, addrX, %configFile%, Targets, AddrX, 0
    IniRead, addrY, %configFile%, Targets, AddrY, 0
    IniRead, cardX, %configFile%, Targets, CardX, 0
    IniRead, cardY, %configFile%, Targets, CardY, 0
    IniRead, timeX, %configFile%, Targets, TimeX, 0
    IniRead, timeY, %configFile%, Targets, TimeY, 0
    IniRead, itemX, %configFile%, Targets, ItemX, 0
    IniRead, itemY, %configFile%, Targets, ItemY, 0
    IniRead, crossX, %configFile%, Targets, CrossX, 0
    IniRead, crossY, %configFile%, Targets, CrossY, 0
    IniRead, cashX, %configFile%, Targets, CashX, 0
    IniRead, cashY, %configFile%, Targets, CashY, 0
    IniRead, changeX, %configFile%, Targets, ChangeX, 0
    IniRead, changeY, %configFile%, Targets, ChangeY, 0
    IniRead, noChangeX, %configFile%, Targets, NoChangeX, 0
    IniRead, noChangeY, %configFile%, Targets, NoChangeY, 0

    IniRead, commRelX, %configFile%, TargetsRel, CommX, 0
    IniRead, commRelY, %configFile%, TargetsRel, CommY, 0
    IniRead, infoRelX, %configFile%, TargetsRel, InfoX, 0
    IniRead, infoRelY, %configFile%, TargetsRel, InfoY, 0
    IniRead, addrRelX, %configFile%, TargetsRel, AddrX, 0
    IniRead, addrRelY, %configFile%, TargetsRel, AddrY, 0
    IniRead, cardRelX, %configFile%, TargetsRel, CardX, 0
    IniRead, cardRelY, %configFile%, TargetsRel, CardY, 0
    IniRead, timeRelX, %configFile%, TargetsRel, TimeX, 0
    IniRead, timeRelY, %configFile%, TargetsRel, TimeY, 0
    IniRead, itemRelX, %configFile%, TargetsRel, ItemX, 0
    IniRead, itemRelY, %configFile%, TargetsRel, ItemY, 0
    IniRead, crossRelX, %configFile%, TargetsRel, CrossX, 0
    IniRead, crossRelY, %configFile%, TargetsRel, CrossY, 0
    IniRead, cashRelX, %configFile%, TargetsRel, CashX, 0
    IniRead, cashRelY, %configFile%, TargetsRel, CashY, 0
    IniRead, changeRelX, %configFile%, TargetsRel, ChangeX, 0
    IniRead, changeRelY, %configFile%, TargetsRel, ChangeY, 0
    IniRead, noChangeRelX, %configFile%, TargetsRel, NoChangeX, 0
    IniRead, noChangeRelY, %configFile%, TargetsRel, NoChangeY, 0

    IniRead, pluPepsi, %configFile%, PLU, Pepsi, 00802
    IniRead, pluBrooklyn, %configFile%, PLU, Brooklyn, 00263
    IniRead, pluBurger, %configFile%, PLU, Burger, 00892
    IniRead, pluSticksNorm, %configFile%, PLU_SIV, SticksNorm, 00430
    IniRead, pluSticksEdu, %configFile%, PLU_SIV, SticksEdu, 00432
    IniRead, pluSoy, %configFile%, PLU_SIV, Soy, 00424
    IniRead, pluGinger, %configFile%, PLU_SIV, Ginger, 00428
    IniRead, pluWasabi, %configFile%, PLU_SIV, Wasabi, 00426
}

SpDly(ms) {
    global speedMode
    if (speedMode = 3)
        return Round(ms * 0.75)
    if (speedMode = 1)
        return Round(ms * 1.35)
    return ms
}

IikoHwnd() {
    global iikoWinExe
    hwnd := ""
    if (iikoWinExe != "")
        hwnd := WinExist("ahk_exe " . iikoWinExe)
    if (!hwnd)
        hwnd := WinExist("Syrve")
    if (!hwnd)
        hwnd := WinExist("Office")
    if (!hwnd)
        hwnd := WinActive("A")
    return hwnd
}

IikoActivate() {
    hwnd := IikoHwnd()
    if (!hwnd)
        return 0
    WinActivate, ahk_id %hwnd%
    Sleep, % SpDly(120)
    return hwnd
}

IikoWindowRect(ByRef wx, ByRef wy, ByRef ww, ByRef wh) {
    hwnd := IikoHwnd()
    if (!hwnd)
        return 0
    WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
    return 1
}

IikoXY(relX, relY, absX, absY, ByRef outX, ByRef outY) {
    global iikoWinW, iikoWinH
    if (IikoWindowRect(wx, wy, ww, wh) && relX != "" && relX != 0) {
        if (iikoWinW > 0 && iikoWinH > 0) {
            outX := Round(wx + relX * ww / iikoWinW)
            outY := Round(wy + relY * wh / iikoWinH)
        } else {
            outX := wx + relX
            outY := wy + relY
        }
    } else {
        outX := absX
        outY := absY
    }
}

ClickAt(x, y, dbl := 0) {
    if (!x || !y)
        return 0
    IikoActivate()
    MouseGetPos, mx, my
    if (dbl)
        Click, %x%, %y%, 2
    else
        Click, %x%, %y%
    Sleep, % SpDly(120)
    MouseMove, %mx%, %my%, 0
    return 1
}

ClickRel(relX, relY, absX, absY, dbl := 0) {
    IikoXY(relX, relY, absX, absY, x, y)
    return ClickAt(x, y, dbl)
}

PasteRel(relX, relY, absX, absY, text) {
    if (text = "")
        return
    IikoXY(relX, relY, absX, absY, x, y)
    if (!x || !y)
        return
    IikoActivate()
    Clipboard := text
    ClipWait, 1
    Click, %x%, %y%
    Sleep, % SpDly(120)
    Send, ^a
    Sleep, 50
    Send, ^v
    Sleep, % SpDly(150)
}

RhlUiaInit() {
    global LiteUIA
    if (IsObject(LiteUIA))
        return 1
    try {
        LiteUIA := UIA_Interface()
        return IsObject(LiteUIA)
    } catch e {
        LiteUIA := ""
        return 0
    }
}

RhlUiaWindow() {
    global LiteUIA
    if (!RhlUiaInit())
        return ""
    hwnd := IikoHwnd()
    if (!hwnd)
        return ""
    try return LiteUIA.ElementFromHandle(hwnd)
    catch e
        return ""
}

RhlUiaRoot() {
    win := RhlUiaWindow()
    if (!IsObject(win))
        return ""
    try root := win.FindFirstBy("AutomationId=DeliveryOrderEditControl")
    catch e
        root := ""
    return IsObject(root) ? root : win
}

RhlUiaFind(aid) {
    root := RhlUiaRoot()
    if (!IsObject(root) || aid = "")
        return ""
    try el := root.FindFirstBy("AutomationId=" . aid)
    catch e
        el := ""
    if (IsObject(el))
        return el
    win := RhlUiaWindow()
    if (!IsObject(win))
        return ""
    try return win.FindFirstBy("AutomationId=" . aid)
    catch e
        return ""
}

RhlUiaClick(aid) {
    el := RhlUiaFind(aid)
    if (!IsObject(el))
        return 0
    IikoActivate()
    try {
        el.Click()
        Sleep, % SpDly(150)
        return 1
    } catch e {
        return 0
    }
}

RhlUiaFocus(aid) {
    el := RhlUiaFind(aid)
    if (!IsObject(el))
        return 0
    IikoActivate()
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

RhlUiaSetValue(aid, text) {
    if (text = "")
        return 1
    el := RhlUiaFind(aid)
    if (!IsObject(el))
        return 0
    IikoActivate()
    try {
        el.SetValue(text)
        Sleep, % SpDly(120)
        return 1
    } catch e {
        if (!RhlUiaFocus(aid))
            return 0
        Clipboard := text
        ClipWait, 1
        Send, ^a
        Sleep, 50
        Send, ^v
        Sleep, % SpDly(150)
        return 1
    }
}

RhlUiaDoublePaste(aid, text, verify := 1) {
    if (text = "")
        return 1
    el := RhlUiaFind(aid)
    if (!IsObject(el))
        return 0
    IikoActivate()
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
    got := RhlUiaGetValue(aid)
    return InStr(got, text) ? 1 : 0
}

RhlReportInit() {
    global LiteReport
    LiteReport := ""
}

RhlReportStep(label, ok, detail := "") {
    global LiteReport
    LiteReport .= (ok ? "✓ " : "⚠ ") . label . (detail != "" ? ": " . detail : "") . "`n"
    ToolTip, %LiteReport%, 30, 60
}

RhlReportFinish() {
    global LiteReport
    GuiControl, Lite:, LitePreview, % RhlCleanTextOneLine(StrReplace(LiteReport, "`n", "  "))
    SetTimer, LiteTipOff, -2500
}

RhlJoinNonEmpty(a, b, sep := " | ") {
    a := Trim(a)
    b := Trim(b)
    if (a != "" && b != "")
        return a . sep . b
    return a != "" ? a : b
}

SetupReportAutopilot:
    MsgBox, 4160, Маршрут F5, Зараз запишемо маршрут звіту.`nПісля кожного повідомлення наведи мишку на потрібне місце і клікни ЛКМ.

    MsgBox, 4160, Крок 1/6, Наведи на заголовок колонки "Точка" і клікни ЛКМ.
    RhlWaitUserClick(p1X, p1Y)

    MsgBox, 4160, Крок 2/6, Наведи на панель групування і клікни ЛКМ.
    RhlWaitUserClick(p2X, p2Y)

    MsgBox, 4160, Крок 3/6, Наведи на фільтр "Статус" і клікни ЛКМ.
    RhlWaitUserClick(p3X, p3Y)

    MsgBox, 4160, Крок 4/6, Наведи на "Вибрати все" і клікни ЛКМ.
    RhlWaitUserClick(p4X, p4Y)

    MsgBox, 4160, Крок 5/6, Наведи на "Отмененные" і клікни ЛКМ.
    RhlWaitUserClick(p5X, p5Y)

    MsgBox, 4160, Крок 6/6, Наведи на кнопку "В Excel" і клікни ЛКМ.
    RhlWaitUserClick(p6X, p6Y)

    RhlSaveReportRoute()
    MsgBox, 4160, Маршрут F5, Маршрут записано.`nТепер F5 повторить ці кроки автоматично.
return

RhlRunReportAutopilot:
    global p1X, p1Y, p2X, p2Y, p3X, p3Y, p4X, p4Y, p5X, p5Y, p6X, p6Y
    if (p1X = 0 || p2X = 0 || p6X = 0) {
        MsgBox, 4144, Звіт F5, Маршрут не налаштовано.`nУ треї RollHouse Lite натисни "Записати маршрут F5".
        return
    }

    MouseClickDrag, Left, %p1X%, %p1Y%, %p2X%, %p2Y%, 10
    Sleep, % SpDly(800)
    Click, %p3X%, %p3Y%
    Sleep, % SpDly(500)
    Click, %p4X%, %p4Y%
    Sleep, % SpDly(300)
    Click, %p5X%, %p5Y%
    Sleep, % SpDly(300)
    Send, {Esc}
    Sleep, % SpDly(500)
    Click, %p6X%, %p6Y%

    WinWaitActive, ahk_exe EXCEL.EXE,, 10
    if (ErrorLevel) {
        MsgBox, 4144, Звіт F5, Excel не відкрився.
        return
    }
    Sleep, % SpDly(1500)
    Send, ^{Home}
    Sleep, % SpDly(300)
    Send, ^+{End}
    Sleep, % SpDly(300)
    GoSub, RhlExcelReportFromSelection
return

RhlWaitUserClick(ByRef outX, ByRef outY) {
    KeyWait, LButton, Up
    KeyWait, LButton, Down
    MouseGetPos, outX, outY
    KeyWait, LButton, Up
}

RhlSaveReportRoute() {
    global configFile, p1X, p1Y, p2X, p2Y, p3X, p3Y, p4X, p4Y, p5X, p5Y, p6X, p6Y
    IniWrite, %p1X%, %configFile%, Autopilot, P1X
    IniWrite, %p1Y%, %configFile%, Autopilot, P1Y
    IniWrite, %p2X%, %configFile%, Autopilot, P2X
    IniWrite, %p2Y%, %configFile%, Autopilot, P2Y
    IniWrite, %p3X%, %configFile%, Autopilot, P3X
    IniWrite, %p3Y%, %configFile%, Autopilot, P3Y
    IniWrite, %p4X%, %configFile%, Autopilot, P4X
    IniWrite, %p4Y%, %configFile%, Autopilot, P4Y
    IniWrite, %p5X%, %configFile%, Autopilot, P5X
    IniWrite, %p5Y%, %configFile%, Autopilot, P5Y
    IniWrite, %p6X%, %configFile%, Autopilot, P6X
    IniWrite, %p6Y%, %configFile%, Autopilot, P6Y
}

RhlExcelReportFromSelection:
    if (!WinActive("ahk_exe EXCEL.EXE")) {
        WinActivate, ahk_exe EXCEL.EXE
        WinWaitActive, ahk_exe EXCEL.EXE,, 2
        if (ErrorLevel) {
            MsgBox, 4144, Звіт F5, Excel не активний.`nВиділи таблицю звіту в Excel і натисни F5.
            return
        }
    }
    Clipboard :=
    Send, ^c
    ClipWait, 3
    if (ErrorLevel || Clipboard = "") {
        MsgBox, 4144, Звіт F5, Не зміг скопіювати виділення Excel.`nВиділи весь звіт і натисни F5 ще раз.
        return
    }
    rawSelection := Clipboard
    report := RhlBuildReportFromExcelText(rawSelection)
    if (report = "") {
        FileDelete, %A_ScriptDir%\excel_report_last_raw.txt
        FileAppend, %Clipboard%, %A_ScriptDir%\excel_report_last_raw.txt, UTF-8
        MsgBox, 4112, Звіт F5, Не знайшов цифри в Excel.`nСирий текст збережено: excel_report_last_raw.txt
        return
    }
    FileDelete, %A_ScriptDir%\excel_report_last.txt
    FileAppend, %report%, %A_ScriptDir%\excel_report_last.txt, UTF-8
    RhlRunReportPythonHook(report, rawSelection)
    Clipboard := report
    MsgBox, 4160, Звіт F5, %report%`n`nСкопійовано в буфер і збережено в excel_report_last.txt.
return

RhlBuildReportFromExcelText(text) {
    totalCount := 0, totalSum := ""
    chCount := 0, chSum := ""
    berCount := 0, berSum := ""
    merCount := 0, merSum := ""
    currentCity := ""

    Loop, Parse, text, `n, `r
    {
        line := A_LoopField
        if (InStr(line, "Точка:")) {
            RegExMatch(line, "\(Итого:\s*(\d+)\)", match)
            if (InStr(line, "Чугуїв") || InStr(line, "Чугуев")) {
                currentCity := "Чугуїв"
                chCount := match1 + 0
            } else if (InStr(line, "Берестин") || InStr(line, "Красноград")) {
                currentCity := "Берестин"
                berCount := match1 + 0
            } else if (InStr(line, "Мерефа")) {
                currentCity := "Мерефа"
                merCount := match1 + 0
            } else {
                currentCity := ""
            }
        } else if (currentCity != "" && RegExMatch(line, "Итого:\s*([\d\s]+,\d{2})", match)) {
            sum := RhlReportCleanMoney(match1)
            if (currentCity = "Чугуїв")
                chSum := sum
            else if (currentCity = "Берестин")
                berSum := sum
            else if (currentCity = "Мерефа")
                merSum := sum
            currentCity := ""
        } else if (InStr(line, "Всего:") && RegExMatch(line, "Всего:\s*(\d+)", match)) {
            totalCount := match1 + 0
            if RegExMatch(line, "Итого:\s*([\d\s]+,\d{2})", matchSum)
                totalSum := RhlReportCleanMoney(matchSum1)
        }
    }

    if (totalCount = 0 && chCount = 0 && merCount = 0 && berCount = 0)
        return ""
    if (totalSum = "")
        totalSum := RhlReportSumMoney(chSum, berSum, merSum)
    return "Ролл Хаус:`nВСЬОГО: " . totalCount . " / " . totalSum . "`n`nБерестин: " . berCount . " / " . berSum . "`nМерефа: " . merCount . " / " . merSum . "`nЧугуїв: " . chCount . " / " . chSum
}

RhlReportCleanMoney(raw) {
    money := RegExReplace(raw, ",00$", "")
    money := RegExReplace(money, "\s+", " ")
    return Trim(money)
}

RhlReportMoneyToNum(money) {
    n := RegExReplace(money, "[^\d]", "")
    return n = "" ? 0 : n + 0
}

RhlReportFormatMoney(n) {
    s := "" . Round(n)
    out := ""
    while (StrLen(s) > 3) {
        out := " " . SubStr(s, StrLen(s) - 2) . out
        s := SubStr(s, 1, StrLen(s) - 3)
    }
    return s . out
}

RhlReportSumMoney(a, b, c) {
    return RhlReportFormatMoney(RhlReportMoneyToNum(a) + RhlReportMoneyToNum(b) + RhlReportMoneyToNum(c))
}

RhlRunReportPythonHook(report, rawText) {
    hook := A_ScriptDir . "\report_after_excel.py"
    rawPath := A_ScriptDir . "\excel_report_last_raw.txt"
    reportPath := A_ScriptDir . "\excel_report_last.txt"
    FileDelete, %rawPath%
    FileAppend, %rawText%, %rawPath%, UTF-8
    if (!FileExist(hook))
        return 0
    RunWait, %ComSpec% /c python "%hook%" "%rawPath%" "%reportPath%", %A_ScriptDir%, Hide UseErrorLevel
    return ErrorLevel ? 0 : 1
}

RhlUiaGetValue(aid) {
    el := RhlUiaFind(aid)
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
    return val
}

RhlReadOrderSumFromTree() {
    tree := RhlUiaFind("treeListItems")
    if (!IsObject(tree))
        return 0
    sum := 0
    seen := {}
    try children := tree.FindAllBy("TrueCondition")
    catch e
        return 0
    if (!IsObject(children))
        return 0
    Loop, % children.MaxIndex() {
        child := children[A_Index]
        try ctype := child.CurrentControlType
        catch e
            ctype := 0
        if (ctype != 50024)
            continue
        val := ""
        try val := child.CurrentValue
        catch e
            val := ""
        if (val = "") {
            try val := child.CurrentValuePattern.Value
            catch e2
                val := ""
        }
        if (val = "" || !InStr(val, ";"))
            continue
        parts := StrSplit(val, ";")
        if (parts.MaxIndex() < 5)
            continue
        rowName := Trim(parts[1])
        rowQty := StrReplace(Trim(parts[2]), ",", ".") + 0
        rowSumText := StrReplace(Trim(parts[5]), " ", "")
        rowSumText := StrReplace(rowSumText, ",", ".")
        rowSum := rowSumText + 0
        key := rowName . "|" . rowQty . "|" . rowSum
        if (rowName = "" || rowQty <= 0 || rowSum <= 0 || seen.HasKey(key))
            continue
        seen[key] := 1
        sum += rowSum
    }
    return Round(sum)
}

RhlReadFromSyrve() {
    global LiteRawComment, LiteOrderSum, LiteStreetText, LiteHouseText, LiteIikoTime
    IikoActivate()
    Sleep, % SpDly(120)
    LiteRawComment := RhlUiaGetValue("memoEditDeliveryComment")
    LiteStreetText := RhlUiaGetValue("gridLookUpEditStreetAddress")
    LiteHouseText := RhlUiaGetValue("textEditDeliveryHouse")
    LiteIikoTime := RhlUiaGetValue("timeEditDeliveryTime")
    LiteOrderSum := RhlReadOrderSumFromTree()
    return (LiteRawComment != "" || LiteOrderSum > 0 || LiteStreetText != "")
}

RhlCleanTextOneLine(txt) {
    txt := RegExReplace(txt, "[\r\n]+", " ")
    txt := RegExReplace(txt, "\s{2,}", " ")
    return Trim(txt)
}

RhlStripLitePayBits(text) {
    global LiteDeliveryCostStr
    text := RhlCleanTextOneLine(text)
    cleaned := ""
    Loop, Parse, text, |
    {
        part := Trim(A_LoopField)
        if (part = "")
            continue
        part := RegExReplace(part, "i)(Готівкою|Готівка|Наличными|Термінал|Terminal|Банківська\s+карта|Банківська\s+картка|Карткою\s+у\s+закладі|Картою\s+в\s+закладі|ОПЛАЧЕНО|оплачено)", "")
        if (LiteDeliveryCostStr != "")
            part := StrReplace(part, LiteDeliveryCostStr, "")
        part := RegExReplace(part, "i)Доставка\s+[^|]*?\s*-\s*\d+\s*грн", "")
        part := RegExReplace(part, "i)(набрати|набрать|подзвонити|позвонить|дзвонити|звонить)\s+по\s+готовності", "")
        part := RegExReplace(part, "i)(?:підготувати\s*|подготовить\s*)?(решт[уа]\s*з|сдача\s*с)(?:[:\sзс]*?)\d+(?:\s*грн)?", "")
        part := RegExReplace(part, "i)(без\s*здачі|без\s*сдачи)", "")
        part := RegExReplace(part, "\s{2,}", " ")
        part := Trim(part, " `t,;:-")
        if (part = "")
            continue
        cleaned .= (cleaned != "" ? " | " : "") . part
    }
    return Trim(cleaned)
}

RhlBuildLiteComment(payMode, changeAmount, noChangeFlag, body) {
    global LiteDeliveryCostStr, LiteIsPickup, LiteH, LiteM
    prefix := ""
    if (payMode = "cash")
        prefix := "Готівка"
    else if (payMode = "card")
        prefix := "Термінал"
    if (LiteDeliveryCostStr != "")
        prefix .= (prefix != "" ? " " : "") . LiteDeliveryCostStr
    if (!noChangeFlag && payMode = "cash" && changeAmount != "" && changeAmount > 0)
        prefix .= (prefix != "" ? " " : "") . "решта з " . changeAmount
    if (LiteIsPickup && RhlPickupReadyNeedsCall(LiteH, LiteM))
        prefix .= (prefix != "" ? " " : "") . "подзвонити по готовності"
    body := RhlStripLitePayBits(body)
    return Trim(prefix . (prefix != "" && body != "" ? " | " : "") . body)
}

RhlPickupReadyNeedsCall(h, m) {
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

RhlRefreshLiteCommentFromControls() {
    global PayMode, LiteChange, LiteNoChange, LiteComment, LiteCommentBody
    Gui, Lite:Submit, NoHide
    body := RhlStripLitePayBits(LiteComment)
    LiteCommentBody := body
    if (LiteNoChange) {
        LiteChange := ""
        GuiControl, Lite:, LiteChange, % ""
    }
    nextComment := RhlBuildLiteComment(PayMode, LiteChange, LiteNoChange, body)
    GuiControl, Lite:, LiteComment, %nextComment%
}

RhlSetDefaultReady(minutes) {
    global LiteReadyTime
    HH := A_Hour + 0
    MM := A_Min + minutes
    HH += Floor(MM / 60)
    MM := Mod(MM, 60)
    HH := Mod(HH, 24)
    rem := Mod(MM, 5)
    if (rem != 0) {
        MM += (5 - rem)
        if (MM >= 60) {
            MM -= 60
            HH := Mod(HH + 1, 24)
        }
    }
    h := Format("{:02}", HH)
    m := Format("{:02}", MM)
    GuiControl, Lite:, LiteH, %h%
    GuiControl, Lite:, LiteM, %m%
    LiteReadyTime := h . ":" . m
}

RhlUpdateHeader() {
    global LiteOrderSum, LiteIsPickup, GiftPepsi, GiftBrooklyn, GiftBurger
    giftText := GiftBurger ? "Бургер" : (GiftBrooklyn ? "Бруклін" : (GiftPepsi ? "Пепсі" : "нема"))
    typeText := LiteIsPickup ? "самовивіз" : "доставка"
    GuiControl, Lite:, LiteHeaderInfo, % "Сума: " . LiteOrderSum . " грн · " . typeText . " · подарунок: " . giftText
}

RhlFindDeliveryCost(searchText, ByRef outLabel) {
    global deliveryPricesFile
    outLabel := ""
    if (searchText = "" || !FileExist(deliveryPricesFile))
        return 0
    oldCaseSense := A_StringCaseSense
    StringCaseSense, Locale
    FileRead, data, %deliveryPricesFile%
    bestName := "", bestPrice := 0, bestLen := 0
    Loop, Parse, data, `n, `r
    {
        line := A_LoopField
        if (!InStr(line, "="))
            continue
        parts := StrSplit(line, "=")
        name := Trim(parts[1], " `t" . Chr(160))
        price := Trim(parts[2], " `t" . Chr(160)) + 0
        if (name = "" || price <= 0)
            continue
        pos := InStr(searchText, name)
        if (!pos)
            continue
        before := pos > 1 ? SubStr(searchText, pos - 1, 1) : " "
        after := SubStr(searchText, pos + StrLen(name), 1)
        if (RegExMatch(before, "[А-Яа-яІЇЄҐіїєґ]") || RegExMatch(after, "[А-Яа-яІЇЄҐіїєґ]"))
            continue
        if (StrLen(name) > bestLen) {
            bestName := name
            bestPrice := price
            bestLen := StrLen(name)
        }
    }
    StringCaseSense, %oldCaseSense%
    if (bestPrice > 0)
        outLabel := "Доставка " . bestName . " - " . bestPrice . " грн"
    return bestPrice
}

RhlHttpGet(url, timeoutMs := 6000) {
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, false)
        whr.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
        whr.SetRequestHeader("User-Agent", "RollHouseLite/1.0 (AHK)")
        whr.Send()
        return whr.ResponseText
    } catch e {
        return ""
    }
}

RhlUriEncode(str) {
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

RhlNormalizeGeoAddress(addr) {
    addr := Trim(addr)
    addr := RegExReplace(addr, "i)[,\s]+(эт|поверх|кв|квартира|под|під|п|к|парадна|корп|корпус)\.?\s*(\d+|empty).*$", "")
    addr := RegExReplace(addr, "i)\bempty\b", "")
    addr := RegExReplace(addr, "i)Чугуев|Чугуєв", "Чугуїв")
    addr := RegExReplace(addr, "i)^\s*(г\.|м\.)\s*", "")
    return Trim(addr)
}

RhlGeocode(addr, ByRef outLat, ByRef outLng) {
    outLat := "", outLng := ""
    addr := RhlNormalizeGeoAddress(addr)
    if (addr = "")
        return 0
    attempts := [addr]
    if RegExMatch(addr, "i)^(Мерефа|Берестин|Чугуїв|Харків)[,\s]+(.*)$", m)
        attempts.Push(Trim(m2))
    for idx, oneAddr in attempts {
        resp := RhlHttpGet("https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&q=" . RhlUriEncode(oneAddr), 6000)
        if (resp != "" && RegExMatch(resp, """lat"":""([^""]+)""", mLat) && RegExMatch(resp, """lon"":""([^""]+)""", mLon)) {
            outLat := mLat1 + 0
            outLng := mLon1 + 0
            return 1
        }
        if (InStr(oneAddr, ",")) {
            noHouse := Trim(RegExReplace(oneAddr, ",[^,]+$", ""))
            resp2 := RhlHttpGet("https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ua&q=" . RhlUriEncode(noHouse), 6000)
            if (resp2 != "" && RegExMatch(resp2, """lat"":""([^""]+)""", mLat2) && RegExMatch(resp2, """lon"":""([^""]+)""", mLon2)) {
                outLat := mLat21 + 0
                outLng := mLon21 + 0
                return 1
            }
        }
    }
    return 0
}

RhlLoadKml() {
    global zonesFile, RhlZones, RhlZonesOk
    RhlZones := []
    RhlZonesOk := 0
    if (!FileExist(zonesFile))
        return 0
    xml := ComObjCreate("MSXML2.DOMDocument.6.0")
    xml.async := false
    if (!xml.load(zonesFile))
        return 0
    try {
        xml.setProperty("SelectionLanguage", "XPath")
        xml.setProperty("SelectionNamespaces", "xmlns:k='http://www.opengis.net/kml/2.2'")
        placemarks := xml.selectNodes("//k:Placemark[.//k:Polygon]")
    } catch e {
        placemarks := xml.selectNodes("//Placemark")
    }
    Loop % placemarks.length {
        pm := placemarks.item(A_Index - 1)
        try nameNode := pm.selectSingleNode(".//k:name")
        catch e
            nameNode := pm.getElementsByTagName("name").item(0)
        zoneName := nameNode ? Trim(RegExReplace(nameNode.text, "[\r\n]+", " ")) : ("Зона " . A_Index)
        try coordNode := pm.selectSingleNode(".//k:Polygon//k:coordinates")
        catch e
            coordNode := ""
        if (!coordNode) {
            try coordNode := pm.selectSingleNode(".//k:coordinates")
            catch e2
                coordNode := pm.getElementsByTagName("coordinates").item(0)
        }
        if (!coordNode)
            continue
        coords := []
        rawCoords := Trim(coordNode.text)
        Loop, Parse, rawCoords, `n, `r
        {
            lf := Trim(A_LoopField)
            if (lf = "")
                continue
            parts := StrSplit(lf, ",")
            if (parts.MaxIndex() >= 2)
                coords.Push([parts[1] + 0, parts[2] + 0])
        }
        zPrice := 0
        try descNode := pm.selectSingleNode(".//k:description")
        catch e
            descNode := pm.getElementsByTagName("description").item(0)
        if (descNode && RegExMatch(descNode.text, "(\d+)", mp))
            zPrice := mp1 + 0
        if (coords.MaxIndex() >= 3)
            RhlZones.Push({name: zoneName, coords: coords, price: zPrice})
    }
    RhlZonesOk := (RhlZones.MaxIndex() > 0) ? 1 : 0
    return RhlZonesOk
}

RhlInPolygon(lng, lat, coords) {
    inside := 0
    n := coords.MaxIndex()
    j := n
    Loop % n {
        i := A_Index
        xi := coords[i][1], yi := coords[i][2]
        xj := coords[j][1], yj := coords[j][2]
        if ((yi > lat) != (yj > lat))
            if (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)
                inside := !inside
        j := i
    }
    return inside
}

RhlFindKmlZone(lng, lat) {
    global RhlZones, RhlZonesOk
    if (!RhlZonesOk)
        RhlLoadKml()
    if (!RhlZonesOk)
        return ""
    for i, z in RhlZones {
        if RhlInPolygon(lng, lat, z.coords)
            return z
    }
    return ""
}

RhlFindDeliveryByMap(addr, ByRef outLabel) {
    outLabel := ""
    if (!RhlGeocode(addr, lat, lng))
        return 0
    z := RhlFindKmlZone(lng, lat)
    if (!IsObject(z))
        return 0
    price := z.price + 0
    if (price <= 0)
        price := RhlFindDeliveryCost(z.name, tmpLabel)
    if (price > 0) {
        outLabel := "Доставка " . z.name . " - " . price . " грн"
        return price
    }
    outLabel := "Доставка " . z.name
    return 0
}

RhlMagicCleanForLite() {
    global LiteRawComment, LiteOrderSum, LiteStreetText, LiteHouseText, LiteIikoTime
    global GiftPepsi, GiftBrooklyn, GiftBurger, PayMode, LiteNoPayChange, LiteIsPickup, LitePaymentMethod
    global LiteCalcChange, LiteDeliveryCostNum, LiteDeliveryCostStr, LiteKitchenNote
    global LiteCommentBody
    global giftPepsiThreshold, giftBrooklynThreshold, giftBurgerThreshold
    global LiteReadyTime

    text := LiteRawComment
    clean := text
    GiftPepsi := 0, GiftBrooklyn := 0, GiftBurger := 0, PayMode := ""
    LiteNoPayChange := 0, LiteIsPickup := 0, LitePaymentMethod := ""
    LiteCalcChange := 0, LiteDeliveryCostNum := 0, LiteDeliveryCostStr := "", LiteKitchenNote := ""
    LiteReadyTime := ""
    parsedNorm := "", parsedEdu := ""

    isAsap := RegExMatch(text, "i)Якомога швидше|Найближчим часом|Як можна скоріше|Как можно скорее")
    extracted := ""
    if (!isAsap) {
        if RegExMatch(text, "i)(?<!\d)([01]?\d|2[0-3])\s*[:\.\-]\s*([0-5]\d)(?!\d)", tm)
            extracted := Format("{:02}:{:02}", tm1+0, tm2+0)
        else if RegExMatch(text, "i)(?<!\d)([01]?\d|2[0-3])\s+([0-5]\d)(?!\d)", tm2)
            extracted := Format("{:02}:{:02}", tm21+0, tm22+0)
    }

    if RegExMatch(text, "i)(Готівкою|Готівка|Наличными)") {
        PayMode := "cash", LitePaymentMethod := "Готівка"
    } else if RegExMatch(text, "i)(Карткою у закладі|Картою в закладі|Банківська карта|Банківська картка|Термінал|Terminal)") {
        PayMode := "card", LitePaymentMethod := "Термінал"
    } else if RegExMatch(text, "i)(Картою онлайн|Карткою онлайн|ОПЛАЧЕНО|оплачено)") {
        PayMode := "", LitePaymentMethod := "ОПЛАЧЕНО"
    } else {
        PayMode := "cash", LitePaymentMethod := "Готівка"
    }

    LiteNoPayChange := RegExMatch(text, "i)(бонус|бонусами|бали)") ? 1 : 0
    hasBonuses := RegExMatch(text, "i)(бонус|бали|знижк|промокод|discount|cashback|кешбек)")
    if (LiteOrderSum > 0 && !hasBonuses) {
        if (LiteOrderSum >= (giftBurgerThreshold + 0))
            GiftBurger := 1
        else if (LiteOrderSum >= (giftBrooklynThreshold + 0))
            GiftBrooklyn := 1
        else if (LiteOrderSum >= (giftPepsiThreshold + 0))
            GiftPepsi := 1
    }

    if (LiteStreetText = "" || RegExMatch(text, "i)(Самовивіз|Самовывоз|Точка закладу)"))
        LiteIsPickup := 1

    if (!LiteIsPickup) {
        searchPool := LiteStreetText . " " . text
        searchPool := RegExReplace(searchPool, "i)Чугуев|Чугуєв", "Чугуїв")
        LiteDeliveryCostNum := RhlFindDeliveryByMap(searchPool, LiteDeliveryCostStr)
        if (LiteDeliveryCostNum <= 0 || LiteDeliveryCostStr = "")
            LiteDeliveryCostNum := RhlFindDeliveryCost(searchPool, LiteDeliveryCostStr)
    }
    totalForChange := LiteOrderSum + LiteDeliveryCostNum

    if RegExMatch(text, "i)(?:підготувати\s*)?решт[уа]\s*з(?:[:\sз]*?)(\d+)", ch)
        LiteCalcChange := ch1 + 0
    else if (LiteIsPickup && PayMode = "cash" && totalForChange > 0)
        LiteCalcChange := Ceil(totalForChange / 200) * 200

    clean := RegExReplace(clean, "i)\d{4}-\d{2}-\d{2}", "")
    clean := RegExReplace(clean, "i)(?:\b(?:на|к|до|в|час|время)\b\s*|Час:\s*|Время:\s*)?(?<!\d)([01]?\d|2[0-3])\s*[:\.\-]\s*([0-5]\d)(?!\d)(?:\s*(?:AM|PM))?", "")
    clean := RegExReplace(clean, "i)\s*\(?Якомога швидше\)?|\s*\(?Найближчим часом\)?", "")
    clean := RegExReplace(clean, "i)(Тип оплати:|Тип оплаты:)\s*.*", "")
    clean := RegExReplace(clean, "i)Оплата:\s*.*", "")
    clean := RegExReplace(clean, "i)(?:підготувати\s*|подготовить\s*)?(решт[уа]\s*з|сдача\s*с)(?:[:\sзс]*?)\d+(?:\s*грн)?\s*", "")
    clean := RegExReplace(clean, "i)(?:Передзвонити|Перетелефонувати|Подзв|зателефону|звонить|перезвонить).*", "")

    if RegExMatch(clean, "i)(?:Коментар:|Комментарий к заказу:)\s*(.*)$", kc) {
        LiteKitchenNote := Trim(kc1)
        clean := StrReplace(clean, kc0, "")
    }
    if RegExMatch(clean, "i)Напишіть свої побажання:\s*([^;]+)", wish) {
        LiteKitchenNote := Trim(LiteKitchenNote . (LiteKitchenNote != "" ? " | " : "") . wish1)
        clean := StrReplace(clean, wish0, "")
    }

    if RegExMatch(clean, "i)(\d+)\s*(?:звичай|обыч)|(?:Звичайні|Обычные).*?(\d+)", sn) {
        parsedNorm := (sn1 != "") ? sn1 : sn2
        clean := RegExReplace(clean, "i)\d+\s*(?:звичай|обыч)[^\s,;]*|(?:Звичайні|Обычные)[^\d]*\d+", "")
    }
    if RegExMatch(clean, "i)(\d+)\s*(?:пар\s*пал|персон|прибор|учбов|навчальн|палоч|палич)|(?:Учбові|Навчальні|Кількість приборів|Количество приборов|Для).*?(\d+)", se) {
        parsedEdu := (se1 != "") ? se1 : se2
        clean := RegExReplace(clean, "i)\d+\s*(?:пар\s*пал|персон|прибор|учбов|навчальн|палоч|палич)[^\s,;]*|(?:Учбові|Навчальні|Кількість приборів|Количество приборов|Для)[^\d]*\d+", "")
    }

    clean := RhlCleanTextOneLine(clean)
    LiteCommentBody := RhlStripLitePayBits(clean)
    clean := RhlBuildLiteComment(PayMode, LiteCalcChange, LiteNoPayChange, LiteCommentBody)

    GuiControl, Lite:, LiteComment, %clean%
    GuiControl, Lite:, LiteKitchen, %LiteKitchenNote%
    liteAddrLine := LiteStreetText . (LiteHouseText != "" ? ", " . LiteHouseText : "")
    GuiControl, Lite:, LiteAddress, % ""
    GuiControl, Lite:, LiteNorm, %parsedNorm%
    GuiControl, Lite:, LiteEdu, %parsedEdu%
    GuiControl, Lite:, LiteNoChange, %LiteNoPayChange%
    if (LiteNoPayChange) {
        GuiControl, Lite:, LiteChange, % ""
    } else if (LiteCalcChange > 0) {
        GuiControl, Lite:, LiteChange, %LiteCalcChange%
    }
    if (extracted != "") {
        parts := StrSplit(extracted, ":")
        GuiControl, Lite:, LiteH, % parts[1]
        GuiControl, Lite:, LiteM, % parts[2]
        LiteReadyTime := extracted
    } else {
        RhlSetDefaultReady(LiteIsPickup ? 40 : 60)
    }
    RhlUpdateHeader()
    GoSub, LitePaintGifts
    GoSub, LitePaintPay
    RhlRefreshLiteCommentFromControls()
}

RhlUiaFindChildByName(rootAid, childName) {
    root := RhlUiaFind(rootAid)
    if (!IsObject(root))
        return ""
    try return root.FindFirstBy("Name=" . childName)
    catch e
        return ""
}

RhlUiaClickPaymentTypeRow() {
    root := RhlUiaFind("gridPaymentItems")
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
                    IikoActivate()
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
    return RhlUiaClick("gridPaymentItems")
}

RhlUiaClickPaymentSumRow() {
    root := RhlUiaFind("gridPaymentItems")
    if (IsObject(root)) {
        try el := root.FindFirstBy("Name=Сумма row 0")
        catch e
            el := ""
        if (!IsObject(el)) {
            try el := root.FindFirstBy("Name=Сума row 0")
            catch e2
                el := ""
        }
        if (IsObject(el)) {
            IikoActivate()
            try {
                el.Click()
                Sleep, % SpDly(150)
                return 1
            } catch e3 {
            }
        }
    }
    return 0
}

RhlUiaClickFirstOrderRow() {
    root := RhlUiaFind("treeListItems")
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
    IikoActivate()
    try {
        best.Click()
        Sleep, % SpDly(180)
        return 1
    } catch e3 {
        return 0
    }
}

OpenLitePult:
    GiftPepsi := 0, GiftBrooklyn := 0, GiftBurger := 0, PayMode := ""
    RhlReadFromSyrve()
    Gui, Lite:Destroy
    Gui, Lite:+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox
    Gui, Lite:Color, F5F6F8
    Gui, Lite:Font, s9, Segoe UI
    Gui, Lite:Add, Text, x14 y10 w240 h22 c1F1F1F, RollHouse Lite
    Gui, Lite:Add, Button, x272 y8 w34 h26 gOpenLiteSettings, ⚙
    Gui, Lite:Add, Button, x310 y8 w28 h26 gLiteGuiClose, ×
    Gui, Lite:Add, Text, x14 y28 w324 h16 c666666 vLiteHeaderInfo, Сума: читаю...

    Gui, Lite:Add, Text, x14 y44 w80 h18 c666666, Коментар
    Gui, Lite:Add, Edit, x94 y42 w244 r3 vLiteComment
    Gui, Lite:Add, Text, x14 y104 w80 h22 c666666, Кухня
    Gui, Lite:Add, Edit, x94 y102 w244 h22 vLiteKitchen
    Gui, Lite:Add, Text, x14 y134 w80 h22 c666666, Адреса
    Gui, Lite:Add, Edit, x94 y132 w244 h22 vLiteAddress
    Gui, Lite:Add, Text, x14 y164 w80 h22 c666666, Карта
    Gui, Lite:Add, Edit, x94 y162 w244 h22 vLiteCard

    Gui, Lite:Add, Text, x14 y210 w80 h22 c666666, Оплата
    Gui, Lite:Add, Button, x94 y206 w76 h30 gLitePayCash vLiteCashBtn, Готівка
    Gui, Lite:Add, Button, x178 y206 w76 h30 gLitePayCard vLiteCardBtn, Картка
    Gui, Lite:Add, CheckBox, x264 y212 w74 h22 vLiteNoChange gLiteNoChangeToggle, Без здачі
    Gui, Lite:Add, Text, x14 y246 w80 h22 c666666, Решта з
    Gui, Lite:Add, Edit, x94 y244 w76 h22 Number vLiteChange gLiteChangeEdited

    Gui, Lite:Add, Text, x14 y284 w80 h22 c666666, Подарунок
    Gui, Lite:Add, Button, x94 y280 w76 h30 gLiteGiftPepsi vLiteGiftP, Пепсі
    Gui, Lite:Add, Button, x178 y280 w76 h30 gLiteGiftBrook vLiteGiftB, Бруклін
    Gui, Lite:Add, Button, x262 y280 w76 h30 gLiteGiftBurg vLiteGiftU, Бургер

    Gui, Lite:Add, Text, x14 y326 w80 h22 c666666, СІВ
    Gui, Lite:Add, Text, x94 y326 w24 h22, Рол
    Gui, Lite:Add, Edit, x120 y324 w34 h22 Center Number vLiteRolls
    Gui, Lite:Add, Text, x162 y326 w20 h22, Зв
    Gui, Lite:Add, Edit, x184 y324 w34 h22 Center Number vLiteNorm
    Gui, Lite:Add, Text, x226 y326 w20 h22, Уч
    Gui, Lite:Add, Edit, x248 y324 w34 h22 Center Number vLiteEdu
    Gui, Lite:Add, Button, x290 y322 w48 h28 gLiteSivOnly, СІВ

    Gui, Lite:Add, Text, x14 y364 w80 h22 c666666, Час
    FormatTime, hh,, HH
    FormatTime, mm,, mm
    Gui, Lite:Add, Edit, x94 y362 w36 h24 Center Limit2 Number vLiteH gLiteTimeEdited, %hh%
    Gui, Lite:Add, Text, x134 y364 w8 h22, :
    Gui, Lite:Add, Edit, x146 y362 w36 h24 Center Limit2 Number vLiteM gLiteTimeEdited, %mm%
    Gui, Lite:Add, Button, x194 y362 w44 h24 gLitePlus40, +40
    Gui, Lite:Add, Button, x242 y362 w44 h24 gLitePlus60, +60
    Gui, Lite:Add, Button, x290 y362 w48 h24 gLitePlus90, +90

    Gui, Lite:Add, Text, x14 y398 w324 h32 c666666 vLitePreview, Enter: внесе поля, подарунок, оплату, СІВ
    Gui, Lite:Add, Button, x14 y438 w324 h38 Default gLiteApply, Внести в Syrve
    Gui, Lite:Show, w352 h490, RollHouse Lite
    RhlMagicCleanForLite()
return

LiteGuiClose:
LiteGuiEscape:
    Gui, Lite:Destroy
return

LitePayCash:
    PayMode := "cash"
    GoSub, LitePaintPay
    RhlRefreshLiteCommentFromControls()
return

LitePayCard:
    PayMode := "card"
    GuiControl, Lite:, LiteNoChange, 0
    GuiControl, Lite:, LiteChange, % ""
    GoSub, LitePaintPay
    RhlRefreshLiteCommentFromControls()
return

LiteNoChangeToggle:
    RhlRefreshLiteCommentFromControls()
return

LiteChangeEdited:
    RhlRefreshLiteCommentFromControls()
return

LiteTimeEdited:
    RhlRefreshLiteCommentFromControls()
return

LitePaintPay:
    GuiControl, Lite:, LiteCashBtn, % PayMode = "cash" ? "✓ Готівка" : "Готівка"
    GuiControl, Lite:, LiteCardBtn, % PayMode = "card" ? "✓ Картка" : "Картка"
return

LiteGiftPepsi:
    GiftPepsi := !GiftPepsi, GiftBrooklyn := 0, GiftBurger := 0
    GoSub, LitePaintGifts
return
LiteGiftBrook:
    GiftBrooklyn := !GiftBrooklyn, GiftPepsi := 0, GiftBurger := 0
    GoSub, LitePaintGifts
return
LiteGiftBurg:
    GiftBurger := !GiftBurger, GiftPepsi := 0, GiftBrooklyn := 0
    GoSub, LitePaintGifts
return
LitePaintGifts:
    GuiControl, Lite:, LiteGiftP, % GiftPepsi ? "✓ Пепсі" : "Пепсі"
    GuiControl, Lite:, LiteGiftB, % GiftBrooklyn ? "✓ Бруклін" : "Бруклін"
    GuiControl, Lite:, LiteGiftU, % GiftBurger ? "✓ Бургер" : "Бургер"
    RhlUpdateHeader()
return

LitePlus40:
    LiteAddMinutes(40)
return
LitePlus60:
    LiteAddMinutes(60)
return
LitePlus90:
    LiteAddMinutes(90)
return

LiteAddMinutes(delta) {
    Gui, Lite:Submit, NoHide
    t := A_Now
    EnvAdd, t, %delta%, Minutes
    FormatTime, h, %t%, HH
    FormatTime, m, %t%, mm
    GuiControl, Lite:, LiteH, %h%
    GuiControl, Lite:, LiteM, %m%
    RhlRefreshLiteCommentFromControls()
}

#IfWinActive RollHouse Lite
Enter::GoSub, LiteApply
NumpadEnter::GoSub, LiteApply
+Enter::Send, {Enter}
+NumpadEnter::Send, {Enter}
#IfWinActive

LiteSivOnly:
    Gui, Lite:Submit, NoHide
    LitePunchSiv(LiteRolls, LiteNorm, LiteEdu)
return

OpenSivOnly:
    Gui, Siv:Destroy
    Gui, Siv:+AlwaysOnTop +ToolWindow
    Gui, Siv:Font, s9, Segoe UI
    Gui, Siv:Add, Text, x12 y12 w40 h22, Роли
    Gui, Siv:Add, Edit, x56 y10 w42 h22 Center Number vSivRolls
    Gui, Siv:Add, Text, x110 y12 w30 h22, Зв
    Gui, Siv:Add, Edit, x140 y10 w42 h22 Center Number vSivNorm
    Gui, Siv:Add, Text, x194 y12 w30 h22, Уч
    Gui, Siv:Add, Edit, x224 y10 w42 h22 Center Number vSivEdu
    Gui, Siv:Add, Button, x12 y46 w254 h30 Default gSivApplyOnly, Пробити СІВ
    Gui, Siv:Show, w280 h90, RollHouse Lite SIV
return

SivApplyOnly:
    Gui, Siv:Submit
    Gui, Siv:Destroy
    LitePunchSiv(SivRolls, SivNorm, SivEdu)
return
SivGuiClose:
SivGuiEscape:
    Gui, Siv:Destroy
return

LiteApply:
    global LiteReadyTime
    if (LiteBusy) {
        ToolTip, Lite вже виконує цепочку...
        SetTimer, LiteTipOff, -1200
        return
    }
    LiteBusy := 1
    Gui, Lite:Submit, NoHide
    GuiControl, Lite:, LitePreview, Працюю... не чіпай Syrve кілька секунд
    Gui, Lite:Hide

    ready := ""
    if (LiteH != "" || LiteM != "")
        ready := Format("{:02}:{:02}", LiteH = "" ? 0 : LiteH, LiteM = "" ? 0 : LiteM)
    else if (LiteReadyTime != "")
        ready := LiteReadyTime

    IikoActivate()
    Sleep, % SpDly(150)
    RhlReportInit()
    _okComment := 1
    if (LiteComment != "") {
        _okComment := RhlUiaSetValue("memoEditDeliveryComment", LiteComment)
        if (!_okComment) {
            PasteRel(commRelX, commRelY, commX, commY, LiteComment)
            _okComment := (commX || commRelX) ? 1 : 0
        }
    }
    RhlReportStep("Коментар", _okComment, LiteComment = "" ? "порожній, пропущено" : "")

    customerInfoText := RhlJoinNonEmpty(LiteKitchen, LiteCard)
    _okKitchen := 1
    if (customerInfoText != "") {
        if (RhlUiaDoublePaste("memoEditCustomerComment", customerInfoText)) {
            _okKitchen := 1
        } else if (infoX || infoRelX) {
            PasteRel(infoRelX, infoRelY, infoX, infoY, customerInfoText)
            _okKitchen := 1
        } else {
            _okKitchen := 0
        }
    }
    RhlReportStep("Кухня/карта", _okKitchen, customerInfoText = "" ? "порожньо, пропущено" : (!(_okKitchen) ? "не найдено поле memoEditCustomerComment и не задан прицел кухни" : ""))

    _okAddr := 1
    if (LiteAddress != "") {
        if (RhlUiaSetValue("memoEditDeliveryAddressComment", LiteAddress))
            _okAddr := 1
        else if (addrX || addrRelX) {
            PasteRel(addrRelX, addrRelY, addrX, addrY, LiteAddress)
            _okAddr := 1
        } else {
            _okAddr := 0
        }
    }
    RhlReportStep("Адресний комент", _okAddr, LiteAddress = "" ? "порожній, не чіпаю адресу" : "")

    _okTime := 1
    if (ready != "")
        _okTime := LiteSetReadyTime(ready)
    RhlReportStep("Час", _okTime, ready = "" ? "порожній" : ready)

    if (GiftBurger)
        _okGift := LitePunchGift(pluBurger)
    else if (GiftBrooklyn)
        _okGift := LitePunchGift(pluBrooklyn)
    else if (GiftPepsi)
        _okGift := LitePunchGift(pluPepsi)
    else
        _okGift := 1
    RhlReportStep("Подарунок", _okGift, (GiftBurger || GiftBrooklyn || GiftPepsi) ? "" : "не потрібен")

    _okPay := LiteApplyPayment(PayMode, LiteChange, LiteNoChange)
    RhlReportStep("Оплата", _okPay, PayMode = "" ? "не змінюю" : PayMode)
    _okSiv := LitePunchSiv(LiteRolls, LiteNorm, LiteEdu)
    _sivDetail := "рол=" . (LiteRolls = "" ? 0 : LiteRolls) . " зв=" . (LiteNorm = "" ? 0 : LiteNorm) . " уч=" . (LiteEdu = "" ? 0 : LiteEdu)
    RhlReportStep("СІВ", _okSiv, _sivDetail)

    RhlReportFinish()
    Gui, Lite:Show
    LiteBusy := 0
return

LiteSetReadyTime(ready) {
    global timeRelX, timeRelY, timeX, timeY
    parts := StrSplit(ready, ":")
    if (RhlUiaSetValue("timeEditDeliveryTime", ready)) {
        Sleep, 180
        got0 := RhlUiaGetValue("timeEditDeliveryTime")
        if (InStr(got0, ready))
            return 1
    }
    if (RhlUiaFocus("timeEditDeliveryTime")) {
        Send, {Home}
        Sleep, 80
        Send, {Del}{Del}{Del}{Del}{Del}
        Sleep, 80
        Send, % parts[1]
        Sleep, 80
        Send, {Right}
        Sleep, 60
        Send, % parts[2]
        Sleep, 120
        Send, {Enter}
        Sleep, 180
        got := RhlUiaGetValue("timeEditDeliveryTime")
        if (InStr(got, ready))
            return 1
    }
    if (!ClickRel(timeRelX, timeRelY, timeX, timeY))
        return 0
    Sleep, % SpDly(150)
    Send, {Home}
    Sleep, 60
    Send, {Del}{Del}{Del}{Del}{Del}
    Sleep, 60
    Send, % parts[1]
    Sleep, 80
    Send, {Right}
    Sleep, 60
    Send, % parts[2]
    Sleep, 120
    Send, {Tab}
    Sleep, 180
    got2 := RhlUiaGetValue("timeEditDeliveryTime")
    return InStr(got2, ready) ? 1 : 0
}

LitePunchGift(plu) {
    global itemRelX, itemRelY, itemX, itemY
    if (plu = "" || plu = "0000")
        return 0
    IikoXY(itemRelX, itemRelY, itemX, itemY, x, y)
    ok := PunchByPlu(plu, 1, x, y, "🎁")
    Sleep, % SpDly(700)
    return ok
}

LiteApplyPayment(mode, changeAmount, noChangeFlag) {
    global crossRelX, crossRelY, crossX, crossY, cashRelX, cashRelY, cashX, cashY, changeRelX, changeRelY, changeX, changeY, noChangeRelX, noChangeRelY, noChangeX, noChangeY
    global paymentCashSearch, paymentCardSearch
    if (mode = "" && !noChangeFlag)
        return 1
    ok := 1
    if (!RhlUiaClick("buttonDeletePaymentItem")) {
        if (crossX || crossRelX)
            ok := ClickRel(crossRelX, crossRelY, crossX, crossY)
        else
            ok := 0
    }
    Sleep, % SpDly(450)
    if (mode != "") {
        if (!RhlUiaClickPaymentTypeRow())
            ok := ClickRel(cashRelX, cashRelY, cashX, cashY)
        Sleep, % SpDly(250)
        if (!RhlUiaClickPaymentTypeRow())
            ok := ClickRel(cashRelX, cashRelY, cashX, cashY)
        Sleep, % SpDly(450)
        s := (mode = "cash") ? paymentCashSearch : paymentCardSearch
        Send, %s%
        Sleep, % SpDly(400)
        Send, {Enter}
        Sleep, % SpDly(450)
    }
    if (mode = "cash" && changeAmount != "" && changeAmount > 0) {
        if (!RhlUiaClickPaymentSumRow() && !ClickRel(changeRelX, changeRelY, changeX, changeY, 1))
            ok := 0
        Sleep, % SpDly(200)
        Send, %changeAmount%
        Sleep, % SpDly(200)
        Send, {NumpadEnter}
    } else if (noChangeFlag) {
        if (!RhlUiaClick("buttonNoChange"))
            ok := ClickRel(noChangeRelX, noChangeRelY, noChangeX, noChangeY)
    }
    return ok
}

LitePunchSiv(rolls, norm, edu) {
    global itemRelX, itemRelY, itemX, itemY, pluSticksNorm, pluSticksEdu, pluSoy, pluGinger, pluWasabi
    rolls := rolls = "" ? 0 : rolls + 0
    norm := norm = "" ? 0 : norm + 0
    edu := edu = "" ? 0 : edu + 0
    soy := rolls > 0 ? Floor((rolls + 1) / 2) : 0
    gw := rolls > 0 ? Floor((rolls + 3) / 4) : 0
    totalSticks := norm + edu
    if (totalSticks > 0) {
        soy := soy > totalSticks ? totalSticks : soy
        gw := gw > totalSticks ? totalSticks : gw
    }
    if (norm <= 0 && edu <= 0 && soy <= 0 && gw <= 0)
        return 1
    IikoXY(itemRelX, itemRelY, itemX, itemY, x, y)
    ok := 1
    if (norm > 0)
        ok := PunchByPlu(pluSticksNorm, norm, x, y, "🥢") && ok
    if (edu > 0)
        ok := PunchByPlu(pluSticksEdu, edu, x, y, "🥢") && ok
    if (soy > 0)
        ok := PunchByPlu(pluSoy, soy, x, y, "🥣") && ok
    if (gw > 0) {
        ok := PunchByPlu(pluGinger, gw, x, y, "🥣") && ok
        ok := PunchByPlu(pluWasabi, gw, x, y, "🥣") && ok
    }
    ToolTip
    return ok
}

PunchByPlu(pluCode, qty, itX, itY, prefix := "PLU") {
    if (qty <= 0 || pluCode = "" || pluCode = "0000")
        return 0
    ToolTip, % prefix . " PLU " . pluCode . " ×" . qty, 30, 60
    if (!RhlFocusOrderTable(itX, itY))
        return 0
    Sleep, % SpDly(250)
    Send, {PgDn}
    Sleep, % SpDly(250)
    Send, {Enter}
    Sleep, % SpDly(350)
    Send, %pluCode%
    Sleep, % SpDly(250)
    Send, {Down}
    Sleep, % SpDly(220)
    Send, {Enter}
    Sleep, % SpDly(420)
    Send, %qty%
    Sleep, % SpDly(250)

    ClipSaved := ClipboardAll
    Clipboard :=
    Send, ^a
    Sleep, % SpDly(120)
    Send, ^c
    ClipWait, 1
    copiedQty := Trim(Clipboard)
    Clipboard := ClipSaved
    ClipSaved :=
    copiedQtyNum := RegExReplace(copiedQty, "[^\d]", "") + 0
    expectedQty := qty + 0
    verified := (copiedQtyNum = expectedQty)

    if (!verified) {
        ToolTip, % "⚠ PLU " . pluCode . ": qty очікував " . expectedQty . ", clipboard=[" . copiedQty . "]", 30, 60
        Sleep, % SpDly(900)
        return 0
    }

    Send, {Enter}
    Sleep, % SpDly(180)
    Send, {Enter}
    Sleep, % SpDly(300)
    return 1
}

RhlFocusOrderTable(itX, itY) {
    IikoActivate()
    Sleep, % SpDly(100)
    if (RhlUiaClickFirstOrderRow())
        return 1
    if (!itX || !itY)
        return 0
    MouseGetPos, mx, my
    Click, %itX%, %itY%
    Sleep, % SpDly(180)
    MouseMove, %mx%, %my%, 0
    return 1
}

OpenLiteSettings:
    LoadConfig()
    Gui, Set:Destroy
    Gui, Set:+AlwaysOnTop +ToolWindow
    Gui, Set:Font, s9, Segoe UI
    Gui, Set:Add, Text, x12 y10 w360 h48, UIA вже закриває коментар, кухню/карту клієнта, адресу, час, оплату, без здачі, суму та таблицю PLU.`nРучних прицілів більше немає.
    Gui, Set:Add, Text, x12 y78 w80 h22, Готівка:
    Gui, Set:Add, Edit, x92 y76 w80 h22 vSetCashSearch, %paymentCashSearch%
    Gui, Set:Add, Text, x192 y78 w60 h22, Картка:
    Gui, Set:Add, Edit, x252 y76 w110 h22 vSetCardSearch, %paymentCardSearch%
    Gui, Set:Add, Button, x12 y116 w350 h28 gSetLoadKml, Завантажити KML зон
    Gui, Set:Add, Button, x12 y160 w350 h30 gSetSave, Зберегти
    Gui, Set:Show, w376 h204, RollHouse Lite Settings
return

SetSave:
    Gui, Set:Submit, NoHide
    IniWrite, %SetCashSearch%, %configFile%, Payment, CashSearch
    IniWrite, %SetCardSearch%, %configFile%, Payment, CardSearch
    LoadConfig()
return

SetTest:
    MsgBox, 64, RollHouse Lite, Ручних прицілів більше немає. Основні поля працюють через UIA/WinAPI.
    ToolTip
return

SetLoadKml:
    FileSelectFile, pickedKml, 3,, Обери RollHouse KML zones, KML (*.kml)
    if (pickedKml = "")
        return
    FileCopy, %pickedKml%, %zonesFile%, 1
    RhlZones := []
    RhlZonesOk := 0
    ok := RhlLoadKml()
    if (ok)
        MsgBox, 64, KML, KML завантажено: %zonesFile%
    else
        MsgBox, 48, KML, Файл скопійовано, але зони не прочитались. Перевір KML.
return

SetComm:
    CaptureTarget("Comm")
return
SetInfo:
    CaptureTarget("Info")
return
SetAddr:
    CaptureTarget("Addr")
return
SetCard:
    CaptureTarget("Card")
return
SetTime:
    CaptureTarget("Time")
return
SetItem:
    CaptureTarget("Item")
return
SetCross:
    CaptureTarget("Cross")
return
SetCash:
    CaptureTarget("Cash")
return
SetChange:
    CaptureTarget("Change")
return
SetNoChange:
    CaptureTarget("NoChange")
return

CaptureTarget(key) {
    global configFile
    Gui, Set:Hide
    ToolTip, % "Наведи мишу на точку " . key . " і натисни Enter", 30, 30
    KeyWait, Enter, D
    MouseGetPos, x, y
    IniWrite, %x%, %configFile%, Targets, %key%X
    IniWrite, %y%, %configFile%, Targets, %key%Y
    if (IikoWindowRect(wx, wy, ww, wh)) {
        rx := x - wx, ry := y - wy
        IniWrite, %rx%, %configFile%, TargetsRel, %key%X
        IniWrite, %ry%, %configFile%, TargetsRel, %key%Y
        IniWrite, %ww%, %configFile%, Targets, IikoWinW
        IniWrite, %wh%, %configFile%, Targets, IikoWinH
    }
    ToolTip, % key . " збережено", 30, 30
    SetTimer, LiteTipOff, -900
    LoadConfig()
    Gui, Set:Show
}

ShowTarget(x, y, label) {
    if (!x || !y) {
        ToolTip, % label . ": не задано", 30, 30
        Sleep, 600
        return
    }
    MouseMove, %x%, %y%, 10
    ToolTip, % label, % x + 16, % y + 16
    Sleep, 700
}

SetGuiClose:
SetGuiEscape:
    Gui, Set:Destroy
return

LiteTipOff:
    ToolTip
return

LiteExit:
ExitApp
