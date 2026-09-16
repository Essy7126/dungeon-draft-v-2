#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [string]$Label = 'stage1_seed2401',
    [object[]]$Seeds = @(2401),
    [object[]]$Difficulties = @('normal', 'easy'),
    [object[]]$Weapons = @('arc', 'disque', 'hampe', 'lame', 'marteau', 'xiphos'),
    [object[]]$Policies = @('balanced'),
    [int]$TimeoutSeconds = 1200,
    [switch]$Cards,
    [ValidateSet('', 'starter', 'pilot', 'adaptive', 'liquidate', 'swarm', 'speed', 'mobility', 'curated', 'informed', 'armor_control', 'armor_mixte')]
    [string]$AuditMode = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Seeds = @($Seeds | ForEach-Object {
    ([string]$_).Split(',', [StringSplitOptions]::RemoveEmptyEntries)
} | ForEach-Object { [int]$_.Trim() })
$Difficulties = @($Difficulties | ForEach-Object {
    ([string]$_).Split(',', [StringSplitOptions]::RemoveEmptyEntries)
} | ForEach-Object { $_.Trim() })
$Weapons = @($Weapons | ForEach-Object {
    ([string]$_).Split(',', [StringSplitOptions]::RemoveEmptyEntries)
} | ForEach-Object { $_.Trim() })
$Policies = @($Policies | ForEach-Object {
    ([string]$_).Split(',', [StringSplitOptions]::RemoveEmptyEntries)
} | ForEach-Object { $_.Trim() })
$validationRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$safeLabel = [IO.Path]::GetFileName($Label)
if ([string]::IsNullOrWhiteSpace($safeLabel) -or $safeLabel -ne $Label) {
    throw 'Label must be one safe directory name.'
}
if ($Seeds.Count -eq 0 -or @($Seeds | Where-Object { $_ -lt 0 }).Count -gt 0) {
    throw 'At least one non-negative seed is required.'
}
$allowedDifficulties = @('normal', 'easy')
$allowedWeapons = @('arc', 'disque', 'hampe', 'lame', 'marteau', 'xiphos')
$allowedPolicies = @('balanced', 'survival', 'pressure')
if (@($Difficulties | Where-Object { $_ -notin $allowedDifficulties }).Count -gt 0) {
    throw 'Difficulty must be normal or easy.'
}
if (@($Weapons | Where-Object { $_ -notin $allowedWeapons }).Count -gt 0) {
    throw 'Unknown weapon preset.'
}
if (@($Policies | Where-Object { $_ -notin $allowedPolicies }).Count -gt 0) {
    throw 'Unknown analysis policy.'
}
if ($TimeoutSeconds -lt 30 -or $TimeoutSeconds -gt 7200) {
    throw 'TimeoutSeconds must be between 30 and 7200.'
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $localToolchain = Join-Path $validationRoot 'artifacts/dev-tools/local.json'
    if (-not (Test-Path -LiteralPath $localToolchain)) {
        throw 'GodotPath is required until ./dev.ps1 doctor has recorded it.'
    }
    $GodotPath = [string](Get-Content -LiteralPath $localToolchain -Raw | ConvertFrom-Json).godot_path
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot executable is missing.'
}

$validationOutput = Join-Path $validationRoot ('artifacts/catabase_run_balance_validation/' + $safeLabel)
[IO.Directory]::CreateDirectory($validationOutput) | Out-Null
$validationAppData = Join-Path $validationOutput 'appdata'
[IO.Directory]::CreateDirectory($validationAppData) | Out-Null
$engineLock = $null
$process = $null
try {
    $lockPath = Join-Path $validationRoot 'artifacts/dev/engine.lock'
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
    $versionInfo = [Diagnostics.ProcessStartInfo]::new()
    $versionInfo.FileName = $GodotPath
    $versionInfo.WorkingDirectory = $validationRoot
    $versionInfo.UseShellExecute = $false
    $versionInfo.CreateNoWindow = $true
    $versionInfo.RedirectStandardOutput = $true
    $versionInfo.ArgumentList.Add('--version')
    $versionProcess = [Diagnostics.Process]::new()
    $versionProcess.StartInfo = $versionInfo
    if (-not $versionProcess.Start()) { throw 'Godot version process did not start.' }
    $versionText = $versionProcess.StandardOutput.ReadToEnd().Trim()
    $versionProcess.WaitForExit()
    $versionExit = $versionProcess.ExitCode
    $versionProcess.Dispose()
    if ($versionExit -ne 0 -or $versionText -ne '4.7.1.stable.official.a13da4feb') {
        throw "Godot 4.7.1 is required; found '$versionText'."
    }

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.WorkingDirectory = $validationRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.Environment['APPDATA'] = $validationAppData
    $startInfo.Environment['LOCALAPPDATA'] = $validationAppData
    $probeScene = if ($AuditMode) { 'res://tools/catabase_run_balance_validation/studio_audit_probe.tscn' } else { 'res://tools/catabase_run_balance_validation/full_run_probe.tscn' }
    $arguments = @(
        '--headless', '--path', $validationRoot, '--audio-driver', 'Dummy',
        '--log-file', (Join-Path $validationOutput 'engine.log'),
        $probeScene, '--',
        ('label=' + $safeLabel),
        ('seeds=' + ($Seeds -join ',')),
        ('difficulties=' + ($Difficulties -join ',')),
        ('weapons=' + ($Weapons -join ',')),
        ('policies=' + ($Policies -join ','))
    )
    if ($Cards) { $arguments += 'cards=true' }
    if ($AuditMode) { $arguments += ('audit=' + $AuditMode) }
    foreach ($argument in $arguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'Godot validation process did not start.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { $process.Kill($true) }
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $validationOutput 'stdout.log'), $stdout)
    [IO.File]::WriteAllText((Join-Path $validationOutput 'stderr.log'), $stderr)
    $processEvidence = [ordered]@{
        started = $true
        timed_out = $timedOut
        exit_code = $exitCode
        godot = $versionText
        seeds = $Seeds
        difficulties = $Difficulties
        weapons = $Weapons
        policies = $Policies
    }
    $processEvidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $validationOutput 'process.json')
    $reportPath = Join-Path $validationOutput 'report.json'
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        throw 'Validation report is missing.'
    }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $combined = $stdout + $stderr + [IO.File]::ReadAllText((Join-Path $validationOutput 'engine.log'))
    $engineErrors = @($combined -split "`n" | Where-Object {
        $_ -match '^(SCRIPT ERROR:|ERROR:|WARNING: .*ObjectDB instances were leaked)'
    } | Sort-Object -Unique)
    $expected = $Seeds.Count * $Difficulties.Count * $Weapons.Count * $Policies.Count
    $passed = -not $timedOut -and $exitCode -eq 0 -and $report.passed -and
        @($report.runs).Count -eq $expected -and $engineErrors.Count -eq 0
    $summary = [ordered]@{
        passed = $passed
        runs = @($report.runs).Count
        expected_runs = $expected
        outcomes = $report.outcome_counts
        engine_errors = $engineErrors
        report = $reportPath
        process = (Join-Path $validationOutput 'process.json')
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $validationOutput 'summary.json')
    $summary | ConvertTo-Json -Depth 8
    if (-not $passed) { exit 1 }
} finally {
    if ($process -ne $null) { $process.Dispose() }
    if ($engineLock -ne $null) { $engineLock.Dispose() }
}
