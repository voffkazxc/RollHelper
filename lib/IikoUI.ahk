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
