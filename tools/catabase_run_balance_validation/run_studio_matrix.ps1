#requires -Version 7.2
[CmdletBinding()]
param([string]$LabelPrefix = 'audit', [int]$TimeoutSeconds = 1800, [switch]$SkipPilot, [switch]$RemainingOnly)
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run_validation.ps1'
$cases = @(
    @{ Mode='pilot'; Seeds='7201,7202,7203'; Policy='balanced'; Difficulties='normal' },
    @{ Mode='adaptive'; Seeds='7201,7202,7203'; Policy='balanced'; Difficulties='normal,easy' },
    @{ Mode='liquidate'; Seeds='7201'; Policy='balanced'; Difficulties='normal' },
    @{ Mode='swarm'; Seeds='7201'; Policy='balanced'; Difficulties='normal' },
    @{ Mode='speed'; Seeds='7201,7202,7203'; Policy='pressure'; Difficulties='normal' }
)
foreach ($case in $cases) {
	if ($SkipPilot -and $case.Mode -eq 'pilot') { continue }
	if ($RemainingOnly -and $case.Mode -in @('pilot', 'adaptive')) { continue }
    & $runner -Cards -AuditMode $case.Mode -Label ($LabelPrefix + '_' + $case.Mode + '_20260916') -Seeds $case.Seeds -Policies $case.Policy -Difficulties $case.Difficulties -Weapons 'arc,disque,hampe,lame,marteau,xiphos' -TimeoutSeconds $TimeoutSeconds
    $summaryPath = Join-Path $PSScriptRoot ('../../artifacts/catabase_run_balance_validation/' + $LabelPrefix + '_' + $case.Mode + '_20260916/summary.json')
    if (-not (Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json).passed) { throw ('Audit matrix failed at ' + $case.Mode) }
}
