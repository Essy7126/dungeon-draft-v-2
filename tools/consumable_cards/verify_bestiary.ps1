#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force
$bestiaryRoot = Get-DevRoot
$bestiaryRun = New-DevRun 'cards-bestiary-visual'
$bestiaryEngine = Resolve-DevGodot
$bestiaryLock = [IO.File]::Open((Join-Path $bestiaryRoot 'artifacts/dev/engine.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $bestiaryEnvironment = @{APPDATA=(Join-Path $bestiaryRun 'appdata'); LOCALAPPDATA=(Join-Path $bestiaryRun 'localappdata')}
    foreach ($directory in $bestiaryEnvironment.Values) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $bestiaryArguments = @('--rendering-method','gl_compatibility','--windowed','--resolution','1280x720','--path',$bestiaryRoot,'--log-file',(Join-Path $bestiaryRun 'capture.engine.log'),'res://tools/consumable_cards/bestiary_capture.tscn','--',('--output=' + (Join-Path $bestiaryRun 'observations.json').Replace('\','/')))
    $process = Invoke-DevProcess -Executable $bestiaryEngine -Directory $bestiaryRoot -LogRoot $bestiaryRun -Label 'capture' -TimeoutSeconds 600 -Environment $bestiaryEnvironment -Arguments $bestiaryArguments
    $report = @{process=$process; diagnostics=@(Get-DevEngineErrors $bestiaryRun 'capture'); directory=$bestiaryRun; passed=$false}
    if ((Test-DevProcessSuccess $process) -and (Test-Path -LiteralPath (Join-Path $bestiaryRun 'observations.json')) -and $report.diagnostics.Count -eq 0) {
        $observations = Get-Content -LiteralPath (Join-Path $bestiaryRun 'observations.json') -Raw | ConvertFrom-Json
        $report.passed = $observations.completed -and $observations.encounters.Count -eq 4 -and @(Get-ChildItem -LiteralPath $bestiaryRun -Filter '*.png').Count -eq 8
    }
    Write-DevJson (Join-Path $bestiaryRun 'summary.json') $report
    $report | ConvertTo-Json -Depth 6
    if (-not $report.passed) { exit 1 }
} finally { $bestiaryLock.Dispose() }
