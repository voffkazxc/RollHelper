; ==============================================================================
; FILE: RollHelper/lib/IikoUI.ahk
; ARCHITECTURE LAYER: High-Level Domain UI Facade (Production-Grade)
; RESPONSIBILITY: Clean business API for all iiko UI actions.
;                 Integrates AutomationIds with legacy coordinate fallbacks.
; ==============================================================================

#Include %A_ScriptDir%\lib\IikoDriver.ahk

; --- DOMAIN API: DELIVERY CARD ACTIONS ---

; 1. Нажать "Найти точку"
IikoUI_AssignDeliveryTerminal() {
    global naitiX, naitiY
    return IikoDriver_ClickElement("buttonAssignDeliveryTerminal", naitiX, naitiY)
}

; 2. Нажать "Сохранить на точку"
IikoUI_SaveAndClose() {
    global saveX, saveY
    return IikoDriver_ClickElement("buttonSaveAndClose", saveX, saveY)
}

; 3. Нажать "Подтвердить"
IikoUI_ConfirmDelivery() {
    global confirmX, confirmY
    return IikoDriver_ClickElement("buttonDeliveryConfirmation", confirmX, confirmY)
}

; 4. Нажать "Отменить доставку"
IikoUI_CancelDelivery() {
    return IikoDriver_ClickElement("buttonCancelDelivery")
}

; 5. Выйти / Закрыть карточку
IikoUI_CloseForm() {
    return IikoDriver_ClickElement("buttonClose")
}

; 6. Открыть карту районов
IikoUI_OpenRegionsMap() {
    return IikoDriver_ClickElement("buttonDeliveryRegionsMap")
}

; 7. Прийняти вхідний PBX-дзвінок.
IikoUI_GetPbxAcceptButton(onlyEnabled := false) {
    iikoWin := IikoDriver_GetWindow()
    if (!iikoWin)
        return ""

    buttonQueries := ["AutomationId=btnPbxCallAccept", "Name=Принять", "Name=Прийняти"]
    fallbackButton := ""
    for _, buttonQuery in buttonQueries {
        try {
            candidates := iikoWin.FindAllBy(buttonQuery)
        } catch e {
            IikoDriver_Log("PBX_ACCEPT_FIND_ERROR query='" . buttonQuery . "': " . e.Message, "WARN")
            continue
        }

        if (!IsObject(candidates) || !candidates.MaxIndex())
            continue

        Loop, % candidates.MaxIndex() {
            button := candidates[A_Index]
            try {
                rect := button.CurrentBoundingRectangle
                nativeHwnd := button.CurrentNativeWindowHandle
                if (button.CurrentIsOffscreen || rect.w <= 0 || rect.h <= 0 || !nativeHwnd)
                    continue

                if (button.CurrentIsEnabled)
                    return button

                if (!onlyEnabled && !IsObject(fallbackButton))
                    fallbackButton := button
            } catch e {
                continue
            }
        }
    }

    return fallbackButton
}

IikoUI_IsElementEnabled(element) {
    if (!IsObject(element))
        return 0

    try {
        return element.CurrentIsEnabled ? 1 : 0
    } catch e {
        return -1
    }
}

IikoUI_GetElementHwnd(element) {
    if (!IsObject(element))
        return 0

    try {
        nativeHwnd := element.CurrentNativeWindowHandle
        if (nativeHwnd && DllCall("IsWindow", "Ptr", nativeHwnd))
            return nativeHwnd
    } catch e {
        return 0
    }

    return 0
}

IikoUI_IsHwndEnabled(nativeHwnd) {
    if (!nativeHwnd)
        return 0
    if (!DllCall("IsWindow", "Ptr", nativeHwnd))
        return -1
    return DllCall("IsWindowEnabled", "Ptr", nativeHwnd) ? 1 : 0
}

IikoUI_AcceptPbxCall(button := "") {
    if (!IsObject(button))
        button := IikoUI_GetPbxAcceptButton()
    if (!IsObject(button))
        return false

    try {
        if (!button.CurrentIsEnabled)
            return false

        if (button.Click()) {
            IikoDriver_Log("NATIVE_SUCCESS: PBX accept invoked through UIA pattern")
            return true
        }

        nativeHwnd := button.CurrentNativeWindowHandle
        if (!nativeHwnd) {
            IikoDriver_Log("PBX_ACCEPT_CLICK_ERROR: NativeWindowHandle is empty", "ERROR")
            return false
        }

        VarSetCapacity(clientRect, 16, 0)
        if (!DllCall("GetClientRect", "Ptr", nativeHwnd, "Ptr", &clientRect)) {
            IikoDriver_Log("PBX_ACCEPT_CLICK_ERROR: GetClientRect failed for HWND=" . nativeHwnd, "ERROR")
            return false
        }

        clientWidth := NumGet(clientRect, 8, "Int")
        clientHeight := NumGet(clientRect, 12, "Int")
        if (clientWidth <= 0 || clientHeight <= 0) {
            IikoDriver_Log("PBX_ACCEPT_CLICK_ERROR: invalid client rectangle for HWND=" . nativeHwnd, "ERROR")
            return false
        }

        clientX := Floor(clientWidth / 2)
        clientY := Floor(clientHeight / 2)
        clickPoint := (clientY << 16) | (clientX & 0xFFFF)
        downQueued := DllCall("PostMessage", "Ptr", nativeHwnd, "UInt", 0x201, "Ptr", 1, "Ptr", clickPoint)
        Sleep, 25
        upQueued := DllCall("PostMessage", "Ptr", nativeHwnd, "UInt", 0x202, "Ptr", 0, "Ptr", clickPoint)
        if (!downQueued || !upQueued) {
            IikoDriver_Log("PBX_ACCEPT_CLICK_ERROR: mouse messages failed for HWND=" . nativeHwnd, "ERROR")
            return false
        }

        IikoDriver_Log("NATIVE_SUCCESS: PBX accept clicked by HWND=" . nativeHwnd . " point=" . clientX . "," . clientY)
        return true
    } catch e {
        IikoDriver_Log("PBX_ACCEPT_CLICK_ERROR: " . e.Message, "ERROR")
        return false
    }
}

; 7. Нажать "Без сдачи"
IikoUI_NoChange() {
    global cashX, cashY
    return IikoDriver_ClickElement("buttonNoChange", cashX, cashY)
}

; --- BATCH #2: INPUT FIELDS FOCUS & VALUE SETTING ---

; 2.1. Поле комментария заказа
IikoUI_FocusComment() {
    global commX, commY
    return IikoDriver_FocusElement("memoEditDeliveryComment", commX, commY)
}
IikoUI_SetComment(text) {
    global commX, commY
    return IikoDriver_SetElementValue("memoEditDeliveryComment", text, commX, commY)
}

; 2.2. Поле адреса доставки
IikoUI_FocusAddress() {
    global addrX, addrY
    return IikoDriver_FocusElement("gridLookUpEditStreetAddress", addrX, addrY)
}

; 2.3. Поле времени доставки
IikoUI_FocusDeliveryTime() {
    global timeX, timeY
    return IikoDriver_FocusElement("timeEditDeliveryTime", timeX, timeY)
}

; 2.4. Чтение состава заказа (Архитектура V2.0: Server REST API + Native UIA Tree)
IikoUI_GetOrderItems() {
    global itemX, itemY
    SetTitleMatchMode, 2
    
    ; 1. Запрос к локальному серверу RollHelper API (/api/iiko/read_order_items)
    if (RH_SERVER_OK || RhPing()) {
        srvResp := RhGet("/api/iiko/read_order_items", 4000)
        if (srvResp != "" && InStr(srvResp, """ok"":true") && InStr(srvResp, """items""")) {
            itemsStr := ""
            if (RegExMatch(srvResp, """items""\s*:\s*\[(.*?)\]", _m)) {
                Loop, Parse, _m1, `,
                {
                    cleanItem := Trim(StrReplace(StrReplace(A_LoopField, """", ""), "\""", """"))
                    if (cleanItem != "")
                        itemsStr .= cleanItem . "`n"
                }
            }
            if (itemsStr != "")
                return itemsStr
        }
    }
    
    ; 2. Резервный нативный UIA-экстрактор дерева в AHK
    directText := IikoDriver_GetTreeItemsTextDirect("treeListItems")
    if (directText != "")
        return directText
        
    return ""
}

; --- BACKWARD COMPATIBILITY ALIASES ---
RcClickFindPoint() {
    return IikoUI_AssignDeliveryTerminal()
}
RcClickSaveAndClose() {
    return IikoUI_SaveAndClose()
}
RcClickConfirm() {
    return IikoUI_ConfirmDelivery()
}
RcClickCancel() {
    return IikoUI_CancelDelivery()
}
RcClickClose() {
    return IikoUI_CloseForm()
}
