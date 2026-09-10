#requires -Version 7.2
param([ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Revision='sentinelle_kit_v5')
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Import-Module (Join-Path $projectRoot 'tools/dev/DevTools.psm1') -Force -DisableNameChecking
$runRoot=New-DevRun 'sentinelle-kit-godot'
$reportPath=Join-Path $runRoot 'preview.json'
$engineLock=$null
try {
    $engineLock=[IO.File]::Open((Join-Path $projectRoot 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $arguments=@('--path',$projectRoot,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution','1200x896','res://tools/spine_trial/SentinelleKit.tscn','--',('--report='+$reportPath),('--revision='+$Revision))
    $process=Invoke-DevProcess (Resolve-DevGodot) $arguments $projectRoot $runRoot 'preview' 90
    $errors=@(Get-DevEngineErrors $runRoot 'preview')
    if(-not(Test-Path -LiteralPath $reportPath)){throw 'Native Spine preview report missing.'}
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $passed=(Test-DevProcessSuccess $process) -and $errors.Count -eq 0 -and $report.passed -and $report.checks.Count -eq 24
    $summary=@{passed=$passed;checks=$report.checks.Count;errors=$errors;reports=$runRoot;visual_review_required=$true}
    Write-DevJson (Join-Path $runRoot 'summary.json') $summary
    $summary | ConvertTo-Json
    exit $(if($passed){0}else{1})
} catch {
    $summary=@{passed=$false;error=$_.Exception.Message;reports=$runRoot}
    Write-DevJson (Join-Path $runRoot 'summary.json') $summary
    $summary | ConvertTo-Json
    exit 1
} finally {if($engineLock){$engineLock.Dispose()}}
