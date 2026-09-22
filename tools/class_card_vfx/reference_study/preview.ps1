param([switch]$Capture, [string]$GodotPath)
$ErrorActionPreference = 'Stop'
$studyRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
if (-not $GodotPath) {
    $GodotPath = (Get-Content -LiteralPath (Join-Path $studyRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
}
$studyOutput = Join-Path $studyRoot 'artifacts/dev/class_card_vfx/reference_study'
[IO.Directory]::CreateDirectory($studyOutput) | Out-Null
$studyArgs = @('--path', $studyRoot, '--resolution', '1440x1040', '--log-file', (Join-Path $studyOutput 'godot.log'), 'res://tools/class_card_vfx/reference_study/study.tscn')
if (-not $Capture) {
    # This launcher is the explicitly requested interactive review window.
    $launch = [Diagnostics.ProcessStartInfo]::new($GodotPath)
    foreach ($argument in $studyArgs) { $launch.ArgumentList.Add($argument) }
    $launch.UseShellExecute = $false
    $launch.CreateNoWindow = $true
    [Diagnostics.Process]::Start($launch) | Out-Null
    return
}
$studyLock = $null
try {
    $studyLock = [IO.File]::Open((Join-Path $studyRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $inputs = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Recurse | Where-Object { $_.Extension -in '.gd','.tscn','.png','.json' } | ForEach-Object {
        @{ path = [IO.Path]::GetRelativePath($studyRoot, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    $inputs += @(Get-ChildItem -LiteralPath (Join-Path $studyRoot 'vfx/class_cards') -Recurse -File | Where-Object { $_.Extension -in '.gd','.gdshader','.tres' } | ForEach-Object {
        @{ path = [IO.Path]::GetRelativePath($studyRoot, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    $started = [DateTime]::UtcNow
    $studyArgs += @('--fixed-fps', '30', '--quit-after', '1800', '--', '--capture')
    & $GodotPath @studyArgs
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $studyOutput 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'La capture Godot a échoué ; lire godot.log.' }
    $reportPath = Join-Path $studyOutput 'report.json'
    if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -lt $started) { throw 'Rapport absent ou périmé.' }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if (-not $report.passed -or $report.frames -ne 216 -or $report.checks.Count -lt 23) { throw 'Étude incomplète ou contrôle en échec.' }
    foreach ($inputFile in $inputs) {
        if ((Get-FileHash -LiteralPath (Join-Path $studyRoot $inputFile.path) -Algorithm SHA256).Hash -ne $inputFile.sha256) { throw "Source modifiée pendant la capture : $($inputFile.path)" }
    }
    @{ stable_sources = $true; captured_utc = $started; inputs = $inputs } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $studyOutput 'capture_manifest.json') -Encoding utf8
} finally {
    if ($null -ne $studyLock) { $studyLock.Dispose() }
}
