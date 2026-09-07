param(
    [string]$Godot = 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe',
    [string]$Batch = 'gut_final'
)
$ErrorActionPreference = 'Stop'
if ($Batch -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Batch must be a simple directory name.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repo "artifacts/philosopher_sprite_validation_v1/$Batch"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$scripts = @(
    'test_philosopher_gameplay', 'test_philosopher_terrain_ai', 'test_philosopher_trial_terrain',
    'test_philosopher_sprite_runtime', 'test_philosopher_sprite_vfx', 'test_philosopher_shield_lifetime',
    'test_philosopher_selection_layout', 'test_philosopher_status_label', 'test_enemy_turn_banner_gate', 'test_registered_terrain_floor_palette',
    'test_sourced_shields', 'test_spectre_sprite_runtime', 'test_spectre_gameplay', 'test_character_selection_screen',
    'test_catabase_relic_tactical_executor', 'test_achilles_kit_sprite_vfx', 'test_achilles_kit_sprite_runtime_v2',
    'test_painted_unit_presence', 'test_vortex_networks', 'test_terrain_status_timing'
)
$testArgument = '-gtest=' + (($scripts | ForEach-Object { "res://test/unit/$_.gd" }) -join ',')
$process = Start-Process -FilePath $Godot -ArgumentList @('--headless', '--path', $repo,
    '-s', 'addons/gut/gut_cmdln.gd', '-gdir=', $testArgument, '-gexit') -WindowStyle Hidden `
    -WorkingDirectory $repo -RedirectStandardOutput (Join-Path $output 'stdout.log') `
    -RedirectStandardError (Join-Path $output 'stderr.log') -PassThru
try {
    $finished = $process.WaitForExit(120000)
    if (-not $finished) { $process.Kill($true); $process.WaitForExit() }
    Get-Content -LiteralPath (Join-Path $output 'stdout.log') -Tail 35
    Get-Content -LiteralPath (Join-Path $output 'stderr.log') -TotalCount 40
    if (-not $finished) { throw 'Mage unit checks timed out.' }
    exit $process.ExitCode
} finally {
    if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
}
