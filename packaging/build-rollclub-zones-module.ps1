param(
    [string]$Version = "0.1.0",
    [string]$OutputDirectory = (Join-Path $env:TEMP "RollHelperRelease")
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path $OutputDirectory $Version
$packageRoot = Join-Path $releaseRoot "rollclub-zones-package"
$moduleSource = Join-Path $repoRoot "modules\rollclub-zones"
$assetName = "module-rollclub-zones-$Version.zip"
$assetPath = Join-Path $releaseRoot $assetName

if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $moduleSource "rollclub_zones.ahk") -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $moduleSource "README.md") -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $moduleSource "data") -Destination $packageRoot -Recurse

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
Get-ChildItem -LiteralPath $packageRoot -Filter "*.ahk" | ForEach-Object {
    $sourceText = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($_.FullName, $sourceText, $utf8Bom)
}

$packageDescription = @{
    schema = 1
    id = "rollclub-zones"
    displayName = "Зони доставки RollClub"
    version = $Version
    entrypoint = @{
        file = "rollclub_zones.ahk"
        workingDirectory = "."
    }
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot "package.json"), ($packageDescription | ConvertTo-Json -Depth 4), $utf8NoBom)

Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $assetPath -CompressionLevel Optimal -Force

[pscustomobject]@{
    Id = "rollclub-zones"
    Version = $Version
    AssetName = $assetName
    AssetPath = $assetPath
    Sha256 = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
