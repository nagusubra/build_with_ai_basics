# Preview the isolated DuoWelcome layered Rive proof.
#
#   .\tool\preview_mascot_duo.ps1            open the live preview
#   .\tool\preview_mascot_duo.ps1 -Verify    validate only
#   .\tool\preview_mascot_duo.ps1 -Build     write build/duo_welcome_layered.riv
#
# This never touches the shipped seven-pose asset or the Flutter app.
param(
    [switch]$Verify,
    [switch]$Build
)

$ErrorActionPreference = "Stop"

$rive = Join-Path $env:USERPROFILE ".rive\bin\rive.exe"
if (-not (Test-Path -LiteralPath $rive)) {
    throw "Rive CLI not found at $rive"
}

$project = Join-Path $PSScriptRoot "mascot_rive_duo"

if ($Verify) {
    & $rive $project --verify
    exit $LASTEXITCODE
}

if ($Build) {
    & $rive $project --once
    exit $LASTEXITCODE
}

& $rive $project --artboard=DuoWelcome
exit $LASTEXITCODE
