#requires -Version 7.2
[CmdletBinding()]
param([ValidateSet('open','verify')][string]$Command='open', [switch]$Simple)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$godot=Resolve-DevGodot
$scene=if($Simple){'res://tools/veilleur_walk/WalkSimpleReview.tscn'}else{'res://tools/veilleur_walk/WalkIsoReview.tscn'}
$verifyScript=if($Simple){'res://tools/veilleur_walk/verify_simple_native.gd'}else{'res://tools/veilleur_walk/verify_iso_native.gd'}
$kit=if($Simple){'veilleur_walk_simple_v1'}else{'veilleur_walk_iso_v1'}
if($Command -eq 'open') {
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$godot;$start.WorkingDirectory=$root
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    foreach($arg in @('--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1376x900',$scene)) {$start.ArgumentList.Add($arg)}
    $process=[Diagnostics.Process]::Start($start)
    @{started=$true;pid=$process.Id;scene=$scene;validation_performed=$false}|ConvertTo-Json
    exit 0
}
$run=New-DevRun $(if($Simple){'veilleur-simple'}else{'veilleur-iso'})
$lock=$null
try {
    $lock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $environment=@{APPDATA=(Join-Path $run 'userdata');LOCALAPPDATA=(Join-Path $run 'userdata')}
    $import=Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--log-file',(Join-Path $run 'import.engine.log'),'--import') $root $run 'import' 240 $environment
    $errors=@(Get-DevEngineErrors $run 'import')
    if(-not(Test-DevProcessSuccess $import) -or $errors.Count -gt 0){throw ('Import failed: '+($errors -join ' / '))}
    $reportPath=Join-Path $root "artifacts/spine_trial/$kit/godot_report.json"
    $oldStamp=if(Test-Path $reportPath){(Get-Item $reportPath).LastWriteTimeUtc}else{[DateTime]::MinValue}
    $arguments=@('--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution','1376x900','--log-file',(Join-Path $run 'native.engine.log'),'--script',$verifyScript)
    $native=Invoke-DevProcess $godot $arguments $root $run 'native' 90 $environment
    $errors=@(Get-DevEngineErrors $run 'native')
    if(-not(Test-Path $reportPath) -or (Get-Item $reportPath).LastWriteTimeUtc -le $oldStamp){throw 'Native report missing or stale'}
    $report=Get-Content $reportPath -Raw|ConvertFrom-Json
    $passed=(Test-DevProcessSuccess $native) -and $report.passed -and $report.checks -gt 0 -and $errors.Count -eq 0
    $summary=@{passed=$passed;errors=$errors;result=$report;reports=$run}
    Write-DevJson (Join-Path $run 'summary.json') $summary
    $summary|ConvertTo-Json -Depth 10
    exit $(if($passed){0}else{1})
} catch {
    $summary=@{passed=$false;error=$_.Exception.Message;reports=$run}
    Write-DevJson (Join-Path $run 'summary.json') $summary
    $summary|ConvertTo-Json
    exit 1
} finally {if($lock){$lock.Dispose()}}
