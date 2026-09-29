#requires -Version 7.2
param([switch]$RuntimeOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force
$dossierRoot = Get-DevRoot
$dossierRun = New-DevRun 'player-dossier'
$dossierEngine = Resolve-DevGodot
$dossierLock = $null
# RuntimeOnly never imports or modifies the resource cache. It is useful when a
# separate validation owns the engine lock; all userdata and outputs stay isolated.
if (-not $RuntimeOnly) {
    $dossierLock = [IO.File]::Open((Join-Path $dossierRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
}
try {
    $results = @()
    foreach ($resolution in @('1280x720', '1600x900')) {
        foreach ($fixture in @(@{name='dossier'; count=12}, @{name='loot'; count=5})) {
            $label = $fixture.name + '-' + $resolution
            $captureRoot = Join-Path $dossierRun $label
            [IO.Directory]::CreateDirectory($captureRoot) | Out-Null
            $dossierEnvironment = @{APPDATA=(Join-Path $captureRoot 'appdata'); LOCALAPPDATA=(Join-Path $captureRoot 'localappdata')}
            foreach ($directory in $dossierEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
            $process = Invoke-DevProcess -Executable $dossierEngine -Directory $dossierRoot -LogRoot $dossierRun -Label $label -TimeoutSeconds 90 -Environment $dossierEnvironment -Arguments @('--path',$dossierRoot,'--rendering-method','gl_compatibility','--windowed','--resolution',$resolution,'--log-file',(Join-Path $dossierRun ($label + '.engine.log')),('res://tools/consumable_cards/' + $fixture.name + '_capture.tscn'),'--',('--output=' + $captureRoot.Replace('\','/')))
            $outputText = Get-Content -LiteralPath (Join-Path $dossierRun ($label + '.stdout.log')) -Raw
            $images = @(Get-ChildItem -LiteralPath $captureRoot -Filter '*.png')
            $diagnostics = @(Get-DevEngineErrors $dossierRun $label)
            $result = @{name=$label; passed=((Test-DevProcessSuccess $process) -and $outputText.Contains('"passed":true') -and $images.Count -eq $fixture.count -and $diagnostics.Count -eq 0); images=$images.Count; process=$process; diagnostics=$diagnostics}
            $results += $result
            Write-Output ($label + ': ' + $result.passed)
        }
    }
    $report = @{passed=(@($results | Where-Object { -not $_.passed }).Count -eq 0); runtimeOnly=[bool]$RuntimeOnly; results=$results; directory=$dossierRun}
    Write-DevJson (Join-Path $dossierRun 'report.json') $report
    $report | ConvertTo-Json -Depth 8
    if (-not $report.passed) { exit 1 }
} finally { if ($null -ne $dossierLock) { $dossierLock.Dispose() } }
