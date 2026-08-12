param(
    [string]$CatalogVersion = "0.1.23",
    [string]$RollClubVersion = "0.1.0",
    [string]$DutyVersion = "0.1.0",
    [string]$SourceRelease = "0.1.22",
    [string]$Repository = "voffkazxc/RollHelper",
    [string]$OutputDirectory = (Join-Path $env:TEMP "RollHelperRollClubRelease"),
    [switch]$Publish
)

$ErrorActionPreference = "Stop"

foreach ($entry in @(
    @{ Name = "CatalogVersion"; Value = $CatalogVersion },
    @{ Name = "RollClubVersion"; Value = $RollClubVersion },
    @{ Name = "DutyVersion"; Value = $DutyVersion },
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
$dutyBuild = & (Join-Path $PSScriptRoot "build-rollclub-duty-module.ps1") `
    -Version $DutyVersion `
    -OutputDirectory $OutputDirectory

$sourceManifestUrl = "https://github.com/$Repository/releases/download/v$SourceRelease/release-manifest.json"
$sourceManifest = Invoke-RestMethod -Uri $sourceManifestUrl
if ($null -eq $sourceManifest.launcher) {
    throw "Source manifest has no launcher section: $sourceManifestUrl"
}

$catalogTag = "v$CatalogVersion"
$assetBaseUrl = "https://github.com/$Repository/releases/download/$catalogTag"
$rollClubAsset = Split-Path -Leaf $rollClubBuild.AssetPath
$dutyAsset = Split-Path -Leaf $dutyBuild.AssetPath

$packages = @()
foreach ($package in @($sourceManifest.packages)) {
    if ($package.id -notin @("rollclub", "rollclub-duty")) {
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
$packages += [ordered]@{
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
Додано RollClub як окрему програму.

- RollClub: $RollClubVersion
- Доповнення «Дежурство заказов (F4)»: $DutyVersion
- RollHouse і лаунчер без змін
"@ | Set-Content -LiteralPath $notesPath -Encoding UTF8

    gh release create $catalogTag `
        $rollClubBuild.AssetPath $dutyBuild.AssetPath $manifestPath `
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
    DutyAsset = $dutyBuild.AssetPath
    Manifest = $manifestPath
    Published = [bool]$Publish
}
