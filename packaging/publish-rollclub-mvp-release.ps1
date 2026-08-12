param(
    [string]$CatalogVersion = "0.1.23",
    [string]$RollClubVersion = "0.1.0",
    [string]$DutyVersion = "0.1.0",
    [string]$ZonesVersion = "0.1.0",
    [string]$SourceRelease = "0.1.22",
    [string]$Repository = "voffkazxc/RollHelper",
    [string]$OutputDirectory = (Join-Path $env:TEMP "RollHelperRollClubRelease"),
    [switch]$RebuildDuty,
    [switch]$RebuildZones,
    [switch]$Publish
)

$ErrorActionPreference = "Stop"

foreach ($entry in @(
    @{ Name = "CatalogVersion"; Value = $CatalogVersion },
    @{ Name = "RollClubVersion"; Value = $RollClubVersion },
    @{ Name = "DutyVersion"; Value = $DutyVersion },
    @{ Name = "ZonesVersion"; Value = $ZonesVersion },
    @{ Name = "SourceRelease"; Value = $SourceRelease }
)) {
    if ($entry.Value -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid $($entry.Name): $($entry.Value)"
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path $OutputDirectory $CatalogVersion
New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null

$rollClubBuild = & (Join-Path $PSScriptRoot "build-rollclub-mvp.ps1") `
    -Version $RollClubVersion `
    -OutputDirectory $OutputDirectory
$sourceManifestUrl = "https://github.com/$Repository/releases/download/v$SourceRelease/release-manifest.json"
$sourceManifestPath = Join-Path $releaseRoot "source-release-manifest.json"
Invoke-WebRequest -UseBasicParsing -Uri $sourceManifestUrl -OutFile $sourceManifestPath
$sourceManifest = [IO.File]::ReadAllText($sourceManifestPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
Remove-Item -LiteralPath $sourceManifestPath -Force
if ($null -eq $sourceManifest.launcher) {
    throw "Source manifest has no launcher section: $sourceManifestUrl"
}

$catalogTag = "v$CatalogVersion"
$assetBaseUrl = "https://github.com/$Repository/releases/download/$catalogTag"
$rollClubAsset = Split-Path -Leaf $rollClubBuild.AssetPath
$sourceDuty = @($sourceManifest.packages) | Where-Object { $_.id -eq "rollclub-duty" } | Select-Object -First 1
$sourceZones = @($sourceManifest.packages) | Where-Object { $_.id -eq "rollclub-zones" } | Select-Object -First 1
if ($RebuildDuty) {
    $dutyBuild = & (Join-Path $PSScriptRoot "build-rollclub-duty-module.ps1") `
        -Version $DutyVersion `
        -OutputDirectory $OutputDirectory
    $dutyAsset = Split-Path -Leaf $dutyBuild.AssetPath
    $dutyPackage = [ordered]@{
        id = "rollclub-duty"
        type = "module"
        displayName = "Дежурство заказов (F4)"
        version = $DutyVersion
        extends = "rollclub"
        requires = @(
            [ordered]@{ id = "rollclub"; minVersion = $RollClubVersion }
        )
        url = "$assetBaseUrl/$dutyAsset"
        sha256 = [string]$dutyBuild.Sha256
    }
} elseif ($null -ne $sourceDuty) {
    $dutyPackage = $sourceDuty
} else {
    throw "Source manifest has no rollclub-duty package. Use -RebuildDuty for the first release."
}

if ($RebuildZones) {
    $zonesBuild = & (Join-Path $PSScriptRoot "build-rollclub-zones-module.ps1") `
        -Version $ZonesVersion `
        -OutputDirectory $OutputDirectory
    $zonesAsset = Split-Path -Leaf $zonesBuild.AssetPath
    $zonesPackage = [ordered]@{
        id = "rollclub-zones"
        type = "module"
        displayName = "Зони доставки RollClub"
        version = $ZonesVersion
        extends = "rollclub"
        requires = @(
            [ordered]@{ id = "rollclub"; minVersion = $RollClubVersion }
        )
        url = "$assetBaseUrl/$zonesAsset"
        sha256 = [string]$zonesBuild.Sha256
    }
} elseif ($null -ne $sourceZones) {
    $zonesPackage = $sourceZones
} else {
    throw "Source manifest has no rollclub-zones package. Use -RebuildZones for the first release."
}

$packages = @()
foreach ($package in @($sourceManifest.packages)) {
    if ($package.id -notin @("rollclub", "rollclub-duty", "rollclub-zones")) {
        $packages += $package
    }
}
$packages += [ordered]@{
    id = "rollclub"
    type = "brand"
    displayName = "RollClub"
    version = $RollClubVersion
    url = "$assetBaseUrl/$rollClubAsset"
    sha256 = [string]$rollClubBuild.Sha256
}
$packages += $dutyPackage
$packages += $zonesPackage

$manifest = [ordered]@{
    schema = 1
    release = $CatalogVersion
    packages = $packages
    launcher = $sourceManifest.launcher
}
$manifestPath = Join-Path $releaseRoot "release-manifest.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 10), $utf8NoBom)

if ($Publish) {
    $notesPath = Join-Path $releaseRoot "release-notes.md"
    @"
Оновлено RollClub MVP без змін RollHouse та його доповнень.

- RollClub: $RollClubVersion
- у базі залишено тільки тільду та F1
- F4 залишається окремим доповненням
- зони доставки винесено в окреме доповнення
- виправлено шапку, вікно F1 і перезапуск сервера
- RollHouse, його доповнення та лаунчер без змін
"@ | Set-Content -LiteralPath $notesPath -Encoding UTF8

    $assetsToPublish = @($rollClubBuild.AssetPath, $manifestPath)
    if ($RebuildDuty) {
        $assetsToPublish += $dutyBuild.AssetPath
    }
    if ($RebuildZones) {
        $assetsToPublish += $zonesBuild.AssetPath
    }
    gh release create $catalogTag `
        $assetsToPublish `
        --target master `
        --title "RollHelper $CatalogVersion" `
        --notes-file $notesPath `
        --latest `
        --repo $Repository
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub release publication failed"
    }
}

[pscustomobject]@{
    CatalogVersion = $CatalogVersion
    RollClubAsset = $rollClubBuild.AssetPath
    DutyAsset = if ($RebuildDuty) { $dutyBuild.AssetPath } else { [string]$dutyPackage.url }
    ZonesAsset = if ($RebuildZones) { $zonesBuild.AssetPath } else { [string]$zonesPackage.url }
    Manifest = $manifestPath
    Published = [bool]$Publish
}
