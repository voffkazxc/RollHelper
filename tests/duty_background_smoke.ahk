#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Off
#Include %A_ScriptDir%\..\lib\RollClubDutyBackground.ahk

try {
    Assert(RcDutyBgHandleNumber("0x001234") == "4660", "HWND encoded as decimal for HTTP and JSON")
    panel := new FakeElement("data")
    row1 := new FakeElement("Строка 1")
    row2 := new FakeElement("Строка 2")
    row1.children := [new FakeElement("№ row 1", "1741877")]
    row2.children := [new FakeElement("№ row 2", "741877")]
    panel.children := [row1, row2]
    result := RcDutyBgRow(panel, 741877)
    Assert(result.cell.value == "741877", "must select exact number, not substring")
    Assert(!IsObject(RcDutyBgRow(panel, 7418)), "partial number must not match")
    Assert(RcDutyBgNumber("{""take_no"":741877}", "take_no") = 741877, "JSON number")
    Assert(RcDutyBgNumber("{""take_no"":0}", "take_no") = 0, "empty scan")

    button := new FakeElement("close")
    button.invoke := new FakePattern()
    Assert(RcDutyBgInvoke(button), "Invoke should execute")
    Assert(button.invoke.calls = 1, "Invoke exactly once")
    button.CurrentIsEnabled := false
    Assert(!RcDutyBgInvoke(button), "disabled button must not execute")
    Assert(button.invoke.calls = 1, "disabled button had no side effect")

    row := new FakeElement("row")
    row.legacy := new FakePattern("Выбрать")
    Assert(!RcDutyBgInvoke(row), "selection must not count as opening")
    Assert(row.legacy.calls = 0, "selection default must not execute")
    row.legacy.CurrentDefaultAction := "Открыть"
    Assert(RcDutyBgInvoke(row), "open default should execute")
    Assert(row.legacy.calls = 1, "open exactly once")

    root := new FakeElement("window")
    grid := new FakeElement("grid")
    grid.CurrentAutomationId := "gridDeliveries"
    grid.children := [new FakeElement("should never inspect")]
    grid.forbidChildren := true
    card := new FakeElement("card")
    card.CurrentAutomationId := "DeliveryOrderEditControl"
    root.children := [grid, card]
    Assert(IsObject(RcDutyBgFindId(root, "DeliveryOrderEditControl")), "find card, skip grid")
    budget := 1
    Assert(!IsObject(RcDutyBgFindId(root, "missing", 12, budget)), "bounded traversal")
    dutyOn := 1, kcStop := 0, rhPunchBusy := 0, _inDutyTake := 0
    RcDutyBgGeneration := 2, RcDutyBgRunGeneration := 1
    stopped := false
    try RcDutyBgCheck(0)
    catch error
        stopped := (error.Message = "STOP")
    Assert(stopped, "stop/start invalidates previous request before accessing HWND")
    RcDutyBgRunGeneration := 2, kcStop := 1
    stopped := false
    try RcDutyBgCheck(0)
    catch error
        stopped := (error.Message = "STOP")
    Assert(stopped, "operator stop blocks window operations")
    FileAppend, PASS: 17 background UIA assertions`n, *
    ExitApp, 0
} catch error {
    FileAppend, % "FAIL: " . error.Message . " line=" . error.Line . "`n", *
    ExitApp, 1
}

Assert(condition, message) {
    if (!condition)
        throw Exception(message)
}

; No real UIA or window action is used in these tests.
IikoDriver_InitEngine() {
    return false
}

class FakePattern {
    __New(action := "") {
        this.CurrentDefaultAction := action
        this.calls := 0
    }
    Invoke() {
        this.calls++
    }
    DoDefaultAction() {
        this.calls++
    }
}

class FakeElement {
    __New(name, value := "") {
        this.CurrentName := name
        this.CurrentAutomationId := ""
        this.CurrentIsEnabled := true
        this.value := value
        this.children := []
    }
    FindAllBy(query, scope := 2) {
        if (this.forbidChildren)
            throw Exception("grid rows traversed during card lookup")
        return this.children
    }
    GetCurrentPatternAs(name) {
        if (name = "Invoke" && IsObject(this.invoke))
            return this.invoke
        if (name = "LegacyIAccessible" && IsObject(this.legacy))
            return this.legacy
        if (name = "Value")
            return {CurrentValue: this.value}
        throw Exception("pattern unavailable")
    }
}
