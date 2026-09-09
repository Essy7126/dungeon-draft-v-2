param(
    [string]$Godot = 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe',
    [string[]]$Directions = @('E', 'N', 'S', 'W'),
    [string[]]$CaseIds = @('base_combo', 'base_shot', 'chiron_shot', 'volley_shot', 'wrath_combo'),
    [string]$Appearance = 'classic',
    [ValidateSet(1, 3)][int]$WalkCells = 3,
    [string]$Batch = 'matrix',
    [switch]$Capture,
    [switch]$IncludeSupplemental
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ($Batch -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Batch must be a simple directory name.' }
if ($Appearance -notin @('classic', 'painted_g')) { throw 'Unknown appearance.' }
$catalog = @{
    exp_braise = @{ kit = 'exp_braise'; scenario = 'shot' }
    exp_givre = @{ kit = 'exp_givre'; scenario = 'shot' }
    exp_foudre = @{ kit = 'exp_foudre'; scenario = 'shot' }
    exp_chiron = @{ kit = 'exp_chiron'; scenario = 'shot' }
    exp_rupture = @{ kit = 'exp_rupture'; scenario = 'shot' }
    exp_traverse = @{ kit = 'exp_traverse'; scenario = 'shot' }
    exp_horizon = @{ kit = 'exp_horizon'; scenario = 'shot' }
    base_combo = @{ kit = 'base'; scenario = 'combo' }
    base_shot = @{ kit = 'base'; scenario = 'shot' }
    stopping_shot = @{ kit = 'stopping'; scenario = 'shot' }
    piercing_shot = @{ kit = 'piercing'; scenario = 'shot' }
    chiron_shot = @{ kit = 'chiron'; scenario = 'shot' }
    volley_shot = @{ kit = 'volley'; scenario = 'shot' }
    wrath_combo = @{ kit = 'wrath'; scenario = 'combo' }
    aeacus_bastion = @{ kit = 'aeacus'; scenario = 'bastion' }
}
$jobs = @()
foreach ($direction in $Directions) {
    if ($direction -notin @('N', 'E', 'S', 'W')) { throw "Unknown direction $direction" }
    foreach ($caseId in $CaseIds) {
        if (-not $catalog.ContainsKey($caseId)) { throw "Unknown case $caseId" }
        $jobs += @{ id = $caseId; direction = $direction; appearance = $Appearance; walk = $WalkCells }
    }
}
if ($IncludeSupplemental) {
    $jobs += @{ id = 'stopping_shot'; direction = 'E'; appearance = 'classic'; walk = 3 }
    $jobs += @{ id = 'piercing_shot'; direction = 'E'; appearance = 'classic'; walk = 3 }
    $jobs += @{ id = 'base_shot'; direction = 'E'; appearance = 'painted_g'; walk = 1 }
}
$results = @()
$rootRelative = "artifacts/achilles_animation_polish_v3_validation/$Batch"
$rootOutput = Join-Path $repo $rootRelative
New-Item -ItemType Directory -Force -Path $rootOutput | Out-Null
foreach ($job in $jobs) {
    $case = $catalog[$job.id]
    $name = "$($job.id)_$($job.direction)_$($job.appearance)_walk$($job.walk)"
    if (@($results | Where-Object { $_.name -eq $name }).Count -gt 0) { continue }
    $relative = "$rootRelative/$name"
    $output = Join-Path $repo $relative
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    $mode = if ($Capture) { '--capture-clip' } else { '--no-screenshots' }
    $arguments = @('--path', $repo, '--resolution', '1200x800',
        'res://tools/achilles_animation_polish_v3_validation/PolishValidation.tscn', '--',
        "--kit=$($case.kit)", "--scenario=$($case.scenario)", "--direction=$($job.direction)",
        "--appearance=$($job.appearance)", "--walk-cells=$($job.walk)",
        $mode, "--artifact-dir=res://$relative")
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = $null
    $finished = $false
    try {
        $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden `
            -WorkingDirectory $repo -RedirectStandardOutput (Join-Path $output 'stdout.log') `
            -RedirectStandardError (Join-Path $output 'stderr.log') -PassThru
        $finished = $process.WaitForExit(120000)
        if (-not $finished) { $process.Kill(); $process.WaitForExit() }
    } finally {
        if ($null -ne $process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $watch.Stop()
    }
    $reportPath = Join-Path $output 'runtime_validation.json'
    $report = if (Test-Path -LiteralPath $reportPath) {
        Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    } else { $null }
    $runtimeErrors = @(Get-Content -LiteralPath (Join-Path $output 'stderr.log'), (Join-Path $output 'stdout.log') |
        Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:)' -and
            $_ -notmatch 'resources still in use at exit|RID allocations .* were leaked at exit' })
    $result = [ordered]@{ name = $name; exit_code = $process.ExitCode; timed_out = -not $finished;
        ok = $finished -and $process.ExitCode -eq 0 -and $null -ne $report -and $report.ok -and $runtimeErrors.Count -eq 0;
        elapsed_seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 3);
        errors = if ($null -ne $report) { @($report.errors) } else { @('missing_runtime_report') };
        runtime_errors = $runtimeErrors; report = "$relative/runtime_validation.json" }
    $results += $result
    $summary = [ordered]@{ schema = 3; capture = [bool]$Capture; results = $results;
        passed = @($results | Where-Object { $_.ok }).Count; total = $results.Count }
    [IO.File]::WriteAllText((Join-Path $rootOutput 'summary.json'),
        ($summary | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Write-Output ($result | ConvertTo-Json -Depth 4 -Compress)
    if (-not $result.ok) { exit 1 }
}
exit 0
