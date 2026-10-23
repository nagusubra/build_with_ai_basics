param(
  [ValidateSet('DuoWelcome', 'DuoMatch', 'DuoCooking', 'BoyHello', 'GirlHello', 'BoyCheer', 'GirlCheer')]
  [string]$Artboard = 'DuoWelcome'
)

$ErrorActionPreference = 'Stop'

$rive = Join-Path $env:USERPROFILE '.rive\bin\rive.exe'
if (-not (Test-Path -LiteralPath $rive)) {
  $rive = 'rive'
}

$project = Join-Path $PSScriptRoot 'mascot_rive'
& $rive $project "--artboard=$Artboard"
