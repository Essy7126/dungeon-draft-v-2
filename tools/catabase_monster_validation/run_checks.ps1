[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GodotPath,
    [string[]]$TestPath = @('res://test/unit/test_catabase_monsters_integration.gd'),
    [string]$TestNameFilter = '',
    [int]$ExpectedTestCount = 9,
    [string]$SuiteId = 'catabase_monsters_integration',
    [string]$ImportEvidenceDirectory = '',
    [switch]$Runtime,
    [string]$Resolution = '1280x720'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$monsterRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$monsterArtifacts = Join-Path $monsterRoot ('artifacts/catabase_monsters/checks/' + $SuiteId)
[IO.Directory]::CreateDirectory($monsterArtifacts) | Out-Null
$monsterAppData = Join-Path $monsterArtifacts 'appdata'
[IO.Directory]::CreateDirectory($monsterAppData) | Out-Null

function Invoke-MonsterGodot {
    param([string[]]$Arguments, [string]$Label, [int]$TimeoutSeconds = 180)
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.WorkingDirectory = $monsterRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.Environment['APPDATA'] = $monsterAppData
    $startInfo.Environment['LOCALAPPDATA'] = $monsterAppData
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $result = [ordered]@{
        started = $false; start_error = $null; timed_out = $false
        killed = $false; exit_code = $null; termination_exit_code = $null
    }
    try {
        $result.started = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $result.timed_out = $true
            $result.killed = $true
            $process.Kill($true)
        }
        $process.WaitForExit()
        $result.termination_exit_code = $process.ExitCode
        if (-not $result.timed_out) { $result.exit_code = $process.ExitCode }
        [IO.File]::WriteAllText((Join-Path $monsterArtifacts ($Label + '.stdout.log')), $stdout.GetAwaiter().GetResult())
        [IO.File]::WriteAllText((Join-Path $monsterArtifacts ($Label + '.stderr.log')), $stderr.GetAwaiter().GetResult())
    } catch {
        $result.start_error = $_.Exception.Message
        if ($result.started -and -not $process.HasExited) { $process.Kill($true) }
    } finally { $process.Dispose() }
    return $result
}

$versionResult = Invoke-MonsterGodot -Arguments @('--version') -Label 'version' -TimeoutSeconds 15
$version = [IO.File]::ReadAllText((Join-Path $monsterArtifacts 'version.stdout.log')).Trim()
if ($versionResult.exit_code -ne 0 -or $version -ne '4.7.1.stable.official.a13da4feb') {
    throw "Godot version check failed: $version"
}

if ($Runtime) {
    $runtimeResult = Invoke-MonsterGodot -Arguments @(
        '--path', $monsterRoot, '--verbose', '--rendering-method', 'gl_compatibility',
        '--audio-driver', 'Dummy', '--position', '-3000,-3000', '--resolution', $Resolution,
        '--log-file', (Join-Path $monsterArtifacts 'runtime.engine.log'),
        'res://tools/catabase_monster_validation/combat_probe.tscn', '--', ('resolution=' + $Resolution)
    ) -Label 'runtime' -TimeoutSeconds 210
    $runtimeResult | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $monsterArtifacts 'runtime.process.json')
    $runtimeText = [IO.File]::ReadAllText((Join-Path $monsterArtifacts 'runtime.stdout.log')) +
        [IO.File]::ReadAllText((Join-Path $monsterArtifacts 'runtime.stderr.log'))
    $reportPath = Join-Path $monsterRoot ('artifacts/catabase_monsters/' + $Resolution + '/report.json')
    if ($runtimeResult.exit_code -ne 0 -or $runtimeText -match '(?m)^(SCRIPT ERROR:|ERROR:|WARNING: .*ObjectDB instances were leaked)' -or
        $runtimeText -notmatch 'CATABASE_MONSTER_RUNTIME=') {
        Write-Output ("Runtime FAIL: exit={0}; logs: {1}" -f $runtimeResult.exit_code, $monsterArtifacts)
        $runtimeText -split "`n" | Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:|WARNING:|Resource still in use:)' } | Select-Object -First 30 | Write-Output
        if (Test-Path -LiteralPath $reportPath) {
            $failedReport = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
            Write-Output ("Probe report: passed={0}; checks={1}; errors={2}" -f $failedReport.passed, $failedReport.checks, ($failedReport.errors -join '; '))
        }
        exit 1
    }
    if (-not (Test-Path -LiteralPath $reportPath)) { throw 'Runtime report is missing.' }
    $runtimeReport = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if (-not $runtimeReport.passed -or $runtimeReport.encounters.Count -ne 4) { exit 1 }
    Write-Output ("Runtime PASS: {0} checks, {1} captures, {2}" -f $runtimeReport.checks, $runtimeReport.captures.Count, $Resolution)
    exit 0
}

# Recovery mode skips editor plugin side effects. The normal strict Run mode
# recursively visits an unrelated protected meshy_output dependency directory.
# Its unchanged Analyze mode still evaluates these actual subprocess results.
$importFiles = @{
    stdout = 'import.stdout.log'; stderr = 'import.stderr.log'; engine = 'import.engine.log'
}
if ([string]::IsNullOrWhiteSpace($ImportEvidenceDirectory)) {
    $importResult = Invoke-MonsterGodot -Arguments @(
        '--headless', '--editor', '--recovery-mode', '--path', $monsterRoot,
        '--log-file', (Join-Path $monsterArtifacts 'import.engine.log'), '--import'
    ) -Label 'import'
} else {
    # Reuse only recorded real import evidence while iterating test-only edits.
    # Asset changes always require a fresh import (omit this option).
    $evidenceRoot = [IO.Path]::GetFullPath($ImportEvidenceDirectory)
    $evidence = Get-Content -LiteralPath (Join-Path $evidenceRoot 'strict-analysis-input.json') -Raw | ConvertFrom-Json
    if ($evidence.godot.version -ne $version -or $evidence.process.import.exit_code -ne 0) {
        throw 'Reusable import evidence is invalid or from a different Godot version.'
    }
    $importResult = $evidence.process.import
    foreach ($entry in @('stdout', 'stderr', 'engine')) {
        $importFiles[$entry] = Join-Path $evidenceRoot ('import.' + $entry + '.log')
        if (-not (Test-Path -LiteralPath $importFiles[$entry])) { throw 'Import evidence log is missing.' }
    }
}
$gutArguments = @(
    '--headless', '--path', $monsterRoot,
    '--log-file', (Join-Path $monsterArtifacts 'gut.engine.log'),
    '--script', 'res://addons/gut/gut_cmdln.gd', '--',
    '-gconfig=', '-gexit', '-gdisable_colors', '-gfailure_error_types', 'engine,gut,push_error',
    '-gjunit_xml_file', (Join-Path $monsterArtifacts 'gut.junit.xml')
)
foreach ($scriptPath in $TestPath) { $gutArguments += @('-gtest', $scriptPath) }
if (-not [string]::IsNullOrWhiteSpace($TestNameFilter)) { $gutArguments += @('-gunit_test_name', $TestNameFilter) }
$gutResult = Invoke-MonsterGodot -Arguments $gutArguments -Label 'gut'
$manifest = [ordered]@{
    schema_version = 1; suite_id = $SuiteId
    godot = @{ path = $GodotPath; version = $version }; gut_version = '9.7.1'
    selection = @{
        directory = 'res://test/unit'; prefix = 'test_'; suffix = '.gd'
        include_subdirectories = $false; scripts = $TestPath
    }
    expected = @{ minimum_tests = 1; test_count = $ExpectedTestCount; failures = @() }
    process = @{ import = $importResult; gut = $gutResult }
    files = @{
        import_stdout = $importFiles.stdout; import_stderr = $importFiles.stderr; import_engine = $importFiles.engine
        gut_stdout = 'gut.stdout.log'; gut_stderr = 'gut.stderr.log'; gut_engine = 'gut.engine.log'; junit = 'gut.junit.xml'
    }
}
$manifest['reused_import_evidence_directory'] = $ImportEvidenceDirectory
$manifest['test_name_filter'] = $TestNameFilter
$manifestPath = Join-Path $monsterArtifacts 'strict-analysis-input.json'
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath
& (Join-Path $monsterRoot 'tools/ci/run_gut_strict.ps1') -Mode Analyze -AnalysisFixturePath $manifestPath -ReportPath (Join-Path $monsterArtifacts 'gut-strict-report.json')
$monsterExit = $LASTEXITCODE
$monsterReport = Get-Content -LiteralPath (Join-Path $monsterArtifacts 'gut-strict-report.json') -Raw | ConvertFrom-Json
Write-Output ("Strict {0}: {1} tests, {2} assertions, {3} errors" -f
    $monsterReport.verdict, $monsterReport.counts.tests_executed,
    $monsterReport.counts.assertions_passed, $monsterReport.errors.Count)
exit $monsterExit
