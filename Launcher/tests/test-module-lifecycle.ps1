param(
    [string]$Version = "0.1.10"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$project = Join-Path $repoRoot "Launcher\RollHelperLauncher\RollHelperLauncher.csproj"
$testRoot = Join-Path $env:TEMP ("RollHelperModuleTest-" + [guid]::NewGuid().ToString("N"))
$launcherRoot = Join-Path $testRoot "launcher"
$releaseRoot = Join-Path $testRoot "release"
$programRoot = Join-Path $testRoot "program-data"
$userRoot = Join-Path $testRoot "user-data"
$server = $null
$launcherProcess = $null
$originalProgramRoot = $env:ROLLHELPER_PROGRAM_ROOT
$originalUserRoot = $env:ROLLHELPER_USER_ROOT
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function New-TestPackage {
    param(
        [string]$Id,
        [string]$PackageVersion,
        [string]$DisplayName,
        [string]$AssetPath,
        [switch]$WithEntrypoint
    )

    $packageRoot = Join-Path $testRoot ("package-" + $Id)
    New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null

    $package = [ordered]@{
        schema = 1
        id = $Id
        displayName = $DisplayName
        version = $PackageVersion
    }

    if ($WithEntrypoint) {
        $package.entrypoint = [ordered]@{
            file = "start.cmd"
            workingDirectory = "."
        }
        [IO.File]::WriteAllText((Join-Path $packageRoot "start.cmd"), "@exit /b 0`r`n", [Text.Encoding]::ASCII)
    }

    [IO.File]::WriteAllText(
        (Join-Path $packageRoot "package.json"),
        ($package | ConvertTo-Json -Depth 5),
        $utf8NoBom)
    Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $AssetPath -Force
}

function Find-ElementByName {
    param(
        [Windows.Automation.AutomationElement]$Root,
        [string]$Name,
        [int]$Attempts = 80
    )

    for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
        $condition = New-Object Windows.Automation.PropertyCondition(
            [Windows.Automation.AutomationElement]::NameProperty,
            $Name)
        $element = $Root.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
        if ($element) {
            return $element
        }
        Start-Sleep -Milliseconds 150
    }

    throw "UI element not found: $Name"
}

function Find-ButtonByName {
    param(
        [Windows.Automation.AutomationElement]$Root,
        [string]$Name,
        [int]$Attempts = 80
    )

    for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
        $condition = New-Object Windows.Automation.AndCondition(
            (New-Object Windows.Automation.PropertyCondition(
                [Windows.Automation.AutomationElement]::NameProperty,
                $Name)),
            (New-Object Windows.Automation.PropertyCondition(
                [Windows.Automation.AutomationElement]::ControlTypeProperty,
                [Windows.Automation.ControlType]::Button)))
        $element = $Root.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
        if ($element) {
            return $element
        }
        Start-Sleep -Milliseconds 150
    }

    throw "UI button not found: $Name"
}

function Invoke-Element {
    param([Windows.Automation.AutomationElement]$Element)
    $patternObject = $null
    if (-not $Element.TryGetCurrentPattern(
        [Windows.Automation.InvokePattern]::Pattern,
        [ref]$patternObject)) {
        throw "Element does not support InvokePattern: $($Element.Current.Name)"
    }
    ([Windows.Automation.InvokePattern]$patternObject).Invoke()
}

function Select-NamedItem {
    param(
        [Windows.Automation.AutomationElement]$Root,
        [string]$Name
    )

    $element = Find-ElementByName -Root $Root -Name $Name
    $walker = [Windows.Automation.TreeWalker]::ControlViewWalker
    for ($depth = 0; $depth -lt 8 -and $element; $depth++) {
        $patternObject = $null
        if ($element.TryGetCurrentPattern(
            [Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$patternObject)) {
            ([Windows.Automation.SelectionItemPattern]$patternObject).Select()
            return
        }
        $element = $walker.GetParent($element)
    }

    throw "Selectable row not found for: $Name"
}

function Read-State {
    $statePath = Join-Path $programRoot "State\packages.json"
    if (-not (Test-Path -LiteralPath $statePath)) {
        return $null
    }
    return Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}

New-Item -ItemType Directory -Force -Path @($launcherRoot, $releaseRoot) | Out-Null

try {
    dotnet publish $project `
        -c Release `
        -r win-x64 `
        --self-contained true `
        -p:PublishSingleFile=true `
        -p:Version=$Version `
        -o $launcherRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Launcher test build failed with exit code $LASTEXITCODE"
    }

    Get-ChildItem -LiteralPath $launcherRoot -Filter "*.pdb" | Remove-Item -Force

    $brandAsset = Join-Path $releaseRoot "test-brand.zip"
    $moduleAsset = Join-Path $releaseRoot "test-module.zip"
    New-TestPackage -Id "test-brand" -PackageVersion "1.0.0" -DisplayName "Test Program" -AssetPath $brandAsset -WithEntrypoint
    New-TestPackage -Id "test-module" -PackageVersion "1.0.0" -DisplayName "Test Module" -AssetPath $moduleAsset

    $manifest = [ordered]@{
        schema = 1
        release = $Version
        packages = @(
            [ordered]@{
                id = "test-brand"
                type = "brand"
                displayName = "Test Program"
                version = "1.0.0"
                asset = "test-brand.zip"
                sha256 = (Get-FileHash -LiteralPath $brandAsset -Algorithm SHA256).Hash.ToLowerInvariant()
            },
            [ordered]@{
                id = "test-module"
                type = "module"
                displayName = "Test Module"
                version = "1.0.0"
                extends = "test-brand"
                requires = @(
                    [ordered]@{ id = "test-brand"; minVersion = "1.0.0" }
                )
                asset = "test-module.zip"
                sha256 = (Get-FileHash -LiteralPath $moduleAsset -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        )
    }
    [IO.File]::WriteAllText(
        (Join-Path $releaseRoot "release-manifest.json"),
        ($manifest | ConvertTo-Json -Depth 8),
        $utf8NoBom)

    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()

    $server = Start-Process python `
        -ArgumentList "-m", "http.server", $port, "--bind", "127.0.0.1", "--directory", $releaseRoot `
        -WindowStyle Hidden `
        -PassThru

    $config = @{ manifestUrl = "http://127.0.0.1:$port/release-manifest.json" } | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $launcherRoot "launcher.config.json"), $config, $utf8NoBom)
    Start-Sleep -Seconds 1

    $env:ROLLHELPER_PROGRAM_ROOT = $programRoot
    $env:ROLLHELPER_USER_ROOT = $userRoot
    $launcherProcess = Start-Process `
        -FilePath (Join-Path $launcherRoot "RollHelperLauncher.exe") `
        -WorkingDirectory $launcherRoot `
        -PassThru

    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ModuleTestNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
}
"@

    $window = $null
    for ($attempt = 0; $attempt -lt 80 -and -not $window; $attempt++) {
        Start-Sleep -Milliseconds 150
        $processCondition = New-Object Windows.Automation.PropertyCondition(
            [Windows.Automation.AutomationElement]::ProcessIdProperty,
            $launcherProcess.Id)
        $window = [Windows.Automation.AutomationElement]::RootElement.FindFirst(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)
    }
    if (-not $window) {
        throw "Launcher window did not appear."
    }

    $transformObject = $null
    if ($window.TryGetCurrentPattern(
        [Windows.Automation.TransformPattern]::Pattern,
        [ref]$transformObject)) {
        $transformPattern = [Windows.Automation.TransformPattern]$transformObject
        if ($transformPattern.Current.CanResize) {
            $transformPattern.Resize(760, 560)
            Start-Sleep -Milliseconds 300
        }
    }

    $headerButtons = @(
        Find-ButtonByName -Root $window -Name "Проверить обновление лаунчера"
        Find-ButtonByName -Root $window -Name "Обновить список программ"
        Find-ButtonByName -Root $window -Name "Открыть лог"
    )
    for ($index = 0; $index -lt ($headerButtons.Count - 1); $index++) {
        $left = $headerButtons[$index].Current.BoundingRectangle
        $right = $headerButtons[$index + 1].Current.BoundingRectangle
        $verticalOverlap = $left.Top -lt $right.Bottom -and $right.Top -lt $left.Bottom
        if ($verticalOverlap -and $left.Right -gt $right.Left) {
            throw "Header buttons overlap at laptop window width."
        }
    }

    Find-ElementByName -Root $window -Name "Test Program" | Out-Null

    $moduleNameCondition = New-Object Windows.Automation.PropertyCondition(
        [Windows.Automation.AutomationElement]::NameProperty,
        "Test Module")
    $moduleBeforeSelection = $window.FindFirst(
        [Windows.Automation.TreeScope]::Descendants,
        $moduleNameCondition)
    if ($moduleBeforeSelection) {
        throw "Modules must stay hidden until the user selects a program."
    }

    Select-NamedItem -Root $window -Name "Test Program"
    Find-ElementByName -Root $window -Name "Test Module" | Out-Null

    $splitterCondition = New-Object Windows.Automation.PropertyCondition(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::Thumb)
    $splitter = $window.FindFirst(
        [Windows.Automation.TreeScope]::Descendants,
        $splitterCondition)
    if (-not $splitter) {
        throw "Resizable program/module splitter was not exposed after program selection."
    }

    $installModuleButton = Find-ButtonByName -Root $window -Name "Установить"
    if ($installModuleButton.Current.IsEnabled) {
        throw "Module installation must be disabled before its required program is installed."
    }

    Invoke-Element (Find-ButtonByName -Root $window -Name "Установить Test Program и запустить")
    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        Start-Sleep -Milliseconds 150
        if (Test-Path -LiteralPath (Join-Path $programRoot "Packages\test-brand\1.0.0\package.json")) {
            break
        }
    }

    $installModuleButton = Find-ButtonByName -Root $window -Name "Установить"
    for ($attempt = 0; $attempt -lt 40 -and -not $installModuleButton.Current.IsEnabled; $attempt++) {
        Start-Sleep -Milliseconds 150
        $installModuleButton = Find-ButtonByName -Root $window -Name "Установить"
    }
    if (-not $installModuleButton.Current.IsEnabled) {
        throw "Module installation did not become available after program installation."
    }

    Invoke-Element $installModuleButton
    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        Start-Sleep -Milliseconds 150
        $state = Read-State
        if ($state -and $state.packages.'test-module'.enabled -eq $true) {
            break
        }
    }
    $state = Read-State
    if (-not $state -or $state.packages.'test-module'.enabled -ne $true) {
        throw "Installed module was not marked as enabled."
    }

    Invoke-Element (Find-ButtonByName -Root $window -Name "Отключить")
    Start-Sleep -Milliseconds 300
    if ((Read-State).packages.'test-module'.enabled -ne $false) {
        throw "Module was not disabled."
    }

    Invoke-Element (Find-ButtonByName -Root $window -Name "Включить")
    Start-Sleep -Milliseconds 300
    if ((Read-State).packages.'test-module'.enabled -ne $true) {
        throw "Module was not enabled again."
    }

    $removeButton = Find-ButtonByName -Root $window -Name "Удалить"
    if (-not $removeButton.Current.IsEnabled) {
        throw "Remove button is disabled after module installation."
    }
    $originalCursor = New-Object ModuleTestNative+POINT
    [ModuleTestNative]::GetCursorPos([ref]$originalCursor) | Out-Null
    $removeBounds = $removeButton.Current.BoundingRectangle
    [ModuleTestNative]::SetForegroundWindow([IntPtr]$window.Current.NativeWindowHandle) | Out-Null
    [ModuleTestNative]::SetCursorPos(
        [int]($removeBounds.Left + ($removeBounds.Width / 2)),
        [int]($removeBounds.Top + ($removeBounds.Height / 2))) | Out-Null
    [ModuleTestNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [ModuleTestNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    [ModuleTestNative]::SetCursorPos($originalCursor.X, $originalCursor.Y) | Out-Null
    Start-Sleep -Milliseconds 300
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait("{LEFT}{ENTER}")
    Start-Sleep -Milliseconds 500

    if (Test-Path -LiteralPath (Join-Path $programRoot "Packages\test-module")) {
        throw "Module directory still exists after removal."
    }
    if ((Read-State).packages.PSObject.Properties.Name -contains "test-module") {
        throw "Module state still exists after removal."
    }

    [pscustomobject]@{
        Passed = $true
        TestRoot = $testRoot
        ProgramInstalled = $true
        ModuleInstalled = $true
        ModuleDisabled = $true
        ModuleEnabledAgain = $true
        ModuleRemoved = $true
    }
}
finally {
    $env:ROLLHELPER_PROGRAM_ROOT = $originalProgramRoot
    $env:ROLLHELPER_USER_ROOT = $originalUserRoot

    if ($launcherProcess -and -not $launcherProcess.HasExited) {
        Stop-Process -Id $launcherProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }
}
