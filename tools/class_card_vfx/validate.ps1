# Reuse the CI strict runner, with one import for the relevant exact suites.
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Import-Module (Join-Path $projectRoot 'tools/dev/DevTools.psm1') -Force -DisableNameChecking
$outputRoot = New-DevRun 'class-card-vfx-regression'
$godotPath = Resolve-DevGodot ''
$engineLock = $null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $engineLock = [IO.File]::Open((Join-Path $projectRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $env:APPDATA = Join-Path $outputRoot 'appdata'
    $env:LOCALAPPDATA = $env:APPDATA
    [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
    $testPaths = @(
        'res://test/unit/test_class_card_vfx.gd',
        'res://test/unit/test_combat_effect_dedup_lifecycle.gd',
        'res://test/unit/test_battle_grid_lifecycle.gd',
        'res://test/unit/test_pending_spell_presentation.gd',
        'res://test/unit/test_achilles_guard_sprite_vfx.gd',
        'res://test/unit/test_terrain_test_integration_path.gd',
        'res://test/unit/test_run_content_isolation.gd'
    )
    & (Join-Path $projectRoot 'tools/ci/run_gut_strict.ps1') -GodotPath $godotPath -ProjectPath $projectRoot -SuiteId 'class-card-vfx-regression' -TestPath $testPaths -ImportTimeoutSeconds 240 -ArtifactsDirectory $outputRoot -ReportPath (Join-Path $outputRoot 'gut-strict-report.json')
    if ($LASTEXITCODE -ne 0) { throw "VFX regression failed: $outputRoot" }
    Write-Output "Strict regression report: $outputRoot/gut-strict-report.json"
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -ne $engineLock) { $engineLock.Dispose() }
}
