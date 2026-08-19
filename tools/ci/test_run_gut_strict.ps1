[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [switch]$RunLive,
    [string]$ExpectedGodotVersionPattern = '^4\.7\.1\.stable\.official\.a13da4feb$'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$RunnerPath = Join-Path $PSScriptRoot "run_gut_strict.ps1"
$SchemaPath = Join-Path $PSScriptRoot "gut_strict_report.schema.json"
$FixtureRoot = Join-Path $RepoRoot "test\fixtures\gut_strict"
$TempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$TempRoot = Join-Path $TempBase ("dungeon-draft-gut-strict-self-test-{0}" -f [Guid]::NewGuid().ToString("N"))
$Failures = New-Object System.Collections.Generic.List[string]

function Write-TestUtf8 {
    param(
        [string]$Path,
        [string]$Content
    )
    $parent = [IO.Path]::GetDirectoryName($Path)
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false)))
}

function Add-TestFailure {
    param([string]$Message)
    $Failures.Add($Message)
    Write-Output "SELF_TEST_FAIL $Message"
}

function Assert-TestEqual {
    param(
        [object]$Expected,
        [object]$Observed,
        [string]$Context
    )
    if ([string]$Expected -ne [string]$Observed) {
        Add-TestFailure ("{0}: attendu '{1}', observe '{2}'." -f $Context, $Expected, $Observed)
    }
}

function Assert-TestTrue {
    param(
        [bool]$Condition,
        [string]$Context
    )
    if (-not $Condition) {
        Add-TestFailure $Context
    }
}

function Get-PowerShellExecutable {
    $current = Get-Process -Id $PID
    if ($null -ne $current -and -not [string]::IsNullOrWhiteSpace($current.Path)) {
        return $current.Path
    }
    $windowsPowerShell = Join-Path $PSHOME "powershell.exe"
    if ([IO.File]::Exists($windowsPowerShell)) {
        return $windowsPowerShell
    }
    throw "Impossible de resoudre l'executable PowerShell courant."
}

function New-SummaryText {
    param(
        [int]$Tests,
        [int]$Passing,
        [int]$Failing,
        [int]$AssertionsPassed,
        [int]$AssertionsTotal
    )
    $passingText = if ($Passing -eq 0) { "none" } else { [string]$Passing }
    $assertText = if ($AssertionsPassed -eq $AssertionsTotal) {
        [string]$AssertionsTotal
    }
    else {
        "${AssertionsPassed}/${AssertionsTotal}"
    }
    $assertLabel = "Asserts".PadRight(18)
    $failingLine = if ($Failing -gt 0) { "Failing Tests         $Failing`n" } else { "" }
    $finalLine = if ($Failing -gt 0) { "---- $Failing failing tests ----" } else { "---- All tests passed! ----" }
    return @"
==============================================
= Run Summary
==============================================

Totals
------
Scripts               1
Tests                 $Tests
Passing Tests         $passingText
$failingLine$assertLabel$assertText
Time                  0.01s

$finalLine
"@
}

function New-JUnitText {
    param(
        [ValidateSet("pass", "fail", "zero")]
        [string]$Kind
    )
    if ($Kind -eq "zero") {
        return @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="GutTests" failures="0" tests="0">
  <testsuite name="test/unit/test_case.gd" tests="0" failures="0" skipped="0" time="0">
  </testsuite>
</testsuites>
'@
    }
    $failureCount = if ($Kind -eq "fail") { 1 } else { 0 }
    $status = if ($Kind -eq "fail") { "fail" } else { "pass" }
    $failureNode = if ($Kind -eq "fail") {
        '<failure message="failed"><![CDATA[Echec volontaire.]]></failure>'
    }
    else {
        ""
    }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="GutTests" failures="$failureCount" tests="1">
  <testsuite name="test/unit/test_case.gd" tests="1" failures="$failureCount" skipped="0" time="0.01">
    <testcase name="test_case" assertions="1" status="$status" classname="test/unit/test_case.gd" time="0.01">$failureNode</testcase>
  </testsuite>
</testsuites>
"@
}

function New-AnalysisFixture {
    param(
        [string]$Name,
        [ValidateSet(
            "pass",
            "fail",
            "parse",
            "zero",
            "timeout",
            "expected_failure",
            "missing_junit",
            "invalid_junit",
            "missing_summary",
            "suite_missing",
            "startup",
            "unexpected_error",
            "unexpected_log_error",
            "process_start",
            "import_timeout"
        )]
        [string]$Kind
    )
    $caseRoot = Join-Path $TempRoot ("synthetic-{0}" -f $Name)
    [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
    $gutStdout = Join-Path $caseRoot "gut.stdout.log"
    $junitPath = Join-Path $caseRoot "gut.junit.xml"
    $gutExit = 0
    $timedOut = $false
    $junitRelative = $null
    $expectedFailures = @()
    $exactTestCount = $null
    $importStarted = $true
    $importStartError = $null
    $importTimedOut = $false
    $importKilled = $false
    $importExit = 0
    $gutStarted = $true
    $gutStartError = $null
    switch ($Kind) {
        "pass" {
            Write-TestUtf8 $gutStdout (New-SummaryText -Tests 1 -Passing 1 -Failing 0 -AssertionsPassed 1 -AssertionsTotal 1)
            Write-TestUtf8 $junitPath (New-JUnitText "pass")
            $junitRelative = "gut.junit.xml"
            $exactTestCount = 1
        }
        "fail" {
            Write-TestUtf8 $gutStdout (New-SummaryText -Tests 1 -Passing 0 -Failing 1 -AssertionsPassed 0 -AssertionsTotal 1)
            Write-TestUtf8 $junitPath (New-JUnitText "fail")
            $junitRelative = "gut.junit.xml"
            $gutExit = 1
            $exactTestCount = 1
        }
        "parse" {
            Write-TestUtf8 $gutStdout "SCRIPT ERROR: Parse Error: Expected ':' after function declaration.`n"
        }
        "zero" {
            Write-TestUtf8 $gutStdout "ERROR: Nothing was run.`nOn the one hand nothing failed, on the other hand nothing did anything.`n"
            Write-TestUtf8 $junitPath (New-JUnitText "zero")
            $junitRelative = "gut.junit.xml"
        }
        "timeout" {
            Write-TestUtf8 $gutStdout "Running test_fixture_never_completes`n"
            $timedOut = $true
            $gutExit = $null
        }
        "expected_failure" {
            Write-TestUtf8 $gutStdout (New-SummaryText -Tests 1 -Passing 0 -Failing 1 -AssertionsPassed 0 -AssertionsTotal 1)
            Write-TestUtf8 $junitPath (New-JUnitText "fail")
            $junitRelative = "gut.junit.xml"
            $gutExit = 1
            $exactTestCount = 1
            $expectedFailures = @("test_case.gd::test_case")
        }
        "missing_junit" {
            Write-TestUtf8 $gutStdout (New-SummaryText -Tests 1 -Passing 1 -Failing 0 -AssertionsPassed 1 -AssertionsTotal 1)
            $exactTestCount = 1
        }
        "invalid_junit" {
            Write-TestUtf8 $gutStdout (New-SummaryText -Tests 1 -Passing 1 -Failing 0 -AssertionsPassed 1 -AssertionsTotal 1)
            Write-TestUtf8 $junitPath "<testsuites><invalid>"
            $junitRelative = "gut.junit.xml"
            $exactTestCount = 1
        }
        "missing_summary" {
            Write-TestUtf8 $gutStdout "A test ran, but no GUT summary was emitted.`n"
            Write-TestUtf8 $junitPath (New-JUnitText "pass")
            $junitRelative = "gut.junit.xml"
            $exactTestCount = 1
        }
        "suite_missing" {
            Write-TestUtf8 $gutStdout (New-SummaryText -Tests 1 -Passing 1 -Failing 0 -AssertionsPassed 1 -AssertionsTotal 1)
            Write-TestUtf8 $junitPath ((New-JUnitText "pass").Replace("test/unit/test_case.gd", "test/unit/test_other.gd"))
            $junitRelative = "gut.junit.xml"
            $exactTestCount = 1
        }
        "startup" {
            Write-TestUtf8 $gutStdout "ERROR: Some GUT class_names have not been imported. Please run godot --headless --import.`n"
        }
        "unexpected_error" {
            $summaryWithError = (New-SummaryText -Tests 1 -Passing 1 -Failing 0 -AssertionsPassed 1 -AssertionsTotal 1).Replace("Totals`n------", "Totals`n------`nErrors                1")
            Write-TestUtf8 $gutStdout $summaryWithError
            Write-TestUtf8 $junitPath (New-JUnitText "pass")
            $junitRelative = "gut.junit.xml"
            $exactTestCount = 1
        }
        "unexpected_log_error" {
            $summaryWithLogError = "ERROR: Synthetic unexpected engine error.`n" + (New-SummaryText -Tests 1 -Passing 1 -Failing 0 -AssertionsPassed 1 -AssertionsTotal 1)
            Write-TestUtf8 $gutStdout $summaryWithLogError
            Write-TestUtf8 $junitPath (New-JUnitText "pass")
            $junitRelative = "gut.junit.xml"
            $exactTestCount = 1
        }
        "process_start" {
            Write-TestUtf8 $gutStdout ""
            $importStarted = $false
            $importStartError = "Executable fixture introuvable."
            $importExit = $null
            $gutStarted = $false
            $gutExit = $null
        }
        "import_timeout" {
            Write-TestUtf8 $gutStdout ""
            $importTimedOut = $true
            $importKilled = $true
            $importExit = $null
            $gutStarted = $false
            $gutExit = $null
        }
    }

    $fixture = [ordered]@{
        schema_version = 1
        suite_id = "synthetic-$Name"
        godot = [ordered]@{ path = "fixture-godot"; version = "4.7.1.stable.official.fixture" }
        gut_version = "9.7.1"
        selection = [ordered]@{
            directory = "res://test/unit"
            prefix = "test_case"
            suffix = ".gd"
            include_subdirectories = $false
            scripts = @("res://test/unit/test_case.gd")
        }
        expected = [ordered]@{
            minimum_tests = 1
            test_count = $exactTestCount
            failures = $expectedFailures
        }
        process = [ordered]@{
            import = [ordered]@{
                started = $importStarted
                start_error = $importStartError
                timed_out = $importTimedOut
                killed = $importKilled
                exit_code = $importExit
                termination_exit_code = $(if ($importTimedOut) { -1 } else { $importExit })
            }
            gut = [ordered]@{
                started = $gutStarted
                start_error = $gutStartError
                timed_out = $timedOut
                killed = $timedOut
                exit_code = $gutExit
                termination_exit_code = $(if ($timedOut) { -1 } else { $gutExit })
            }
        }
        files = [ordered]@{
            import_stdout = $null
            import_stderr = $null
            import_engine = $null
            gut_stdout = "gut.stdout.log"
            gut_stderr = $null
            gut_engine = $null
            junit = $junitRelative
        }
    }
    $manifest = Join-Path $caseRoot "analysis-fixture.json"
    Write-TestUtf8 $manifest ($fixture | ConvertTo-Json -Depth 8)
    return $manifest
}

function Invoke-RunnerChild {
    param(
        [string[]]$Arguments,
        [string]$ExpectedClassification,
        [int]$ExpectedExit,
        [string]$ExpectedReportPath,
        [string]$Context
    )
    $powershell = Get-PowerShellExecutable
    $output = & $powershell -NoProfile -ExecutionPolicy Bypass -File $RunnerPath @Arguments 2>&1
    $observedExit = $LASTEXITCODE
    Assert-TestEqual $ExpectedExit $observedExit "$Context exit"
    if (-not [IO.File]::Exists($ExpectedReportPath)) {
        Add-TestFailure "$Context rapport absent: $ExpectedReportPath"
        if ($output) { Write-Output ($output -join "`n") }
        return
    }
    try {
        $report = [IO.File]::ReadAllText($ExpectedReportPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
        Assert-TestEqual $ExpectedClassification $report.primary_classification "$Context classification"
        Assert-TestTrue ([int]$report.schema_version -eq 1) "$Context schema_version incorrect"
        Assert-TestTrue (-not [string]::IsNullOrWhiteSpace([string]$report.artifacts.report)) "$Context chemin de rapport non publie"
        if ($observedExit -ne $ExpectedExit -or [string]$report.primary_classification -ne $ExpectedClassification) {
            Write-Output ("{0} report errors: {1}" -f $Context, (@($report.errors) | ConvertTo-Json -Depth 5 -Compress))
        }
    }
    catch {
        Add-TestFailure "$Context rapport JSON invalide: $($_.Exception.Message)"
    }
    if ($observedExit -ne $ExpectedExit -or -not [IO.File]::Exists($ExpectedReportPath)) {
        if ($output) { Write-Output ($output -join "`n") }
    }
}

function Test-SyntheticCases {
    $cases = @(
        [pscustomobject]@{ Name = "pass"; Kind = "pass"; Classification = "PASS"; Exit = 0 },
        [pscustomobject]@{ Name = "failure"; Kind = "fail"; Classification = "TEST_FAILURE"; Exit = 10 },
        [pscustomobject]@{ Name = "parse"; Kind = "parse"; Classification = "PARSE_ERROR"; Exit = 11 },
        [pscustomobject]@{ Name = "zero"; Kind = "zero"; Classification = "ZERO_TESTS"; Exit = 12 },
        [pscustomobject]@{ Name = "timeout"; Kind = "timeout"; Classification = "GUT_TIMEOUT"; Exit = 124 },
        [pscustomobject]@{ Name = "expected-failure"; Kind = "expected_failure"; Classification = "PASS_WITH_EXPECTED_FAILURES"; Exit = 0 },
        [pscustomobject]@{ Name = "missing-junit"; Kind = "missing_junit"; Classification = "JUNIT_MISSING"; Exit = 15 },
        [pscustomobject]@{ Name = "invalid-junit"; Kind = "invalid_junit"; Classification = "JUNIT_INVALID"; Exit = 15 },
        [pscustomobject]@{ Name = "missing-summary"; Kind = "missing_summary"; Classification = "SUMMARY_MISSING"; Exit = 14 },
        [pscustomobject]@{ Name = "suite-missing"; Kind = "suite_missing"; Classification = "SUITE_MISSING"; Exit = 13 },
        [pscustomobject]@{ Name = "startup"; Kind = "startup"; Classification = "GUT_STARTUP_ERROR"; Exit = 16 },
        [pscustomobject]@{ Name = "unexpected-error"; Kind = "unexpected_error"; Classification = "UNEXPECTED_ENGINE_ERROR"; Exit = 16 },
        [pscustomobject]@{ Name = "unexpected-log-error"; Kind = "unexpected_log_error"; Classification = "UNEXPECTED_ENGINE_ERROR"; Exit = 16 },
        [pscustomobject]@{ Name = "process-start"; Kind = "process_start"; Classification = "PROCESS_START_ERROR"; Exit = 2 },
        [pscustomobject]@{ Name = "import-timeout"; Kind = "import_timeout"; Classification = "IMPORT_TIMEOUT"; Exit = 124 }
    )
    foreach ($case in $cases) {
        $manifest = New-AnalysisFixture -Name $case.Name -Kind $case.Kind
        $caseRoot = [IO.Path]::GetDirectoryName($manifest)
        $outputDirectory = Join-Path $caseRoot "output"
        $reportPath = Join-Path $outputDirectory "gut-strict-report.json"
        Invoke-RunnerChild -Arguments @(
            "-Mode", "Analyze",
            "-AnalysisFixturePath", $manifest,
            "-ArtifactsDirectory", $outputDirectory,
            "-ReportPath", $reportPath
        ) -ExpectedClassification $case.Classification -ExpectedExit $case.Exit -ExpectedReportPath $reportPath -Context ("synthetic {0}" -f $case.Name)
    }
}

function Test-ConfigurationFailureWritesReport {
    $caseRoot = Join-Path $TempRoot "synthetic-config-error"
    $outputDirectory = Join-Path $caseRoot "output"
    $reportPath = Join-Path $outputDirectory "gut-strict-report.json"
    $missingProject = Join-Path $caseRoot "missing-project"
    Invoke-RunnerChild -Arguments @(
        "-Mode", "Run",
        "-ProjectPath", $missingProject,
        "-ArtifactsDirectory", $outputDirectory,
        "-ReportPath", $reportPath
    ) -ExpectedClassification "CONFIG_ERROR" -ExpectedExit 2 -ExpectedReportPath $reportPath -Context "synthetic config-error"
}

function Test-ProductionDiscoveryIgnoresGeneratedEphemeralTrees {
    $caseRoot = Join-Path $TempRoot "synthetic-production-discovery"
    $projectRoot = Join-Path $caseRoot "project"
    Write-TestUtf8 (Join-Path $projectRoot "src\production.gd") "extends RefCounted`n"
    Write-TestUtf8 (Join-Path $projectRoot "test\unit\test_not_production.gd") "extends RefCounted`n"
    Write-TestUtf8 (Join-Path $projectRoot "addons\gut\generated.gd") "extends RefCounted`n"
    foreach ($generatedName in @(
        ".git", ".godot", "output", "artifacts", "artefacts",
        "recovery", "cache", "shader_cache"
    )) {
        $generatedScriptPath = Join-Path $projectRoot (
            "{0}\volatile\generated.gd" -f $generatedName
        )
        Write-TestUtf8 -Path $generatedScriptPath -Content "extends RefCounted`n"
    }

    $manifest = New-AnalysisFixture -Name "production-discovery" -Kind "pass"
    $fixture = [IO.File]::ReadAllText($manifest, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $fixture | Add-Member -NotePropertyName "production_discovery_root" -NotePropertyValue $projectRoot
    Write-TestUtf8 $manifest ($fixture | ConvertTo-Json -Depth 8)

    # Reproduce the original race: a generated output subtree disappears while
    # the child runner is discovering production scripts. Because output is an
    # explicit boundary, this can never invalidate an otherwise successful run.
    $ephemeralOutput = Join-Path $projectRoot "output"
    $powershell = Get-PowerShellExecutable
    $escapedOutput = $ephemeralOutput.Replace("'", "''")
    $deleteScript = "Start-Sleep -Milliseconds 10; if ([IO.Directory]::Exists('$escapedOutput')) { [IO.Directory]::Delete('$escapedOutput', `$true) }"
    $encodedDeleteScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($deleteScript))
    $deleterArguments = @{
        FilePath = $powershell
        ArgumentList = @("-NoProfile", "-EncodedCommand", $encodedDeleteScript)
        WindowStyle = "Hidden"
        PassThru = $true
    }
    $deleter = Start-Process @deleterArguments

    $outputDirectory = Join-Path $caseRoot "output"
    $reportPath = Join-Path $outputDirectory "gut-strict-report.json"
    Invoke-RunnerChild -Arguments @(
        "-Mode", "Analyze",
        "-AnalysisFixturePath", $manifest,
        "-ArtifactsDirectory", $outputDirectory,
        "-ReportPath", $reportPath
    ) -ExpectedClassification "PASS" -ExpectedExit 0 -ExpectedReportPath $reportPath -Context "synthetic production discovery"

    if (-not $deleter.WaitForExit(5000)) {
        $deleter.Kill()
        Add-TestFailure "synthetic production discovery: suppression ephemere timeout"
    }
    if ([IO.File]::Exists($reportPath)) {
        $report = [IO.File]::ReadAllText($reportPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
        Assert-TestEqual 1 $report.counts.production_scripts_compile_checked "synthetic production discovery production count"
    }
    Assert-TestTrue (-not [IO.Directory]::Exists($ephemeralOutput)) "synthetic production discovery: output ephemere non supprime"
}

function Test-SchemaContract {
    if (-not [IO.File]::Exists($SchemaPath)) {
        Add-TestFailure "Schema absent: $SchemaPath"
        return
    }
    try {
        $schema = [IO.File]::ReadAllText($SchemaPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
        Assert-TestEqual "object" $schema.type "schema type"
        $required = @($schema.required)
        foreach ($key in @("verdict", "primary_classification", "selection", "counts", "process", "summary", "junit", "errors", "artifacts")) {
            Assert-TestTrue ($required -contains $key) "schema required doit contenir '$key'"
        }
        $classifications = @($schema.'$defs'.classification.enum)
        foreach ($classification in @("PASS", "PARSE_ERROR", "ZERO_TESTS", "GUT_TIMEOUT", "TEST_FAILURE")) {
            Assert-TestTrue ($classifications -contains $classification) "classification schema absente: $classification"
        }
    }
    catch {
        Add-TestFailure "Schema JSON invalide: $($_.Exception.Message)"
    }
}

function New-LiveFixtureProject {
    param(
        [string]$Name,
        [string]$TemplateName
    )
    $projectRoot = Join-Path $TempRoot ("live-{0}" -f $Name)
    [IO.Directory]::CreateDirectory($projectRoot) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $projectRoot "addons")) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $projectRoot "test\unit")) | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot "addons\gut") -Destination (Join-Path $projectRoot "addons\gut") -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $FixtureRoot "project.godot.txt") -Destination (Join-Path $projectRoot "project.godot") -Force
    Copy-Item -LiteralPath (Join-Path $FixtureRoot $TemplateName) -Destination (Join-Path $projectRoot "test\unit\test_case.gd") -Force
    return $projectRoot
}

function Test-LiveCases {
    if ([string]::IsNullOrWhiteSpace($GodotPath)) {
        throw "-GodotPath est obligatoire avec -RunLive."
    }
    $resolvedGodot = [IO.Path]::GetFullPath($GodotPath)
    if (-not [IO.File]::Exists($resolvedGodot)) {
        throw "Godot absent: $resolvedGodot"
    }
    $cases = @(
        [pscustomobject]@{ Name = "pass"; Template = "test_pass.gd.txt"; Classification = "PASS"; Exit = 0; Timeout = 60; Exact = 1 },
        [pscustomobject]@{ Name = "failure"; Template = "test_failure.gd.txt"; Classification = "TEST_FAILURE"; Exit = 10; Timeout = 60; Exact = 1 },
        [pscustomobject]@{ Name = "parse"; Template = "test_parse_error.gd.txt"; Classification = "PARSE_ERROR"; Exit = 11; Timeout = 60; Exact = $null },
        [pscustomobject]@{ Name = "zero"; Template = "test_zero_tests.gd.txt"; Classification = "ZERO_TESTS"; Exit = 12; Timeout = 60; Exact = $null },
        [pscustomobject]@{ Name = "timeout"; Template = "test_timeout.gd.txt"; Classification = "GUT_TIMEOUT"; Exit = 124; Timeout = 2; Exact = 1 }
    )
    foreach ($case in $cases) {
        $projectRoot = New-LiveFixtureProject -Name $case.Name -TemplateName $case.Template
        $outputDirectory = Join-Path $projectRoot "artifacts\gut-strict"
        $reportPath = Join-Path $outputDirectory "gut-strict-report.json"
        $arguments = @(
            "-Mode", "Run",
            "-GodotPath", $resolvedGodot,
            "-ProjectPath", $projectRoot,
            "-SuiteId", ("live-{0}" -f $case.Name),
            "-TestPath", "res://test/unit/test_case.gd",
            "-ImportTimeoutSeconds", "120",
            "-TestTimeoutSeconds", [string]$case.Timeout,
            "-ExpectedGodotVersionPattern", $ExpectedGodotVersionPattern,
            "-ArtifactsDirectory", $outputDirectory,
            "-ReportPath", $reportPath
        )
        if ($null -ne $case.Exact) {
            $arguments += @("-ExpectedTestCount", [string]$case.Exact)
        }
        Invoke-RunnerChild -Arguments $arguments -ExpectedClassification $case.Classification -ExpectedExit $case.Exit -ExpectedReportPath $reportPath -Context ("live {0}" -f $case.Name)
    }
}

function Remove-VerifiedTempRoot {
    if (-not [IO.Directory]::Exists($TempRoot)) {
        return
    }
    $resolved = [IO.Path]::GetFullPath($TempRoot)
    $requiredPrefix = $TempBase + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase) -or
        -not ([IO.Path]::GetFileName($resolved)).StartsWith("dungeon-draft-gut-strict-self-test-", [StringComparison]::Ordinal)) {
        throw "Refus de supprimer un chemin temporaire non verifie: $resolved"
    }
    [IO.Directory]::Delete($resolved, $true)
}

try {
    foreach ($requiredPath in @($RunnerPath, $SchemaPath, $FixtureRoot)) {
        Assert-TestTrue ([IO.File]::Exists($requiredPath) -or [IO.Directory]::Exists($requiredPath)) "Prerequis absent: $requiredPath"
    }
    [IO.Directory]::CreateDirectory($TempRoot) | Out-Null
    Test-SchemaContract
    Test-SyntheticCases
    Test-ConfigurationFailureWritesReport
    Test-ProductionDiscoveryIgnoresGeneratedEphemeralTrees
    if ($RunLive) {
        Test-LiveCases
    }
}
catch {
    Add-TestFailure ("Exception self-test: {0}" -f $_.Exception.Message)
}
finally {
    try {
        Remove-VerifiedTempRoot
    }
    catch {
        Add-TestFailure ("Nettoyage temporaire: {0}" -f $_.Exception.Message)
    }
}

if ($Failures.Count -gt 0) {
    Write-Output ("GUT_STRICT_SELF_TEST_FAIL failures={0}" -f $Failures.Count)
    exit 1
}

$modeLabel = if ($RunLive) { "synthetic+live" } else { "synthetic" }
Write-Output ("GUT_STRICT_SELF_TEST_PASS mode={0} cases={1}" -f $modeLabel, $(if ($RunLive) { 22 } else { 17 }))
exit 0
