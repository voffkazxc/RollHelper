$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$mainPath = Join-Path $repoRoot "main.ahk"
$source = Get-Content -LiteralPath $mainPath -Raw

if ($source -notmatch 'RhUiaFindVisible\(win, "AutomationId=DeliveryOrderEditControl"\)') {
    throw "RollHouse does not select the visible order editor"
}

if ($source -notmatch 'RhUiaFindVisible\(root, "AutomationId=" \. aid\)') {
    throw "RollHouse does not select visible UIA controls"
}

$focusMatch = [regex]::Match(
    $source,
    'RhFocusOrderItems\(itX:="", itY:=""\)\s*\{(?<body>.*?)\r?\n\}',
    [Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $focusMatch.Success) {
    throw "RhFocusOrderItems was not found"
}

$focusBody = $focusMatch.Groups['body'].Value
if ($focusBody -match 'Click,\s*%itX%,\s*%itY%') {
    throw "Unsafe fixed-coordinate PLU fallback is enabled"
}
if ($focusBody -notmatch 'RhUiaFocusOrderTableRoot\(\)') {
    throw "Live UIA table fallback is missing"
}

$ahk = "C:\Program Files\AutoHotkey\v1.1.37.02\AutoHotkeyU64.exe"
if (Test-Path -LiteralPath $ahk) {
    & $ahk /ErrorStdOut /iLib NUL $mainPath
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "AutoHotkey v1 syntax check failed with exit code $LASTEXITCODE"
    }
}

Write-Host "RollHouse PLU focus regression test passed."
