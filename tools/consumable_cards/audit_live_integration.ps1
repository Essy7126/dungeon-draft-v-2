#requires -Version 7.2
param([int]$LockTimeoutSeconds = 300, [switch]$Capture, [string]$Resolution = '1280x720')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force
$auditRoot = Get-DevRoot
$auditRun = New-DevRun 'cards-live-reaudit'
$auditEngine = Resolve-DevGodot
$auditLock = $null
$auditWait = [Diagnostics.Stopwatch]::StartNew()
while ($null -eq $auditLock) {
    try { $auditLock = [IO.File]::Open((Join-Path $auditRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch [IO.IOException] {
        if ($auditWait.Elapsed.TotalSeconds -ge $LockTimeoutSeconds) { throw 'Godot in use; audit not executed.' }
        Start-Sleep -Seconds 2
    }
}
try {
    $auditEnvironment = @{APPDATA=(Join-Path $auditRun 'appdata'); LOCALAPPDATA=(Join-Path $auditRun 'localappdata')}
    foreach ($directory in $auditEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $probeArguments = @('--headless')
    if ($Capture) { $probeArguments = @('--rendering-method','gl_compatibility','--windowed','--resolution',$Resolution) }
    $probeArguments += @('--path',$auditRoot,'--log-file',(Join-Path $auditRun 'probe.engine.log'),'res://tools/consumable_cards/audit_live_integration.tscn','--',('--output=' + (Join-Path $auditRun 'observations.json').Replace('\','/')))
    if ($Capture) { $probeArguments += '--capture' }
    $process = Invoke-DevProcess -Executable $auditEngine -Directory $auditRoot -LogRoot $auditRun -Label 'probe' -TimeoutSeconds 240 -Environment $auditEnvironment -Arguments $probeArguments
    $report = @{process=$process; diagnostics=@(Get-DevEngineErrors $auditRun 'probe'); directory=$auditRun; observations_present=(Test-Path -LiteralPath (Join-Path $auditRun 'observations.json')); verdict='INCOMPLETE'}
    if ((Test-DevProcessSuccess $process) -and $report.observations_present -and $report.diagnostics.Count -eq 0) {
        $observations = Get-Content -LiteralPath (Join-Path $auditRun 'observations.json') -Raw | ConvertFrom-Json
        if ($observations.completed) {
            $report.verdict = if ($observations.integration_complete) { 'OK' } else { 'NEEDS_CHANGES' }
            $report.findings = @($observations.findings)
        }
    }
    if ($Capture) {
        $report.captures = @(Get-ChildItem -LiteralPath $auditRun -Filter '*.png').Count
        $report.resolution = $Resolution
        if ($report.captures -ne 7) { $report.verdict = 'INCOMPLETE' }
    }
    Write-DevJson (Join-Path $auditRun 'summary.json') $report
    $report | ConvertTo-Json -Depth 6
    if (-not (Test-DevProcessSuccess $process) -or -not $report.observations_present -or $report.diagnostics.Count -gt 0) { exit 1 }
    if ($report.verdict -eq 'NEEDS_CHANGES') { exit 3 }
    if ($report.verdict -ne 'OK') { exit 1 }
} finally { $auditLock.Dispose() }
