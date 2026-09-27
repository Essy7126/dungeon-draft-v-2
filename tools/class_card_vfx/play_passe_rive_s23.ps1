#requires -Version 7.2
$ErrorActionPreference = 'Stop'
$gameRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out = Join-Path $gameRoot ('artifacts/dev/passe-rive-s23-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[IO.Directory]::CreateDirectory((Join-Path $out 'appdata')) | Out-Null
$engineLock = $null
$previousAppData = $env:APPDATA
$previousLocal = $env:LOCALAPPDATA
try {
    $engineLock = [IO.File]::Open((Join-Path $gameRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $env:APPDATA = Join-Path $out 'appdata'
    $env:LOCALAPPDATA = $env:APPDATA
    $godot = (Get-Content (Join-Path $gameRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
    & $godot --path $gameRoot --resolution 1440x950 --max-fps 60 --quit-after 18000 --log-file (Join-Path $out 'godot.log') res://tools/class_card_vfx/passe_rive_s23_review.tscn -- ('--s19-output=' + $out)
    if ($LASTEXITCODE -ne 0) { throw "S23 process failed: $out" }
    $report = Get-Content (Join-Path $out 'report.json') -Raw | ConvertFrom-Json
    if (-not $report.passed -or (Select-String -LiteralPath (Join-Path $out 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "S23 validation failed: $out" }
    @{output=$out; passed=$report.passed; checks=$report.checks.Count} | ConvertTo-Json
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocal
    if ($null -ne $engineLock) { $engineLock.Dispose() }
}
