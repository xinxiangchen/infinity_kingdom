param(
    [switch]$Editor,
    [switch]$Test
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$CandidatePaths = @(
    (Join-Path $ProjectRoot "..\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe"),
    (Join-Path $ProjectRoot "..\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64.exe")
)

$Godot = $null
foreach ($Path in $CandidatePaths) {
    if (Test-Path $Path) {
        $Godot = Resolve-Path $Path
        break
    }
}

if ($null -eq $Godot) {
    $Command = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $Command) {
        $Godot = $Command.Source
    }
}

if ($null -eq $Godot) {
    Write-Host "Godot was not found." -ForegroundColor Red
    Write-Host "Install Godot 4.6 or place it in ..\_tools\godot_4_6_3."
    exit 1
}

Push-Location $ProjectRoot
try {
    if ($Test) {
        & $Godot --headless --path . --quit --verbose
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $Godot --headless --path . --script res://tests/smoke_accessory_flow.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $Godot --headless --path . --script res://tests/smoke_accessory_catalog.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $Godot --headless --path . --script res://tests/smoke_run_effects.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $Godot --headless --path . --script res://tests/smoke_run_flow.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $Godot --headless --path . --script res://tests/smoke_ui_screens.gd
        exit $LASTEXITCODE
    }

    if ($Editor) {
        & $Godot --editor --path .
        exit $LASTEXITCODE
    }

    & $Godot --path .
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
