; ========================================================
; МОДУЛЬ КНОПОК UIA (rc_uia_buttons.ahk)
; Изолированный модуль для нативных кликов по элементам iiko
; ========================================================

#Include %A_ScriptDir%\rc_uia_click.ahk

; --- ФУНКЦИИ КЛИКОВ ПО КНОПКАМ ---

; 1. Найти точку
RcClickFindPoint() {
    return RcNativeUiaClick("buttonAssignDeliveryTerminal")
}

; 2. Сохранить на точку (и закрыть)
RcClickSaveAndClose() {
    return RcNativeUiaClick("buttonSaveAndClose")
}

; 3. Подтвердить доставку
RcClickConfirm() {
    return RcNativeUiaClick("buttonDeliveryConfirmation")
}

; 4. Отменить доставку
RcClickCancel() {
    return RcNativeUiaClick("buttonCancelDelivery")
}

; 5. Выйти / Закрыть
RcClickClose() {
    return RcNativeUiaClick("buttonClose")
}

; --- ТЕСТОВЫЕ ГОРЯЧИЕ КЛАВИШИ ---
; Ctrl + F7 : Найти точку
^F7::
    RcLog("TEST: Click Найти точку")
    RcClickFindPoint()
return

; Ctrl + F8 : Сохранить на точку
^F8::
    RcLog("TEST: Click Сохранить на точку")
    RcClickSaveAndClose()
return

; Ctrl + F9 : Подтвердить
^F9::
    RcLog("TEST: Click Подтвердить")
    RcClickConfirm()
return
