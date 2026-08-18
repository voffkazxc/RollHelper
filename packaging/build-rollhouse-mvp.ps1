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

$resolvedOutput = [IO.Path]::GetFullPath($OutputDirectory)
$resolvedRelease = [IO.Path]::GetFullPath($releaseRoot)
if (-not $resolvedRelease.StartsWith($resolvedOutput, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe release path: $resolvedRelease"
}

if (Test-Path $releaseRoot) {
    Remove-Item -LiteralPath $releaseRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path @(
    $rollHelperRoot,
    $serverRoot,
    $pythonRoot,
    (Join-Path $packageRoot "data"),
    (Join-Path $rollHelperRoot "brands\rollhouse")
) | Out-Null

Copy-Item -LiteralPath (Join-Path $repoRoot "main.ahk") -Destination $rollHelperRoot
Copy-Item -LiteralPath "C:\Program Files\AutoHotkey\v1.1.37.02\AutoHotkeyU64.exe" -Destination (Join-Path $rollHelperRoot "AutoHotkeyU64.exe")
Copy-Item -LiteralPath (Join-Path $repoRoot "config") -Destination $rollHelperRoot -Recurse
Copy-Item -LiteralPath (Join-Path $repoRoot "core") -Destination $rollHelperRoot -Recurse
Copy-Item -LiteralPath (Join-Path $repoRoot "lib") -Destination $rollHelperRoot -Recurse

# AutoHotkey v1 determines source encoding before FileEncoding is applied.
# Every standalone and included AHK source therefore needs a UTF-8 BOM.
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
Get-ChildItem -LiteralPath $rollHelperRoot -Recurse -Filter "*.ahk" | ForEach-Object {
    $sourceText = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($_.FullName, $sourceText, $utf8Bom)
}

foreach ($fileName in @("DeliveryPrices.ini", "RkTemplates.txt", "zones.kml")) {
    Copy-Item -LiteralPath (Join-Path $repoRoot "brands\rollhouse\$fileName") -Destination (Join-Path $rollHelperRoot "brands\rollhouse\$fileName")
}

$cleanConfig = git -C $repoRoot show HEAD:brands/rollhouse/RkConfig.ini
if ($LASTEXITCODE -ne 0) {
    throw "Cannot read the committed RollHouse configuration"
}
$cleanConfig | Set-Content -LiteralPath (Join-Path $rollHelperRoot "brands\rollhouse\RkConfig.ini") -Encoding Unicode

$emptyEnterState = @"
[Enter]
Time=
Preview=
[Order]
Brand=rollhouse
IsPickup=0
OrderSum=0
TotalSum=0
DeliveryCostText=
[Controls]
PaymentSelected=none
PaymentWillRun=0
Gifts=none
ReadyTime=
[SIV]
Rolls=0
SticksNormal=0
SticksEdu=0
[Fields]
Comment=
Kitchen=
Address=
ClientCard=
"@
$emptyEnterState | Set-Content -LiteralPath (Join-Path $rollHelperRoot "brands\rollhouse\last_enter_state.ini") -Encoding Unicode

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
    "pult_speed.json"
)
foreach ($fileName in $serverFiles) {
    Copy-Item -LiteralPath (Join-Path $sourceServer $fileName) -Destination (Join-Path $serverRoot $fileName)
}
Copy-Item -LiteralPath (Join-Path $sourceServer "static") -Destination $serverRoot -Recurse
New-Item -ItemType Directory -Force -Path (Join-Path $serverRoot "diagnostics") | Out-Null

$pythonVersion = "3.13.12"
$pythonArchive = Join-Path $releaseRoot "python-embed.zip"
$pythonUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-embed-amd64.zip"
Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonArchive
Expand-Archive -LiteralPath $pythonArchive -DestinationPath $pythonRoot
New-Item -ItemType Directory -Force -Path (Join-Path $pythonRoot "Lib\site-packages") | Out-Null

python -m pip install --disable-pip-version-check --no-compile --target (Join-Path $pythonRoot "Lib\site-packages") -r (Join-Path $sourceServer "requirements.txt")
if ($LASTEXITCODE -ne 0) {
    throw "Cannot install the embedded server dependencies"
}

$pythonPathFile = Join-Path $pythonRoot "python313._pth"
$pythonPathLines = Get-Content -LiteralPath $pythonPathFile | ForEach-Object {
    if ($_ -eq "#import site") { "import site" } else { $_ }
}
$pythonPathLines += "Lib\site-packages"
$pythonPathLines += "..\..\server"
$pythonPathLines | Set-Content -LiteralPath $pythonPathFile -Encoding ASCII

$startScript = @"
@echo off
setlocal
cd /d "%~dp0"
start "RollHouse Server" /min "%~dp0runtime\python\pythonw.exe" "%~dp0server\app.py"
start "RollHouse" "%~dp0RollHelper\AutoHotkeyU64.exe" "%~dp0RollHelper\main.ahk"
endlocal
"@
$startScript | Set-Content -LiteralPath (Join-Path $packageRoot "start_rollhouse.bat") -Encoding ASCII

$packageDescription = @{
    schema = 1
    id = "rollhouse"
    displayName = "RollHouse"
    version = $Version
    entrypoint = @{
        file = "start_rollhouse.bat"
        workingDirectory = "."
    }
    runtime = @{
        primaryExecutable = "RollHelper\AutoHotkeyU64.exe"
    }
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$packageJson = $packageDescription | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText((Join-Path $packageRoot "package.json"), $packageJson, $utf8NoBom)

$assetName = "brand-rollhouse-$Version.zip"
$assetPath = Join-Path $releaseRoot $assetName
Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $assetPath -CompressionLevel Optimal
$sha256 = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()

$releaseManifest = @{
    schema = 1
    release = $Version
    packages = @(
        @{
            id = "rollhouse"
            type = "brand"
            displayName = "RollHouse"
            version = $Version
            asset = $assetName
            sha256 = $sha256
        }
    )
}
$manifestPath = Join-Path $releaseRoot "release-manifest.json"
$manifestJson = $releaseManifest | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)

Remove-Item -LiteralPath $pythonArchive -Force

[pscustomobject]@{
    Version = $Version
    Package = $assetPath
    Manifest = $manifestPath
    Sha256 = $sha256
    PackageSizeMb = [math]::Round((Get-Item $assetPath).Length / 1MB, 2)
}
