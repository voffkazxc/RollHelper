#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
FileEncoding, UTF-8
#Include %A_ScriptDir%\..\core\modules\ModuleRegistry.ahk

_testDir := A_Temp . "\RollHelperModuleRegistrySmoke"
FileCreateDir, %_testDir%
FileDelete, %_testDir%\logs\module_registry.log
FileDelete, %_testDir%\module_registry_smoke.result.txt

ModuleRegistry_Init(_testDir, "rollhouse", "mvp")
ModuleRegistry_ApplyRollHouseMvpPolicy()

_testLogPath := _testDir . "\logs\module_registry.log"
FileRead, _testLog, %_testLogPath%
_testOk := InStr(_testLog, "module=reports;key=F5")
    && InStr(_testLog, "module=calling;key=F2")
    && InStr(_testLog, "module=calling;key=F6")
    && InStr(_testLog, "module=calling;key=F7")
    && InStr(_testLog, "module=calling;key=^F6")
    && InStr(_testLog, "module=web_pult;key=^vkC0")
    && InStr(_testLog, "module=duty;key=^F4")

_testResultPath := _testDir . "\module_registry_smoke.result.txt"
FileAppend, % _testOk ? "PASS" : "FAIL", %_testResultPath%
ExitApp, % _testOk ? 0 : 1

F2::return
F5::return
F6::return
F7::return
^F6::return
^F4::return
^vkC0::return

CheckCall:
WaitForCallEnd:
AutoDialNext:
WaitForTalkStart:
CallAutoListenAfterGreeting:
return
