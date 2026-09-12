param(
    [string]$CatalogVersion = "0.1.23",
    [string]$RollClubVersion = "0.1.0",
    [string]$DutyVersion = "0.1.0",
    [string]$ZonesVersion = "0.1.0",
    [string]$RefundVersion = "0.1.0",
    [string]$GunkanVersion = "0.1.0",
    [string]$CallAutoAcceptVersion = "0.1.0",
    [string]$SourceRelease = "0.1.22",
    [string]$Repository = "voffkazxc/RollHelper",
    [string]$OutputDirectory = (Join-Path $env:TEMP "RollHelperRollClubRelease"),
    [switch]$RebuildDuty,
    [switch]$RebuildZones,
    [switch]$RebuildRefund,
    [switch]$RebuildGunkan,
    [switch]$RebuildCallAutoAccept,
    [switch]$Publish
)

$ErrorActionPreference = "Stop"

foreach ($entry in @(
    @{ Name = "CatalogVersion"; Value = $CatalogVersion },
    @{ Name = "RollClubVersion"; Value = $RollClubVersion },
    @{ Name = "DutyVersion"; Value = $DutyVersion },
    @{ Name = "ZonesVersion"; Value = $ZonesVersion },
    @{ Name = "RefundVersion"; Value = $RefundVersion },
    @{ Name = "GunkanVersion"; Value = $GunkanVersion },
    @{ Name = "CallAutoAcceptVersion"; Value = $CallAutoAcceptVersion },
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
$sourceRefund = @($sourceManifest.packages) | Where-Object { $_.id -eq "rollclub-refund" } | Select-Object -First 1
$sourceGunkan = @($sourceManifest.packages) | Where-Object { $_.id -eq "rollclub-first-order-gunkan" } | Select-Object -First 1
$sourceCallAutoAccept = @($sourceManifest.packages) | Where-Object { $_.id -eq "rollclub-call-auto-accept" } | Select-Object -First 1
if ($RebuildDuty) {
    $dutyBuild = & (Join-Path $PSScriptRoot "build-rollclub-duty-module.ps1") `
        -Version $DutyVersion `
        -OutputDirectory $OutputDirectory
    $dutyAsset = Split-Path -Leaf $dutyBuild.AssetPath
    $dutyPackage = [ordered]@{
        id = "rollclub-duty"
        type = "module"
        displayName = "Дежурство заказов (Ctrl+F4)"
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
$dutyPackage.displayName = "Дежурство заказов (Ctrl+F4)"

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
$zonesPackage.displayName = "Зони доставки RollClub"

if ($RebuildRefund) {
    $refundBuild = & (Join-Path $PSScriptRoot "build-rollclub-refund-module.ps1") `
        -Version $RefundVersion `
        -OutputDirectory $OutputDirectory
    $refundAsset = Split-Path -Leaf $refundBuild.AssetPath
    $refundPackage = [ordered]@{
        id = "rollclub-refund"
        type = "module"
        displayName = "Повернення коштів"
        version = $RefundVersion
        extends = "rollclub"
        requires = @(
            [ordered]@{ id = "rollclub"; minVersion = $RollClubVersion }
        )
        url = "$assetBaseUrl/$refundAsset"
        sha256 = [string]$refundBuild.Sha256
    }
} elseif ($null -ne $sourceRefund) {
    $refundPackage = $sourceRefund
} else {
    throw "Source manifest has no rollclub-refund package. Use -RebuildRefund for the first release."
}
$refundPackage.displayName = "Повернення коштів"

if ($RebuildGunkan) {
    $gunkanBuild = & (Join-Path $PSScriptRoot "build-rollclub-first-order-gunkan-module.ps1") `
        -Version $GunkanVersion `
        -OutputDirectory $OutputDirectory
    $gunkanAsset = Split-Path -Leaf $gunkanBuild.AssetPath
    $gunkanPackage = [ordered]@{
        id = "rollclub-first-order-gunkan"
        type = "module"
        displayName = "Гункан за перше замовлення"
        version = $GunkanVersion
        extends = "rollclub"
        requires = @(
            [ordered]@{ id = "rollclub"; minVersion = $RollClubVersion }
        )
        url = "$assetBaseUrl/$gunkanAsset"
        sha256 = [string]$gunkanBuild.Sha256
    }
} elseif ($null -ne $sourceGunkan) {
    $gunkanPackage = $sourceGunkan
} else {
    throw "Source manifest has no rollclub-first-order-gunkan package. Use -RebuildGunkan for the first release."
}
$gunkanPackage.displayName = "Гункан за перше замовлення"

if ($RebuildCallAutoAccept) {
    $callAutoAcceptBuild = & (Join-Path $PSScriptRoot "build-rollclub-call-auto-accept-module.ps1") `
        -Version $CallAutoAcceptVersion `
        -OutputDirectory $OutputDirectory
    $callAutoAcceptAsset = Split-Path -Leaf $callAutoAcceptBuild.AssetPath
    $callAutoAcceptPackage = [ordered]@{
        id = "rollclub-call-auto-accept"
        type = "module"
        displayName = "Автоприйом дзвінка (Ctrl+F2)"
        version = $CallAutoAcceptVersion
        extends = "rollclub"
        requires = @(
            [ordered]@{ id = "rollclub"; minVersion = $RollClubVersion }
        )
        url = "$assetBaseUrl/$callAutoAcceptAsset"
        sha256 = [string]$callAutoAcceptBuild.Sha256
    }
} elseif ($null -ne $sourceCallAutoAccept) {
    $callAutoAcceptPackage = $sourceCallAutoAccept
} else {
    throw "Source manifest has no rollclub-call-auto-accept package. Use -RebuildCallAutoAccept for the first release."
}
$callAutoAcceptPackage.displayName = "Автоприйом дзвінка (Ctrl+F2)"

$packages = @()
foreach ($package in @($sourceManifest.packages)) {
    if ($package.id -notin @("rollclub", "rollclub-duty", "rollclub-zones", "rollclub-refund", "rollclub-first-order-gunkan", "rollclub-call-auto-accept")) {
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
$packages += $refundPackage
$packages += $gunkanPackage
$packages += $callAutoAcceptPackage

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
- додано підтримку україномовної локалізації Syrve (Панель даних, Рядок, Коментар): дежурство (Ctrl+F4) працює швидко без 10-секундного підвисання і коректно розпізнає замовлення з коментарем «Пост»
- налаштування, координати та WinAPI-прив'язки тепер зберігаються в UserData і не губляться після оновлення
- при першому запуску нової версії RollClub автоматично підхоплює найповніші налаштування з попередньої встановленої версії
- виправлено пакування UTF-16 конфігурації, через яке лаунчер міг встановити пошкоджений RkConfig.ini
- режим чергування перенесено з F4 на Ctrl+F4
- повернуто окрему перевірку адреси та точки доставки після визначення KML-зони
- при внесенні замовлення RollClub натискає «Найти точку» і читає фактичну точку Syrve
- очікувана кухня з KML знову порівнюється з фактичною точкою; збіг і помилка мають різні сигнали
- біля межі або перетину KML-зон пульт показує попередження і не змінює час автоматично
- додано регресійний тест повного ланцюжка: адреса → зона в пульті → звірка точки
- визначення зони більше не зависає на мережевому пошуку адреси
- мережевий запит має короткий ліміт часу, а повторна перевірка тієї самої адреси використовує кеш
- RollHouse, його доповнення та лаунчер без змін
- додано окреме доповнення «Повернення коштів» з запуском через Ctrl+F5
- «Повернення коштів» автоматично повторює читання при тимчасовому збої, без ручного натискання «Оновити дані»
- виправлено ФОП без останньої крапки в ініціалах: адреса більше не потрапляє у поле ФОП
- вікно повернення спрощено до одного сценарію: причина → «Сформувати та скопіювати»
- сума та історія замовлення читаються одним серверним проходом без повторного повного сканування Syrve
- виправлено запуск нового вікна повернення та додано окремий GUI smoke-тест перед публікацією
- місто повернення береться з верхньої мітки замовлення `(Site/App ...)` і нормалізується українською
- назва вулиці більше не може потрапити у поле «Місто»
- самовивіз більше не зависає на «Визначення зони»: KML-пошук для нього не запускається
- кухня самовивозу читається прямо з поля «Точка» Syrve і одразу показується у пульті
- повернуто окреме доповнення «Гункан за перше замовлення»
- маркер `!!!ПЕРШЕМОБ` знову вмикає картку Гункана та автоматичне пробиття його PLU
- PLU Гункана можна змінити в налаштуваннях RollClub; після вимкнення доповнення акція повністю неактивна
- додано окреме доповнення «Автоприйом дзвінка (Ctrl+F2)»
- Ctrl+F2 очікує один вхідний дзвінок і натискає штатну кнопку Syrve «Принять» через UIA
- координати, калібрування та пошук картинки дзвінка більше не використовуються
- прибрано частий обхід UIA-дерева під час очікування дзвінка, який гальмував ручне редагування замовлення в Syrve
- після одноразового пошуку кнопки автоприйом перевіряє її стан легким WinAPI-викликом, а повторний UIA-пошук робить не частіше одного разу на 2 секунди
"@ | Set-Content -LiteralPath $notesPath -Encoding UTF8

    $assetsToPublish = @($rollClubBuild.AssetPath, $manifestPath)
    if ($RebuildDuty) {
        $assetsToPublish += $dutyBuild.AssetPath
    }
    if ($RebuildZones) {
        $assetsToPublish += $zonesBuild.AssetPath
    }
    if ($RebuildRefund) {
        $assetsToPublish += $refundBuild.AssetPath
    }
    if ($RebuildGunkan) {
        $assetsToPublish += $gunkanBuild.AssetPath
    }
    if ($RebuildCallAutoAccept) {
        $assetsToPublish += $callAutoAcceptBuild.AssetPath
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
    RefundAsset = if ($RebuildRefund) { $refundBuild.AssetPath } else { [string]$refundPackage.url }
    GunkanAsset = if ($RebuildGunkan) { $gunkanBuild.AssetPath } else { [string]$gunkanPackage.url }
    CallAutoAcceptAsset = if ($RebuildCallAutoAccept) { $callAutoAcceptBuild.AssetPath } else { [string]$callAutoAcceptPackage.url }
    Manifest = $manifestPath
    Published = [bool]$Publish
}
