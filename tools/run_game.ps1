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

function Invoke-Godot {
    param(
        [string[]]$Arguments
    )

    $HasNativeErrorPreference = $null -ne (Get-Variable PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue)
    if ($HasNativeErrorPreference) {
        $PreviousNativeErrorPreference = $global:PSNativeCommandUseErrorActionPreference
        $global:PSNativeCommandUseErrorActionPreference = $false
    }

    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & $Godot @Arguments
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference

        if ($HasNativeErrorPreference) {
            $global:PSNativeCommandUseErrorActionPreference = $PreviousNativeErrorPreference
        }
    }

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Push-Location $ProjectRoot
try {
    # Keep imported resources current so freshly synced archives can launch and test immediately.
    Invoke-Godot @("--headless", "--path", ".", "--import")

    if ($Test) {
        Invoke-Godot @("--headless", "--path", ".", "--quit")
        Invoke-Godot @("--headless", "--path", ".", "--script", "res://tests/smoke_accessory_flow.gd")
        Invoke-Godot @("--headless", "--path", ".", "--script", "res://tests/smoke_accessory_catalog.gd")
        Invoke-Godot @("--headless", "--path", ".", "--script", "res://tests/smoke_run_effects.gd")
        Invoke-Godot @("--headless", "--path", ".", "--script", "res://tests/smoke_player_control.gd")
        Invoke-Godot @("--headless", "--path", ".", "--script", "res://tests/smoke_run_flow.gd")
        Invoke-Godot @("--headless", "--path", ".", "--script", "res://tests/smoke_locale_zh_hans.gd")
        Invoke-Godot @("--headless", "--path", ".", "--script", "res://tests/smoke_ui_screens.gd")
        exit 0
    }

    if ($Editor) {
        Invoke-Godot @("--editor", "--path", ".")
        exit 0
    }

    Invoke-Godot @("--path", ".")
    exit 0
}
finally {
    Pop-Location
}
