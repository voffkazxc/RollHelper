param(
    [string]$ReleaseRoot = (Join-Path $env:TEMP "RollHelperRelease\0.1.11"),
    [string]$OldVersion = "0.1.10",
    [string]$NewVersion = "0.1.11"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$project = Join-Path $repoRoot "Launcher\RollHelperLauncher\RollHelperLauncher.csproj"
$testRoot = Join-Path $env:TEMP ("RollHelperSelfUpdateTest-" + [guid]::NewGuid().ToString("N"))
$installRoot = Join-Path $testRoot "launcher"
$server = $null

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

dotnet publish $project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:Version=$OldVersion `
    -o $installRoot

if ($LASTEXITCODE -ne 0) {
    throw "Old launcher test build failed with exit code $LASTEXITCODE"
}

Get-ChildItem -LiteralPath $installRoot -Filter "*.pdb" | Remove-Item -Force

$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()

try {
    $server = Start-Process python `
        -ArgumentList "-m", "http.server", $port, "--bind", "127.0.0.1", "--directory", $ReleaseRoot `
        -WindowStyle Hidden `
        -PassThru

    $config = @{ manifestUrl = "http://127.0.0.1:$port/release-manifest.json" } | ConvertTo-Json
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $installRoot "launcher.config.json"), $config, $utf8NoBom)
    Start-Sleep -Seconds 1

    $executable = Join-Path $installRoot "RollHelperLauncher.exe"
    $versionBefore = (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
    $launcherProcess = Start-Process -FilePath $executable -WorkingDirectory $installRoot -PassThru

    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes

    $updateButton = $null
    for ($attempt = 0; $attempt -lt 60 -and -not $updateButton; $attempt++) {
        Start-Sleep -Milliseconds 250
        $processCondition = New-Object Windows.Automation.PropertyCondition(
            [Windows.Automation.AutomationElement]::ProcessIdProperty,
            $launcherProcess.Id)
        $window = [Windows.Automation.AutomationElement]::RootElement.FindFirst(
            [Windows.Automation.TreeScope]::Children,
            $processCondition)

        if ($window) {
            $nameCondition = New-Object Windows.Automation.PropertyCondition(
                [Windows.Automation.AutomationElement]::NameProperty,
                "Обновить лаунчер до $NewVersion")
            $updateButton = $window.FindFirst(
                [Windows.Automation.TreeScope]::Descendants,
                $nameCondition)
        }
    }

    if (-not $updateButton) {
        throw "Update button did not appear."
    }

    $invokePattern = $updateButton.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern)
    $invokePattern.Invoke()

    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        Start-Sleep -Milliseconds 500
        $versionAfter = (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
        if ($versionAfter -like "$NewVersion*") {
            break
        }
    }

    $versionAfter = (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
    $updated = $versionAfter -like "$NewVersion*"

    [pscustomobject]@{
        TestRoot = $testRoot
        VersionBefore = $versionBefore
        VersionAfter = $versionAfter
        Updated = $updated
        UpdaterLog = Join-Path $env:LOCALAPPDATA "RollHelper\Logs\updater.log"
    }

    if (-not $updated) {
        throw "Self-update did not replace the launcher."
    }
}
finally {
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force
    }

    Get-Process RollHelperLauncher -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Path -and $_.Path.StartsWith($installRoot, [StringComparison]::OrdinalIgnoreCase)
        } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
