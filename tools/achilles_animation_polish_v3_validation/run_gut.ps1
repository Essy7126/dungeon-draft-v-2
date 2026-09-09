param(
    [string]$Godot = 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe',
    [string]$Batch = 'gut_final'
)
$ErrorActionPreference = 'Stop'
if ($Batch -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Batch must be a simple directory name.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repo "artifacts/achilles_animation_polish_v3_validation/$Batch"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$scripts = @(
    'test_achilles_polish_v3_assets',
    'test_achilles_expedition_visual_contract',
    'test_achilles_sprite_motion_sampling',
    'test_achilles_kit_sprite_runtime_v2',
    'test_achilles_sprite_runtime',
    'test_achilles_sprite_assets',
    'test_achilles_sprite_stride',
    'test_achilles_sprite_advance_timing',
    'test_achilles_spell_visual_resolver',
    'test_achilles_kit_sprite_vfx',
    'test_achilles_guard_sprite_vfx',
    'test_achilles_kit_movement_v2',
    'test_achilles_kit_reaction_arrival',
    'test_achilles_painted_g_runtime',
    'test_achilles_visual_variant_run',
    'test_achilles_canonical_kit',
    'test_unit_movement_presentation'
)
foreach ($script in $scripts) {
    if (-not (Test-Path -LiteralPath (Join-Path $repo "test/unit/$script.gd"))) { throw "Missing test script: $script" }
}

function Invoke-ValidationStage {
    param([string]$Name, [string[]]$Arguments, [int]$TimeoutMs)
    $stageDirectory = Join-Path $output $Name
    New-Item -ItemType Directory -Force -Path $stageDirectory | Out-Null
    $stdout = Join-Path $stageDirectory 'stdout.log'
    $stderr = Join-Path $stageDirectory 'stderr.log'
    $process = $null
    $finished = $false
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $process = Start-Process -FilePath $Godot -ArgumentList $Arguments -WindowStyle Hidden `
            -WorkingDirectory $repo -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
        $finished = $process.WaitForExit($TimeoutMs)
        if (-not $finished) { $process.Kill(); $process.WaitForExit() }
    } finally {
        # Never target an editor or another task's process: this is our exact child.
        if ($null -ne $process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $watch.Stop()
    }
    $lines = @(Get-Content -LiteralPath $stdout, $stderr)
    $runtimeErrors = @($lines | Where-Object {
        $_ -match '^(SCRIPT ERROR:|ERROR:)|Parse Error:|Failed to load script' -and
        $_ -notmatch 'resources still in use at exit|RID allocations .* were leaked at exit|Pages in use exist at exit in PagedAllocator'
    })
    $shutdownDiagnostics = @($lines | Where-Object {
        $_ -match 'resources still in use at exit|RID allocations .* were leaked at exit|Pages in use exist at exit in PagedAllocator|ObjectDB instances were leaked at exit'
    })
    $result = [ordered]@{ stage = $Name; finished = $finished; exit_code = $process.ExitCode;
        elapsed_seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 3);
        ok = $finished -and $process.ExitCode -eq 0 -and $runtimeErrors.Count -eq 0;
        runtime_errors = $runtimeErrors; known_shutdown_diagnostics = $shutdownDiagnostics;
        stdout = $stdout; stderr = $stderr }
    [IO.File]::WriteAllText((Join-Path $stageDirectory 'result.json'),
        ($result | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    Write-Host ($result | ConvertTo-Json -Depth 4 -Compress)
    if (-not $result.ok) {
        Get-Content -LiteralPath $stdout -Tail 30 | Write-Host
        Get-Content -LiteralPath $stderr -Tail 35 | Write-Host
        throw "Achilles $Name validation failed; inspect the isolated stage logs."
    }
    return $result
}

$import = Invoke-ValidationStage -Name 'import' -TimeoutMs 180000 -Arguments @(
    '--headless', '--editor', '--import', '--path', $repo, '--quit'
)
$testArgument = '-gtest=' + (($scripts | ForEach-Object { "res://test/unit/$_.gd" }) -join ',')
$gut = Invoke-ValidationStage -Name 'gut' -TimeoutMs 240000 -Arguments @(
    '--headless', '--path', $repo, '-s', 'addons/gut/gut_cmdln.gd', '-gdir=', $testArgument, '-gexit'
)
$gutText = Get-Content -LiteralPath (Join-Path $output 'gut/stdout.log') -Raw
$gutText = [regex]::Replace($gutText, '\x1B\[[0-9;]*[A-Za-z]', '')
$testsMatch = [regex]::Match($gutText, '(?m)^Tests\s+(\d+)\s*$')
$passingMatch = [regex]::Match($gutText, '(?m)^Passing Tests\s+(\d+)\s*$')
$scriptMatch = [regex]::Match($gutText, '(?m)^Scripts\s+(\d+)\s*$')
$assertMatch = [regex]::Match($gutText, '(?m)^Asserts\s+(\d+)\s*$')
$tests = if ($testsMatch.Success) { [int]$testsMatch.Groups[1].Value } else { 0 }
$passing = if ($passingMatch.Success) { [int]$passingMatch.Groups[1].Value } else { 0 }
$scriptCount = if ($scriptMatch.Success) { [int]$scriptMatch.Groups[1].Value } else { 0 }
if ($tests -le 0 -or $passing -ne $tests -or $scriptCount -ne $scripts.Count -or $gutText -notmatch 'All tests passed!') {
    throw 'GUT did not confirm every requested script and test as passing.'
}
$summary = [ordered]@{ schema = 3; import = $import; gut = $gut; ok = $true;
    scripts = $scripts; script_count = $scriptCount; tests = $tests; passing = $passing;
    assertions = if ($assertMatch.Success) { [int]$assertMatch.Groups[1].Value } else { $null } }
[IO.File]::WriteAllText((Join-Path $output 'summary.json'),
    ($summary | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Get-Content -LiteralPath (Join-Path $output 'gut/stdout.log') -Tail 20
Write-Output ($summary | ConvertTo-Json -Depth 4 -Compress)
exit 0
