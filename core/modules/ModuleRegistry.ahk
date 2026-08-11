; RollHelper module registry.
; The launcher and core use module ids; brand-specific code stays inside packages.

global ModuleRegistry_AppDir := ""
global ModuleRegistry_Brand := ""
global ModuleRegistry_Profile := ""
global ModuleRegistry_ConfigPath := ""
global ModuleRegistry_Modules := {}
global ModuleRegistry_ExternalPackages := {}

ModuleRegistry_Init(appDir, brand, profile := "mvp") {
    global ModuleRegistry_AppDir, ModuleRegistry_Brand, ModuleRegistry_Profile
    global ModuleRegistry_ConfigPath, ModuleRegistry_Modules, ModuleRegistry_ExternalPackages

    ModuleRegistry_AppDir := appDir
    ModuleRegistry_Brand := brand
    ModuleRegistry_Profile := profile
    ModuleRegistry_ConfigPath := appDir . "\config\" . profile . "_modules.ini"
    ModuleRegistry_Modules := {}
    ModuleRegistry_ExternalPackages := {}

    ModuleRegistry_Load("orders", 1)
    ModuleRegistry_Load("siv", 1)
    ModuleRegistry_Load("duty", 0)
    ModuleRegistry_Load("reports", 0)
    ModuleRegistry_Load("calling", 0)
    ModuleRegistry_Load("ocr", 0)
    ModuleRegistry_Load("crm", 0)
    ModuleRegistry_Load("web_pult", 0)
    ModuleRegistry_Load("diagnostics", 0)

    ModuleRegistry_RegisterExternal("reports", "rollhouse-report-load")

    ModuleRegistry_Log("init", "profile=" . profile . ";brand=" . brand . ";config=" . ModuleRegistry_ConfigPath)
}

ModuleRegistry_RegisterExternal(moduleId, packageId) {
    global ModuleRegistry_Modules, ModuleRegistry_ExternalPackages

    EnvGet, _programRoot, ROLLHELPER_PROGRAM_ROOT
    if (_programRoot = "")
        _programRoot := A_LocalAppData . "\Programs\RollHelper"
    _statePath := _programRoot . "\State\packages.json"
    if !FileExist(_statePath)
        return 0

    FileRead, _stateJson, %_statePath%
    if (ErrorLevel || _stateJson = "")
        return 0

    _quote := Chr(34)
    if !RegExMatch(_stateJson, "is)" . _quote . "\Q" . packageId . "\E" . _quote . "\s*:\s*\{(.*?)\}", _packageMatch)
        return 0

    _packageState := _packageMatch1
    if !RegExMatch(_packageState, "i)" . _quote . "Enabled" . _quote . "\s*:\s*true")
        return 0
    if !RegExMatch(_packageState, "i)" . _quote . "Version" . _quote . "\s*:\s*" . _quote . "([^" . _quote . "]+)" . _quote, _versionMatch)
        return 0

    _version := _versionMatch1
    _packageDir := _programRoot . "\Packages\" . packageId . "\" . _version
    _packageManifest := _packageDir . "\package.json"
    if !FileExist(_packageManifest)
        return 0

    FileRead, _packageJson, %_packageManifest%
    if (ErrorLevel || !RegExMatch(_packageJson, "is)" . _quote . "entrypoint" . _quote . "\s*:\s*\{(.*?)\}", _entryMatch))
        return 0
    if !RegExMatch(_entryMatch1, "i)" . _quote . "file" . _quote . "\s*:\s*" . _quote . "([^" . _quote . "]+)" . _quote, _fileMatch)
        return 0

    _entryFile := StrReplace(_fileMatch1, "/", "\")
    _entryPath := _packageDir . "\" . _entryFile
    if !FileExist(_entryPath)
        return 0

    _workingDir := _packageDir
    if RegExMatch(_entryMatch1, "i)" . _quote . "workingDirectory" . _quote . "\s*:\s*" . _quote . "([^" . _quote . "]+)" . _quote, _workingMatch) {
        _relativeWorkingDir := StrReplace(_workingMatch1, "/", "\")
        if (_relativeWorkingDir != "" && _relativeWorkingDir != ".")
            _workingDir := _packageDir . "\" . _relativeWorkingDir
    }

    ModuleRegistry_Modules[moduleId] := 1
    ModuleRegistry_ExternalPackages[moduleId] := {id: packageId, version: _version, entrypoint: _entryPath, workingDir: _workingDir}
    ModuleRegistry_Log("external_enabled", "module=" . moduleId . ";package=" . packageId . ";version=" . _version)
    return 1
}

ModuleRegistry_RunExternal(moduleId) {
    global ModuleRegistry_ExternalPackages

    if (!IsObject(ModuleRegistry_ExternalPackages) || !ModuleRegistry_ExternalPackages.HasKey(moduleId)) {
        ModuleRegistry_Log("external_run_missing", "module=" . moduleId)
        return 0
    }

    _package := ModuleRegistry_ExternalPackages[moduleId]
    _entrypoint := _package.entrypoint
    _workingDir := _package.workingDir
    if !FileExist(_entrypoint) {
        ModuleRegistry_Log("external_run_missing_entrypoint", "module=" . moduleId . ";path=" . _entrypoint)
        return 0
    }

    SplitPath, _entrypoint, , , _entryExt
    if (_entryExt = "ahk")
        Run, "%A_AhkPath%" "%_entrypoint%", %_workingDir%, UseErrorLevel
    else
        Run, "%_entrypoint%", %_workingDir%, UseErrorLevel

    if (ErrorLevel) {
        ModuleRegistry_Log("external_run_error", "module=" . moduleId . ";error=" . ErrorLevel)
        return 0
    }

    ModuleRegistry_Log("external_run", "module=" . moduleId . ";package=" . _package.id . ";version=" . _package.version)
    return 1
}

ModuleRegistry_Load(moduleId, defaultValue) {
    global ModuleRegistry_ConfigPath, ModuleRegistry_Modules

    _moduleValue := defaultValue
    if FileExist(ModuleRegistry_ConfigPath)
        IniRead, _moduleValue, %ModuleRegistry_ConfigPath%, Modules, %moduleId%, %defaultValue%
    _moduleValue := (_moduleValue = 1 || _moduleValue = "1" || _moduleValue = "true" || _moduleValue = "on") ? 1 : 0
    ModuleRegistry_Modules[moduleId] := _moduleValue
}

Module_IsEnabled(moduleId, defaultValue := 0) {
    global ModuleRegistry_Modules

    if (!IsObject(ModuleRegistry_Modules) || !ModuleRegistry_Modules.HasKey(moduleId))
        return defaultValue
    return ModuleRegistry_Modules[moduleId] ? 1 : 0
}

ModuleRegistry_ApplyRollHouseMvpPolicy() {
    global callMode, callListMode, callPaused, callFrozen, callAutoNext, callAutoListenBusy

    ModuleRegistry_Log("policy_begin", "rollhouse_mvp")

    if (!Module_IsEnabled("reports"))
        ModuleRegistry_DisableHotkey("F5", "reports")

    if (!Module_IsEnabled("calling")) {
        ModuleRegistry_DisableHotkey("F2", "calling")
        ModuleRegistry_DisableHotkey("F6", "calling")
        ModuleRegistry_DisableHotkey("F7", "calling")
        ModuleRegistry_DisableHotkey("^F6", "calling")

        callMode := 0
        callListMode := 0
        callPaused := 1
        callFrozen := 0
        callAutoNext := 0
        callAutoListenBusy := 0
        SetTimer, CheckCall, Off
        SetTimer, WaitForCallEnd, Off
        SetTimer, AutoDialNext, Off
        SetTimer, WaitForTalkStart, Off
        SetTimer, CallAutoListenAfterGreeting, Off
        ModuleRegistry_Log("runtime_disabled", "module=calling")
    }

    if (!Module_IsEnabled("duty"))
        ModuleRegistry_DisableHotkey("^F4", "duty")

    if (!Module_IsEnabled("web_pult"))
        ModuleRegistry_DisableHotkey("^vkC0", "web_pult")

    ModuleRegistry_Log("policy_end", "rollhouse_mvp")
}

ModuleRegistry_DisableHotkey(keyName, moduleId) {
    ModuleRegistry_Log("hotkey_disable_begin", "module=" . moduleId . ";key=" . keyName)
    Hotkey, %keyName%, Off, UseErrorLevel
    if (ErrorLevel)
        ModuleRegistry_Log("hotkey_disable_error", "module=" . moduleId . ";key=" . keyName . ";error=" . ErrorLevel)
    else
        ModuleRegistry_Log("hotkey_disabled", "module=" . moduleId . ";key=" . keyName)
}

ModuleRegistry_Log(event, details := "") {
    global ModuleRegistry_AppDir, ModuleRegistry_Brand, ModuleRegistry_Profile

    if (ModuleRegistry_AppDir = "")
        return
    _moduleLogDir := ModuleRegistry_AppDir . "\logs"
    FileCreateDir, %_moduleLogDir%
    _moduleLogPath := _moduleLogDir . "\module_registry.log"
    FormatTime, _moduleNow,, yyyy-MM-dd HH:mm:ss
    _moduleLine := _moduleNow . "`t" . ModuleRegistry_Brand . "`t" . ModuleRegistry_Profile . "`t" . event . "`t" . details . "`n"
    FileAppend, %_moduleLine%, %_moduleLogPath%
}
