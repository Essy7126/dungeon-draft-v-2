#requires -Version 7.2
param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$gameRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$out = Join-Path $gameRoot ('artifacts/dev/passe-rive-drain-cards-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[IO.Directory]::CreateDirectory($out) | Out-Null
$shortData = Join-Path $env:TEMP ('pr-drains-' + [guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($shortData) | Out-Null
$oldAppData = $env:APPDATA
$oldLocalData = $env:LOCALAPPDATA
$engineLock = $null
try {
    if ($Capture) {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while ($null -eq $engineLock) {
            try { $engineLock = [IO.File]::Open((Join-Path $gameRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
            catch [IO.IOException] { if ($clock.Elapsed.TotalSeconds -gt 300) { throw 'Godot engine lock busy.' }; Start-Sleep -Seconds 2 }
        }
    }
    $env:APPDATA = $shortData
    $env:LOCALAPPDATA = $shortData
    $godot = (Get-Content (Join-Path $gameRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
    if ($Capture) {
        & $godot --headless --path $gameRoot --editor --import --recovery-mode --quit --log-file (Join-Path $out 'import.log') *> (Join-Path $out 'import_console.log')
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $out 'import_console.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "Import failed: $out" }
    }
    $runtime = @('--path',$gameRoot,'--resolution','1440x950','--max-fps','60','--log-file',(Join-Path $out 'godot.log'),'res://tools/class_card_vfx/passe_rive_drain_directions/arena.tscn','--',('--s24-output='+$out))
    if ($Capture) { $runtime += '--s24-capture' }

    & $godot @runtime *> (Join-Path $out 'console.log')
    if ($LASTEXITCODE -ne 0) { throw "Runtime failed: $out" }
    if ($Capture) {
        $report = Get-Content (Join-Path $out 'report.json') -Raw | ConvertFrom-Json
        if (-not $report.passed -or (Select-String -LiteralPath (Join-Path $out 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "Verification failed: $out" }
        @{output=$out;passed=$report.passed;casts=$report.casts.Count;checks=$report.checks.Count;frames=$report.frames} | ConvertTo-Json
    }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalData
    if ($null -ne $engineLock) { $engineLock.Dispose() }
}



