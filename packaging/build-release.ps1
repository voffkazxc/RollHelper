param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$OutputDirectory = (Join-Path $env:TEMP "RollHelperRelease")
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path $OutputDirectory $Version
$launcherPublishRoot = Join-Path $releaseRoot "launcher-publish"
$launcherAssetName = "RollHelperLauncher-win-x64-$Version.zip"
$launcherAssetPath = Join-Path $releaseRoot $launcherAssetName
$launcherProject = Join-Path $repoRoot "Launcher\RollHelperLauncher\RollHelperLauncher.csproj"
$manifestPath = Join-Path $releaseRoot "release-manifest.json"

& (Join-Path $PSScriptRoot "build-rollhouse-mvp.ps1") `
    -Version $Version `
    -OutputDirectory $OutputDirectory

$reportModule = & (Join-Path $PSScriptRoot "build-report-load-module.ps1") `
    -Version $Version `
    -OutputDirectory $OutputDirectory

New-Item -ItemType Directory -Force -Path $launcherPublishRoot | Out-Null

dotnet publish $launcherProject `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:Version=$Version `
    -o $launcherPublishRoot

if ($LASTEXITCODE -ne 0) {
    throw "Launcher publish failed with exit code $LASTEXITCODE"
}

Get-ChildItem -LiteralPath $launcherPublishRoot -Filter "*.pdb" | Remove-Item -Force
Compress-Archive `
    -Path (Join-Path $launcherPublishRoot "*") `
    -DestinationPath $launcherAssetPath `
    -CompressionLevel Optimal `
    -Force

$launcherSha256 = (Get-FileHash -LiteralPath $launcherAssetPath -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.packages += [pscustomobject]@{
    id = $reportModule.Id
    type = "module"
    displayName = "Отчёт — нагрузка"
    version = $reportModule.Version
    extends = "rollhouse"
    requires = @(
        [pscustomobject]@{
            id = "rollhouse"
            minVersion = $Version
        }
    )
    asset = $reportModule.AssetName
    sha256 = $reportModule.Sha256
}
$manifest | Add-Member -NotePropertyName launcher -NotePropertyValue ([pscustomobject]@{
    version = $Version
    asset = $launcherAssetName
    sha256 = $launcherSha256
}) -Force

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$manifestJson = $manifest | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)

Remove-Item -LiteralPath $launcherPublishRoot -Recurse -Force

[pscustomobject]@{
    Version = $Version
    Launcher = $launcherAssetPath
    LauncherSha256 = $launcherSha256
    Package = Join-Path $releaseRoot "brand-rollhouse-$Version.zip"
    ReportModule = $reportModule.AssetPath
    Manifest = $manifestPath
}
