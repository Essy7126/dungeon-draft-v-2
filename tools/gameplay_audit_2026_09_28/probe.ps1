#requires -Version 7.2
param([switch]$Capture)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force
$auditRoot = Get-DevRoot
$auditRun = New-DevRun 'gameplay-audit-september28'
$auditEngine = Resolve-DevGodot
$auditLock = [IO.File]::Open((Join-Path $auditRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $auditEnvironment = @{APPDATA=(Join-Path $auditRun 'appdata'); LOCALAPPDATA=(Join-Path $auditRun 'localappdata')}
    foreach ($directory in $auditEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $probeArguments = @('--headless')
    if ($Capture) { $probeArguments = @('--rendering-method','gl_compatibility','--windowed','--resolution','1280x720') }
    $probeArguments += @('--path',$auditRoot,'--log-file',(Join-Path $auditRun 'probe.engine.log'),'res://tools/gameplay_audit_2026_09_28/probe.tscn','--',('--output=' + (Join-Path $auditRun 'observations.json').Replace('\','/')))
    if ($Capture) { $probeArguments += '--capture' }
    $process = Invoke-DevProcess -Executable $auditEngine -Directory $auditRoot -LogRoot $auditRun -Label 'probe' -TimeoutSeconds 300 -Environment $auditEnvironment -Arguments $probeArguments
    $report = @{process=$process; diagnostics=@(Get-DevEngineErrors $auditRun 'probe'); directory=$auditRun; verdict='INCOMPLETE'}
    if ((Test-DevProcessSuccess $process) -and (Test-Path -LiteralPath (Join-Path $auditRun 'observations.json')) -and $report.diagnostics.Count -eq 0) {
        $observations = Get-Content -LiteralPath (Join-Path $auditRun 'observations.json') -Raw | ConvertFrom-Json
        if ($observations.completed -and $observations.integration_complete -and $observations.probes.geometry.Count -eq 12 -and $observations.probes.all_native_rosters.Count -eq 32) { $report.verdict = 'OK' }
    }
    if ($Capture -and @(Get-ChildItem -LiteralPath $auditRun -Filter '*.png').Count -ne 7) { $report.verdict = 'INCOMPLETE' }
    Write-DevJson (Join-Path $auditRun 'summary.json') $report
    $report | ConvertTo-Json -Depth 6
    if ($report.verdict -ne 'OK') { exit 1 }
} finally { $auditLock.Dispose() }
