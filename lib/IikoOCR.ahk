IikoOCR_SaveScreenRegion(x, y, w, h, filename) {
    SetTitleMatchMode, 2
    hwnd := WinExist("ahk_exe iikoCard5.Pos.Host.exe")
    if (!hwnd)
        hwnd := WinExist("Syrve")
    if (!hwnd)
        hwnd := WinExist("Office")
    if (!hwnd)
        hwnd := WinExist("Ролл Клаб")
        
    pToken := 0
    DllCall("LoadLibrary", "Str", "gdiplus.dll")
    VarSetCapacity(si, 24, 0), NumPut(1, si, 0, "UInt")
    DllCall("gdiplus\GdiplusStartup", "Ptr*", pToken, "Ptr", &si, "Ptr", 0)
    
    hdcSrc := DllCall("GetDC", "Ptr", 0, "Ptr")
    
    ; Снимаем чистое окно iiko через PrintWindow (PW_RENDERFULLCONTENT = 2)
    ; Это гарантирует снимок таблицы БЕЗ наложенного поверх всплывающего окна MsgBox!
    WinGetPos, winX, winY, winW, winH, ahk_id %hwnd%
    relX := (winX > 0) ? (x - winX) : x
    relY := (winY > 0) ? (y - winY) : y
    
    hdcWin := DllCall("CreateCompatibleDC", "Ptr", hdcSrc, "Ptr")
    hbmWin := DllCall("CreateCompatibleBitmap", "Ptr", hdcSrc, "Int", winW, "Int", winH, "Ptr")
    obmWin := DllCall("SelectObject", "Ptr", hdcWin, "Ptr", hbmWin, "Ptr")
    
    if (hwnd && winW > 0 && winH > 0 && DllCall("PrintWindow", "Ptr", hwnd, "Ptr", hdcWin, "UInt", 2)) {
        hdcDst := DllCall("CreateCompatibleDC", "Ptr", hdcSrc, "Ptr")
        hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcSrc, "Int", w, "Int", h, "Ptr")
        obm := DllCall("SelectObject", "Ptr", hdcDst, "Ptr", hbm, "Ptr")
        DllCall("BitBlt", "Ptr", hdcDst, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcWin, "Int", relX, "Int", relY, "UInt", 0x00CC0020)
    } else {
        hdcDst := DllCall("CreateCompatibleDC", "Ptr", hdcSrc, "Ptr")
        hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcSrc, "Int", w, "Int", h, "Ptr")
        obm := DllCall("SelectObject", "Ptr", hdcDst, "Ptr", hbm, "Ptr")
        DllCall("BitBlt", "Ptr", hdcDst, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcSrc, "Int", x, "Int", y, "UInt", 0x00CC0020)
    }
    
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", pBitmap)
    pGraphics := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", pGraphics)
    hdcBitmap := DllCall("gdiplus\GdipGetDC", "Ptr", pGraphics, "Ptr")
    DllCall("BitBlt", "Ptr", hdcBitmap, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcDst, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("gdiplus\GdipReleaseDC", "Ptr", pGraphics, "Ptr", hdcBitmap)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
    
    VarSetCapacity(clsid, 16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", &clsid)
    
    DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", filename, "Ptr", &clsid, "Ptr", 0)
    
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    DllCall("SelectObject", "Ptr", hdcDst, "Ptr", obm)
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", hdcDst)
    if (hbmWin) {
        DllCall("SelectObject", "Ptr", hdcWin, "Ptr", obmWin)
        DllCall("DeleteObject", "Ptr", hbmWin)
        DllCall("DeleteDC", "Ptr", hdcWin)
    }
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcSrc)
    DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
}

IikoOCR_CaptureAndRead() {
    SetTitleMatchMode, 2
    
    cropFile := A_Temp . "\temp_order_crop.png"
    
    ; 1. Находим таблицу или координаты
    cropX := 48, cropY := 432, cropW := 353, cropH := 484
    treeEl := IikoDriver_FindElement("treeListItems")
    if (treeEl) {
        try {
            rect := treeEl.CurrentBoundingRectangle
            w := rect.r - rect.l
            h := rect.b - rect.t
            if (w > 100 && h > 100 && rect.l >= 0 && rect.t >= 0) {
                cropX := rect.l, cropY := rect.t, cropW := w, cropH := h
            }
        } catch {
        }
    }
    
    ; 2. Сохраняем кроп через нативный GDI+ (5мс)
    IikoOCR_SaveScreenRegion(cropX, cropY, cropW, cropH, cropFile)
    
    ; Проверяем, что файл создался и не пустой!
    FileGetSize, fSize, %cropFile%
    urlPath := ""
    if (fSize > 500) {
        urlPath := "?image_path=" . StrReplace(cropFile, "\", "/")
    }
    
    ; 3. Запрашиваем локальный OCR
    ocrResp := ""
    try {
        whr := ComObjCreate("MSXML2.ServerXMLHTTP.6.0")
        whr.Open("GET", "http://127.0.0.1:5000/api/iiko/ocr_crop" . urlPath, false)
        whr.Send()
        ocrResp := whr.ResponseText
    } catch {
    }
    
    return ocrResp
}
