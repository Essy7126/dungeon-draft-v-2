[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GodotPath,
    [string]$Resolution = '1280x720',
    [switch]$DataOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Resolution -notmatch '^\d{3,4}x\d{3,4}$') { throw 'Invalid resolution.' }
$evolutionRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$evolutionOutput = Join-Path $evolutionRoot ('artifacts/catabase_monsters/evolution/' + $Resolution)
[IO.Directory]::CreateDirectory($evolutionOutput) | Out-Null
$evolutionAppData = Join-Path $evolutionOutput 'appdata'
[IO.Directory]::CreateDirectory($evolutionAppData) | Out-Null
$evolutionStart = [Diagnostics.ProcessStartInfo]::new()
$evolutionStart.FileName = $GodotPath
$evolutionStart.WorkingDirectory = $evolutionRoot
$evolutionStart.UseShellExecute = $false
$evolutionStart.CreateNoWindow = $true
$evolutionStart.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$evolutionStart.RedirectStandardOutput = $true
$evolutionStart.RedirectStandardError = $true
$evolutionStart.Environment['APPDATA'] = $evolutionAppData
$evolutionStart.Environment['LOCALAPPDATA'] = $evolutionAppData
$evolutionArguments = @('--path', $evolutionRoot, '--audio-driver', 'Dummy', '--log-file', (Join-Path $evolutionOutput 'engine.log'))
if ($DataOnly) {
    $evolutionArguments += '--headless'
} else {
    $evolutionArguments += @('--rendering-method', 'gl_compatibility', '--position', '-3000,-3000', '--resolution', $Resolution)
}
$evolutionArguments += @('res://tests/expedition/CatabaseEncounterEvolutionProbe.tscn', '--', ('resolution=' + $Resolution))
$evolutionArguments += $(if ($DataOnly) { 'data_only' } else { 'capture=true' })
foreach ($argument in $evolutionArguments) { $evolutionStart.ArgumentList.Add($argument) }
$evolutionProcess = [Diagnostics.Process]::new()
$evolutionProcess.StartInfo = $evolutionStart
$evolutionExit = -1
try {
    if (-not $evolutionProcess.Start()) { throw 'Godot could not start.' }
    $evolutionStdout = $evolutionProcess.StandardOutput.ReadToEndAsync()
    $evolutionStderr = $evolutionProcess.StandardError.ReadToEndAsync()
    if (-not $evolutionProcess.WaitForExit(300000)) {
        $evolutionProcess.Kill($true)
        throw 'Encounter probe exceeded five minutes.'
    }
    $evolutionProcess.WaitForExit()
    $evolutionExit = $evolutionProcess.ExitCode
    [IO.File]::WriteAllText((Join-Path $evolutionOutput 'stdout.log'), $evolutionStdout.GetAwaiter().GetResult())
    [IO.File]::WriteAllText((Join-Path $evolutionOutput 'stderr.log'), $evolutionStderr.GetAwaiter().GetResult())
} finally {
    $evolutionProcess.Dispose()
}
$evolutionLog = [IO.File]::ReadAllText((Join-Path $evolutionOutput 'stdout.log')) + [IO.File]::ReadAllText((Join-Path $evolutionOutput 'stderr.log'))
$evolutionReportPath = Join-Path $evolutionOutput 'report.json'
if (-not (Test-Path -LiteralPath $evolutionReportPath)) { throw 'Encounter report missing.' }
$evolutionReport = Get-Content -LiteralPath $evolutionReportPath -Raw | ConvertFrom-Json
$evolutionClean = $evolutionLog -notmatch '(?m)^(SCRIPT ERROR:|ERROR:|WARNING: .*ObjectDB instances were leaked)'
$evolutionPassed = $evolutionExit -eq 0 -and $evolutionReport.passed -and $evolutionClean
if (-not $DataOnly) {
    $evolutionPassed = $evolutionPassed -and $evolutionReport.runtime_nodes.Count -eq 3 -and $evolutionReport.captures.Count -eq 5
}
Write-Output ("Evolution {0}: {1} checks, {2} failures, {3} runtime rooms, {4} captures; exit={5}" -f $(if ($evolutionPassed) {'PASS'} else {'FAIL'}), $evolutionReport.checks, $evolutionReport.errors.Count, $evolutionReport.runtime_nodes.Count, $evolutionReport.captures.Count, $evolutionExit)
if (-not $evolutionPassed) {
    $evolutionReport.errors | Write-Output
    $evolutionLog -split "`n" | Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:|WARNING:)' } | Select-Object -First 20 | Write-Output
    exit 1
}
