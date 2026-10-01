#requires -Version 7.2
$ErrorActionPreference = 'Stop'
$gameRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$out = Join-Path $gameRoot ('artifacts/dev/passe-rive-recenter-directions-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[IO.Directory]::CreateDirectory($out) | Out-Null
$shortData = Join-Path $env:TEMP ('pr-recenter-' + [guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($shortData) | Out-Null
$oldAppData = $env:APPDATA
$oldLocalData = $env:LOCALAPPDATA
$engineLock = $null
$clock = [Diagnostics.Stopwatch]::StartNew()
while ($null -eq $engineLock) {
    try { $engineLock = [IO.File]::Open((Join-Path $gameRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch [IO.IOException] { if ($clock.Elapsed.TotalSeconds -gt 600) { throw 'Godot engine lock busy.' }; Start-Sleep -Seconds 2 }
}
try {
    $env:APPDATA = $shortData
    $env:LOCALAPPDATA = $shortData
    $godot = (Get-Content (Join-Path $gameRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
    & $godot --headless --path $gameRoot --editor --import --recovery-mode --quit --log-file (Join-Path $out 'import.log') *> (Join-Path $out 'import_console.log')
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $out 'import_console.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "Import failed: $out" }
    & $godot --path $gameRoot --resolution 1440x820 --max-fps 60 --log-file (Join-Path $out 'godot.log') res://tools/class_card_vfx/passe_rive_s32/poses.tscn -- --recenter-capture ('--recenter-output='+$out) *> (Join-Path $out 'console.log')
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $out 'console.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw "Capture failed: $out" }
    @{output=$out;frames=(Get-ChildItem (Join-Path $out 'frames') -Filter '*.png').Count} | ConvertTo-Json
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalData
    $engineLock.Dispose()
}
