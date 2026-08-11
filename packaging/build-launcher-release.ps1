param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$PackagesManifestPath,
    [Parameter(Mandatory = $true)]
    [string]$PackageAssetBaseUrl,
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

if (-not (Test-Path -LiteralPath $PackagesManifestPath -PathType Leaf)) {
    throw "Packages manifest not found: $PackagesManifestPath"
}

New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
if (Test-Path -LiteralPath $launcherPublishRoot) {
    Remove-Item -LiteralPath $launcherPublishRoot -Recurse -Force
}
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

$sourceManifest = Get-Content -LiteralPath $PackagesManifestPath -Raw | ConvertFrom-Json
$packageBaseUri = [Uri]($PackageAssetBaseUrl.TrimEnd('/') + '/')
$packages = foreach ($package in @($sourceManifest.packages)) {
    $copy = [ordered]@{}
    foreach ($property in $package.PSObject.Properties) {
        if ($property.Name -notin @('asset', 'url')) {
            $copy[$property.Name] = $property.Value
        }
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$package.url)) {
        $copy.url = [string]$package.url
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$package.asset)) {
        $copy.url = ([Uri]::new($packageBaseUri, [string]$package.asset)).AbsoluteUri
    }
    else {
        throw "Package '$($package.id)' has neither url nor asset."
    }

    [pscustomobject]$copy
}

$launcherSha256 = (Get-FileHash -LiteralPath $launcherAssetPath -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest = [ordered]@{
    schema = 1
    release = $Version
    packages = @($packages)
    launcher = [ordered]@{
        version = $Version
        asset = $launcherAssetName
        sha256 = $launcherSha256
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$manifestJson = $manifest | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)

Remove-Item -LiteralPath $launcherPublishRoot -Recurse -Force

[pscustomobject]@{
    Version = $Version
    Launcher = $launcherAssetPath
    LauncherSha256 = $launcherSha256
    Packages = @($packages).Count
    Manifest = $manifestPath
}
