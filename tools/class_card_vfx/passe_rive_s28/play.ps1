#requires -Version 7.2
param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$gameRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$out = Join-Path $gameRoot ('artifacts/dev/passe-rive-prelevement-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[IO.Directory]::CreateDirectory((Join-Path $out 'appdata')) | Out-Null
$engineLock = $null
$previousAppData = $env:APPDATA
$previousLocal = $env:LOCALAPPDATA
try {
    # Automated captures serialize with imports/tests. The interactive viewer,
    # like an editor play session, must not hold this lock until the user closes it.
    if ($Capture) {
        $lockWait = [Diagnostics.Stopwatch]::StartNew()
        while ($null -eq $engineLock) {
            try {
                $engineLock = [IO.File]::Open((Join-Path $gameRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            } catch [IO.IOException] {
                if ($lockWait.Elapsed.TotalSeconds -ge 600) { throw 'Godot remains busy after ten minutes.' }
                Start-Sleep -Seconds 2
            }
        }
    }
    $env:APPDATA = Join-Path $out 'appdata'
    $env:LOCALAPPDATA = $env:APPDATA
    $godot = (Get-Content (Join-Path $gameRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
    if ($Capture) {
        & $godot --headless --path $gameRoot --editor --import --recovery-mode --quit --log-file (Join-Path $out 'import.log') *> (Join-Path $out 'import_console.log')
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $out 'import_console.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "Drain import failed: $out" }
    }
    $runtimeArgs = @('--path', $gameRoot, '--resolution', '1440x950', '--max-fps', '60', '--log-file', (Join-Path $out 'godot.log'), 'res://tools/class_card_vfx/passe_rive_s28/arena.tscn', '--', ('--s24-output=' + $out))
    if ($Capture) { $runtimeArgs += '--s24-capture' }
    & $godot @runtimeArgs
    if ($LASTEXITCODE -ne 0) { throw "Drain process failed: $out" }
    if ($Capture) {
        $report = Get-Content (Join-Path $out 'report.json') -Raw | ConvertFrom-Json
        if (-not $report.passed -or (Select-String -LiteralPath (Join-Path $out 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "Drain validation failed: $out" }
        @{output=$out; passed=$report.passed; checks=$report.checks.Count; frames=$report.frames} | ConvertTo-Json
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocal
    if ($null -ne $engineLock) { $engineLock.Dispose() }
}



