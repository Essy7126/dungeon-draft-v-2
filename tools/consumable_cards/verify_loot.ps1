#requires -Version 7.2
param([int]$LockTimeoutSeconds = 900)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force
$lootRoot = Get-DevRoot
$lootRun = New-DevRun 'cards-loot-visual'
$lootEngine = Resolve-DevGodot
$lootLock = $null
$lootWait = [Diagnostics.Stopwatch]::StartNew()
while ($null -eq $lootLock) {
    try { $lootLock = [IO.File]::Open((Join-Path $lootRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch [IO.IOException] {
        if ($lootWait.Elapsed.TotalSeconds -ge $LockTimeoutSeconds) { throw 'Godot remains in use; no loot verification was executed.' }
        Start-Sleep -Seconds 2
    }
}
try {
    $results = @()
    foreach ($resolution in @('1280x720', '1600x900')) {
        $captureRoot = Join-Path $lootRun $resolution
        [IO.Directory]::CreateDirectory($captureRoot) | Out-Null
        $lootEnvironment = @{APPDATA=(Join-Path $captureRoot 'appdata'); LOCALAPPDATA=(Join-Path $captureRoot 'localappdata')}
        foreach ($directory in $lootEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
        $label = 'loot-' + $resolution
        $process = Invoke-DevProcess -Executable $lootEngine -Directory $lootRoot -LogRoot $lootRun -Label $label -TimeoutSeconds 90 -Environment $lootEnvironment -Arguments @('--path',$lootRoot,'--rendering-method','gl_compatibility','--windowed','--resolution',$resolution,'--log-file',(Join-Path $lootRun ($label + '.engine.log')),'res://tools/consumable_cards/loot_capture.tscn','--',('--output=' + $captureRoot.Replace('\','/')))
        $outputText = Get-Content -LiteralPath (Join-Path $lootRun ($label + '.stdout.log')) -Raw
        $images = @(Get-ChildItem -LiteralPath $captureRoot -Filter '*.png')
        $results += @{name=$label; passed=((Test-DevProcessSuccess $process) -and $outputText.Contains('"passed":true') -and $images.Count -eq 5); images=$images.Count; process=$process; diagnostics=@(Get-DevEngineErrors $lootRun $label)}
    }
    $report = @{passed=(@($results | Where-Object { -not $_.passed -or $_.diagnostics.Count -gt 0 }).Count -eq 0); results=$results; directory=$lootRun}
    Write-DevJson (Join-Path $lootRun 'report.json') $report
    $report | ConvertTo-Json -Depth 8
    if (-not $report.passed) { exit 1 }
} finally { $lootLock.Dispose() }
