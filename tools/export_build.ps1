param(
    [ValidateSet("Windows Desktop", "Web")]
    [string]$Preset = "Windows Desktop"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$GodotCandidates = @(
    (Join-Path $ProjectRoot "..\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe"),
    (Join-Path $ProjectRoot "..\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64.exe")
)

$Godot = $null
foreach ($Path in $GodotCandidates) {
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
    exit 1
}

$Output = if ($Preset -eq "Web") {
    Join-Path $ProjectRoot "build\web\index.html"
} else {
    Join-Path $ProjectRoot "build\windows\InfinityKingdom.exe"
}

New-Item -ItemType Directory -Force -Path (Split-Path $Output) | Out-Null
Push-Location $ProjectRoot
try {
    & $Godot --headless --path . --export-release $Preset $Output
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
