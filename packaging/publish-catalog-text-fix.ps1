param(
    [string]$CatalogVersion = "0.1.24",
    [string]$SourceRelease = "0.1.23",
    [string]$Repository = "voffkazxc/RollHelper",
    [string]$OutputDirectory = (Join-Path $env:TEMP "RollHelperCatalogFix"),
    [switch]$Publish
)

$ErrorActionPreference = "Stop"

foreach ($entry in @(
    @{ Name = "CatalogVersion"; Value = $CatalogVersion },
    @{ Name = "SourceRelease"; Value = $SourceRelease }
)) {
    if ($entry.Value -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid $($entry.Name): $($entry.Value)"
    }
}

$sourceUrl = "https://github.com/$Repository/releases/download/v$SourceRelease/release-manifest.json"
$manifest = Invoke-RestMethod -Uri $sourceUrl
$displayNames = @{
    "rollhouse" = "RollHouse"
    "rollhouse-report-load" = "Отчёт — нагрузка"
    "rollclub" = "RollClub"
    "rollclub-duty" = "Дежурство заказов (F4)"
}

foreach ($package in @($manifest.packages)) {
    if ($displayNames.ContainsKey([string]$package.id)) {
        $package.displayName = $displayNames[[string]$package.id]
    }
}
$manifest.release = $CatalogVersion

$releaseRoot = Join-Path $OutputDirectory $CatalogVersion
New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
$manifestPath = Join-Path $releaseRoot "release-manifest.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 10), $utf8NoBom)

if ($Publish) {
    $notesPath = Join-Path $releaseRoot "release-notes.md"
    @"
Виправлено відображення назв програм і доповнень у лаунчері.

Пакети RollHouse, RollClub та всі доповнення не перевипускалися.
"@ | Set-Content -LiteralPath $notesPath -Encoding UTF8

    gh release create "v$CatalogVersion" $manifestPath `
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
    Manifest = $manifestPath
    Published = [bool]$Publish
}
