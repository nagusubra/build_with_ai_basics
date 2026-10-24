# Preview the Jack wingman Rive rig.
#
#   .\tool\preview_mascot_jack.ps1                       live preview in the browser (all artboards, full + 120 px)
#   .\tool\preview_mascot_jack.ps1 -Artboard JackWrite   start on one segment
#   .\tool\preview_mascot_jack.ps1 -Native               Rive CLI window that hot-reloads scene.rml
#   .\tool\preview_mascot_jack.ps1 -Verify               validate only
#   .\tool\preview_mascot_jack.ps1 -Build                write build/jack_wingman.riv
#
# The browser preview plays build/jack_wingman.riv, so rebuild (python build_jack.py, then -Build or
# verify_jack.py) before refreshing the page. Ctrl+C stops the local server.
param(
    [string]$Artboard = "JackWingman",
    [int]$Port = 8765,
    [switch]$Native,
    [switch]$Verify,
    [switch]$Build
)

$ErrorActionPreference = "Stop"
$project = Join-Path $PSScriptRoot "mascot_rive_jack"
$rive = Join-Path $env:USERPROFILE ".rive\bin\rive.exe"
$needsRive = $Native -or $Verify -or $Build
if ($needsRive -and -not (Test-Path -LiteralPath $rive)) {
    throw "Rive CLI not found at $rive"
}

if ($Verify) { & $rive $project --verify; exit $LASTEXITCODE }
if ($Build) { & $rive $project --once; exit $LASTEXITCODE }
if ($Native) { & $rive $project --artboard=$Artboard; exit $LASTEXITCODE }

if (-not (Test-Path -LiteralPath (Join-Path $project "build\jack_wingman.riv"))) {
    throw "build\jack_wingman.riv is missing; run python tool\mascot_rive_jack\verify_jack.py --quick first"
}
$url = "http://127.0.0.1:$Port/preview.html?artboard=$Artboard"
Write-Host "Serving $project at $url (Ctrl+C to stop)"
Start-Process $url
python -m http.server $Port --bind 127.0.0.1 --directory $project
