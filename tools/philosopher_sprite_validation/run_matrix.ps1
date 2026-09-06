param(
    [string]$Godot = 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe',
    [string[]]$Directions = @('E', 'N', 'S', 'W'),
    [string[]]$Scenarios = @('attack', 'control', 'shield', 'heal_self', 'heal_ally', 'approach', 'repel', 'defeat'),
    [string]$Batch = 'matrix',
    [switch]$Capture
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ($Batch -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Batch must be a simple directory name.' }
foreach ($direction in $Directions) {
    if ($direction -notin @('N', 'E', 'S', 'W')) { throw "Unknown direction $direction" }
}
foreach ($scenario in $Scenarios) {
    if ($scenario -notin @('attack', 'control', 'shield', 'heal_self', 'heal_ally', 'approach', 'repel', 'defeat')) {
        throw "Unknown scenario $scenario"
    }
}
$results = @()
$relativeRoot = "artifacts/philosopher_sprite_validation_v1/$Batch"
$outputRoot = Join-Path $repo $relativeRoot
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
foreach ($direction in $Directions) {
    foreach ($scenario in $Scenarios) {
        $name = "${scenario}_${direction}"
        $relative = "$relativeRoot/$name"
        $output = Join-Path $repo $relative
        New-Item -ItemType Directory -Force -Path $output | Out-Null
        $mode = if ($Capture) { '--capture-clip' } else { '--no-screenshots' }
        $arguments = @('--path', $repo, '--resolution', '1200x800',
            'res://tools/philosopher_sprite_validation/PhilosopherCombatValidation.tscn', '--',
            "--scenario=$scenario", "--direction=$direction", $mode, "--artifact-dir=res://$relative")
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden `
            -WorkingDirectory $repo -RedirectStandardOutput (Join-Path $output 'stdout.log') `
            -RedirectStandardError (Join-Path $output 'stderr.log') -PassThru
        $finished = $process.WaitForExit(180000)
        if (-not $finished) {
            # Stop only the exact child started by this case.
            $process.Kill()
            $process.WaitForExit()
        }
        $watch.Stop()
        $reportPath = Join-Path $output 'runtime_validation.json'
        $report = if (Test-Path -LiteralPath $reportPath) {
            Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        } else { $null }
        $runtimeErrors = @(Get-Content -LiteralPath (Join-Path $output 'stderr.log'), (Join-Path $output 'stdout.log') |
            Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:)' -and
                $_ -notmatch 'resources still in use at exit|RID allocations .* were leaked at exit|Pages in use exist at exit in PagedAllocator: N12VariantPools12BucketMediumE' })
        $result = [ordered]@{ name = $name; exit_code = $process.ExitCode; timed_out = -not $finished;
            ok = $finished -and $process.ExitCode -eq 0 -and $null -ne $report -and $report.ok -and $runtimeErrors.Count -eq 0;
            elapsed_seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 3);
            errors = if ($null -ne $report) { @($report.errors) } else { @('missing_runtime_report') };
            runtime_errors = $runtimeErrors; report = "$relative/runtime_validation.json" }
        $results += $result
        $summary = [ordered]@{ capture = [bool]$Capture; results = $results;
            passed = @($results | Where-Object { $_.ok }).Count; total = $results.Count }
        [IO.File]::WriteAllText((Join-Path $outputRoot 'summary.json'),
            ($summary | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        Write-Output ($result | ConvertTo-Json -Depth 4 -Compress)
        if (-not $result.ok) { exit 1 }
    }
}
exit 0
