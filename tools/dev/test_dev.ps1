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
$contextFiles=@(
    'art/source/maps/catabase_old/brief.md',
    'docs/ai/CATABASE_OLD.md',
    'docs/archive/catabase_old.md',
    'docs/current/product.md',
    'core/expedition/expedition_session.gd',
    'core/expedition/expedition_session.gd',
    'ui/expedition/expedition_screen.gd',
    'test/unit/test_catabase_class_run.gd',
    'addons/gut/catabase_test.gd',
    'artifacts/catabase/report.json',
    'data/units/alliés/catabase.tres'
)
$context=Get-DevContext catabase -Files $contextFiles -PageSize 2
Assert-Contract ($context.paths[0] -eq 'core/expedition/expedition_session.gd' -and $context.paths[1] -eq 'ui/expedition/expedition_screen.gd') 'Context hid runtime entry points behind artwork.'
Assert-Contract ($context.total -eq 6 -and $context.shown -eq 2 -and $context.has_more) 'Context did not deduplicate/filter generated, vendor or archived paths.'
$next=Get-DevContext catabase -Files $contextFiles -PageSize 2 -Page 2
Assert-Contract ($next.paths.Count -eq 2 -and $next.paths[0] -notin $context.paths) 'Context pagination repeated the first page.'
$emptyPage=Get-DevContext catabase -Files $contextFiles -Page 100
Assert-Contract ($emptyPage.shown -eq 0 -and -not $emptyPage.has_more) 'Context page past the end is invalid.'
$archived=Get-DevContext catabase -Files $contextFiles -Kind docs -IncludeArchive
Assert-Contract ($archived.total -eq 4 -and 'docs/ai/CATABASE_OLD.md' -in $archived.paths) 'Explicit archive search lost historical documents.'
$dataContext=Get-DevContext catabase -Files $contextFiles -Kind data
Assert-Contract ($dataContext.paths.Count -eq 1 -and $dataContext.paths[0] -eq 'data/units/alliés/catabase.tres') 'Context lost accented resource paths or ignored the kind filter.'
$cardsContext=Get-DevContext cartes -Files @('core/expedition/class_card_catalog.gd','vfx/class_cards/class_card_vfx_player.gd')
Assert-Contract ($cardsContext.total -eq 2) 'Domain aliases lost card catalog/VFX paths.'
Assert-Contract ((Get-DevContext unknown -Files @()).total -eq 0) 'Empty context search failed.'
Assert-Contract ((Get-DevContext philosopher -Files @('characters/philosopher_mage/view.gd')).shown -eq 1) 'Literal search outside registered domains failed.'
$domains=Get-Content (Join-Path $PSScriptRoot 'context-domains.json') -Raw | ConvertFrom-Json -AsHashtable
foreach ($domain in $domains.Values) {
    foreach ($entrypoint in $domain.entrypoints) { Assert-Contract (Test-Path -LiteralPath (Join-Path (Get-DevRoot) $entrypoint) -PathType Leaf) "Missing context entry point: $entrypoint" }
}
$cardTests=@(Get-DevTestPaths cards)
$allTests=@(Get-DevTestPaths all)
Assert-Contract ('res://test/unit/test_pathfinder_query_reuse.gd' -in $allTests -and 'res://test/unit/test_item_studio_v1.gd' -in $allTests -and 'res://test/unit/test_class_card_vfx.gd' -in $allTests) 'Single-pattern all suite lost gameplay or editor tests.'
Assert-Contract (@(Get-DevTestPaths 'test/unit/test_champion_codex.gd').Count -eq 1) 'Exact test selection failed.'
$catabaseTests=@(Get-DevTestPaths catabase)
Assert-Contract ('res://test/unit/test_class_card_vfx.gd' -in $cardTests -and 'res://test/unit/test_class_painted_icons.gd' -in $cardTests) 'Cards suite omitted visual contracts.'
Assert-Contract (@($cardTests | Where-Object { $_ -notin $catabaseTests }).Count -eq 0) 'Catabase omitted a card contract.'
$cardAudit=@(Get-DevTestPaths cards-audit)
Assert-Contract ('res://test/unit/test_cards_studio_audit.gd' -in $cardAudit -and $cardAudit[0] -in $allTests -and $cardAudit[0] -notin $cardTests) 'Expensive card audit was lost or mixed into routine card contracts.'
$studioTests=@(Get-DevTestPaths studio)
Assert-Contract ($studioTests.Count -gt 30 -and 'res://test/unit/test_encounter_document_safety.gd' -in $studioTests -and 'res://test/unit/test_item_studio_v1.gd' -in $studioTests) 'Studio suite lost editor contracts.'
Assert-Contract (Test-DevFormatPath 'addons/dungeon_draft_arena_studio/ui/arena_studio_main.gd') 'Project-owned addon excluded from formatting.'
Assert-Contract (-not(Test-DevFormatPath 'addons/gut/gut.gd') -and -not(Test-DevFormatPath 'artifacts/generated.gd')) 'Vendor or generated script accepted for formatting.'
Write-Output "HARNESS_TESTS_PASS: $checks checks. Reports: $testRoot"
