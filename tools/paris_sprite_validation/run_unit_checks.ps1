param(
    [string]$Godot = 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe',
    [string]$Batch = 'gut_paris',
    [switch]$Regression
)
$ErrorActionPreference = 'Stop'
if ($Batch -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Batch must be a simple directory name.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $repo "artifacts/paris_sprite_validation_v1/$Batch"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$scripts = @(
    'test_paris_gameplay', 'test_paris_sprite_runtime', 'test_paris_sprite_vfx',
    'test_paris_visual_phase_lifecycle', 'test_paris_phase_portrait', 'test_paris_sprite_mirroring',
    'test_paris_production_access', 'test_paris_campaign_classifications', 'test_paris_enemy_inspection', 'test_paris_phase_hud', 'test_optional_preview_frames'
)
if ($Regression) {
    $scripts += @(
        'test_philosopher_gameplay', 'test_philosopher_terrain_ai', 'test_philosopher_sprite_runtime',
        'test_philosopher_sprite_vfx', 'test_philosopher_shield_lifetime', 'test_sourced_shields',
        'test_turn_order_timeline', 'test_room_transition_async_lifecycle', 'test_unit_movement_presentation',
        'test_catabase_vertical_slice_content', 'test_catabase_registered_terrain',
        'test_achilles_kit_movement_v2', 'test_achilles_kit_sprite_runtime_v2',
        'test_achilles_kit_sprite_vfx', 'test_vortex_networks', 'test_terrain_status_timing',
        'test_spectre_gameplay', 'test_spectre_sprite_runtime'
    )
}
$testArgument = '-gtest=' + (($scripts | ForEach-Object { "res://test/unit/$_.gd" }) -join ',')
$process = Start-Process -FilePath $Godot -ArgumentList @('--headless', '--path', $repo,
    '-s', 'addons/gut/gut_cmdln.gd', '-gdir=', $testArgument, '-gexit') -WindowStyle Hidden `
    -WorkingDirectory $repo -RedirectStandardOutput (Join-Path $output 'stdout.log') `
    -RedirectStandardError (Join-Path $output 'stderr.log') -PassThru
try {
    $finished = $process.WaitForExit(180000)
    if (-not $finished) { $process.Kill($true); $process.WaitForExit() }
    Get-Content -LiteralPath (Join-Path $output 'stdout.log') -Tail 45
    Get-Content -LiteralPath (Join-Path $output 'stderr.log') -TotalCount 65
    if (-not $finished) { throw 'Paris unit checks timed out.' }
    exit $process.ExitCode
} finally {
    if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
}
