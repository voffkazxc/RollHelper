; ========================================================
; DEVELOPER TEST SUITE: test_uia_hotkeys.ahk
; Isolated test script for testing iiko UI Driver hotkeys
; Can be launched independently or included.
; ========================================================

#Requires AutoHotkey v1.1
#MaxThreadsPerHotkey 5
#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%
#Include %A_ScriptDir%\lib\IikoUI.ahk
#Include %A_ScriptDir%\lib\IikoOCR.ahk

; --- BATCH #2 TEST HOTKEYS (FIELDS FOCUS) ---

; Ctrl + F2 : Фокус комментария
^F2::
    ToolTip, [TEST] UIA: Фокус комментария...
    IikoUI_FocusComment()
    SetTimer, UiaTestRemoveTip, -2000
return

; Ctrl + F3 : Фокус адреса
^F3::
    ToolTip, [TEST] UIA: Фокус адреса...
    IikoUI_FocusAddress()
    SetTimer, UiaTestRemoveTip, -2000
return

; Ctrl + Shift + F4 : Фокус времени
^+F4::
    ToolTip, [TEST] UIA: Фокус времени...
    IikoUI_FocusDeliveryTime()
    SetTimer, UiaTestRemoveTip, -2000
return

; Ctrl + F5 : Диагностика состава заказа: UIA + OCR + сырой ответ
^F5::
    SetTitleMatchMode, 2

    uiText := IikoUI_GetOrderItems()
    uiaDump := IikoDriver_DumpTreeItemsDiag("treeListItems", 180)
    winDump := IikoDriver_DumpWinApiItemsDiag("treeListItems")
    clipDump := IikoDriver_CopyTreeItemsClipboardDiag("treeListItems")
    ocrResp := IikoOCR_CaptureAndRead()
    ocrItems := UiaTestExtractOcrItems(ocrResp)
    ocrText := UiaTestExtractJsonString(ocrResp, "text")
    if (ocrText = "")
        ocrText := UiaTestExtractJsonString(ocrResp, "raw_text")
    if (ocrText = "")
        ocrText := UiaTestExtractJsonString(ocrResp, "ocr_text")

    if (uiText = "")
        uiText := "(UIA ничего не вернул)"
    if (ocrItems = "")
        ocrItems := "(OCR items пустой — парсер не нашёл массив items)"
    if (ocrText = "")
        ocrText := "(OCR text/raw_text/ocr_text пустой или такого поля нет)"
    if (ocrResp = "")
        ocrResp := "(сервер OCR вернул пустой ответ)"

    diag := "=== UIA / WinAPI состав ===`r`n" . uiText
        . "`r`n`r`n=== UIA TREE DUMP ===`r`n" . uiaDump
        . "`r`n`r`n=== WINAPI/HWND DUMP ===`r`n" . winDump
        . "`r`n`r`n=== GRID CLIPBOARD COPY ===`r`n" . clipDump
        . "`r`n`r`n=== OCR items ===`r`n" . ocrItems
        . "`r`n`r`n=== OCR text ===`r`n" . ocrText
        . "`r`n`r`n=== RAW OCR RESPONSE ===`r`n" . ocrResp

    FileDelete, %A_ScriptDir%\ocr_debug_last.txt
    FileAppend, %diag%, %A_ScriptDir%\ocr_debug_last.txt, UTF-8
    UiaTestShowLargeText("Состав заказа — диагностика UIA/OCR", diag)
return

; Ctrl + F6 : Без сдачи
^F6::
    ToolTip, [TEST] UIA: Без сдачи...
    IikoUI_NoChange()
    SetTimer, UiaTestRemoveTip, -2000
return

; Ctrl + F7 : Найти точку
^F7::
    ToolTip, [TEST] UIA: Найти точку...
    IikoUI_AssignDeliveryTerminal()
    SetTimer, UiaTestRemoveTip, -2000
return

; Ctrl + F8 : Сохранить на точку
^F8::
    ToolTip, [TEST] UIA: Сохранить на точку...
    IikoUI_SaveAndClose()
    SetTimer, UiaTestRemoveTip, -2000
return

; Ctrl + F9 : Подтвердить
^F9::
    ToolTip, [TEST] UIA: Подтвердить...
    IikoUI_ConfirmDelivery()
    SetTimer, UiaTestRemoveTip, -2000
return


; Ctrl + F10 : Grid clipboard copy diagnostics
^F10::
    clipDump := IikoDriver_CopyTreeItemsClipboardDiag("treeListItems")
    FileDelete, %A_ScriptDir%\grid_clipboard_last.txt
    FileAppend, %clipDump%, %A_ScriptDir%\grid_clipboard_last.txt, UTF-8
    UiaTestShowLargeText("Order items - clipboard grid", clipDump)
return

UiaTestRemoveTip:
    ToolTip
return



UiaTestExtractOcrItems(json) {
    out := ""
    if (RegExMatch(json, "s)""items""\s*:\s*\[(.*?)\]", m)) {
        Loop, Parse, m1, `,
        {
            cleanItem := UiaTestJsonUnescape(Trim(A_LoopField))
            cleanItem := Trim(cleanItem, " `t`r`n""")
            if (cleanItem != "")
                out .= "• " . cleanItem . "`r`n"
        }
    }
    return RTrim(out, "`r`n")
}

UiaTestExtractJsonString(json, key) {
    pattern := "s)""" . key . """\s*:\s*""((?:[^""\\]|\\.)*)"""
    if RegExMatch(json, pattern, m)
        return UiaTestJsonUnescape(m1)
    return ""
}

UiaTestJsonUnescape(text) {
    text := StrReplace(text, "\r", "`r")
    text := StrReplace(text, "\n", "`n")
    text := StrReplace(text, "\t", "`t")
    text := StrReplace(text, "\""", """")
    text := StrReplace(text, "\\", "\")
    return text
}

UiaTestShowLargeText(title, text) {
    global OcrDiagText
    Gui, OcrDiag:Destroy
    Gui, OcrDiag:+AlwaysOnTop +Resize
    Gui, OcrDiag:Font, s9, Consolas
    Gui, OcrDiag:Add, Edit, x10 y10 w900 h520 ReadOnly -Wrap HScroll vOcrDiagText, %text%
    Gui, OcrDiag:Font, s9, Segoe UI
    Gui, OcrDiag:Add, Button, x10 y540 w160 h30 gUiaTestCopyDiag, Скопировать
    Gui, OcrDiag:Add, Button, x180 y540 w160 h30 gUiaTestOpenDiagLog, Открыть лог
    Gui, OcrDiag:Add, Button, x750 y540 w160 h30 gUiaTestCloseDiag, Закрыть
    Gui, OcrDiag:Show, w920 h580, %title%
}

UiaTestCopyDiag:
    global OcrDiagText
    GuiControlGet, _diagText, OcrDiag:, OcrDiagText
    Clipboard := _diagText
    ToolTip, Диагностика скопирована
    SetTimer, UiaTestRemoveTip, -1200
return

UiaTestOpenDiagLog:
    Run, notepad.exe "%A_ScriptDir%\ocr_debug_last.txt"
return

UiaTestCloseDiag:
OcrDiagGuiClose:
OcrDiagGuiEscape:
    Gui, OcrDiag:Destroy
return



