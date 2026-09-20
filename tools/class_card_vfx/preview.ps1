param([switch]$Capture, [string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (-not $GodotPath) {
    $GodotPath = (Get-Content (Join-Path $projectRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
}
$outputPath = Join-Path $projectRoot 'artifacts/dev/class_card_vfx/ethereal/gallery'
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$arguments = @('--path', $projectRoot, '--resolution', '1440x950', '--log-file', (Join-Path $outputPath 'godot.log'), 'res://tools/class_card_vfx/gallery.tscn')
if ($Capture) {
    $engineLock = $null
    try {
        try { $engineLock = [IO.File]::Open((Join-Path $projectRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
        catch { throw 'Another dev command is using Godot. Retry after it finishes.' }
        $captureStarted = [DateTime]::UtcNow
        $arguments += @('--', '--capture')
        & $GodotPath @arguments
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path (Join-Path $outputPath 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'Godot VFX capture failed; inspect godot.log.' }
        $reportPath = Join-Path $outputPath 'report.json'
        if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -lt $captureStarted) { throw 'Missing or stale capture report.' }
        $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        if ($report.count -ne $report.coverage.cards -or $report.coverage.missing.Count -ne 0 -or $report.enemies_captured.Count -ne $report.enemy_count -or $report.frames -ne 66) { throw 'Incomplete VFX capture.' }
    } finally { if ($null -ne $engineLock) { $engineLock.Dispose() } }
} else {
    # A visible window is the requested interactive preview.
    $launch = [Diagnostics.ProcessStartInfo]::new($GodotPath)
    foreach ($argument in $arguments) { $launch.ArgumentList.Add($argument) }
    $launch.UseShellExecute = $false
    $launch.CreateNoWindow = $true
    [Diagnostics.Process]::Start($launch) | Out-Null
}
