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
        $inputs = @(Get-ChildItem (Join-Path $projectRoot 'vfx/class_cards') -Recurse -File | Where-Object { $_.Extension -in '.gd','.gdshader','.tres' } | ForEach-Object {
            @{ path = [IO.Path]::GetRelativePath($projectRoot, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
        })
        foreach ($sourcePath in @('tools/class_card_vfx/gallery.gd','tools/class_card_vfx/enemy_inventory.gd','tools/class_card_vfx/export_contracts.gd')) {
            $inputs += @{ path = $sourcePath; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $sourcePath) -Algorithm SHA256).Hash }
        }
        $captureStarted = [DateTime]::UtcNow
        $arguments += @('--', '--capture')
        & $GodotPath @arguments
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path (Join-Path $outputPath 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'Godot VFX capture failed; inspect godot.log.' }
        $reportPath = Join-Path $outputPath 'report.json'
        if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -lt $captureStarted) { throw 'Missing or stale capture report.' }
        $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        if ($report.count -ne $report.coverage.cards -or $report.coverage.missing.Count -ne 0 -or $report.enemies_captured.Count -ne $report.enemy_count -or $report.frames -ne 66) { throw 'Incomplete VFX capture.' }
        foreach ($inputFile in $inputs) {
            if ((Get-FileHash -LiteralPath (Join-Path $projectRoot $inputFile.path) -Algorithm SHA256).Hash -ne $inputFile.sha256) { throw "VFX sources changed during capture: $($inputFile.path)" }
        }
        @{ stable_sources = $true; captured_utc = $captureStarted; inputs = $inputs } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputPath 'capture_manifest.json') -Encoding utf8
    } finally { if ($null -ne $engineLock) { $engineLock.Dispose() } }
} else {
    # A visible window is the requested interactive preview.
    $launch = [Diagnostics.ProcessStartInfo]::new($GodotPath)
    foreach ($argument in $arguments) { $launch.ArgumentList.Add($argument) }
    $launch.UseShellExecute = $false
    $launch.CreateNoWindow = $true
    [Diagnostics.Process]::Start($launch) | Out-Null
}
