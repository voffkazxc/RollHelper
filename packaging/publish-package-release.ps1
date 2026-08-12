param(
    [string]$RequestPath = (Join-Path $PSScriptRoot "package-release.json"),
    [string]$Repository = "voffkazxc/RollHelper",
    [string]$OutputDirectory = (Join-Path $env:TEMP "RollHelperPackageRelease"),
    [switch]$Publish
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $RequestPath -PathType Leaf)) {
    throw "Release request not found: $RequestPath"
}

$request = Get-Content -LiteralPath $RequestPath -Raw | ConvertFrom-Json
$catalogVersion = [string]$request.catalogVersion
$launcherVersion = [string]$request.launcherVersion
$rollhouseVersion = [string]$request.rollhouseVersion
$reportLoadVersion = [string]$request.reportLoadVersion

foreach ($versionEntry in @(
    @{ Name = "catalogVersion"; Value = $catalogVersion },
    @{ Name = "launcherVersion"; Value = $launcherVersion },
    @{ Name = "rollhouseVersion"; Value = $rollhouseVersion },
    @{ Name = "reportLoadVersion"; Value = $reportLoadVersion }
)) {
    if ($versionEntry.Value -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid $($versionEntry.Name): $($versionEntry.Value)"
    }
}

$catalogRoot = Join-Path $OutputDirectory $catalogVersion
$rollhouseBuild = & (Join-Path $PSScriptRoot "build-rollhouse-mvp.ps1") `
    -Version $rollhouseVersion `
    -OutputDirectory $OutputDirectory
$reportBuild = & (Join-Path $PSScriptRoot "build-report-load-module.ps1") `
    -Version $reportLoadVersion `
    -OutputDirectory $OutputDirectory

New-Item -ItemType Directory -Force -Path $catalogRoot | Out-Null

$rollhouseAssetName = Split-Path -Leaf $rollhouseBuild.Package
$reportAssetName = Split-Path -Leaf $reportBuild.AssetPath
$catalogTag = "v$catalogVersion"
$catalogAssetBaseUrl = "https://github.com/$Repository/releases/download/$catalogTag"
$launcherManifestUrl = "https://github.com/$Repository/releases/download/v$launcherVersion/release-manifest.json"
$launcherManifestPath = Join-Path $catalogRoot "launcher-source-manifest.json"
Invoke-WebRequest -Uri $launcherManifestUrl -OutFile $launcherManifestPath
$launcherManifest = Get-Content -LiteralPath $launcherManifestPath -Raw | ConvertFrom-Json

if ([string]$launcherManifest.launcher.version -ne $launcherVersion) {
    throw "Launcher manifest version mismatch: expected $launcherVersion, got $($launcherManifest.launcher.version)"
}

$launcherAsset = [string]$launcherManifest.launcher.asset
$launcherUrl = if (-not [string]::IsNullOrWhiteSpace([string]$launcherManifest.launcher.url)) {
    [string]$launcherManifest.launcher.url
}
else {
    "https://github.com/$Repository/releases/download/v$launcherVersion/$launcherAsset"
}

$manifest = [ordered]@{
    schema = 1
    release = $catalogVersion
    packages = @(
        [ordered]@{
            id = "rollhouse"
            type = "brand"
            displayName = "RollHouse"
            version = $rollhouseVersion
            url = "$catalogAssetBaseUrl/$rollhouseAssetName"
            sha256 = [string]$rollhouseBuild.Sha256
        },
        [ordered]@{
            id = "rollhouse-report-load"
            type = "module"
            displayName = "Отчёт — нагрузка"
            version = $reportLoadVersion
            extends = "rollhouse"
            requires = @(
                [ordered]@{
                    id = "rollhouse"
                    minVersion = $rollhouseVersion
                }
            )
            url = "$catalogAssetBaseUrl/$reportAssetName"
            sha256 = [string]$reportBuild.Sha256
        }
    )
    launcher = [ordered]@{
        version = $launcherVersion
        url = $launcherUrl
        sha256 = [string]$launcherManifest.launcher.sha256
    }
}

$manifestPath = Join-Path $catalogRoot "release-manifest.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText(
    $manifestPath,
    ($manifest | ConvertTo-Json -Depth 8),
    $utf8NoBom)

Remove-Item -LiteralPath $launcherManifestPath -Force

foreach ($assetPath in @($rollhouseBuild.Package, $reportBuild.AssetPath, $manifestPath)) {
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        throw "Release asset was not created: $assetPath"
    }
}

if ($Publish) {
    $notesPath = Join-Path $catalogRoot "release-notes.md"
    @"
Обновлены пакеты RollHelper.

- RollHouse: $rollhouseVersion
- Дополнение «Отчёт — нагрузка»: $reportLoadVersion
- Лаунчер остаётся на версии $launcherVersion
"@ | Set-Content -LiteralPath $notesPath -Encoding UTF8

    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $existingRelease = gh release view $catalogTag --repo $Repository --json tagName 2>$null
        $releaseLookupExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorPreference
    }

    if ($releaseLookupExitCode -eq 0 -and $existingRelease) {
        gh release upload $catalogTag `
            $rollhouseBuild.Package `
            $reportBuild.AssetPath `
            $manifestPath `
            --clobber `
            --repo $Repository
        gh release edit $catalogTag `
            --title "RollHelper $catalogVersion" `
            --notes-file $notesPath `
            --latest `
            --repo $Repository
    }
    else {
        gh release create $catalogTag `
            $rollhouseBuild.Package `
            $reportBuild.AssetPath `
            $manifestPath `
            --target master `
            --title "RollHelper $catalogVersion" `
            --notes-file $notesPath `
            --latest `
            --repo $Repository
    }

    if ($LASTEXITCODE -ne 0) {
        throw "GitHub release publication failed"
    }

    $latestManifestUrl = "https://github.com/$Repository/releases/latest/download/release-manifest.json"
    $response = Invoke-WebRequest -Uri $latestManifestUrl -Method Head
    if ($response.StatusCode -ne 200) {
        throw "Published manifest is unavailable: $latestManifestUrl"
    }
}

[pscustomobject]@{
    CatalogVersion = $catalogVersion
    LauncherVersion = $launcherVersion
    RollHouseVersion = $rollhouseVersion
    ReportLoadVersion = $reportLoadVersion
    RollHouseAsset = $rollhouseBuild.Package
    ReportLoadAsset = $reportBuild.AssetPath
    Manifest = $manifestPath
    Published = [bool]$Publish
}
