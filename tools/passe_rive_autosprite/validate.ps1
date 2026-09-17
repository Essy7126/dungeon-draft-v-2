#requires -Version 7.2
param([switch]$Full, [switch]$Integration, [switch]$VerboseEngine)
$ErrorActionPreference = 'Stop'
$taskRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Import-Module (Join-Path $taskRepo 'tools/dev/DevTools.psm1') -Force -DisableNameChecking
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = $taskRepo.Replace('\', '/')
$runRoot = New-DevRun 'passe-rive-autosprite'
$godot = Resolve-DevGodot
$toolchain = Get-DevToolchain
$version = (& $godot --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch $toolchain.godot_version_pattern) {
    throw "Unexpected Godot version: $version"
}
$appData = Join-Path $runRoot 'appdata'
[IO.Directory]::CreateDirectory($appData) | Out-Null
$environment = @{APPDATA=$appData; LOCALAPPDATA=$appData}
$import = Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$taskRepo,'--import') $taskRepo $runRoot 'import' 240 $environment
if (-not (Test-DevProcessSuccess $import) -or @(Get-DevEngineErrors $runRoot 'import').Count -gt 0) {
    throw "Import failed. See $runRoot"
}
$scripts = @('res://test/unit/test_passe_rive_autosprite.gd')
if ($Integration) {
    $names = @('test_achilles_autosprite.gd','test_character_selection*.gd','test_catabase_threshold.gd','test_run_hero*.gd','test_achilles_sprite_*.gd','test_achilles_kit_sprite_*.gd','test_achilles_kit_movement_v2.gd','test_achilles_kit_reaction_arrival.gd','test_achilles_polish_v3_assets.gd','test_achilles_painted_g_runtime.gd','test_achilles_guard_sprite_vfx.gd','test_achilles_odyssey_production_contract.gd','test_painted_halt_runtime.gd','test_unit_movement_presentation.gd')
    foreach ($pattern in $names) {
        $scripts += @(Get-ChildItem (Join-Path $taskRepo 'test/unit') -Filter $pattern | ForEach-Object { 'res://test/unit/' + $_.Name })
    }
    $scripts = @($scripts | Sort-Object -Unique)
}
if ($Full) {
    $scripts = @('res://test/unit/test_passe_rive_autosprite.gd') + @(Get-ChildItem (Join-Path $taskRepo 'test/unit') -Filter 'test_achilles_*.gd' | ForEach-Object { 'res://test/unit/' + $_.Name })
    $scripts += @('res://test/unit/test_catabase_threshold.gd', 'res://test/unit/test_painted_halt_runtime.gd', 'res://test/unit/test_painted_halt_catabase.gd', 'res://test/unit/test_unit_movement_presentation.gd')
}
$arguments = @('--headless','--path',$taskRepo,'--script','res://addons/gut/gut_cmdln.gd','--','-gconfig=','-gexit','-gdisable_colors','-gfailure_error_types','engine,gut,push_error','-gjunit_xml_file',(Join-Path $runRoot 'gut.junit.xml'))
if ($VerboseEngine) { $arguments = @('--verbose') + $arguments }
foreach ($path in $scripts) { $arguments += @('-gtest',$path) }
$gut = Invoke-DevProcess $godot $arguments $taskRepo $runRoot 'gut' 900 $environment
$inputPath = Join-Path $runRoot 'strict-input.json'
Write-DevJson $inputPath @{schema_version=1;suite_id='passe-rive-autosprite';godot=@{path=$godot;version=$version};gut_version=$toolchain.gut_version;selection=@{directory='res://test/unit';prefix='test_';suffix='.gd';include_subdirectories=$false;scripts=$scripts};expected=@{minimum_tests=13;failures=@()};process=@{import=$import;gut=$gut};files=@{import_stdout='import.stdout.log';import_stderr='import.stderr.log';gut_stdout='gut.stdout.log';gut_stderr='gut.stderr.log';junit='gut.junit.xml'}}
$reportPath = Join-Path $runRoot 'gut-strict-report.json'
$analysis = Invoke-DevProcess (Get-Process -Id $PID).Path @('-NoProfile','-File',(Join-Path $taskRepo 'tools/ci/run_gut_strict.ps1'),'-Mode','Analyze','-AnalysisFixturePath',$inputPath,'-ReportPath',$reportPath) $taskRepo $runRoot 'analyzer' 60
$summary = Get-DevStrictSummary $reportPath $analysis
$summary | ConvertTo-Json -Depth 12
if (-not $summary.passed) { exit 1 }
