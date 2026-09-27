#requires -Version 7.2
param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$gameRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotPath) {
    $GodotPath = (Get-Content (Join-Path $gameRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
}
$out = Join-Path $gameRoot ('artifacts/dev/passe-rive-flow-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[IO.Directory]::CreateDirectory((Join-Path $out 'appdata')) | Out-Null
$engineLock = $null
$previousAppData = $env:APPDATA
$previousLocal = $env:LOCALAPPDATA
try {
    $engineLock = [IO.File]::Open((Join-Path $gameRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $env:APPDATA = Join-Path $out 'appdata'
    $env:LOCALAPPDATA = $env:APPDATA
    & $GodotPath --headless --path $gameRoot --log-file (Join-Path $out 'godot.log') res://tools/class_card_vfx/passe_rive_s19_flow.tscn
    if ($LASTEXITCODE -ne 0) { throw "Flow process failed: $out" }
    $report = Get-Content (Join-Path $env:APPDATA 's19_flow_report.json') -Raw | ConvertFrom-Json
    if (-not $report.passed -or (Select-String -LiteralPath (Join-Path $out 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "Flow validation failed: $out" }
    @{output=$out; report=$report} | ConvertTo-Json -Depth 6
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocal
    if ($null -ne $engineLock) { $engineLock.Dispose() }
}
