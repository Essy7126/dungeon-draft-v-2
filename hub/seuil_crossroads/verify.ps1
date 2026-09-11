#requires -Version 7.2
[CmdletBinding()]
param([string]$GodotPath='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../tools/dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=New-DevRun 'seuil-crossroads-verify'
$engineLock=$null
try {
    $godot=Resolve-DevGodot $GodotPath
    $engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $relative='res://' + [IO.Path]::GetRelativePath($root,$runRoot).Replace('\','/')
    $environment=@{APPDATA=(Join-Path $runRoot 'userdata');LOCALAPPDATA=(Join-Path $runRoot 'userdata')}
    [IO.Directory]::CreateDirectory($environment.APPDATA) | Out-Null
    $arguments=@('--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x720','--position','-3000,-3000','--log-file',(Join-Path $runRoot 'seuil.engine.log'),'res://hub/seuil_crossroads/VerifySeuil.tscn','--',"--output=$relative")
    $result=Invoke-DevProcess $godot $arguments $root $runRoot 'seuil' 300 $environment
    $errors=@(Get-DevEngineErrors $runRoot 'seuil' | Sort-Object -Unique)
    $path=Join-Path $runRoot 'verification.json'
    $report=if(Test-Path $path){Get-Content $path -Raw | ConvertFrom-Json}else{$null}
    $passed=(Test-DevProcessSuccess $result) -and $null -ne $report -and $report.passed -and $report.count -gt 0 -and $errors.Count -eq 0
    Write-DevJson (Join-Path $runRoot 'summary.json') @{passed=$passed;errors=$errors;reports=$runRoot;report=$path}
    Get-Content (Join-Path $runRoot 'summary.json')
    exit $(if($passed){0}else{1})
} finally { if($engineLock){$engineLock.Dispose()} }
