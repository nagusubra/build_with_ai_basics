# Standalone Jill preview; does not deploy to Flutter.
param(
    [string]$Artboard = "JillWingwoman",
    [int]$Port = 8766,
    [switch]$Native,
    [switch]$Verify,
    [switch]$Build
)
$ErrorActionPreference = "Stop"
$project = Join-Path $PSScriptRoot "mascot_rive_jill"
$rive = Join-Path $env:USERPROFILE ".rive\bin\rive.exe"
if ($Verify) { & $rive $project --verify; exit $LASTEXITCODE }
if ($Build) { & $rive $project --once; exit $LASTEXITCODE }
if ($Native) { & $rive $project --artboard=$Artboard; exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath (Join-Path $project "build\jill_wingwoman.riv"))) {
    throw "Build Jill first: python app\tool\mascot_rive_jill\build_jill.py, then verify_jill.py"
}
$url = "http://127.0.0.1:$Port/preview.html?artboard=$Artboard"
Write-Host "Serving $project at $url (Ctrl+C to stop)"
Start-Process $url
python -m http.server $Port --bind 127.0.0.1 --directory $project
