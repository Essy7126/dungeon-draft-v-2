#requires -Version 7.2
[CmdletBinding()]
param([ValidateSet('start','status','prepare')][string]$Command='status')
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$settings=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$statusUrl="http://127.0.0.1:$($settings.port)/api/status"
if($Command -eq 'prepare'){
    Import-Module (Join-Path $projectRoot 'tools/dev/DevTools.psm1') -Force -DisableNameChecking
    $runRoot=New-DevRun 'spine-prepare'
    $python=Join-Path $projectRoot 'artifacts/dev-tools/sprite-python/Scripts/python.exe'
    $result=Invoke-DevProcess $python @((Join-Path $PSScriptRoot 'prepare_sentinelle.py')) $projectRoot $runRoot 'prepare' 120
    if(-not(Test-DevProcessSuccess $result)){throw "Preparation failed: $runRoot"}
    Get-Content -LiteralPath (Join-Path $runRoot 'prepare.stdout.log')
    exit 0
}
$status=$null
try {$status=Invoke-RestMethod -Uri $statusUrl -TimeoutSec 2} catch {}
if($status){
    if([IO.Path]::GetFullPath($status.projectRoot) -ne (Join-Path $projectRoot 'artifacts/spine_trial')){throw 'Port belongs to another Spine workspace.'}
} elseif($Command -eq 'start'){
    $node=(Get-Command node -ErrorAction Stop).Source
    $logRoot=Join-Path $projectRoot 'artifacts/dev-tools/spine'
    [IO.Directory]::CreateDirectory($logRoot) | Out-Null
    $entry=Join-Path $PSScriptRoot 'server.mjs'
    $process=Start-Process -FilePath $node -ArgumentList @('"'+$entry+'"') -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logRoot 'server.stdout.log') -RedirectStandardError (Join-Path $logRoot 'server.stderr.log') -PassThru
    for($attempt=0;$attempt -lt 20;$attempt++){
        Start-Sleep -Milliseconds 250
        try {$status=Invoke-RestMethod -Uri $statusUrl -TimeoutSec 1; break} catch {}
        if($process.HasExited){throw "Server exited; read $logRoot/server.stderr.log"}
    }
    if(-not $status){throw "Server not ready; read $logRoot/server.stderr.log"}
    $process.Id | Set-Content -LiteralPath (Join-Path $logRoot 'server.pid')
}
if(-not $status){throw 'Spine connector is not running. Run ./tools/spine_trial/spine.ps1 start.'}
@{running=$true;root=$status.projectRoot;dashboard="http://127.0.0.1:$($settings.port)/";cli=$status.cli;trial_editor_version=$settings.trial_editor_observed;data_version=$settings.data_version} | ConvertTo-Json -Depth 5

exit 0
