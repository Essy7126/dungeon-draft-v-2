#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [string]$Label = 'r6_ui',
    [int]$TimeoutSeconds = 180,
    [switch]$Cards,
    [switch]$StudioAudit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$safeLabel = [IO.Path]::GetFileName($Label)
if ([string]::IsNullOrWhiteSpace($safeLabel) -or $safeLabel -ne $Label) {
    throw 'Label must be one safe directory name.'
}
if ($TimeoutSeconds -lt 30 -or $TimeoutSeconds -gt 600) {
    throw 'TimeoutSeconds must be between 30 and 600.'
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $toolchain = Join-Path $projectRoot 'artifacts/dev-tools/local.json'
    if (-not (Test-Path -LiteralPath $toolchain -PathType Leaf)) {
        throw 'GodotPath is required until ./dev.ps1 doctor has recorded it.'
    }
    $GodotPath = [string](Get-Content -LiteralPath $toolchain -Raw | ConvertFrom-Json).godot_path
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot executable is missing.'
}

$output = Join-Path $projectRoot ('artifacts/catabase_run_balance_validation/' + $safeLabel)
$appData = Join-Path $output 'appdata'
[IO.Directory]::CreateDirectory($output) | Out-Null
[IO.Directory]::CreateDirectory($appData) | Out-Null
[IO.File]::WriteAllText((Join-Path $appData '.gdignore'), '')
$engineLock = $null
$process = $null
try {
    $lockPath = Join-Path $projectRoot 'artifacts/dev/engine.lock'
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($lockPath)) | Out-Null
    try {
        $engineLock = [IO.File]::Open(
            $lockPath,
            [IO.FileMode]::OpenOrCreate,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::None
        )
    } catch {
        throw 'Another dev command is using Godot. Retry after it finishes.'
    }

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.Environment['APPDATA'] = $appData
    $startInfo.Environment['LOCALAPPDATA'] = $appData
    $arguments = @(
        '--path', $projectRoot, '--single-window',
        '--rendering-method', 'gl_compatibility',
        '--audio-driver', 'Dummy', '--position', '-3000,-3000',
        '--resolution', '1280x720',
        '--log-file', (Join-Path $output 'engine.log'),
        $(if ($StudioAudit) { 'res://tools/catabase_run_balance_validation/studio_ui_audit.tscn' } elseif ($Cards) { 'res://tools/catabase_run_balance_validation/cards_ui_probe.tscn' } else { 'res://tools/catabase_run_balance_validation/ui_probe.tscn' }), '--',
        ('output=' + $output.Replace('\', '/'))
    )
    foreach ($argument in $arguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'Godot UI probe did not start.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { $process.Kill($true) }
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $output 'stdout.log'), $stdout)
    [IO.File]::WriteAllText((Join-Path $output 'stderr.log'), $stderr)
    $reportPath = Join-Path $output 'report.json'
    $report = if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
        Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    } else { $null }
    $combined = $stdout + $stderr
    $engineErrors = @($combined -split "`n" | Where-Object {
        $_ -match '^(SCRIPT ERROR:|ERROR:|WARNING: .*ObjectDB instances were leaked)'
    } | Sort-Object -Unique)
    $passed = -not $timedOut -and $exitCode -eq 0 -and $null -ne $report -and
        [bool]$report.passed -and $engineErrors.Count -eq 0
    $summary = [ordered]@{
        passed = $passed
        timed_out = $timedOut
        exit_code = $exitCode
        captures = if ($null -ne $report) { @($report.captures).Count } else { 0 }
        checks = if ($null -ne $report) { @($report.checks).Count } else { 0 }
        engine_errors = $engineErrors
        report = $reportPath
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'summary.json')
    $summary | ConvertTo-Json -Depth 8
    if (-not $passed) { exit 1 }
} finally {
    if ($process -ne $null) { $process.Dispose() }
    if ($engineLock -ne $null) { $engineLock.Dispose() }
}
