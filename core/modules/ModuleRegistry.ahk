; RollHelper module registry.
; The launcher and core use module ids; brand-specific code stays inside packages.

global ModuleRegistry_AppDir := ""
global ModuleRegistry_Brand := ""
global ModuleRegistry_Profile := ""
global ModuleRegistry_ConfigPath := ""
global ModuleRegistry_Modules := {}

ModuleRegistry_Init(appDir, brand, profile := "mvp") {
    global ModuleRegistry_AppDir, ModuleRegistry_Brand, ModuleRegistry_Profile
    global ModuleRegistry_ConfigPath, ModuleRegistry_Modules

    ModuleRegistry_AppDir := appDir
    ModuleRegistry_Brand := brand
    ModuleRegistry_Profile := profile
    ModuleRegistry_ConfigPath := appDir . "\config\" . profile . "_modules.ini"
    ModuleRegistry_Modules := {}

    ModuleRegistry_Load("orders", 1)
    ModuleRegistry_Load("siv", 1)
    ModuleRegistry_Load("duty", 0)
    ModuleRegistry_Load("reports", 0)
    ModuleRegistry_Load("calling", 0)
    ModuleRegistry_Load("ocr", 0)
    ModuleRegistry_Load("crm", 0)
    ModuleRegistry_Load("web_pult", 0)
    ModuleRegistry_Load("diagnostics", 0)

    ModuleRegistry_Log("init", "profile=" . profile . ";brand=" . brand . ";config=" . ModuleRegistry_ConfigPath)
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
