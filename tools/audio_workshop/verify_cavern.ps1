#requires -Version 7.2
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$godot=Resolve-DevGodot ''
$run=New-DevRun 'cavern-audio'
$environment=@{APPDATA=(Join-Path $run 'userdata');LOCALAPPDATA=(Join-Path $run 'userdata')}
$engineLock=$null
try {
    $lockTimer=[Diagnostics.Stopwatch]::StartNew()
    while($null -eq $engineLock) {
        try {$engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException] {
            if($lockTimer.Elapsed.TotalSeconds -ge 60){throw 'Godot is still in use by another validation.'}
            Start-Sleep -Milliseconds 1000
        }
    }
    $import=Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--import') $root $run 'import' 240 $environment
    $errors=@(Get-DevEngineErrors $run 'import')
    if(-not(Test-DevProcessSuccess $import) -or $errors.Count -gt 0){throw 'Import failed'}
    $output='res://'+[IO.Path]::GetRelativePath($root,(Join-Path $run 'cavern-report.json')).Replace('\','/')
    $argsList=@('--single-window','--path',$root,'--rendering-method','gl_compatibility','--audio-driver','WASAPI','--position','-3000,-3000','--log-file',(Join-Path $run 'verify.engine.log'),'res://tools/audio_workshop/CavernAudioQA.tscn','--',"--output=$output")
    $result=Invoke-DevProcess $godot $argsList $root $run 'verify' 60 $environment
    $errors=@(Get-DevEngineErrors $run 'verify')
    $report=Get-Content (Join-Path $run 'cavern-report.json') -Raw | ConvertFrom-Json
    $summary=@{passed=(Test-DevProcessSuccess $result) -and $report.passed -and $report.checks.Count -eq 10 -and $errors.Count -eq 0;checks=$report.checks.Count;errors=$errors;reports=$run}
    Write-DevJson (Join-Path $run 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 4
    exit $(if($summary.passed){0}else{1})
} catch {
    Write-DevJson (Join-Path $run 'summary.json') @{passed=$false;error=$_.Exception.Message;reports=$run}
    throw
} finally {if($engineLock){$engineLock.Dispose()}}
