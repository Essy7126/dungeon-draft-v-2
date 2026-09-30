#requires -Version 7.2
param([string]$Class = '', [int]$TimeoutSeconds = 1800)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force
$probeRoot = Get-DevRoot
$probeRun = New-DevRun 'prototype-v1-passe-rive'
$probeEngine = Resolve-DevGodot
$probeLock = [IO.File]::Open((Join-Path $probeRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $probeEnvironment = @{ APPDATA=(Join-Path $probeRun 'appdata'); LOCALAPPDATA=(Join-Path $probeRun 'localappdata') }
    foreach ($directory in $probeEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $probeArguments = @('--rendering-method','gl_compatibility','--windowed','--resolution','1280x720','--path',$probeRoot,'--log-file',(Join-Path $probeRun 'probe.engine.log'),'res://tools/consumable_cards/prototype_v1_probe.tscn','--',('--output=' + (Join-Path $probeRun 'observations.json').Replace('\','/')))
    if ($Class) { $probeArguments += '--class=' + $Class }
    $process = Invoke-DevProcess -Executable $probeEngine -Directory $probeRoot -LogRoot $probeRun -Label 'probe' -TimeoutSeconds $TimeoutSeconds -Environment $probeEnvironment -Arguments $probeArguments
    $report = @{ process=$process; diagnostics=@(Get-DevEngineErrors $probeRun 'probe'); directory=$probeRun; passed=$false }
    if ((Test-DevProcessSuccess $process) -and (Test-Path -LiteralPath (Join-Path $probeRun 'observations.json')) -and $report.diagnostics.Count -eq 0) {
        $observations = Get-Content -LiteralPath (Join-Path $probeRun 'observations.json') -Raw | ConvertFrom-Json
        $expected = if ($Class) { 6 } else { 24 }
        $invalidTrials = @($observations.trials | Where-Object {
            $_.casts.Count -eq 0 -or
            @($_.casts | Where-Object { $_.failed }).Count -gt 0 -or
            $_.appearance -ne 'res://characters/achilles/2d/passe_rive_s19_backend.gd' -or
            $_.outcome -notin @('victory','defeat','turn_limit')
        })
        $report.passed = $observations.completed -and $observations.trials.Count -eq $expected -and $invalidTrials.Count -eq 0 -and $observations.numerical.Count -eq 1728
        $report.trials = $observations.trials.Count
        $report.invalid_trials = $invalidTrials.Count
        $report.numerical_cases = $observations.numerical.Count
    }
    Write-DevJson (Join-Path $probeRun 'summary.json') $report
    $report | ConvertTo-Json -Depth 6
    if (-not $report.passed) { exit 1 }
} finally { $probeLock.Dispose() }
