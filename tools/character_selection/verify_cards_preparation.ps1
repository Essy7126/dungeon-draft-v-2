#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force
$reviewRoot = Get-DevRoot
$reviewRun = New-DevRun 'cards-preparation-visual'
$reviewEngine = Resolve-DevGodot
$reviewLock = [IO.File]::Open((Join-Path $reviewRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $reviewEnvironment = @{APPDATA=(Join-Path $reviewRun 'appdata'); LOCALAPPDATA=(Join-Path $reviewRun 'localappdata')}
    foreach ($directory in $reviewEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $process = Invoke-DevProcess -Executable $reviewEngine -Directory $reviewRoot -LogRoot $reviewRun -Label 'capture' -TimeoutSeconds 180 -Environment $reviewEnvironment -Arguments @('--path',$reviewRoot,'--rendering-method','gl_compatibility','--windowed','--minimized','--resolution','1280x720','--log-file',(Join-Path $reviewRun 'capture.engine.log'),'res://tools/character_selection/selection_cards_review.tscn','--',('output=' + $reviewRun.Replace('\','/')))
    $reportPath = Join-Path $reviewRun 'report.json'
    $reportExists = Test-Path -LiteralPath $reportPath
    $reviewPassed = $false
    $checks = 0
    if ($reportExists) {
        $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $checks = $report.checks.Count
        $reviewPassed = $report.passed -and $checks -gt 0 -and $report.captures.Count -ge 4
    }
    $diagnostics = @(Get-DevEngineErrors $reviewRun 'capture')
    $summary = @{passed=((Test-DevProcessSuccess $process) -and $reviewPassed -and $diagnostics.Count -eq 0); checks=$checks; reports=$reviewRun; process=$process; diagnostics=$diagnostics}
    Write-DevJson (Join-Path $reviewRun 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 6
    if (-not $summary.passed) { exit 1 }
} finally { $reviewLock.Dispose() }
