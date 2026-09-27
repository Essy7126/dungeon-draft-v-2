#requires -Version 7.2
param([switch]$Capture, [switch]$Directions, [switch]$Locomotion, [string]$Card = '', [string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
if ($Card -and (-not $Capture -or -not $Directions)) { throw '-Card requires -Capture -Directions.' }
if ($Card -and $Card -notin @('a_sweep','a_ambush','a_dagger','r_shot','r_fan','t_fire','t_mark')) { throw "Unknown card: $Card" }
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotPath) {
    $GodotPath = (Get-Content (Join-Path $projectRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Provide -GodotPath pointing to Godot 4.7.1.' }
$outputRoot = Join-Path $projectRoot ('artifacts/dev/passe-rive-' + $(if ($Locomotion) { 's22-' } else { 's19-' }) + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[IO.Directory]::CreateDirectory((Join-Path $outputRoot 'appdata')) | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$engineLock = $null
try {
    $engineLock = [IO.File]::Open((Join-Path $projectRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $env:APPDATA = Join-Path $outputRoot 'appdata'
    $env:LOCALAPPDATA = $env:APPDATA
    $arguments = @('--path', $projectRoot, '--resolution', '1440x950', '--max-fps', '60', '--log-file', (Join-Path $outputRoot 'godot.log'))
    if ($Capture) { $arguments += @('--quit-after', $(if ($Directions -or $Locomotion) { '18000' } else { '6000' })) }
    $scene = if ($Locomotion) { 'res://tools/class_card_vfx/passe_rive_s22_locomotion.tscn' } else { 'res://tools/class_card_vfx/passe_rive_s19_arena.tscn' }
    $arguments += @($scene, '--', ('--s19-output=' + $outputRoot))
    if ($Capture) { $arguments += $(if ($Locomotion) { '--s22-capture' } else { '--s19-capture' }) }
    if ($Directions) { $arguments += '--s19-directions' }
    if ($Card) { $arguments += '--s19-card=' + $Card }
    & $GodotPath @arguments
    if ($LASTEXITCODE -ne 0) { throw "Godot failed: $outputRoot" }
    if ($Capture) {
        $report = Get-Content (Join-Path $outputRoot 'report.json') -Raw | ConvertFrom-Json
        if (-not $report.passed -or (Select-String -LiteralPath (Join-Path $outputRoot 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) {
            throw "Capture failed: $outputRoot"
        }
        @{passed=$true; checks=$report.checks.Count; casts=$report.casts.Count; output=$outputRoot} | ConvertTo-Json
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -ne $engineLock) { $engineLock.Dispose() }
}
