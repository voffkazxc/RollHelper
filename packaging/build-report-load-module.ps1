param(
    [string]$Version = "0.1.0",
    [string]$OutputDirectory = (Join-Path $env:TEMP "RollHelperRelease")
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path $OutputDirectory $Version
$packageRoot = Join-Path $releaseRoot "report-load-package"
$moduleSource = Join-Path $repoRoot "modules\rollhouse-report-load"
$assetName = "module-rollhouse-report-load-$Version.zip"
$assetPath = Join-Path $releaseRoot $assetName

if (Test-Path $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $packageRoot "lib") | Out-Null
Copy-Item -LiteralPath (Join-Path $moduleSource "report_load.ahk") -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $moduleSource "README.md") -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repoRoot "lib\UIA_Interface.ahk") -Destination (Join-Path $packageRoot "lib")

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
Get-ChildItem -LiteralPath $packageRoot -Recurse -Filter "*.ahk" | ForEach-Object {
    $sourceText = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($_.FullName, $sourceText, $utf8Bom)
}

$packageDescription = @{
    schema = 1
    id = "rollhouse-report-load"
    displayName = "Отчёт — нагрузка"
    version = $Version
    entrypoint = @{
        file = "report_load.ahk"
        workingDirectory = "."
    }
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText(
    (Join-Path $packageRoot "package.json"),
    ($packageDescription | ConvertTo-Json -Depth 4),
    $utf8NoBom)

Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $assetPath -CompressionLevel Optimal -Force
$sha256 = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()

[pscustomobject]@{
    Id = "rollhouse-report-load"
    Version = $Version
    AssetName = $assetName
    AssetPath = $assetPath
    Sha256 = $sha256
}
