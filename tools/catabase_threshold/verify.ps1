#requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('unit','flow','capture')][string]$Mode='unit',
    [ValidateSet('skip','natural')][string]$Ending='skip',
    [ValidateSet('classic','painted_g')][string]$Appearance='painted_g',
    [ValidateRange(0,60)][int]$WaitForEngineSeconds=55,
    [ValidatePattern('^test/unit/[a-z0-9_]+\.gd$|^$')][string]$UnitPath='',
    [ValidateRange(30,900)][int]$UnitTimeoutSeconds=900
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$godot='C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe'
$run=New-DevRun "threshold-$Mode-$Ending-$Appearance"
$engineLock=$null
try {
    $deadline=[DateTime]::UtcNow.AddSeconds($WaitForEngineSeconds)
    while (-not $engineLock) {
        try {$engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException] {if([DateTime]::UtcNow -ge $deadline){throw}; Start-Sleep -Milliseconds 500}
    }
    $userdata=Join-Path $run 'userdata'
    [IO.Directory]::CreateDirectory($userdata) | Out-Null
    $environment=@{APPDATA=$userdata;LOCALAPPDATA=$userdata}
    $version=Invoke-DevProcess $godot @('--version') $root $run 'version' 15
    $versionText=[IO.File]::ReadAllText((Join-Path $run 'version.stdout.log')).Trim()
    if(-not(Test-DevProcessSuccess $version) -or $versionText -notmatch (Get-DevToolchain).godot_version_pattern){throw 'Godot version mismatch'}
    $import=Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--log-file',(Join-Path $run 'import.engine.log'),'--import') $root $run 'import' 240 $environment
    $errors=@(Get-DevEngineErrors $run 'import' | Sort-Object -Unique)
    if(-not(Test-DevProcessSuccess $import) -or $errors.Count -gt 0){throw "Import failed: $($errors -join ' | ')"}
    if($Mode -eq 'unit') {
        $names=@('test_catabase_threshold.gd','test_threshold_fog.gd','test_intro_cinematic.gd',
            'test_character_selection_screen.gd','test_catabase_selection_launch.gd','test_selection_replacement_guard.gd',
            'test_painted_halt_runtime.gd','test_painted_halt_catabase.gd','test_painted_halt_audio_lifecycle.gd',
            'test_battle_grid_lifecycle.gd','test_arena_visual_signature_lifecycle.gd',
            'test_room_transition_async_lifecycle.gd','test_combat_atomic_outcomes.gd','test_combat_effect_dedup_lifecycle.gd')
        $paths=if($UnitPath){@('res://'+$UnitPath)}else{@($names | ForEach-Object {'res://test/unit/'+$_})}
        $arguments=@('--headless','--path',$root,'--log-file',(Join-Path $run 'gut.engine.log'),'--script','res://addons/gut/gut_cmdln.gd','--','-gconfig=','-gexit','-gdisable_colors','-gfailure_error_types','engine,gut,push_error','-gjunit_xml_file',(Join-Path $run 'gut.junit.xml'))
        foreach($path in $paths){$arguments+=@('-gtest',$path)}
        $result=Invoke-DevProcess $godot $arguments $root $run 'gut' $UnitTimeoutSeconds $environment
        $input=@{schema_version=1;suite_id='threshold-integration';godot=@{path=$godot;version=$versionText};gut_version=(Get-DevToolchain).gut_version;
            selection=@{directory='res://test/unit';prefix='test_';suffix='.gd';include_subdirectories=$true;scripts=$paths};
            expected=@{minimum_tests=$(if($UnitPath){1}else{14});failures=@()};process=@{import=$import;gut=$result};
            files=@{import_stdout='import.stdout.log';import_stderr='import.stderr.log';import_engine='import.engine.log';gut_stdout='gut.stdout.log';gut_stderr='gut.stderr.log';gut_engine='gut.engine.log';junit='gut.junit.xml'}}
        $inputPath=Join-Path $run 'strict-input.json'
        Write-DevJson $inputPath $input
        $reportPath=Join-Path $run 'gut-strict-report.json'
        $analysis=Invoke-DevProcess (Get-Process -Id $PID).Path @('-NoProfile','-File',(Join-Path $root 'tools/ci/run_gut_strict.ps1'),'-Mode','Analyze','-AnalysisFixturePath',$inputPath,'-ReportPath',$reportPath) $root $run 'analyzer' 60
        $summary=Get-DevStrictSummary $reportPath $analysis
        $summary['reports']=$run
    } else {
        $relative='res://'+[IO.Path]::GetRelativePath($root,$run).Replace('\','/')
        $scene=if($Mode -eq 'flow'){'res://tests/cinematics/CatabaseThresholdFlowQA.tscn'}else{'res://tests/cinematics/CatabaseThresholdVisualQA.tscn'}
        $arguments=@('--verbose','--single-window','--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution','1280x720','--log-file',(Join-Path $run 'verify.engine.log'),$scene,'--',"--output=$relative","--ending=$Ending","--appearance=$Appearance")
        $result=Invoke-DevProcess $godot $arguments $root $run 'verify' 300 $environment
        $errors=@(Get-DevEngineErrors $run 'verify' | Sort-Object -Unique)
        $reportPath=Join-Path $run $(if($Mode -eq 'flow'){'flow-report.json'}else{'report.json'})
        if(-not(Test-Path -LiteralPath $reportPath)){throw 'Missing rendered report'}
        $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $summary=@{passed=(Test-DevProcessSuccess $result) -and $report.ok -and $report.checks.Count -gt 0 -and $report.captures.Count -gt 0 -and $errors.Count -eq 0;
                   checks=$report.checks.Count;captures=$report.captures.Count;errors=$errors;reports=$run}
    }
    Write-DevJson (Join-Path $run 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 6
    exit $(if($summary.passed){0}else{1})
} catch {
    $summary=@{passed=$false;error=$_.Exception.Message;reports=$run}
    Write-DevJson (Join-Path $run 'summary.json') $summary
    $summary | ConvertTo-Json
    exit 1
} finally {if($engineLock){$engineLock.Dispose()}}
