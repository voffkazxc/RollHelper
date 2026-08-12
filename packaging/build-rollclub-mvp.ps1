param(
    [string]$Version = "0.1.0",
    [string]$OutputDirectory = (Join-Path $env:TEMP "RollHelperRelease")
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$suiteRoot = Split-Path -Parent $repoRoot
$sourceServer = Join-Path $suiteRoot "server"
$releaseRoot = Join-Path $OutputDirectory $Version
$packageRoot = Join-Path $releaseRoot "package"
$rollHelperRoot = Join-Path $packageRoot "RollHelper"
$serverRoot = Join-Path $packageRoot "server"
$pythonRoot = Join-Path $packageRoot "runtime\python"
$assetName = "brand-rollclub-$Version.zip"
$assetPath = Join-Path $releaseRoot $assetName

if (Test-Path -LiteralPath $releaseRoot) {
    Remove-Item -LiteralPath $releaseRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path @(
    $rollHelperRoot,
    $serverRoot,
    $pythonRoot,
    (Join-Path $rollHelperRoot "brands\rollclub")
) | Out-Null

Copy-Item -LiteralPath (Join-Path $repoRoot "engine_rollclub.ahk") -Destination $rollHelperRoot
Copy-Item -LiteralPath "C:\Program Files\AutoHotkey\v1.1.37.02\AutoHotkeyU64.exe" -Destination (Join-Path $rollHelperRoot "AutoHotkeyU64.exe")
Copy-Item -LiteralPath (Join-Path $repoRoot "beep_ok.wav") -Destination $rollHelperRoot
Copy-Item -LiteralPath (Join-Path $repoRoot "beep_err.wav") -Destination $rollHelperRoot
Copy-Item -LiteralPath (Join-Path $repoRoot "config") -Destination $rollHelperRoot -Recurse
Copy-Item -LiteralPath (Join-Path $repoRoot "core") -Destination $rollHelperRoot -Recurse
Copy-Item -LiteralPath (Join-Path $repoRoot "lib") -Destination $rollHelperRoot -Recurse
Copy-Item -Path (Join-Path $repoRoot "brands\rollclub\*") -Destination (Join-Path $rollHelperRoot "brands\rollclub") -Recurse
foreach ($zoneFile in @(
    "RkKitchens.ini",
    "RkKitchens.ini.bak_sheet",
    "RkPresets.txt",
    "zones.kml",
    "zones_map.ini",
    "zones_map.BEFORE_NEW_MAPPINGS_20260726_215931.ini"
)) {
    $zonePath = Join-Path $rollHelperRoot "brands\rollclub\$zoneFile"
    if (Test-Path -LiteralPath $zonePath) {
        Remove-Item -LiteralPath $zonePath -Force
    }
}

$cleanConfig = git -C $repoRoot show HEAD:brands/rollclub/RkConfig.ini
if ($LASTEXITCODE -ne 0) {
    throw "Cannot read the committed RollClub configuration"
}
$cleanConfig | Set-Content -LiteralPath (Join-Path $rollHelperRoot "brands\rollclub\RkConfig.ini") -Encoding Unicode
$packageConfig = Join-Path $rollHelperRoot "brands\rollclub\RkConfig.ini"
$configText = [IO.File]::ReadAllText($packageConfig, [Text.Encoding]::Unicode)
$configText = [regex]::Replace(
    $configText,
    "(?ms)^\[UiaMap\]\r?\n.*?(?=^\[|\z)",
    ""
)
$configText = [regex]::Replace(
    $configText,
    "(?ms)^\[UiaHidden\]\r?\n.*?(?=^\[|\z)",
    ""
)
if ($configText -match "(?im)^\[Features\]\s*$") {
    if ($configText -match "(?im)^Gifts\s*=") {
        $configText = [regex]::Replace($configText, "(?im)^Gifts\s*=.*$", "Gifts=0")
    } else {
        $configText = [regex]::Replace($configText, "(?im)^\[Features\]\s*$", "[Features]`r`nGifts=0")
    }
} else {
    $configText += "`r`n[Features]`r`nGifts=0`r`n"
}
[IO.File]::WriteAllText($packageConfig, $configText, [Text.Encoding]::Unicode)

$serverFiles = @(
    "app.py",
    "business_logic.py",
    "database.py",
    "errors.py",
    "iiko_bridge.py",
    "parser.py",
    "pult_actions.py",
    "pult_config.py",
    "pult_logic.py",
    "pult_rollclub.py",
    "pult_rollhouse_zones.py",
    "report_bot.py",
    "telegram.py",
    "pult_speed.json",
    "sync_rollclub_kitchens.py"
)
foreach ($fileName in $serverFiles) {
    Copy-Item -LiteralPath (Join-Path $sourceServer $fileName) -Destination $serverRoot
}
Copy-Item -LiteralPath (Join-Path $sourceServer "static") -Destination $serverRoot -Recurse

$syncScriptPath = Join-Path $serverRoot "sync_rollclub_kitchens.py"
$syncScriptText = [IO.File]::ReadAllText($syncScriptPath, [Text.Encoding]::UTF8)
if ($syncScriptText -notmatch "ROLLHELPER_ROLLCLUB_USERDATA") {
    $syncScriptText = $syncScriptText -replace "import datetime as dt\r?\n", "import datetime as dt`r`nimport os`r`n"
    $syncScriptText = $syncScriptText -replace "def kitchens_path\(\) -> Path:\r?\n\s+return root_dir\(\) / ""RollHelper"" / ""brands"" / ""rollclub"" / ""RkKitchens.ini""", "def kitchens_path() -> Path:`r`n    user_data = os.environ.get(""ROLLHELPER_ROLLCLUB_USERDATA"")`r`n    if user_data:`r`n        return Path(user_data) / ""RkKitchens.ini""`r`n    return root_dir() / ""RollHelper"" / ""brands"" / ""rollclub"" / ""RkKitchens.ini"""
    [IO.File]::WriteAllText($syncScriptPath, $syncScriptText, [Text.Encoding]::UTF8)
}

$pythonVersion = "3.13.12"
$pythonArchive = Join-Path $releaseRoot "python-embed.zip"
$pythonUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-embed-amd64.zip"
Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonArchive
Expand-Archive -LiteralPath $pythonArchive -DestinationPath $pythonRoot
New-Item -ItemType Directory -Force -Path (Join-Path $pythonRoot "Lib\site-packages") | Out-Null

python -m pip install --disable-pip-version-check --no-compile --target (Join-Path $pythonRoot "Lib\site-packages") -r (Join-Path $sourceServer "requirements.txt")
if ($LASTEXITCODE -ne 0) {
    throw "Cannot install embedded server dependencies"
}

$pythonPathFile = Join-Path $pythonRoot "python313._pth"
$pythonPathLines = Get-Content -LiteralPath $pythonPathFile | ForEach-Object {
    if ($_ -eq "#import site") { "import site" } else { $_ }
}
$pythonPathLines += "Lib\site-packages"
$pythonPathLines += "..\..\server"
$pythonPathLines | Set-Content -LiteralPath $pythonPathFile -Encoding ASCII

# AutoHotkey v1 determines source encoding before FileEncoding is applied.
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
Get-ChildItem -LiteralPath $rollHelperRoot -Recurse -Filter "*.ahk" | ForEach-Object {
    $sourceText = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($_.FullName, $sourceText, $utf8Bom)
}

$startScript = @"
@echo off
setlocal
cd /d "%~dp0"
start "RollClub Server" /min "%~dp0runtime\python\pythonw.exe" "%~dp0server\app.py"
start "RollClub" "%~dp0RollHelper\AutoHotkeyU64.exe" "%~dp0RollHelper\engine_rollclub.ahk"
endlocal
"@
$startScript | Set-Content -LiteralPath (Join-Path $packageRoot "start_rollclub.bat") -Encoding ASCII

$restartServerScript = @"
@echo off
setlocal
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":5000 " ^| findstr LISTENING') do taskkill /PID %%a /F >nul 2>&1
timeout /t 1 /nobreak >nul
start "RollClub Server" /min "%~dp0runtime\python\pythonw.exe" "%~dp0server\app.py"
endlocal
"@
$restartServerScript | Set-Content -LiteralPath (Join-Path $packageRoot "restart_rollclub_server.bat") -Encoding ASCII

$packageDescription = @{
    schema = 1
    id = "rollclub"
    displayName = "RollClub"
    version = $Version
    entrypoint = @{
        file = "start_rollclub.bat"
        workingDirectory = "."
    }
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot "package.json"), ($packageDescription | ConvertTo-Json -Depth 4), $utf8NoBom)

Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $assetPath -CompressionLevel Optimal -Force
Remove-Item -LiteralPath $pythonArchive -Force

[pscustomobject]@{
    Id = "rollclub"
    Version = $Version
    AssetName = $assetName
    AssetPath = $assetPath
    Sha256 = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
