param(
    [string]$Godot = 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe',
    [string[]]$Maps = @('greek_drawn_courtyard_v1', 'ashen_hell_courtyard_v1', 'silent_judgment_courtyard_v1', 'lethe_crossing_v1', 'black_oath_temple_v1'),
    [string[]]$Scenarios = @('push_lava', 'push_water', 'push_ice', 'portal_pair'),
    [string]$Direction = 'E',
    [string]$Batch = 'terrain_matrix',
    [int]$Seed = 9062026,
    [switch]$IncludeCourtyardExtras,
    [switch]$Capture
)
$ErrorActionPreference = 'Stop'
function Read-SharedLog([string]$Path) {
    $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = [IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$validMaps = @('greek_drawn_courtyard_v1', 'ashen_hell_courtyard_v1', 'silent_judgment_courtyard_v1', 'lethe_crossing_v1', 'black_oath_temple_v1')
$validScenarios = @('push_lava', 'push_water', 'push_ice', 'portal_pair', 'avoid_fire', 'escape_fire', 'push_electric', 'portal_network')
if ($Batch -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Batch must be a simple directory name.' }
if ($Direction -notin @('E', 'N', 'S', 'W')) { throw 'Unknown direction.' }
foreach ($map in $Maps) { if ($map -notin $validMaps) { throw "Unknown canonical map $map" } }
foreach ($scenario in $Scenarios) { if ($scenario -notin $validScenarios) { throw "Unknown scenario $scenario" } }
$relativeRoot = "artifacts/philosopher_sprite_validation_v1/$Batch"
$outputRoot = Join-Path $repo $relativeRoot
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$results = @()
foreach ($map in $Maps) {
    $cases = @($Scenarios)
    if ($IncludeCourtyardExtras -and $map -eq 'greek_drawn_courtyard_v1') {
        $cases = @($cases + @('avoid_fire', 'escape_fire', 'push_electric', 'portal_network') | Select-Object -Unique)
    }
    foreach ($scenario in $cases) {
        $name = "${map}_${scenario}_${Direction}"
        $relative = "$relativeRoot/$name"
        $output = Join-Path $repo $relative
        New-Item -ItemType Directory -Force -Path $output | Out-Null
        $mode = if ($Capture) { '--capture-clip' } else { '--no-screenshots' }
        $arguments = @('--path', $repo, '--resolution', '1200x800',
            'res://tools/philosopher_sprite_validation/TerrainCombatValidation.tscn', '--',
            "--scenario=$scenario", "--direction=$Direction", "--room-path=res://data/arenas/$map/arena.tres",
            "--seed=$Seed", $mode, "--artifact-dir=res://$relative")
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden `
            -WorkingDirectory $repo -RedirectStandardOutput (Join-Path $output 'stdout.log') `
            -RedirectStandardError (Join-Path $output 'stderr.log') -PassThru
        try {
        $finished = $false
        $fatalScript = $false
        while ($watch.Elapsed.TotalSeconds -lt 180 -and -not $finished) {
            $finished = $process.WaitForExit(1000)
            if (-not $finished) {
                $errorLog = Read-SharedLog (Join-Path $output 'stderr.log')
                $fatalScript = $errorLog -match '(?m)^(SCRIPT ERROR:.*Parse Error|ERROR: Failed to load script)'
                if ($fatalScript) { break }
            }
        }
        if (-not $finished) { $process.Kill(); $process.WaitForExit() }
        $watch.Stop()
        $reportPath = Join-Path $output 'runtime_validation.json'
        $report = if (Test-Path -LiteralPath $reportPath) { Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json } else { $null }
        $runtimeErrors = @(Get-Content -LiteralPath (Join-Path $output 'stderr.log'), (Join-Path $output 'stdout.log') |
            Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:)' -and $_ -notmatch 'resources still in use at exit|RID allocations .* were leaked at exit|Pages in use exist at exit in PagedAllocator: N12VariantPools12BucketMediumE' })
        $result = [ordered]@{ name = $name; map = $map; scenario = $scenario; seed = $Seed;
            exit_code = $process.ExitCode; timed_out = -not $finished -and -not $fatalScript; fatal_script_stopped = $fatalScript;
            ok = $finished -and $process.ExitCode -eq 0 -and $null -ne $report -and $report.ok -and $runtimeErrors.Count -eq 0;
            elapsed_seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 3);
            errors = if ($null -ne $report) { @($report.errors) } else { @('missing_runtime_report') };
            runtime_errors = $runtimeErrors; report = "$relative/runtime_validation.json" }
        $results += $result
        $summary = [ordered]@{ capture = [bool]$Capture; results = $results;
            fixture_scope = 'Permanent tiles and portal networks declared before combat on unchanged canonical map topology; no midcombat stat or terrain mutations.';
            passed = @($results | Where-Object { $_.ok }).Count; total = $results.Count }
        [IO.File]::WriteAllText((Join-Path $outputRoot 'summary.json'), ($summary | ConvertTo-Json -Depth 9), [Text.UTF8Encoding]::new($false))
        Write-Output ($result | ConvertTo-Json -Depth 4 -Compress)
        } finally {
            if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        }
        if (-not $result.ok) { exit 1 }
    }
}
exit 0
