$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "PackageRepairProbe\PackageRepairProbe.csproj"
dotnet run --project $project -c Release
if ($LASTEXITCODE -ne 0) {
    throw "Package repair probe failed with exit code $LASTEXITCODE"
}
