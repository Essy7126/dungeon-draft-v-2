$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$outputRoot = Join-Path $projectRoot 'artifacts/dev/class_card_vfx/persistence'
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$godotPath = (Get-Content (Join-Path $projectRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
$engineLock = $null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $engineLock = [IO.File]::Open((Join-Path $projectRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $env:APPDATA = Join-Path $outputRoot 'appdata'
    $env:LOCALAPPDATA = $env:APPDATA
    [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
    $captureStarted = [DateTime]::UtcNow
    & $godotPath --path $projectRoot --resolution 1440x950 --quit-after 1800 --log-file (Join-Path $outputRoot 'godot.log') res://tools/class_card_vfx/combat_probe.tscn
    if ($LASTEXITCODE -ne 0) { throw 'Combat VFX capture failed.' }
    $reportPath = Join-Path $outputRoot 'report.json'
    if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -lt $captureStarted) { throw 'Missing or stale combat capture report.' }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if (-not $report.passed -or (Select-String -LiteralPath (Join-Path $outputRoot 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'Combat capture has failed checks or engine errors; inspect godot.log.' }
    $report | ConvertTo-Json -Depth 6
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -ne $engineLock) { $engineLock.Dispose() }
}
