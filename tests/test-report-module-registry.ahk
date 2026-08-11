#Requires AutoHotkey v1.1
#NoEnv
#Include %A_ScriptDir%\..\core\modules\ModuleRegistry.ahk

GoTo, RegistryTestStart

CheckCall:
WaitForCallEnd:
AutoDialNext:
WaitForTalkStart:
CallAutoListenAfterGreeting:
return

RegistryTestStart:
if (!IsObject(A_Args) || A_Args[1] = "")
    ExitApp, 10

_tracePath := A_Args[2]
FileDelete, %_tracePath%
FileAppend, start`n, %_tracePath%
EnvSet, ROLLHELPER_PROGRAM_ROOT, % A_Args[1]
EnvGet, _actualProgramRoot, ROLLHELPER_PROGRAM_ROOT
FileAppend, % "env_set=" . _actualProgramRoot . "`nstate_exists=" . FileExist(_actualProgramRoot . "\State\packages.json") . "`n", %_tracePath%
FileRead, _debugStateJson, % _actualProgramRoot . "\State\packages.json"
_debugQuote := Chr(34)
_debugId := "rollhouse-report-load"
_debugPattern := "is)" . _debugQuote . "\Q" . _debugId . "\E" . _debugQuote . "\s*:\s*\{(.*?)\}"
_debugMatched := RegExMatch(_debugStateJson, _debugPattern, _debugPackageMatch)
FileAppend, % "pattern=" . _debugPattern . "`nmatched=" . _debugMatched . "`nblock=" . _debugPackageMatch1 . "`n", %_tracePath%
ModuleRegistry_Init(A_ScriptDir . "\..", "rollhouse", "mvp")
FileAppend, registry_initialized`n, %_tracePath%

if (!Module_IsEnabled("reports"))
    ExitApp, 11
if (!ModuleRegistry_ExternalPackages.HasKey("reports"))
    ExitApp, 12

_reportPackage := ModuleRegistry_ExternalPackages["reports"]
if (_reportPackage.id != "rollhouse-report-load")
    ExitApp, 13
if !FileExist(_reportPackage.entrypoint)
    ExitApp, 14

FileAppend, success`n, %_tracePath%
ExitApp, 0
