#requires -Version 7.2
[CmdletBinding()]
param([switch]$Headless, [switch]$EngineVerbose, [string]$GodotPath='')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$run=New-DevRun 'sentinelle-sprite-pilot'
$engineLock=$null
try {
    $engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $godot=Resolve-DevGodot $GodotPath
    $arguments=@('--path',$root,'--log-file',(Join-Path $run 'pilot.engine.log'))
    if($EngineVerbose) {$arguments+=@('--verbose')}
    if($Headless) {$arguments+=@('--headless')} else {
        $arguments+=@('--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution','1280x720')
    }
    $arguments+=@('res://tools/sprite_workshop/experiments/SentinelleProbe.tscn','--',"--output=$run")
    $process=Invoke-DevProcess $godot $arguments $root $run 'pilot' 150 @{APPDATA=(Join-Path $run 'userdata');LOCALAPPDATA=(Join-Path $run 'localdata')}
    $errors=@(Get-DevEngineErrors $run 'pilot' | Sort-Object -Unique)
    $reportPath=Join-Path $run 'report.json'
    if(-not(Test-Path -LiteralPath $reportPath)) {throw "Rapport absent : $run"}
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $passed=(Test-DevProcessSuccess $process) -and $report.passed -and $report.checks -gt 0 -and $errors.Count -eq 0
    $summary=@{passed=$passed;checks=$report.checks;errors=$errors;failures=$report.errors;reports=$run}
    Write-DevJson (Join-Path $run 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 4
    exit $(if($passed){0}else{1})
} catch {
    @{passed=$false;error=$_.Exception.Message;reports=$run} | ConvertTo-Json
    exit 1
} finally {
    if($engineLock){$engineLock.Dispose()}
}
