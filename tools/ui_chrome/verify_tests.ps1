# Run the official recovery-mode harness for each affected suite.
[CmdletBinding()]
param([string]$ProjectPath='', [string[]]$Suites=@('inventory_equipment_system','catabase_meshy_art','hud_visual_skin_data','hud_material_polish_v2','dark_pause_menu','champion_spell_tooltips'))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
if(-not $ProjectPath){$ProjectPath=Get-DevRoot}
$run=New-DevRun 'chrome-regression'
$shell=(Get-Process -Id $PID).Path
$results=@()
foreach($name in $Suites){
 $process=Invoke-DevProcess $shell @('-NoProfile','-File',(Join-Path $ProjectPath 'dev.ps1'),'test',"test/unit/test_$name.gd",'-GodotPath',(Resolve-DevGodot '')) $ProjectPath $run $name 960
 $summary=Get-Content -Raw -LiteralPath (Join-Path $run "$name.stdout.log") | ConvertFrom-Json
 $results+=@{suite=$name;process=$process;summary=$summary}
 Write-Output "$name : $($summary.verdict) ($($summary.tests) tests)"
}
$tests=($results.summary.tests | Measure-Object -Sum).Sum
$assertions=($results.summary.assertions | Measure-Object -Sum).Sum
$passed=$tests -gt 0 -and @($results | Where-Object {-not $_.summary.passed -or -not (Test-DevProcessSuccess $_.process)}).Count -eq 0
$report=@{passed=$passed;tests=$tests;assertions=$assertions;project=$ProjectPath;results=$results;reports=$run}
Write-DevJson (Join-Path $run 'summary.json') $report
$report | Select-Object passed,tests,assertions,project,reports | ConvertTo-Json
if(-not $passed){exit 1}
