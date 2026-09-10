#requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('merchant','sanctuary')][string]$Kind='merchant',
    [string]$GodotPath=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=New-DevRun "halt-production-$Kind"
$engineLock=$null
try {
    $godot=Resolve-DevGodot $GodotPath
    $engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $userdata=Join-Path $runRoot 'userdata'
    [IO.Directory]::CreateDirectory($userdata) | Out-Null
    $environment=@{APPDATA=$userdata;LOCALAPPDATA=$userdata}
    $compileArgs=@('--headless','--path',$root,'--script','res://tools/halt_workshop/compile_living_halt.gd','--log-file',(Join-Path $runRoot 'compile.engine.log'),'--','--compile-scene=res://tools/halt_workshop/VerifyProductionHalt.tscn')
    $compile=Invoke-DevProcess $godot $compileArgs $root $runRoot 'compile' 60 $environment
    $compileErrors=@(Get-DevEngineErrors $runRoot 'compile' | Sort-Object -Unique)
    $compileOutput=Get-Content -LiteralPath (Join-Path $runRoot 'compile.stdout.log') -Raw
    if (-not(Test-DevProcessSuccess $compile) -or $compileErrors.Count -gt 0 -or $compileOutput -notmatch '(?m)^HALT_VERIFIER_COMPILED\r?$') {throw "Production verifier failed compilation: $($compileErrors -join ' | ')"}
    $arguments=@('--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--log-file',(Join-Path $runRoot 'production.engine.log'),'res://tools/halt_workshop/VerifyProductionHalt.tscn','--',"--production-output=$runRoot","--production-kind=$Kind")
    $result=Invoke-DevProcess $godot $arguments $root $runRoot 'production' 180 $environment
    $errors=@(Get-DevEngineErrors $runRoot 'production' | Sort-Object -Unique)
    $reportPath=Join-Path $runRoot 'production_verification.json'
    if (-not(Test-Path -LiteralPath $reportPath)) {throw 'Missing production report: validation incomplete.'}
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $passed=(Test-DevProcessSuccess $result) -and $report.passed -and $report.rendered -and $report.check_count -gt 0 -and $report.captures.Count -ge 4 -and $errors.Count -eq 0
    $summary=@{passed=$passed;kind=$Kind;checks=$report.check_count;captures=$report.captures.Count;errors=$errors;reports=$runRoot}
    Write-DevJson (Join-Path $runRoot 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 5
    exit $(if($passed){0}else{1})
} catch {
    $summary=@{passed=$false;error=$_.Exception.Message;reports=$runRoot}
    Write-DevJson (Join-Path $runRoot 'summary.json') $summary
    $summary | ConvertTo-Json
    exit 1
} finally {
    if($engineLock){$engineLock.Dispose()}
}
