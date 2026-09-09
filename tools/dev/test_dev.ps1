#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'DevTools.psm1') -Force -DisableNameChecking
$testRoot=New-DevRun 'harness-contract-tests'
$shell=(Get-Process -Id $PID).Path
$checks=0
function Assert-Contract([bool]$Value,[string]$Message) {
    if(-not $Value){throw $Message}
    $script:checks++
}
$fixture=Join-Path $testRoot 'process with spaces.ps1'
[IO.File]::WriteAllText($fixture,'param([string]$Value) Write-Output $Value; exit 7')
$literal='spaces " quotes $(not-a-command) ; &'
$result=Invoke-DevProcess $shell @('-NoProfile','-File',$fixture,'-Value',$literal) $testRoot $testRoot 'nonzero' 15
Assert-Contract ($result.exit_code -eq 7) 'Nonzero exit was lost.'
Assert-Contract (-not(Test-DevProcessSuccess $result)) 'Failed subprocess became a success.'
Assert-Contract ([IO.File]::ReadAllText((Join-Path $testRoot 'nonzero.stdout.log')).Trim() -eq $literal) 'Argument quoting changed literal input.'
$missing=Invoke-DevProcess (Join-Path $testRoot 'missing.exe') @() $testRoot $testRoot 'missing' 1
Assert-Contract (-not(Test-DevProcessSuccess $missing) -and [bool]$missing.start_error) 'Failed startup became a success.'
$sleeper=Join-Path $testRoot 'sleep.ps1'
[IO.File]::WriteAllText($sleeper,'Write-Output "before timeout"; Start-Sleep -Seconds 20')
$timeout=Invoke-DevProcess $shell @('-NoProfile','-File',$sleeper) $testRoot $testRoot 'timeout' 1
Assert-Contract ($timeout.timed_out -and -not(Test-DevProcessSuccess $timeout)) 'Timeout became a success.'
$success=@{started=$true;start_error=$null;timed_out=$false;exit_code=0}
$reportPath=Join-Path $testRoot 'strict.json'
$missingRejected=$false
try { Get-DevStrictSummary $reportPath $success | Out-Null } catch { $missingRejected=$true }
Assert-Contract $missingRejected 'Missing report accepted.'
Write-DevJson $reportPath @{verdict='PASS';counts=@{tests_executed=0;assertions_passed=0};failure_codes=@();errors=@()}
Assert-Contract (-not(Get-DevStrictSummary $reportPath $success).passed) 'Zero tests accepted.'
Write-DevJson $reportPath @{verdict='PASS_WITH_EXPECTED_FAILURES';counts=@{tests_executed=3;assertions_passed=4};failure_codes=@();errors=@()}
$summary=Get-DevStrictSummary $reportPath $success
Assert-Contract ($summary.passed -and $summary.verdict -eq 'PASS_WITH_EXPECTED_FAILURES') 'Expected failures were concealed.'
Assert-Contract (-not(Get-DevStrictSummary $reportPath $timeout).passed) 'A report overrode process failure.'
[IO.File]::WriteAllText((Join-Path $testRoot 'engine.stderr.log'),"ERROR: import failed`nWARNING: ObjectDB instances were leaked at exit.`n")
Assert-Contract (@(Get-DevEngineErrors $testRoot 'engine').Count -eq 2) 'Engine errors or shutdown leaks were hidden.'
$traversalRejected=$false
try { Get-DevTestPaths 'test/unit/../../project.godot' | Out-Null } catch { $traversalRejected=$true }
Assert-Contract $traversalRejected 'Test path traversal accepted.'
Write-Output "HARNESS_TESTS_PASS: $checks checks. Reports: $testRoot"
