"""Exercise the shipped AHK formatter and real isolated card, without Syrve."""
import os
import configparser
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
AHK = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "AutoHotkey/v1.1.37.02/AutoHotkeyU64.exe"


class KitchenCardTests(unittest.TestCase):
    def test_real_ahk_ini_loader_and_editor_writer_preserve_new_fields(self):
        if not AHK.is_file():
            self.skipTest("AutoHotkey v1 on Windows required")
        engine = (ROOT / "engine_rollclub.ahk").read_text(encoding="utf-8-sig")
        labels = engine[engine.index("LoadKitchens:\n"):engine.index("SyncKitchensFromSheet:\n")]
        labels += engine[engine.index("WriteKitchensFile:\n"):engine.index("KitchClose:\n")]
        fields = dict(City="Київ", Address="Драгоманова 38", KmlKey="CUSTOM", Remark="Генератор ±30 хв", Center="По предзаказам", Pickup="Стандарт", FarZone="По предзаказам", StopList="Пепсі 0,33", StopWorkshop="ТЕМПУРА", Terminal="ЕСТЬ", PreorderAvailable="22:00", PreorderLimited="21:00", SlotsLoaded="1", DataVersion="2", UpdatedUTC="20261114180000")
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            path = directory / "RkKitchens.ini"
            path.write_text("[Драгоманова]\n" + "\n".join(f"{k}={v}" for k, v in fields.items()), encoding="utf-8-sig")
            harness = r'''#Requires AutoHotkey v1.1
#NoEnv
#NoTrayIcon
#SingleInstance Off
FileEncoding, UTF-8
RcZonesModuleEnabled := true
GoSub, LoadKitchens
if (Kitchens.Length() != 1)
    ExitApp, 2
GoSub, WriteKitchensFile
ExitApp, 0
RcRefreshZonesModuleState() {
    return true
}
RcLoadZoneMap() {
}
RcReadableRollclubDataPath(name) {
    return A_ScriptDir . "\" . name
}
RcWritableRollclubDataPath(name) {
    return A_ScriptDir . "\" . name
}
RcKitchenPresent(k, extra := "") {
    throw Exception("loader must not open a card without a current kitchen")
}
'''
            script = directory / "ini.ahk"
            script.write_text(harness + labels, encoding="utf-8-sig")
            result = subprocess.run([str(AHK), "/ErrorStdOut", str(script)], capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout.decode("utf-8", "replace"))
            ini = configparser.ConfigParser(interpolation=None)
            ini.read(path, encoding="utf-8-sig")
            for key, value in fields.items():
                self.assertEqual(ini["Драгоманова"][key], value)

    def test_model_and_real_card_at_three_scales(self):
        if not AHK.is_file():
            self.skipTest("AutoHotkey v1 on Windows required")
        engine = (ROOT / "engine_rollclub.ahk").read_text(encoding="utf-8-sig")
        # Use the production theme registration and native color handler.
        colors = engine[engine.index("RhRegColor(hwnd, bg, tx) {"):engine.index("RhRepaintRollPult:\n")]
        colors += engine[engine.index("WM_CTLCOLORSTATIC(wParam, lParam) {"):engine.index("; --- ПРОВЕРКА СЕРВЕРНОЙ")]
        harness = r'''
#Requires AutoHotkey v1.1
#NoEnv
#NoTrayIcon
#SingleInstance Off
#Include INCLUDE_PATH
SetBatchLines, -1
FileEncoding, UTF-8
try {
    k := {Name:"Драгоманова",City:"Київ",Center:"Работаем по предзаказам",Pickup:"Стандарт",FarZone:"Работаем по предзаказам",StopWorkshop:"СТОП: ТЕМПУРА",StopList:"Пепсі 0,33 блек",Remark:"Працюємо від генератора. Інтервал: ±30 хв",Terminal:"ЕСТЬ",DataVersion:"2",SlotsLoaded:"1",UpdatedUTC:"20261114180000",PreorderAvailable:"22:00",PreorderLimited:"21:00"}
    m := RcKitchenCardModel(k, "20261114180100")
    Assert(m.known && m.preorder, "fresh preorder")
    Assert(m.open == "Доступні: 22:00" && m.limited == "Обмежено: 21:00", "source capacity preserved")
    Assert(InStr(m.body, "ТЕМПУРА") && InStr(m.body, "Пепсі") && InStr(m.body, "генератора"), "separate stops and notes")
    Assert(InStr(m.mode, "Центр: По предам") && InStr(m.mode, "Самовивіз: Стандарт"), "channel modes")
    Assert(!RcKitchenCardModel(k, "20261114181500").known, "stale hours hidden")
    Assert(!RcKitchenCardModel(k, "20261114175900", true).known, "failed sync hides hours")
    k.SlotsLoaded := "0"
    Assert(!RcKitchenCardModel(k, "20261114180100").known, "missing hours are unknown")
    k.SlotsLoaded := "1", k.PreorderAvailable := "", k.PreorderLimited := ""
    Assert(RcKitchenCardModel(k, "20261114180100").open == "Доступні: немає", "known empty capacity")
    k.DataVersion := ""
    Assert(!RcKitchenCardModel(k, "20261114180100").known, "legacy cache cannot advertise availability")
    k.DataVersion := "2", k.UpdatedUTC := A_NowUTC, k.PreorderAvailable := "22:00", k.PreorderLimited := "21:00"
    for _, scale in [1,1.25,1.5] {
        for _, work in [{x:0,y:0,r:1366,b:728},{x:-1366,y:0,r:0,b:728},{x:0,y:0,r:800,b:560}] {
            for _, offset in [0,350,900] {
                b := RcKitchenCardBounds({x:work.x+offset,y:20,r:work.x+offset+360},work,scale)
                Assert(b.x >= work.x && b.y >= work.y && b.x+b.w <= work.r && b.y+b.h <= work.b, "card fits small/negative-coordinate monitor")
            }
        }
    }
    RhC_BG := "F5F6F8", RhC_Panel := "FFFFFF", RhC_Text := "1F1F1F", RhC_Muted := "6B7280"
    RhB_TintGreen := 0xE7F9EB, RhB_TintAmber := 0xC7F3FF, RhB_Text := 0x1F1F1F
    RhStaticColors := {}, RhStaticBrush := {}
    OnMessage(0x138, "WM_CTLCOLORSTATIC")
    for _, scale in [1,1.25,1.5] {
        Gui, Roll:New, +HwndRollHwnd -DPIScale
        Gui, Roll:Add, Text, vKitchenStatusText w300, Test owner
        Gui, Roll:Show, NoActivate x350 y20 w360 h560, Kitchen fixture owner
        RcKC := {k:k,extra:"",dismissed:false}
        active := WinActive("A")
        RcKitchenCardShow(scale)
        Assert(WinActive("A") == active, "show must not steal focus")
        Assert(DllCall("IsWindowVisible","Ptr",RcKC.hwnd), "automatic side card visible")
        Assert(DllCall("GetWindow","Ptr",RcKC.hwnd,"UInt",4,"Ptr") == RollHwnd, "card owned by pult")
        WinGetPos, x,y,w,h, % "ahk_id " RcKC.hwnd
        SysGet, wa, MonitorWorkArea
        Assert(x >= waLeft && y >= waTop && x+w <= waRight && y+h <= waBottom, "actual non-client bounds inside work area")
        VarSetCapacity(client,16,0), DllCall("GetClientRect","Ptr",RcKC.hwnd,"Ptr",&client)
        VarSetCapacity(origin,8,0), DllCall("ClientToScreen","Ptr",RcKC.hwnd,"Ptr",&origin)
        for _, control in [RcKC.title,RcKC.mode,RcKC.open,RcKC.limited,RcKC.body,RcKC.refresh] {
            VarSetCapacity(rect,16,0), DllCall("GetWindowRect","Ptr",control,"Ptr",&rect)
            left := NumGet(rect,0,"Int")-NumGet(origin,0,"Int")
            top := NumGet(rect,4,"Int")-NumGet(origin,4,"Int")
            right := NumGet(rect,8,"Int")-NumGet(origin,0,"Int")
            bottom := NumGet(rect,12,"Int")-NumGet(origin,4,"Int")
            Assert(left>=0 && top>=0 && right<=NumGet(client,8,"Int") && bottom<=NumGet(client,12,"Int"), "every actual control inside card")
        }
        for _, control in [RcKC.open,RcKC.limited,RcKC.body] {
            WinGet, editStyle, Style, ahk_id %control%
            Assert(editStyle & 0x4, "status fields must remain multiline after resize")
        }
        PostMessage, 0x10, 0, 0,, % "ahk_id " RcKC.hwnd
        Sleep, 50
        Assert(RcKC.dismissed, "native close event invokes card handler")
        Assert(!DllCall("IsWindowVisible","Ptr",RcKC.hwnd), "close dismisses card")
        RcShowKitchenCard()
        Assert(DllCall("IsWindowVisible","Ptr",RcKC.hwnd), "summary reopens card")
        Gui, Roll:Hide
        RcKitchenCardTick()
        Assert(!DllCall("IsWindowVisible","Ptr",RcKC.hwnd), "card hides with owner")
        Gui, Roll:Show, NoActivate
        RcKitchenCardTick()
        Assert(DllCall("IsWindowVisible","Ptr",RcKC.hwnd), "card returns with owner")
        EnvGet, capture, ROLLHELPER_KITCHEN_CAPTURE
        if (capture != "") {
            FileAppend, % scale . "," . RcKC.hwnd . "`n", %capture%
            Sleep, 1800
        }
        Gui, Roll:Destroy
    }
    FileAppend, PASS kitchen model and 100/125/150 percent owned-card checks`n, *
    ExitApp, 0
} catch e {
    FileAppend, % "FAIL: " e.Message . " line=" e.Line . "`n", *
    ExitApp, 1
}
Assert(ok, message) {
    if (!ok)
        throw Exception(message)
}
RcKitchensSyncBlocked() {
    return true
}
RcKitchensSyncIfStale:
return
'''.replace("INCLUDE_PATH", str(ROOT / "lib/RollClubKitchenStatus.ahk"))
        with tempfile.TemporaryDirectory() as tmp:
            script = Path(tmp) / "card.ahk"
            script.write_text(harness + colors, encoding="utf-8-sig")
            result = subprocess.run([str(AHK), "/ErrorStdOut", str(script)], capture_output=True, timeout=20)
            output = result.stdout.decode("utf-8-sig", "replace")
            self.assertEqual(result.returncode, 0, output + result.stderr.decode("utf-8", "replace"))
            self.assertIn("PASS kitchen model", output)


if __name__ == "__main__":
    unittest.main()
