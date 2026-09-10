# Rendered review of a prepared Catabase inventory using actual UI/services.
[CmdletBinding()]
param([ValidateSet('1280x720','1920x1080')][string]$Resolution='1280x720', [string]$ProjectPath='', [ValidateSet('inventory','menus','game','hud','icons')][string]$Screen='inventory')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
if(-not $ProjectPath){$ProjectPath=$root}
$run=New-DevRun "chrome-$Screen-$Resolution"
$scene=@{menus='MenusReview';inventory='InventoryReview';game='GameReview';hud='HudReview';icons='IconsReview'}[$Screen]
# Public selection now contains the two Catabase presentations; the classic Mage screen was removed.
$expectedImages=@{menus=6;inventory=6;game=14;hud=4;icons=6}[$Screen]
$lockPath=Join-Path $ProjectPath 'artifacts/dev/engine.lock'
[IO.Directory]::CreateDirectory((Split-Path $lockPath)) | Out-Null
$engineLock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
 $godot=Resolve-DevGodot ''
 $envDir=Join-Path $run 'appdata'
 [IO.Directory]::CreateDirectory($envDir) | Out-Null
 $result=Invoke-DevProcess $godot @('--path',$ProjectPath,'--rendering-method','gl_compatibility','--resolution',$Resolution,'--log-file',(Join-Path $run 'probe.engine.log'),"res://tools/ui_chrome/$scene.tscn",'--',"review_resolution=$Resolution","output_dir=$(Join-Path $run 'captures')") $ProjectPath $run 'probe' 240 @{APPDATA=$envDir;LOCALAPPDATA=$envDir}
 $source=Join-Path $run 'captures'
 $reportPath=Join-Path $source 'report.json'
 $report=$null
 if(Test-Path $reportPath){
  $report=Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
 }
 $diagnostics=@(Get-DevEngineErrors $run 'probe')
 $imageCount=@(Get-ChildItem -LiteralPath $source -Filter '*.png' -ErrorAction SilentlyContinue).Count
 $passed=$imageCount -eq $expectedImages -and (Test-DevProcessSuccess $result) -and $null -ne $report -and $report.checks -gt 0 -and $report.failures.Count -eq 0 -and $diagnostics.Count -eq 0
 $summary=@{passed=$passed;project=$ProjectPath;images=$imageCount;process=$result;checks=if($report){$report.checks}else{0};failures=if($report){$report.failures}else{@('Report missing')};engine_errors=$diagnostics;reports=$run}
 Write-DevJson (Join-Path $run 'summary.json') $summary
 $summary | ConvertTo-Json -Depth 5
 if(-not $passed){exit 1}
} finally {$engineLock.Dispose()}
