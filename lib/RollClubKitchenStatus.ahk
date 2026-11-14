; Kitchen presentation only. No order entry, time changes or Syrve activation.
RcKitchenMode(value) {
    return RegExMatch(value, "i)предзаказ|передзамов|по пред") ? "По предам" : (value != "" ? value : "Стандарт")
}

RcKitchenCardModel(k, nowUTC := "", syncFailed := false) {
    if (!IsObject(k))
        return ""
    preorder := RegExMatch(k.Center . " " . k.Pickup . " " . k.FarZone, "i)предзаказ|передзамов|по пред")
    age := nowUTC != "" ? nowUTC : A_NowUTC
    stamp := k.UpdatedUTC
    validStamp := RegExMatch(stamp, "^\d{14}$")
    if (validStamp)
        EnvSub, age, %stamp%, Seconds
    fresh := !syncFailed && validStamp && age >= -60 && age <= 600
    known := k.DataVersion == "2" && k.SlotsLoaded == "1" && fresh
    mode := "Центр: " . RcKitchenMode(k.Center) . "`r`nДальня: " . RcKitchenMode(k.FarZone) . "`r`nСамовивіз: " . RcKitchenMode(k.Pickup)
    open := "Доступні: " . (known ? (k.PreorderAvailable != "" ? k.PreorderAvailable : "немає") : "не підтверджено")
    limited := "Обмежено: " . (known ? (k.PreorderLimited != "" ? k.PreorderLimited : "немає") : "не підтверджено")
    body := "Стоп цеха: " . (k.DataVersion != "2" ? "не завантажено" : (k.StopWorkshop != "" ? k.StopWorkshop : "немає"))
    body .= "`r`n`r`nСтоп-позиції: " . (k.DataVersion != "2" ? "не завантажено" : (k.StopList != "" ? k.StopList : "немає"))
    if (k.Remark != "")
        body .= "`r`n`r`nПримітка / режим роботи: " . k.Remark
    if (k.Terminal != "")
        body .= "`r`n`r`nТермінал: " . k.Terminal
    if (!fresh || k.DataVersion != "2")
        body := "УВАГА: дані застарілі або не завантажені. Оновіть перед прийманням.`r`n`r`n" . body
    else if (preorder && k.SlotsLoaded != "1")
        body := "Години предзамовлень не завантажені.`r`n`r`n" . body
    if (validStamp) {
        FormatTime, updated, %stamp%, dd.MM HH:mm
        body .= "`r`n`r`nОновлено: " . updated . " UTC. Автооновлення: 3 хв."
    }
    summary := k.Name . (preorder ? " | По предам" : " | " . RcKitchenMode(k.Center))
    if (k.StopList != "" || k.StopWorkshop != "")
        summary .= " | СТОП"
    return {title: k.Name . (k.City != "" ? " / " . k.City : ""), mode: mode, open: open, limited: limited, body: body, summary: summary, preorder: preorder, known: known}
}

RcKitchenCardBounds(owner, work, scale := 1) {
    gap := Round(8 * scale)
    rightSpace := work.r - owner.r - gap
    leftSpace := owner.x - work.x - gap
    sideRight := rightSpace >= Min(Round(340 * scale), leftSpace)
    space := sideRight ? rightSpace : leftSpace
    w := Min(Round(340 * scale), space)
    ; If neither side fits, keep the card inside the work area with overlap.
    w := Min(work.r - work.x, Max(Round(220 * scale), w))
    h := Min(Round(420 * scale), work.b - work.y)
    x := sideRight ? owner.r + gap : owner.x - gap - w
    x := Max(work.x, Min(x, work.r - w))
    y := Max(work.y, Min(owner.y, work.b - h))
    return {x:x, y:y, w:w, h:h}
}

RcKitchenPresent(k, extra := "") {
    global RcKC, RollHwnd, RcKitchenSyncFailed
    if (!IsObject(RcKC))
        RcKC := {}
    RcKC.k := k
    RcKC.extra := extra
    m := RcKitchenCardModel(k, "", RcKitchenSyncFailed)
    if (!IsObject(m)) {
        RcKitchenCardHide()
        return
    }
    GuiControl, Roll:, KitchenStatusText, % (extra != "" ? extra . " | " : "") . m.summary
    if (!RcKC.dismissed)
        RcKitchenCardShow()
}

RcShowKitchenCard() {
    global RcKC
    RcKC.dismissed := false
    RcKitchenCardShow()
}

RcKitchenCardShow(scale := 0) {
    global RcKC, RollHwnd, RhC_BG, RhC_Panel, RhC_Text, RhC_Muted, RhB_TintGreen, RhB_TintAmber, RhB_Text, RhB_Chip, RcKitchenSyncFailed
    if (!IsObject(RcKC) || !IsObject(RcKC.k) || !DllCall("IsWindowVisible", "Ptr", RollHwnd))
        return
    m := RcKitchenCardModel(RcKC.k, "", RcKitchenSyncFailed)
    if (!scale)
        scale := RcKC.scale ? RcKC.scale : A_ScreenDPI / 96
    RcKC.scale := scale
    if (!DllCall("IsWindow", "Ptr", RcKC.hwnd)) {
        Gui, KitchenCard:New, +Owner%RollHwnd% +ToolWindow -MinimizeBox -MaximizeBox +Hwndhwnd +LabelRcKitchenCard -DPIScale
        RcKC.hwnd := hwnd
        Gui, KitchenCard:Color, %RhC_BG%, %RhC_Panel%
        fontSize := 9 * scale / (A_ScreenDPI / 96)
        Gui, KitchenCard:Font, s%fontSize% c%RhC_Text%, Segoe UI
        Gui, KitchenCard:Add, Text, hwndhTitle
        RcKC.title := hTitle
        Gui, KitchenCard:Add, Text, hwndhMode
        RcKC.mode := hMode
        Gui, KitchenCard:Add, Edit, ReadOnly +Multi +VScroll -HScroll hwndhOpen
        RcKC.open := hOpen
        Gui, KitchenCard:Add, Edit, ReadOnly +Multi +VScroll -HScroll hwndhLimited
        RcKC.limited := hLimited
        RhRegColor(hOpen, RhB_TintGreen, RhB_Text)
        RhRegColor(hLimited, RhB_TintAmber, RhB_Text)
        Gui, KitchenCard:Add, Edit, ReadOnly +Multi +VScroll -HScroll hwndhBody
        RcKC.body := hBody
        Gui, KitchenCard:Add, Button, gRcKitchenCardRefresh hwndhRefresh, Оновити дані
        RcKC.refresh := hRefresh
    }
    RhRegColor(RcKC.open, m.known ? RhB_TintGreen : RhB_Chip, RhB_Text)
    RhRegColor(RcKC.limited, m.known ? RhB_TintAmber : RhB_Chip, RhB_Text)
    GuiControl, KitchenCard:, % RcKC.title, % m.title
    GuiControl, KitchenCard:, % RcKC.mode, % m.mode
    GuiControl, KitchenCard:, % RcKC.open, % m.open
    GuiControl, KitchenCard:, % RcKC.limited, % m.limited
    GuiControl, KitchenCard:, % RcKC.body, % (RcKC.extra != "" ? RcKC.extra . "`r`n`r`n" : "") . m.body
    WinGetPos, ox, oy, ow, oh, ahk_id %RollHwnd%
    SysGet, count, MonitorCount
    Loop, %count% {
        SysGet, wa, MonitorWorkArea, %A_Index%
        if (ox + ow/2 >= waLeft && ox + ow/2 < waRight && oy >= waTop && oy < waBottom)
            break
    }
    b := RcKitchenCardBounds({x:ox,y:oy,r:ox+ow}, {x:waLeft,y:waTop,r:waRight,b:waBottom}, scale)
    WinGet, style, Style, % "ahk_id " RcKC.hwnd
    WinGet, exStyle, ExStyle, % "ahk_id " RcKC.hwnd
    VarSetCapacity(frame, 16, 0)
    DllCall("AdjustWindowRectEx", "Ptr", &frame, "UInt", style, "Int", 0, "UInt", exStyle)
    cw := b.w - (NumGet(frame, 8, "Int") - NumGet(frame, 0, "Int"))
    ch := b.h - (NumGet(frame, 12, "Int") - NumGet(frame, 4, "Int"))
    margin := Round(12 * scale)
    width := cw - 2 * margin
    y := margin
    RcKitchenCardMove(RcKC.title, margin, y, width, Round(24 * scale))
    y += Round(28 * scale)
    RcKitchenCardMove(RcKC.mode, margin, y, width, Round(60 * scale))
    y += Round(64 * scale)
    for _, control in [RcKC.open, RcKC.limited] {
        GuiControl, % "KitchenCard:" . (m.preorder ? "Show" : "Hide"), %control%
        if (m.preorder) {
            RcKitchenCardMove(control, margin, y, width, Round(36 * scale))
            y += Round(40 * scale)
        }
    }
    footer := Round(30 * scale)
    RcKitchenCardMove(RcKC.body, margin, y, width, Max(Round(40 * scale), ch-y-footer-margin))
    RcKitchenCardMove(RcKC.refresh, margin, ch-footer, width, Round(24 * scale))
    Gui, KitchenCard:Show, % "NoActivate x" b.x " y" b.y " w" cw " h" ch, Кухня / доступність
    RcKC.renderTick := A_TickCount
    RcKC.ownerPos := ox . "," . oy . "," . ow . "," . oh
    timer := Func("RcKitchenCardTick")
    SetTimer, %timer%, 300
}

RcKitchenCardMove(control, x, y, w, h) {
    GuiControl, KitchenCard:Move, %control%, % "x" x " y" y " w" w " h" h
}

RcKitchenCardHide() {
    Gui, KitchenCard:Hide
}

RcKitchenCardTick() {
    global RcKC, RollHwnd, RcKitchenSyncFailed
    if (!IsObject(RcKC) || !DllCall("IsWindow", "Ptr", RcKC.hwnd))
        return
    WinGet, state, MinMax, ahk_id %RollHwnd%
    if (!DllCall("IsWindowVisible", "Ptr", RollHwnd) || state == -1 || RcKC.dismissed) {
        RcKitchenCardHide()
        return
    }
    WinGetPos, x, y, w, h, ahk_id %RollHwnd%
    pos := x . "," . y . "," . w . "," . h
    if (!DllCall("IsWindowVisible", "Ptr", RcKC.hwnd) || RcKC.ownerPos != pos || A_TickCount - RcKC.renderTick > 30000)
        RcKitchenCardShow()
}

RcKitchenCardClose() {
    global RcKC
    RcKC.dismissed := true
    RcKitchenCardHide()
}

RcKitchenCardEscape() {
    RcKitchenCardClose()
}

RcKitchenCardRefresh() {
    global
    if (RcKitchensSyncBlocked())
        return
    oldName := RcKC.k.Name
    RcKitchenLastSyncTick := 0
    GoSub, RcKitchensSyncIfStale
    for _, k in Kitchens {
        if (k.Name == oldName) {
            RcCurrentKitchen := k
            RcKitchenPresent(k, RcKC.extra)
            break
        }
    }
}
