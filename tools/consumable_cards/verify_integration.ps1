#requires -Version 7.2
param([int]$LockTimeoutSeconds = 900)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force
$auditRoot = Get-DevRoot
$auditRun = New-DevRun 'cards-integrated-visual'
$auditEngine = Resolve-DevGodot
$auditLock = $null
$auditWait = [Diagnostics.Stopwatch]::StartNew()
while ($null -eq $auditLock) {
    try { $auditLock = [IO.File]::Open((Join-Path $auditRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch [IO.IOException] {
        if ($auditWait.Elapsed.TotalSeconds -ge $LockTimeoutSeconds) { throw 'Godot remains in use; no verification was executed.' }
        Start-Sleep -Seconds 2
    }
}
try {
    $auditEnvironment = @{APPDATA=(Join-Path $auditRun 'appdata'); LOCALAPPDATA=(Join-Path $auditRun 'localappdata')}
    foreach ($directory in $auditEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $results = @()
    $smoke = Invoke-DevProcess -Executable $auditEngine -Directory $auditRoot -LogRoot $auditRun -Label 'entry' -TimeoutSeconds 120 -Environment $auditEnvironment -Arguments @('--headless','--path',$auditRoot,'--log-file',(Join-Path $auditRun 'entry.engine.log'),'res://tools/consumable_cards/integration_smoke.tscn')
    $entryText = Get-Content -LiteralPath (Join-Path $auditRun 'entry.stdout.log') -Raw
    $results += @{name='public-entry'; passed=((Test-DevProcessSuccess $smoke) -and $entryText.Contains('"passed":true')); process=$smoke; diagnostics=@(Get-DevEngineErrors $auditRun 'entry')}
    foreach ($resolution in @('1280x720', '1600x900')) {
        $captureRoot = Join-Path $auditRun $resolution
        [IO.Directory]::CreateDirectory($captureRoot) | Out-Null
        $auditEnvironment = @{APPDATA=(Join-Path $captureRoot 'appdata'); LOCALAPPDATA=(Join-Path $captureRoot 'localappdata')}
        foreach ($directory in $auditEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
        $label = 'capture-' + $resolution
        $capture = Invoke-DevProcess -Executable $auditEngine -Directory $auditRoot -LogRoot $auditRun -Label $label -TimeoutSeconds 180 -Environment $auditEnvironment -Arguments @('--path',$auditRoot,'--rendering-method','gl_compatibility','--windowed','--resolution',$resolution,'--log-file',(Join-Path $auditRun ($label + '.engine.log')),'res://tools/consumable_cards/integrated_capture.tscn','--',('--output=' + $captureRoot.Replace('\','/')))
        $captureText = Get-Content -LiteralPath (Join-Path $auditRun ($label + '.stdout.log')) -Raw
        $images = @(Get-ChildItem -LiteralPath $captureRoot -Filter '*.png')
        $results += @{name=$label; passed=((Test-DevProcessSuccess $capture) -and $captureText.Contains('"passed":true') -and $images.Count -eq 8); images=$images.Count; process=$capture; diagnostics=@(Get-DevEngineErrors $auditRun $label)}
    }
    $report = @{passed=(@($results | Where-Object { -not $_.passed -or $_.diagnostics.Count -gt 0 }).Count -eq 0); results=$results; directory=$auditRun}
    Write-DevJson (Join-Path $auditRun 'report.json') $report
    $report | ConvertTo-Json -Depth 8
    if (-not $report.passed) { exit 1 }
} finally { $auditLock.Dispose() }
