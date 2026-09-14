#requires -Version 7.2
[CmdletBinding()]
param([string]$GodotPath='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$godot=Resolve-DevGodot $GodotPath
$run=New-DevRun 'production-audio'
$environment=@{APPDATA=(Join-Path $run 'userdata');LOCALAPPDATA=(Join-Path $run 'userdata');XDG_DATA_HOME=(Join-Path $run 'userdata')}
$engineLock=$null
try {
    $engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $import=Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--import') $root $run 'import' 240 $environment
    $errors=@(Get-DevEngineErrors $run 'import' | Sort-Object -Unique)
    if(-not(Test-DevProcessSuccess $import) -or $errors.Count -gt 0){throw "Import failed: $($errors -join ' | ')"}
    $relative='res://'+[IO.Path]::GetRelativePath($root,$run).Replace('\','/')
    $arguments=@('--single-window','--path',$root,'--rendering-method','gl_compatibility','--audio-driver','WASAPI','--position','-3000,-3000','--resolution','1280x720','--log-file',(Join-Path $run 'verify.engine.log'),'res://tools/audio_workshop/ProductionAudioQA.tscn','--',"--output=$relative",'--ending=skip','--appearance=classic')
    $result=Invoke-DevProcess $godot $arguments $root $run 'verify' 420 $environment
    $errors=@(Get-DevEngineErrors $run 'verify' | Sort-Object -Unique)
    $reportPath=Join-Path $run 'flow-report.json'
    if(-not(Test-Path -LiteralPath $reportPath)){throw 'Missing normal-launch audio report'}
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $cues=if($report.PSObject.Properties.Name -contains 'production_cues'){@($report.production_cues.PSObject.Properties).Count}else{0}
    $summary=@{passed=(Test-DevProcessSuccess $result) -and $report.ok -and $report.checks.Count -gt 0 -and $report.captures.Count -gt 0 -and $cues -eq 4 -and $errors.Count -eq 0;
        checks=$report.checks.Count;production_cues=$cues;errors=$errors;reports=$run}
    Write-DevJson (Join-Path $run 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 5
    exit $(if($summary.passed){0}else{1})
} catch {
    Write-DevJson (Join-Path $run 'summary.json') @{passed=$false;error=$_.Exception.Message;reports=$run}
    throw
} finally {if($engineLock){$engineLock.Dispose()}}
