#requires -Version 7.2
param([switch]$RuntimeOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force
$readabilityRoot = Get-DevRoot
$readabilityRun = New-DevRun 'combat-readability'
$readabilityEngine = Resolve-DevGodot
$readabilityLock = $null
# RuntimeOnly never imports or modifies the resource cache. It is useful when a
# separate validation owns the engine lock; all userdata and outputs stay isolated.
if (-not $RuntimeOnly) {
    $readabilityLock = [IO.File]::Open((Join-Path $readabilityRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
}
try {
    $results = @()
    foreach ($resolution in @('1280x720', '1600x900')) {
        foreach ($fixture in @(@{name='readability'; count=12})) {
            $label = $fixture.name + '-' + $resolution
            $captureRoot = Join-Path $readabilityRun $label
            [IO.Directory]::CreateDirectory($captureRoot) | Out-Null
            $readabilityEnvironment = @{APPDATA=(Join-Path $captureRoot 'appdata'); LOCALAPPDATA=(Join-Path $captureRoot 'localappdata')}
            foreach ($directory in $readabilityEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
            $process = Invoke-DevProcess -Executable $readabilityEngine -Directory $readabilityRoot -LogRoot $readabilityRun -Label $label -TimeoutSeconds 90 -Environment $readabilityEnvironment -Arguments @('--path',$readabilityRoot,'--rendering-method','gl_compatibility','--windowed','--resolution',$resolution,'--log-file',(Join-Path $readabilityRun ($label + '.engine.log')),('res://tools/consumable_cards/' + $fixture.name + '_capture.tscn'),'--',('--output=' + $captureRoot.Replace('\','/')))
            $outputText = Get-Content -LiteralPath (Join-Path $readabilityRun ($label + '.stdout.log')) -Raw
            $images = @(Get-ChildItem -LiteralPath $captureRoot -Filter '*.png')
            $diagnostics = @(Get-DevEngineErrors $readabilityRun $label)
            $result = @{name=$label; passed=((Test-DevProcessSuccess $process) -and $outputText.Contains('"passed":true') -and $images.Count -eq $fixture.count -and $diagnostics.Count -eq 0); images=$images.Count; process=$process; diagnostics=$diagnostics}
            $results += $result
            Write-Output ($label + ': ' + $result.passed)
        }
    }
    $report = @{passed=(@($results | Where-Object { -not $_.passed }).Count -eq 0); runtimeOnly=[bool]$RuntimeOnly; results=$results; directory=$readabilityRun}
    Write-DevJson (Join-Path $readabilityRun 'report.json') $report
    $report | ConvertTo-Json -Depth 8
    if (-not $report.passed) { exit 1 }
} finally { if ($null -ne $readabilityLock) { $readabilityLock.Dispose() } }
