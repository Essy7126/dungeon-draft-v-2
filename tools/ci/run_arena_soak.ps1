[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$ReportPath = "",

    [ValidateRange(1, 100)]
    [int]$Strokes = 100,

    [ValidateRange(1, 100)]
    [int]$Transforms = 100,

    [ValidateRange(1, 20)]
    [int]$Decorations = 20,

    [ValidateRange(1, 20)]
    [int]$Previews = 20,

    [ValidateRange(1, 20)]
    [int]$TesterProbes = 20,

    [ValidateRange(1, 20)]
    [int]$Rooms = 20,

    [ValidateRange(1, 10)]
    [int]$ProductionUpdates = 10,

    [ValidateRange(30, 3600)]
    [int]$TimeoutSeconds = 900,

    [ValidateRange(100, 5000)]
    [int]$SettleMilliseconds = 2000,

    [switch]$KeepArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ExitCode = 2
$script:ReportWritten = $false
$script:TemporaryRoot = ""
$script:ResolvedReportPath = ""


function Write-ArenaSoakJson {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value
    )
    $target = $script:ResolvedReportPath
    if ([string]::IsNullOrWhiteSpace($target)) {
        $target = Join-Path ([IO.Path]::GetTempPath()) (
            "arena-reliability-soak-fallback-{0}.json" -f [Guid]::NewGuid().ToString("N")
        )
        $script:ResolvedReportPath = $target
    }
    $absolute = [IO.Path]::GetFullPath($target)
    $directory = Split-Path -Parent $absolute
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $json = $Value | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($absolute, $json, [Text.UTF8Encoding]::new($false))
    $script:ReportWritten = $true
}


function Get-ContinuousGrowth {
    param(
        [object[]]$Values,
        [double]$Tolerance,
        [int]$Window = 10
    )
    if ($null -eq $Values -or $Values.Count -lt $Window) {
        return $false
    }
    $start = $Values.Count - $Window
    for ($index = $start + 1; $index -lt $Values.Count; $index++) {
        $step = [double]$Values[$index] - [double]$Values[$index - 1]
        if ($step -le $Tolerance) {
            return $false
        }
    }
    return $true
}


function Get-SeriesSummary {
    param(
        [object[]]$Values,
        [double]$GrowthTolerance
    )
    if ($null -eq $Values -or $Values.Count -eq 0) {
        return [ordered]@{
            sample_count = 0
            baseline = $null
            peak = $null
            final = $null
            delta = $null
            tail_span = $null
            continuous_tail_growth = $false
        }
    }
    $tailCount = [Math]::Min(10, $Values.Count)
    $tail = @($Values[($Values.Count - $tailCount)..($Values.Count - 1)])
    $tailMinimum = ($tail | Measure-Object -Minimum).Minimum
    $tailMaximum = ($tail | Measure-Object -Maximum).Maximum
    return [ordered]@{
        sample_count = $Values.Count
        baseline = $Values[0]
        peak = ($Values | Measure-Object -Maximum).Maximum
        final = $Values[$Values.Count - 1]
        delta = [double]$Values[$Values.Count - 1] - [double]$Values[0]
        tail_span = [double]$tailMaximum - [double]$tailMinimum
        continuous_tail_growth = Get-ContinuousGrowth `
            -Values $Values `
            -Tolerance $GrowthTolerance `
            -Window 10
    }
}


function Get-ProcessMemoryReport {
    param([object[]]$Samples)
    $working = @($Samples | ForEach-Object { [long]$_.working_set_bytes })
    $private = @($Samples | ForEach-Object { [long]$_.private_memory_bytes })
    $handles = @($Samples | ForEach-Object { [int]$_.handle_count })
    return [ordered]@{
        sample_interval_ms = 200
        samples = $Samples
        working_set = Get-SeriesSummary -Values $working -GrowthTolerance 65536
        private_memory = Get-SeriesSummary -Values $private -GrowthTolerance 65536
        handles = Get-SeriesSummary -Values $handles -GrowthTolerance 0
    }
}


function Convert-LogDiagnostic {
    param(
        [string]$Text,
        [int]$LineNumber,
        [string]$Phase
    )
    $severity = "INFO"
    if ($Text -match "^\s*ERROR:") {
        $severity = "ERROR"
    }
    elseif ($Text -match "^\s*WARNING:") {
        $severity = "WARNING"
    }
    return [ordered]@{
        phase = $Phase
        line = $LineNumber
        severity = $severity
        text = $Text
    }
}


function Get-EngineLogReport {
    param(
        [string[]]$Lines,
        [string]$Marker
    )
    $markerIndex = -1
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index] -like "*$Marker*") {
            $markerIndex = $index
            break
        }
    }
    $runtime = @()
    $historical = @()
    $otherShutdown = @()
    $historicalPattern = (
        "RID allocations.*leaked|ObjectDB instances leaked|" +
        "resources still in use|StringName allocations.*lost"
    )
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = [string]$Lines[$index]
        if ($line -notmatch "^\s*(ERROR|WARNING):") {
            continue
        }
        if ($markerIndex -lt 0 -or $index -lt $markerIndex) {
            if ($line -match "^\s*ERROR:") {
                $runtime += Convert-LogDiagnostic `
                    -Text $line -LineNumber ($index + 1) -Phase "arena_in_process"
            }
            continue
        }
        $diagnostic = Convert-LogDiagnostic `
            -Text $line -LineNumber ($index + 1) -Phase "engine_shutdown"
        if ($line -match $historicalPattern) {
            $historical += $diagnostic
        }
        else {
            $otherShutdown += $diagnostic
        }
    }
    $markerLine = $null
    if ($markerIndex -ge 0) {
        $markerLine = $markerIndex + 1
    }
    $shutdownStatus = "CLEAN"
    if ($historical.Count -gt 0) {
        $shutdownStatus = "HISTORICAL_ERRORS_PRESENT"
    }
    return [ordered]@{
        marker_found = $markerIndex -ge 0
        marker_line = $markerLine
        arena_execution_errors = $runtime
        shutdown_historical_errors = [ordered]@{
            status = $shutdownStatus
            gate_affects_arena = $false
            count = $historical.Count
            diagnostics = $historical
            other_shutdown_diagnostics = $otherShutdown
        }
    }
}


try {
    if ([string]::IsNullOrWhiteSpace($ReportPath)) {
        $ReportPath = Join-Path ([IO.Path]::GetTempPath()) (
            "arena-reliability-soak-{0}.json" -f [Guid]::NewGuid().ToString("N")
        )
    }
    $script:ResolvedReportPath = [IO.Path]::GetFullPath($ReportPath)
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw "Godot executable introuvable: $GodotPath"
    }
    $projectRoot = [IO.Path]::GetFullPath((Get-Location).Path)
    $projectFile = Join-Path $projectRoot "project.godot"
    if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
        throw "project.godot introuvable dans $projectRoot"
    }
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $script:TemporaryRoot = Join-Path $tempBase (
        "dungeon-draft-arena-soak-{0}" -f [Guid]::NewGuid().ToString("N")
    )
    $resolvedTemporaryRoot = [IO.Path]::GetFullPath($script:TemporaryRoot)
    if (-not $resolvedTemporaryRoot.StartsWith(
            $tempBase + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Racine temporaire non sure: $resolvedTemporaryRoot"
    }
    [IO.Directory]::CreateDirectory($resolvedTemporaryRoot) | Out-Null
    $internalReportPath = Join-Path $resolvedTemporaryRoot "internal-report.json"
    $engineLogPath = Join-Path $resolvedTemporaryRoot "engine.log"
    $stdoutPath = Join-Path $resolvedTemporaryRoot "stdout.log"
    $stderrPath = Join-Path $resolvedTemporaryRoot "stderr.log"
    $arguments = @(
        "--headless",
        "--path", $projectRoot,
        "--log-file", $engineLogPath,
        "res://tools/labs/arena_authoring/arena_reliability_soak_runner.tscn",
        "--",
        "--soak-report=$internalReportPath",
        "--soak-strokes=$Strokes",
        "--soak-transforms=$Transforms",
        "--soak-decorations=$Decorations",
        "--soak-previews=$Previews",
        "--soak-tester-probes=$TesterProbes",
        "--soak-rooms=$Rooms",
        "--soak-production-updates=$ProductionUpdates",
        "--soak-settle-ms=$SettleMilliseconds"
    )
    $process = Start-Process `
        -FilePath $GodotPath `
        -ArgumentList $arguments `
        -WorkingDirectory $projectRoot `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -PassThru
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $samples = New-Object System.Collections.Generic.List[object]
    $timedOut = $false
    while (-not $process.HasExited) {
        $process.Refresh()
        try {
            $samples.Add([ordered]@{
                elapsed_ms = [Math]::Round($watch.Elapsed.TotalMilliseconds, 3)
                working_set_bytes = [long]$process.WorkingSet64
                private_memory_bytes = [long]$process.PrivateMemorySize64
                handle_count = [int]$process.HandleCount
            })
        }
        catch {
            # Le processus peut sortir entre HasExited et Refresh. Ce trou
            # d'echantillonnage n'est pas transforme en fuite Arena.
        }
        if ($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            & "$env:SystemRoot\System32\taskkill.exe" `
                /PID $process.Id /T /F | Out-Null
            break
        }
        Start-Sleep -Milliseconds 200
    }
    $process.WaitForExit()
    $process.Refresh()
    $watch.Stop()
    $processExitCode = $process.ExitCode
    $memoryReport = Get-ProcessMemoryReport -Samples $samples.ToArray()

    # Le runner doit nettoyer lui-meme son namespace res:// de fixture. Le
    # wrapper constate d'abord tout residu (qui reste un echec du soak), puis
    # tente une recuperation strictement bornee afin qu'un timeout ne salisse
    # pas le worktree pour les executions suivantes.
    $integrationFixtureParent = [IO.Path]::GetFullPath((Join-Path `
        $projectRoot "artifacts\studio_2_0"
    ))
    $integrationFixtureRoot = [IO.Path]::GetFullPath((Join-Path `
        $integrationFixtureParent "arena_reliability_soak"
    ))
    $integrationFixtureResidue = Test-Path `
        -LiteralPath $integrationFixtureRoot -PathType Container
    $integrationFixtureRecovered = -not $integrationFixtureResidue
    if ($integrationFixtureResidue) {
        $fixtureIsExactChild = (
            [IO.Path]::GetDirectoryName($integrationFixtureRoot) -eq
            $integrationFixtureParent
        )
        if ($fixtureIsExactChild -and
                [IO.Path]::GetFileName($integrationFixtureRoot) -eq
                "arena_reliability_soak") {
            try {
                Remove-Item -LiteralPath $integrationFixtureRoot -Recurse -Force
                $integrationFixtureRecovered = -not (Test-Path `
                    -LiteralPath $integrationFixtureRoot
                )
            }
            catch {
                $integrationFixtureRecovered = $false
            }
        }
    }
    $internal = $null
    $internalParseError = ""
    if (Test-Path -LiteralPath $internalReportPath -PathType Leaf) {
        try {
            $internal = Get-Content -Raw -LiteralPath $internalReportPath |
                ConvertFrom-Json
        }
        catch {
            $internalParseError = $_.Exception.Message
        }
    }
    else {
        $internalParseError = "internal_report_missing"
    }
    $logLines = @()
    if (Test-Path -LiteralPath $engineLogPath -PathType Leaf) {
        $logLines = @(Get-Content -LiteralPath $engineLogPath)
    }
    $logReport = Get-EngineLogReport `
        -Lines $logLines `
        -Marker "ARENA_SOAK_IN_PROCESS_COMPLETE"
    $processGrowth = @()
    foreach ($metric in @("working_set", "private_memory", "handles")) {
        if ([bool]$memoryReport[$metric].continuous_tail_growth) {
            $processGrowth += [ordered]@{
                classification = "CONTINUOUS_PROCESS_GROWTH"
                metric = $metric
                summary = $memoryReport[$metric]
            }
        }
    }
    $wrapperErrors = @()
    if ($timedOut) {
        $wrapperErrors += [ordered]@{
            classification = "SOAK_TIMEOUT"
            timeout_seconds = $TimeoutSeconds
        }
    }
    if ($null -eq $internal) {
        $wrapperErrors += [ordered]@{
            classification = "INTERNAL_REPORT_INVALID"
            error = $internalParseError
        }
    }
    if (-not [bool]$logReport.marker_found) {
        $wrapperErrors += [ordered]@{
            classification = "COMPLETION_MARKER_MISSING"
        }
    }
    foreach ($errorValue in $logReport.arena_execution_errors) {
        $wrapperErrors += [ordered]@{
            classification = "ARENA_IN_PROCESS_ENGINE_ERROR"
            diagnostic = $errorValue
        }
    }
    $wrapperErrors += $processGrowth
    if ($integrationFixtureResidue) {
        $wrapperErrors += [ordered]@{
            classification = "INTEGRATION_FIXTURE_RESIDUE"
            path = $integrationFixtureRoot
            recovered = $integrationFixtureRecovered
        }
    }
    $shutdownGateErrors = @()
    foreach ($diagnostic in $logReport.shutdown_historical_errors.other_shutdown_diagnostics) {
        if ([string]$diagnostic.severity -eq "ERROR") {
            $shutdownGateErrors += [ordered]@{
                classification = "UNEXPECTED_SHUTDOWN_ERROR"
                diagnostic = $diagnostic
            }
        }
    }
    $internalOk = $false
    $arenaDelta = @{}
    if ($null -ne $internal) {
        $internalOk = [bool]$internal.ok
        $arenaDelta = $internal.arena_in_process_delta
    }
    $arenaOk = $internalOk -and $wrapperErrors.Count -eq 0
    if ($arenaOk -and $processExitCode -ne 0) {
        $arenaOk = $false
        $wrapperErrors += [ordered]@{
            classification = "UNEXPECTED_PROCESS_EXIT"
            exit_code = $processExitCode
        }
    }
    $overallOk = $arenaOk -and $shutdownGateErrors.Count -eq 0
    $verdict = "FAIL"
    if ($overallOk) {
        $verdict = $(if (
            [int]$logReport.shutdown_historical_errors.count -gt 0
        ) {
            "PASS_WITH_HISTORICAL_SHUTDOWN_ERRORS"
        } else {
            "PASS"
        })
    }
    $combined = [ordered]@{
        schema_version = 1
        suite = "ARENA_RELIABILITY_SOAK_WINDOWS_V1"
        ok = $overallOk
        verdict = $verdict
        arena_verdict = $(if ($arenaOk) { "PASS" } else { "FAIL" })
        report_path = $script:ResolvedReportPath
        configuration = [ordered]@{
            default_counts_exact = (
                $Strokes -eq 100 -and
                $Transforms -eq 100 -and
                $Decorations -eq 20 -and
                $Previews -eq 20 -and
                $TesterProbes -eq 20 -and
                $Rooms -eq 20 -and
                $ProductionUpdates -eq 10
            )
            strokes = $Strokes
            transforms = $Transforms
            decorations = $Decorations
            previews = $Previews
            tester_probes = $TesterProbes
            rooms = $Rooms
            production_updates = $ProductionUpdates
            timeout_seconds = $TimeoutSeconds
            settle_milliseconds = $SettleMilliseconds
        }
        process = [ordered]@{
            pid = $process.Id
            exit_code = $processExitCode
            timed_out = $timedOut
            duration_ms = [Math]::Round($watch.Elapsed.TotalMilliseconds, 3)
        }
        arena_in_process_delta = $arenaDelta
        arena_in_process_report = $internal
        process_memory = $memoryReport
        fixture_recovery = [ordered]@{
            integration_residue_detected = $integrationFixtureResidue
            integration_residue_recovered = $integrationFixtureRecovered
            integration_fixture_path = $integrationFixtureRoot
        }
        arena_execution_errors = $wrapperErrors
        shutdown_historical_errors = $logReport.shutdown_historical_errors
        shutdown_gate_errors = $shutdownGateErrors
        separation_contract = [ordered]@{
            completion_marker_found = [bool]$logReport.marker_found
            shutdown_errors_affect_arena_verdict = $false
            arena_delta_contains_shutdown_errors = $false
        }
        artifacts = [ordered]@{
            kept = [bool]$KeepArtifacts
            temporary_root = $(if ($KeepArtifacts) { $resolvedTemporaryRoot } else { "" })
        }
    }
    Write-ArenaSoakJson -Value $combined
    Write-Output ("ARENA_SOAK_REPORT={0}" -f $script:ResolvedReportPath)
    Write-Output ("ARENA_SOAK_VERDICT={0}" -f $combined.verdict)
    Write-Output ("ARENA_SOAK_SHUTDOWN_STATUS={0}" -f (
        $combined.shutdown_historical_errors.status
    ))
    $script:ExitCode = $(if ($timedOut) { 124 } elseif ($overallOk) { 0 } else { 10 })
}
catch {
    $failure = [ordered]@{
        schema_version = 1
        suite = "ARENA_RELIABILITY_SOAK_WINDOWS_V1"
        ok = $false
        verdict = "CONFIG_ERROR"
        report_path = $script:ResolvedReportPath
        arena_in_process_delta = @{}
        arena_execution_errors = @([ordered]@{
            classification = "WRAPPER_ERROR"
            message = $_.Exception.Message
        })
        shutdown_historical_errors = [ordered]@{
            status = "NOT_CLASSIFIED"
            gate_affects_arena = $false
            count = 0
            diagnostics = @()
            other_shutdown_diagnostics = @()
        }
        separation_contract = [ordered]@{
            shutdown_errors_affect_arena_verdict = $false
            arena_delta_contains_shutdown_errors = $false
        }
    }
    try {
        Write-ArenaSoakJson -Value $failure
    }
    catch {
        Write-Error $_.Exception.Message
    }
    $script:ExitCode = 2
}
finally {
    if (-not $script:ReportWritten) {
        try {
            Write-ArenaSoakJson -Value ([ordered]@{
                schema_version = 1
                suite = "ARENA_RELIABILITY_SOAK_WINDOWS_V1"
                ok = $false
                verdict = "CONFIG_ERROR"
                arena_in_process_delta = @{}
                arena_execution_errors = @([ordered]@{
                    classification = "REPORT_NOT_WRITTEN"
                })
                shutdown_historical_errors = [ordered]@{
                    status = "NOT_CLASSIFIED"
                    gate_affects_arena = $false
                    diagnostics = @()
                }
            })
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }
    if (-not $KeepArtifacts -and
            -not [string]::IsNullOrWhiteSpace($script:TemporaryRoot) -and
            (Test-Path -LiteralPath $script:TemporaryRoot -PathType Container)) {
        $resolved = [IO.Path]::GetFullPath($script:TemporaryRoot)
        $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
            [IO.Path]::DirectorySeparatorChar,
            [IO.Path]::AltDirectorySeparatorChar
        )
        $reportInsideTemporaryRoot = (
            -not [string]::IsNullOrWhiteSpace($script:ResolvedReportPath) -and
            [IO.Path]::GetFullPath($script:ResolvedReportPath).StartsWith(
                $resolved + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            )
        )
        if (-not $reportInsideTemporaryRoot -and $resolved.StartsWith(
                $tempBase + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and $resolved -ne $tempBase) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

exit $script:ExitCode
