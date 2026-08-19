[CmdletBinding()]
param(
    [ValidateSet("Run", "Analyze")]
    [string]$Mode = "Run",
    [string]$GodotPath = "",
    [string]$ProjectPath = ".",
    [string]$SuiteId = "unit",
    [string]$TestDirectory = "res://test/unit",
    [string]$Prefix = "test_",
    [string]$Suffix = ".gd",
    [switch]$IncludeSubdirectories,
    [string[]]$TestPath = @(),
    [int]$MinimumTests = 1,
    [Nullable[int]]$ExpectedTestCount = $null,
    [string]$ExpectedFailuresPath = "",
    [int]$ImportTimeoutSeconds = 180,
    [int]$TestTimeoutSeconds = 900,
    [string]$ExpectedGodotVersionPattern = '^4\.7\.1\.stable\.official\.a13da4feb$',
    [string]$ArtifactsDirectory = "",
    [string]$ReportPath = "",
    [string]$AnalysisFixturePath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:GutStrictStartedAt = [DateTime]::UtcNow
$script:GutStrictExitCode = 2
$script:GutStrictReportWritten = $false

$ClassificationOrder = @(
    "CONFIG_ERROR",
    "PROCESS_START_ERROR",
    "IMPORT_TIMEOUT",
    "GUT_TIMEOUT",
    "PARSE_ERROR",
    "GUT_STARTUP_ERROR",
    "JUNIT_MISSING",
    "JUNIT_INVALID",
    "ZERO_TESTS",
    "SUMMARY_MISSING",
    "SUITE_MISSING",
    "UNEXPECTED_ENGINE_ERROR",
    "EXPECTED_FAILURE_SET_MISMATCH",
    "TEST_FAILURE"
)

$ExitCodeByClassification = @{
    CONFIG_ERROR                  = 2
    PROCESS_START_ERROR           = 2
    IMPORT_TIMEOUT                = 124
    GUT_TIMEOUT                   = 124
    PARSE_ERROR                   = 11
    GUT_STARTUP_ERROR             = 16
    JUNIT_MISSING                 = 15
    JUNIT_INVALID                 = 15
    ZERO_TESTS                    = 12
    SUMMARY_MISSING               = 14
    SUITE_MISSING                 = 13
    UNEXPECTED_ENGINE_ERROR       = 16
    EXPECTED_FAILURE_SET_MISMATCH = 10
    TEST_FAILURE                  = 10
}

function Get-ObjectValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = $null
    )
    if ($null -eq $Object) {
        return $Default
    }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $Default
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }
    return $property.Value
}

function ConvertTo-Utf8Path {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }
    return $Path.Replace('\', '/')
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    $parent = [IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false)))
}

function Read-TextIfExists {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.File]::Exists($Path)) {
        return ""
    }
    return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

function New-GutStrictReport {
    param([string]$RequestedSuiteId)
    return [ordered]@{
        schema_version          = 1
        suite_id                = $RequestedSuiteId
        verdict                 = "FAIL"
        primary_classification  = "CONFIG_ERROR"
        failure_codes           = @()
        started_at_utc          = $script:GutStrictStartedAt.ToString("o")
        duration_ms             = 0
        godot                   = [ordered]@{
            path    = $null
            version = $null
        }
        gut_version             = $null
        selection               = [ordered]@{
            directory             = $null
            prefix                = $null
            suffix                = $null
            include_subdirectories = $false
            scripts_discovered    = @()
            scripts_expected      = @()
            scripts_executed      = @()
            scripts_missing       = @()
        }
        counts                  = [ordered]@{
            production_scripts_compile_checked = 0
            test_scripts_compile_checked       = 0
            tests_expected                     = [ordered]@{
                mode  = "minimum"
                value = 1
            }
            tests_executed                     = 0
            passing_tests                      = 0
            failing_tests                      = 0
            pending_tests                      = 0
            risky_tests                        = 0
            skipped_tests                      = 0
            assertions_passed                  = 0
            assertions_total                   = 0
            parse_errors                       = 0
        }
        process                 = [ordered]@{
            version_exit_code    = $null
            import_started       = $false
            import_exit_code     = $null
            import_timed_out     = $false
            gut_started          = $false
            gut_exit_code        = $null
            gut_timed_out        = $false
            killed               = $false
            termination_exit_code = $null
        }
        summary                 = [ordered]@{
            present       = $false
            scripts       = $null
            tests         = $null
            passing_tests = $null
            failing_tests = $null
            risky_pending = $null
            errors        = $null
            warnings      = $null
            assertions_passed = $null
            assertions_total  = $null
        }
        junit                   = [ordered]@{
            path           = $null
            present        = $false
            bytes          = 0
            valid          = $false
            tests          = $null
            failures       = $null
            testcases      = $null
            suite_count    = $null
            assertion_sum  = $null
        }
        expected_failures       = @()
        observed_failures       = @()
        errors                  = @()
        artifacts               = [ordered]@{
            import_stdout = $null
            import_stderr = $null
            import_engine = $null
            gut_stdout    = $null
            gut_stderr    = $null
            gut_engine    = $null
            junit         = $null
            report        = $null
        }
    }
}

function Add-GutStrictFailure {
    param(
        [System.Collections.IDictionary]$Report,
        [string]$Classification,
        [string]$Code,
        [string]$Message,
        [string]$Source = "",
        [Nullable[int]]$Line = $null,
        [string]$Text = ""
    )
    if ($ClassificationOrder -notcontains $Classification) {
        $Classification = "CONFIG_ERROR"
    }
    if (@($Report.failure_codes) -notcontains $Classification) {
        $Report.failure_codes = @($Report.failure_codes) + @($Classification)
    }
    $Report.errors = @($Report.errors) + @([ordered]@{
        classification = $Classification
        code           = $Code
        message        = $Message
        source         = $(if ([string]::IsNullOrWhiteSpace($Source)) { $null } else { $Source })
        line           = $Line
        text           = $(if ([string]::IsNullOrWhiteSpace($Text)) { $null } else { $Text })
    })
}

function Complete-GutStrictReport {
    param([System.Collections.IDictionary]$Report)
    $Report.duration_ms = [int64]([DateTime]::UtcNow - $script:GutStrictStartedAt).TotalMilliseconds
    if (@($Report.failure_codes).Count -eq 0) {
        if (@($Report.observed_failures).Count -gt 0) {
            $Report.verdict = "PASS_WITH_EXPECTED_FAILURES"
            $Report.primary_classification = "PASS_WITH_EXPECTED_FAILURES"
        }
        else {
            $Report.verdict = "PASS"
            $Report.primary_classification = "PASS"
        }
        $script:GutStrictExitCode = 0
        return
    }

    $Report.verdict = "FAIL"
    foreach ($candidate in $ClassificationOrder) {
        if (@($Report.failure_codes) -contains $candidate) {
            $Report.primary_classification = $candidate
            $script:GutStrictExitCode = [int]$ExitCodeByClassification[$candidate]
            return
        }
    }
    $Report.primary_classification = "CONFIG_ERROR"
    $script:GutStrictExitCode = 2
}

function Write-GutStrictReport {
    param(
        [System.Collections.IDictionary]$Report,
        [string]$PreferredPath
    )
    $target = $PreferredPath
    if ([string]::IsNullOrWhiteSpace($target)) {
        $fallbackRoot = Join-Path ([IO.Path]::GetTempPath()) "dungeon-draft-gut-strict"
        $target = Join-Path $fallbackRoot ("gut-strict-report-{0}.json" -f [Guid]::NewGuid().ToString("N"))
    }
    try {
        $target = [IO.Path]::GetFullPath($target)
        $Report.artifacts.report = ConvertTo-Utf8Path $target
        $json = $Report | ConvertTo-Json -Depth 12
        Write-Utf8NoBom -Path $target -Content $json
    }
    catch {
        $fallbackRoot = Join-Path ([IO.Path]::GetTempPath()) "dungeon-draft-gut-strict"
        $fallback = Join-Path $fallbackRoot ("gut-strict-report-{0}.json" -f [Guid]::NewGuid().ToString("N"))
        $Report.artifacts.report = ConvertTo-Utf8Path $fallback
        Add-GutStrictFailure $Report "CONFIG_ERROR" "REPORT_PATH_FALLBACK" ("Le rapport principal n'a pas pu etre ecrit: {0}" -f $_.Exception.Message) $target
        Complete-GutStrictReport -Report $Report
        $json = $Report | ConvertTo-Json -Depth 12
        Write-Utf8NoBom -Path $fallback -Content $json
        $target = $fallback
    }
    $script:GutStrictReportWritten = $true
    Write-Output ("GUT_STRICT_REPORT={0}" -f (ConvertTo-Utf8Path $target))
    Write-Output ("GUT_STRICT_CLASSIFICATION={0}" -f $Report.primary_classification)
    return $target
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $slashes += 1
            continue
        }
        if ($character -eq '"') {
            if ($slashes -gt 0) {
                [void]$builder.Append(('\' * ($slashes * 2)))
            }
            [void]$builder.Append('\"')
            $slashes = 0
            continue
        }
        if ($slashes -gt 0) {
            [void]$builder.Append(('\' * $slashes))
            $slashes = 0
        }
        [void]$builder.Append($character)
    }
    if ($slashes -gt 0) {
        [void]$builder.Append(('\' * ($slashes * 2)))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Stop-GutStrictProcessTree {
    param([Diagnostics.Process]$Process)
    if ($null -eq $Process -or $Process.HasExited) {
        return
    }
    $isWindowsPlatform = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    if ($isWindowsPlatform) {
        $taskkill = Join-Path $env:SystemRoot "System32\taskkill.exe"
        if ([IO.File]::Exists($taskkill)) {
            $killer = Start-Process -FilePath $taskkill -ArgumentList ("/PID {0} /T /F" -f $Process.Id) -PassThru -Wait -WindowStyle Hidden
            $null = $killer.ExitCode
        }
        else {
            $Process.Kill()
        }
    }
    else {
        $Process.Kill()
    }
}

function Invoke-GutStrictProcess {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds,
        [string]$StdoutPath,
        [string]$StderrPath
    )
    $result = [ordered]@{
        started          = $false
        start_error      = $null
        timed_out        = $false
        killed           = $false
        exit_code        = $null
        termination_exit_code = $null
        duration_ms      = 0
    }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = $null
    $stdoutTask = $null
    $stderrTask = $null
    try {
        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = $Executable
        $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-NativeArgument ([string]$_) }) -join ' ')
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        $process = New-Object Diagnostics.Process
        $process.StartInfo = $startInfo
        $result.started = $process.Start()
        if (-not $result.started) {
            $result.start_error = "Le processus n'a pas demarre."
            return $result
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $waitMilliseconds = [Math]::Max(1, $TimeoutSeconds) * 1000
        if (-not $process.WaitForExit($waitMilliseconds)) {
            $result.timed_out = $true
            Stop-GutStrictProcessTree -Process $process
            $result.killed = $true
        }
        $process.WaitForExit()
        $result.termination_exit_code = $process.ExitCode
        if (-not $result.timed_out) {
            $result.exit_code = $process.ExitCode
        }
    }
    catch {
        $result.start_error = $_.Exception.Message
        if ($null -ne $process -and $result.started -and -not $process.HasExited) {
            try {
                Stop-GutStrictProcessTree -Process $process
                $result.killed = $true
            }
            catch {
                # Le rapport principal conserve l'erreur de lancement originale.
            }
        }
    }
    finally {
        $watch.Stop()
        $result.duration_ms = [int64]$watch.Elapsed.TotalMilliseconds
        $stdout = ""
        $stderr = ""
        if ($null -ne $stdoutTask) {
            try { $stdout = $stdoutTask.GetAwaiter().GetResult() } catch { $stdout = "" }
        }
        if ($null -ne $stderrTask) {
            try { $stderr = $stderrTask.GetAwaiter().GetResult() } catch { $stderr = "" }
        }
        Write-Utf8NoBom -Path $StdoutPath -Content $stdout
        Write-Utf8NoBom -Path $StderrPath -Content $stderr
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
    return $result
}

function Get-NormalizedResourcePath {
    param(
        [string]$AbsolutePath,
        [string]$AbsoluteProjectPath
    )
    $file = [IO.Path]::GetFullPath($AbsolutePath)
    $root = [IO.Path]::GetFullPath($AbsoluteProjectPath).TrimEnd('\', '/')
    $comparison = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        [StringComparison]::OrdinalIgnoreCase
    }
    else {
        [StringComparison]::Ordinal
    }
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    if (-not $file.StartsWith($prefix, $comparison)) {
        throw "Le fichier '$file' est hors du projet '$root'."
    }
    $relative = $file.Substring($prefix.Length).Replace('\', '/')
    return "res://$relative"
}

function Resolve-ResourcePath {
    param(
        [string]$ResourcePath,
        [string]$AbsoluteProjectPath
    )
    if (-not $ResourcePath.StartsWith("res://", [StringComparison]::Ordinal)) {
        throw "Chemin Resource attendu, recu '$ResourcePath'."
    }
    $relative = $ResourcePath.Substring(6).Replace('/', [IO.Path]::DirectorySeparatorChar)
    return [IO.Path]::GetFullPath((Join-Path $AbsoluteProjectPath $relative))
}

function Test-IsGeneratedDiscoveryDirectory {
    param([string]$DirectoryName)
    foreach ($excludedName in @(
        ".git",
        ".godot",
        "output",
        "artifact",
        "artifacts",
        "artefact",
        "artefacts",
        ".artifacts",
        "recovery",
        "recoveries",
        ".recovery",
        "cache",
        "caches",
        ".cache",
        "shader_cache"
    )) {
        if ([string]::Equals(
            $DirectoryName,
            $excludedName,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            return $true
        }
    }
    return $false
}

function Get-StableDiscoveryFiles {
    param(
        [string]$RootPath,
        [bool]$Recursive,
        [string]$FileSuffix = ""
    )
    $found = @()
    $pending = New-Object 'System.Collections.Generic.Queue[string]'
    $pending.Enqueue([IO.Path]::GetFullPath($RootPath))
    while ($pending.Count -gt 0) {
        $directoryPath = $pending.Dequeue()
        try {
            $items = @(Get-ChildItem -LiteralPath $directoryPath -Force -ErrorAction Stop)
        }
        catch {
            # Generated directories can disappear after their parent was read.
            # Missing paths are benign; every other I/O failure remains fatal.
            if (-not [IO.Directory]::Exists($directoryPath)) {
                continue
            }
            throw
        }
        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                if ($Recursive -and -not (Test-IsGeneratedDiscoveryDirectory $item.Name)) {
                    $pending.Enqueue($item.FullName)
                }
                continue
            }
            if ([string]::IsNullOrEmpty($FileSuffix) -or
                $item.Name.EndsWith($FileSuffix, [StringComparison]::OrdinalIgnoreCase)) {
                $found += $item
            }
        }
    }
    return @($found)
}

function Find-TestScripts {
    param(
        [string]$AbsoluteProjectPath,
        [string]$DirectoryResourcePath,
        [string]$FilePrefix,
        [string]$FileSuffix,
        [bool]$Recursive,
        [string[]]$ExplicitPaths
    )
    $found = @()
    if (@($ExplicitPaths).Count -gt 0) {
        foreach ($resourcePath in @($ExplicitPaths)) {
            $absolute = Resolve-ResourcePath -ResourcePath $resourcePath -AbsoluteProjectPath $AbsoluteProjectPath
            if (-not [IO.File]::Exists($absolute)) {
                throw "Script de test attendu absent: $resourcePath"
            }
            $found += Get-NormalizedResourcePath -AbsolutePath $absolute -AbsoluteProjectPath $AbsoluteProjectPath
        }
    }
    else {
        $directory = Resolve-ResourcePath -ResourcePath $DirectoryResourcePath -AbsoluteProjectPath $AbsoluteProjectPath
        if (-not [IO.Directory]::Exists($directory)) {
            throw "Repertoire de tests absent: $DirectoryResourcePath"
        }
        foreach ($item in (Get-StableDiscoveryFiles -RootPath $directory -Recursive $Recursive -FileSuffix $FileSuffix)) {
            if ($item.Name.StartsWith($FilePrefix, [StringComparison]::Ordinal) -and
                $item.Name.EndsWith($FileSuffix, [StringComparison]::Ordinal)) {
                $found += Get-NormalizedResourcePath -AbsolutePath $item.FullName -AbsoluteProjectPath $AbsoluteProjectPath
            }
        }
    }
    return @($found | Sort-Object -Unique)
}

function Get-ProductionScriptCount {
    param([string]$AbsoluteProjectPath)

    # Do not recurse through generated trees. Apart from not being production
    # sources, Godot may remove cache directories while it exits; asking
    # Get-ChildItem -Recurse to follow them turns a successful import into a
    # runner CONFIG_ERROR when one disappears between two directory reads.
    $count = 0

    foreach ($item in (Get-StableDiscoveryFiles -RootPath $AbsoluteProjectPath -Recursive $true -FileSuffix ".gd")) {
        $resourcePath = Get-NormalizedResourcePath -AbsolutePath $item.FullName -AbsoluteProjectPath $AbsoluteProjectPath
        if ($resourcePath -notmatch '^res://(?:test|addons/gut)(?:/|$)') {
            $count += 1
        }
    }
    return $count
}

function Remove-AnsiSequences {
    param([string]$Text)
    return [regex]::Replace($Text, "`e\[[0-9;?]*[ -/]*[@-~]", "")
}

function Find-GutDiagnostics {
    param(
        [string]$Text,
        [string]$Source
    )
    $diagnostics = @()
    $seen = @{}
    $patterns = @(
        [pscustomobject]@{ Classification = "PARSE_ERROR"; Code = "SCRIPT_ERROR"; Pattern = '(?i)\bSCRIPT ERROR\b' },
        [pscustomobject]@{ Classification = "PARSE_ERROR"; Code = "PARSE_ERROR"; Pattern = '(?i)\bParse Error\b' },
        [pscustomobject]@{ Classification = "PARSE_ERROR"; Code = "FAILED_TO_LOAD_SCRIPT"; Pattern = '(?i)Failed to load script' },
        [pscustomobject]@{ Classification = "PARSE_ERROR"; Code = "COULD_NOT_LOAD_SCRIPT"; Pattern = '(?i)Could not load script|could not be loaded' },
        [pscustomobject]@{ Classification = "GUT_STARTUP_ERROR"; Code = "GUT_CLASSES_NOT_IMPORTED"; Pattern = '(?i)Some GUT class_names have not been imported' },
        [pscustomobject]@{ Classification = "GUT_STARTUP_ERROR"; Code = "MAIN_LOOP_NOT_STARTED"; Pattern = '(?i)Main loop did not start in time' },
        [pscustomobject]@{ Classification = "GUT_STARTUP_ERROR"; Code = "UNKNOWN_ARGUMENTS"; Pattern = '(?i)^Unknown arguments:' },
        [pscustomobject]@{ Classification = "GUT_STARTUP_ERROR"; Code = "INVALID_GUTCONFIG"; Pattern = '(?i)^Invalid gutconfig' }
    )
    $clean = Remove-AnsiSequences $Text
    $lines = $clean -split "`r?`n"
    for ($index = 0; $index -lt $lines.Count; $index += 1) {
        foreach ($pattern in $patterns) {
            if ($lines[$index] -match $pattern.Pattern) {
                $key = "{0}|{1}" -f $pattern.Code, $lines[$index].Trim()
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    $diagnostics += [ordered]@{
                        classification = $pattern.Classification
                        code           = $pattern.Code
                        message        = "Diagnostic Godot/GUT bloquant detecte."
                        source         = $Source
                        line           = $index + 1
                        text           = $lines[$index].Trim()
                    }
                }
                break
            }
        }
    }
    return @($diagnostics)
}

function Find-UnexpectedLogErrors {
    param(
        [string]$Text,
        [string]$Source
    )
    $errors = @()
    $seen = @{}
    $knownBlockingOrZeroTestPatterns = @(
        '(?i)\bSCRIPT ERROR\b',
        '(?i)\bParse Error\b',
        '(?i)Failed to load script',
        '(?i)Could not load script|could not be loaded',
        '(?i)Some GUT class_names have not been imported',
        '(?i)Main loop did not start in time',
        '(?i)Nothing was run\.'
    )
    $clean = Remove-AnsiSequences $Text
    $lines = $clean -split "`r?`n"
    for ($index = 0; $index -lt $lines.Count; $index += 1) {
        $line = $lines[$index].Trim()
        if ($line -notmatch '^(?:ERROR:|\[GUT ERROR\]:)') {
            continue
        }
        $alreadyClassified = $false
        foreach ($pattern in $knownBlockingOrZeroTestPatterns) {
            if ($line -match $pattern) {
                $alreadyClassified = $true
                break
            }
        }
        if ($alreadyClassified -or $seen.ContainsKey($line)) {
            continue
        }
        $seen[$line] = $true
        $errors += [ordered]@{
            classification = "UNEXPECTED_ENGINE_ERROR"
            code           = "UNEXPECTED_LOG_ERROR"
            message        = "Erreur inattendue detectee dans les logs Godot/GUT."
            source         = $Source
            line           = $index + 1
            text           = $line
        }
    }
    return @($errors)
}

function Get-LastSummaryInteger {
    param(
        [string]$Text,
        [string]$Label,
        [bool]$Optional = $false
    )
    $escaped = [regex]::Escape($Label)
    $matches = [regex]::Matches($Text, "(?m)^\s*$escaped\s+(?<value>\d+|none)\s*$")
    if ($matches.Count -eq 0) {
        if ($Optional) { return 0 }
        return $null
    }
    $raw = $matches[$matches.Count - 1].Groups["value"].Value
    if ($raw -eq "none") { return 0 }
    return [int]$raw
}

function Read-GutSummary {
    param([string]$Text)
    $clean = Remove-AnsiSequences $Text
    $assertMatches = [regex]::Matches($clean, '(?m)^\s*Asserts\s+(?<passed>\d+)(?:/(?<total>\d+))?\s*$')
    $assertPassed = $null
    $assertTotal = $null
    if ($assertMatches.Count -gt 0) {
        $assertMatch = $assertMatches[$assertMatches.Count - 1]
        $assertPassed = [int]$assertMatch.Groups["passed"].Value
        if ($assertMatch.Groups["total"].Success) {
            $assertTotal = [int]$assertMatch.Groups["total"].Value
        }
        else {
            $assertTotal = $assertPassed
        }
    }
    $scripts = Get-LastSummaryInteger -Text $clean -Label "Scripts"
    $tests = Get-LastSummaryInteger -Text $clean -Label "Tests"
    $passing = Get-LastSummaryInteger -Text $clean -Label "Passing Tests"
    $header = $clean -match '(?m)^= Run Summary\s*$'
    $totals = $clean -match '(?m)^Totals\s*$'
    return [ordered]@{
        present       = [bool]($header -and $totals -and $null -ne $scripts -and $null -ne $tests -and $null -ne $passing -and $null -ne $assertTotal)
        scripts       = $scripts
        tests         = $tests
        passing_tests = $passing
        failing_tests = Get-LastSummaryInteger -Text $clean -Label "Failing Tests" -Optional $true
        risky_pending = Get-LastSummaryInteger -Text $clean -Label "Risky/Pending" -Optional $true
        errors        = Get-LastSummaryInteger -Text $clean -Label "Errors" -Optional $true
        warnings      = Get-LastSummaryInteger -Text $clean -Label "Warnings" -Optional $true
        assertions_passed = $assertPassed
        assertions_total  = $assertTotal
        nothing_run   = [bool]($clean -match '(?im)^.*Nothing was run\..*$')
    }
}

function Convert-JUnitSuiteToResourcePath {
    param([string]$SuiteName)
    $normalized = $SuiteName.Replace('\', '/')
    if ($normalized -match '^(?<script>.*?\.gd)(?:\..*)?$') {
        $normalized = $Matches["script"]
    }
    $normalized = $normalized.TrimStart('/')
    if ($normalized.StartsWith("res://", [StringComparison]::Ordinal)) {
        return $normalized
    }
    return "res://$normalized"
}

function Convert-JUnitFailureIdentity {
    param(
        [string]$SuiteName,
        [string]$TestName
    )
    $resourcePath = Convert-JUnitSuiteToResourcePath $SuiteName
    $filename = ($resourcePath.Replace('\', '/') -split '/')[-1]
    return "${filename}::${TestName}"
}

function Read-GutJUnit {
    param([string]$Path)
    $result = [ordered]@{
        path          = ConvertTo-Utf8Path $Path
        present       = $false
        bytes         = 0
        valid         = $false
        error         = $null
        tests         = $null
        failures      = $null
        testcases     = $null
        suite_count   = $null
        assertion_sum = $null
        scripts       = @()
        failure_ids   = @()
        passing       = 0
        failing       = 0
        pending       = 0
        risky         = 0
        skipped       = 0
    }
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.File]::Exists($Path)) {
        return $result
    }
    $result.present = $true
    $result.bytes = (Get-Item -LiteralPath $Path).Length
    if ($result.bytes -le 0) {
        $result.error = "Le rapport JUnit est vide."
        return $result
    }
    try {
        [xml]$document = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ($null -eq $document.testsuites) {
            throw "Racine <testsuites> absente."
        }
        $rootTests = 0
        $rootFailures = 0
        if (-not [int]::TryParse([string]$document.testsuites.tests, [ref]$rootTests)) {
            throw "Attribut tests invalide sur <testsuites>."
        }
        if (-not [int]::TryParse([string]$document.testsuites.failures, [ref]$rootFailures)) {
            throw "Attribut failures invalide sur <testsuites>."
        }
        $suiteNodes = @($document.SelectNodes('/testsuites/testsuite'))
        $caseNodes = @($document.SelectNodes('/testsuites/testsuite/testcase'))
        $suiteTestSum = 0
        $suiteFailureSum = 0
        $assertionSum = 0
        $scripts = @()
        $failureIds = @()
        foreach ($suite in $suiteNodes) {
            $suiteTests = 0
            $suiteFailures = 0
            if (-not [int]::TryParse($suite.GetAttribute("tests"), [ref]$suiteTests)) {
                throw "Attribut tests invalide sur une suite."
            }
            if (-not [int]::TryParse($suite.GetAttribute("failures"), [ref]$suiteFailures)) {
                throw "Attribut failures invalide sur une suite."
            }
            $suiteTestSum += $suiteTests
            $suiteFailureSum += $suiteFailures
            $scripts += Convert-JUnitSuiteToResourcePath $suite.GetAttribute("name")
        }
        foreach ($case in $caseNodes) {
            $assertions = 0
            if (-not [int]::TryParse($case.GetAttribute("assertions"), [ref]$assertions)) {
                throw "Attribut assertions invalide sur un testcase."
            }
            $assertionSum += $assertions
            $status = $case.GetAttribute("status")
            $failure = $case.SelectSingleNode('failure')
            if ($null -ne $failure -or $status -eq "fail") {
                $result.failing += 1
                $failureIds += Convert-JUnitFailureIdentity -SuiteName $case.GetAttribute("classname") -TestName $case.GetAttribute("name")
            }
            elseif ($status -eq "pass") {
                $result.passing += 1
            }
            elseif ($status -eq "pending") {
                $result.pending += 1
            }
            elseif ($status -eq "no asserts") {
                $result.risky += 1
            }
            elseif ($status -eq "skipped") {
                $result.skipped += 1
            }
            else {
                $result.risky += 1
            }
        }
        if ($suiteTestSum -ne $rootTests -or $caseNodes.Count -ne $rootTests) {
            throw "Incoherence du nombre de tests JUnit."
        }
        $result.tests = $rootTests
        $result.failures = $rootFailures
        $result.testcases = $caseNodes.Count
        $result.suite_count = $suiteNodes.Count
        $result.assertion_sum = $assertionSum
        $result.scripts = @($scripts | Sort-Object -Unique)
        $result.failure_ids = @($failureIds | Sort-Object -Unique)
        $result.valid = $true
    }
    catch {
        $result.error = $_.Exception.Message
    }
    return $result
}

function Compare-StringSets {
    param(
        [string[]]$Expected,
        [string[]]$Observed
    )
    $expectedSet = @{}
    $observedSet = @{}
    foreach ($item in @($Expected)) { $expectedSet[[string]$item] = $true }
    foreach ($item in @($Observed)) { $observedSet[[string]$item] = $true }
    $missing = @()
    $added = @()
    foreach ($item in $expectedSet.Keys) {
        if (-not $observedSet.ContainsKey($item)) { $missing += $item }
    }
    foreach ($item in $observedSet.Keys) {
        if (-not $expectedSet.ContainsKey($item)) { $added += $item }
    }
    return [ordered]@{
        equal   = [bool]($missing.Count -eq 0 -and $added.Count -eq 0)
        missing = @($missing | Sort-Object)
        added   = @($added | Sort-Object)
    }
}

function Invoke-GutStrictAnalysis {
    param(
        [System.Collections.IDictionary]$Report,
        [object]$Analysis
    )
    $importProcess = Get-ObjectValue $Analysis "import_process" ([pscustomobject]@{})
    $gutProcess = Get-ObjectValue $Analysis "gut_process" ([pscustomobject]@{})
    $importText = [string](Get-ObjectValue $Analysis "import_text" "")
    $gutText = [string](Get-ObjectValue $Analysis "gut_text" "")
    $junitPath = [string](Get-ObjectValue $Analysis "junit_path" "")
    $expectedScripts = @((Get-ObjectValue $Analysis "expected_scripts" @()) | ForEach-Object { [string]$_ })
    $minimum = [int](Get-ObjectValue $Analysis "minimum_tests" 1)
    $expectedCountRaw = Get-ObjectValue $Analysis "expected_test_count" $null
    $expectedFailures = @((Get-ObjectValue $Analysis "expected_failures" @()) | ForEach-Object { [string]$_ } | Sort-Object -Unique)

    $Report.expected_failures = $expectedFailures
    $Report.process.import_started = [bool](Get-ObjectValue $importProcess "started" $false)
    $Report.process.import_exit_code = Get-ObjectValue $importProcess "exit_code" $null
    $Report.process.import_timed_out = [bool](Get-ObjectValue $importProcess "timed_out" $false)
    $Report.process.gut_started = [bool](Get-ObjectValue $gutProcess "started" $false)
    $Report.process.gut_exit_code = Get-ObjectValue $gutProcess "exit_code" $null
    $Report.process.gut_timed_out = [bool](Get-ObjectValue $gutProcess "timed_out" $false)
    $Report.process.killed = [bool]((Get-ObjectValue $importProcess "killed" $false) -or (Get-ObjectValue $gutProcess "killed" $false))
    $Report.process.termination_exit_code = Get-ObjectValue $gutProcess "termination_exit_code" (Get-ObjectValue $importProcess "termination_exit_code" $null)

    $importStartError = [string](Get-ObjectValue $importProcess "start_error" "")
    $gutStartError = [string](Get-ObjectValue $gutProcess "start_error" "")
    if (-not [string]::IsNullOrWhiteSpace($importStartError)) {
        Add-GutStrictFailure $Report "PROCESS_START_ERROR" "IMPORT_START_ERROR" $importStartError "import"
    }
    if (-not [string]::IsNullOrWhiteSpace($gutStartError)) {
        Add-GutStrictFailure $Report "PROCESS_START_ERROR" "GUT_START_ERROR" $gutStartError "gut"
    }
    if ($Report.process.import_timed_out) {
        Add-GutStrictFailure $Report "IMPORT_TIMEOUT" "IMPORT_TIMEOUT" "L'import Godot a depasse son timeout." "import"
    }
    if ($Report.process.gut_timed_out) {
        Add-GutStrictFailure $Report "GUT_TIMEOUT" "GUT_TIMEOUT" "La suite GUT a depasse son timeout." "gut"
    }

    $allDiagnostics = @()
    $allDiagnostics += Find-GutDiagnostics -Text $importText -Source "import"
    $allDiagnostics += Find-GutDiagnostics -Text $gutText -Source "gut"
    foreach ($diagnostic in $allDiagnostics) {
        Add-GutStrictFailure $Report $diagnostic.classification $diagnostic.code $diagnostic.message $diagnostic.source $diagnostic.line $diagnostic.text
    }
    $Report.counts.parse_errors = @($allDiagnostics | Where-Object { $_.classification -eq "PARSE_ERROR" }).Count

    $unexpectedLogErrors = @()
    $unexpectedLogErrors += Find-UnexpectedLogErrors -Text $importText -Source "import"
    $unexpectedLogErrors += Find-UnexpectedLogErrors -Text $gutText -Source "gut"
    foreach ($diagnostic in $unexpectedLogErrors) {
        Add-GutStrictFailure $Report $diagnostic.classification $diagnostic.code $diagnostic.message $diagnostic.source $diagnostic.line $diagnostic.text
    }

    if ($Report.process.import_started -and -not $Report.process.import_timed_out -and
        $null -ne $Report.process.import_exit_code -and [int]$Report.process.import_exit_code -ne 0) {
        Add-GutStrictFailure $Report "UNEXPECTED_ENGINE_ERROR" "IMPORT_EXIT_NONZERO" ("Import Godot sorti avec le code {0}." -f $Report.process.import_exit_code) "import"
    }

    if (-not $Report.process.gut_started) {
        return
    }

    $summary = Read-GutSummary -Text $gutText
    foreach ($key in @("present", "scripts", "tests", "passing_tests", "failing_tests", "risky_pending", "errors", "warnings", "assertions_passed", "assertions_total")) {
        $Report.summary[$key] = $summary[$key]
    }

    $junit = Read-GutJUnit -Path $junitPath
    foreach ($key in @("path", "present", "bytes", "valid", "tests", "failures", "testcases", "suite_count", "assertion_sum")) {
        $Report.junit[$key] = $junit[$key]
    }
    $Report.artifacts.junit = $(if ([string]::IsNullOrWhiteSpace($junitPath)) { $null } else { ConvertTo-Utf8Path $junitPath })

    if (-not $junit.present) {
        Add-GutStrictFailure $Report "JUNIT_MISSING" "JUNIT_MISSING" "Le rapport JUnit est absent." $junitPath
    }
    elseif (-not $junit.valid) {
        Add-GutStrictFailure $Report "JUNIT_INVALID" "JUNIT_INVALID" ([string]$junit.error) $junitPath
    }

    $zeroTests = [bool]$summary.nothing_run
    if ($junit.valid -and [int]$junit.tests -eq 0) {
        $zeroTests = $true
    }
    if ($zeroTests) {
        Add-GutStrictFailure $Report "ZERO_TESTS" "ZERO_TESTS" "Aucun test GUT n'a ete execute." "gut"
    }
    elseif (-not $summary.present) {
        Add-GutStrictFailure $Report "SUMMARY_MISSING" "SUMMARY_MISSING" "Le resume GUT complet est absent ou incomplet." "gut"
    }

    if ($junit.valid) {
        $Report.selection.scripts_executed = @($junit.scripts)
        $scriptComparison = Compare-StringSets -Expected $expectedScripts -Observed @($junit.scripts)
        $Report.selection.scripts_missing = @($scriptComparison.missing)
        if (-not $scriptComparison.equal) {
            Add-GutStrictFailure $Report "SUITE_MISSING" "SUITE_SET_MISMATCH" ("Scripts absents: [{0}]; scripts inattendus: [{1}]." -f ($scriptComparison.missing -join ', '), ($scriptComparison.added -join ', ')) "junit"
        }

        $Report.counts.tests_executed = [int]$junit.tests
        $Report.counts.passing_tests = [int]$junit.passing
        $Report.counts.failing_tests = [int]$junit.failing
        $Report.counts.pending_tests = [int]$junit.pending
        $Report.counts.risky_tests = [int]$junit.risky
        $Report.counts.skipped_tests = [int]$junit.skipped
        $Report.observed_failures = @($junit.failure_ids)

        if ([int]$junit.tests -lt $minimum) {
            Add-GutStrictFailure $Report "ZERO_TESTS" "MINIMUM_TEST_COUNT_NOT_MET" ("{0} test(s) executes, minimum attendu {1}." -f $junit.tests, $minimum) "junit"
        }
        if ($null -ne $expectedCountRaw -and [int]$junit.tests -ne [int]$expectedCountRaw) {
            Add-GutStrictFailure $Report "SUITE_MISSING" "EXPECTED_TEST_COUNT_MISMATCH" ("{0} test(s) executes, {1} attendu(s)." -f $junit.tests, $expectedCountRaw) "junit"
        }
        if ($summary.present -and [int]$summary.tests -ne [int]$junit.tests) {
            Add-GutStrictFailure $Report "JUNIT_INVALID" "SUMMARY_JUNIT_TEST_MISMATCH" ("Resume={0}, JUnit={1}." -f $summary.tests, $junit.tests) "junit"
        }
        if ($summary.present -and [int]$summary.scripts -ne [int]$junit.suite_count) {
            Add-GutStrictFailure $Report "JUNIT_INVALID" "SUMMARY_JUNIT_SCRIPT_MISMATCH" ("Resume={0}, JUnit={1}." -f $summary.scripts, $junit.suite_count) "junit"
        }
        if ($summary.present -and [int]$summary.failing_tests -ne [int]$junit.failures) {
            Add-GutStrictFailure $Report "JUNIT_INVALID" "SUMMARY_JUNIT_FAILURE_MISMATCH" ("Resume={0}, JUnit={1}." -f $summary.failing_tests, $junit.failures) "junit"
        }
        if ($summary.present -and [int]$summary.passing_tests -ne [int]$junit.passing) {
            Add-GutStrictFailure $Report "JUNIT_INVALID" "SUMMARY_JUNIT_PASSING_MISMATCH" ("Resume={0}, JUnit={1}." -f $summary.passing_tests, $junit.passing) "junit"
        }
        if ([int]$junit.pending -gt 0) {
            Add-GutStrictFailure $Report "TEST_FAILURE" "PENDING_TESTS" ("{0} test(s) pending." -f $junit.pending) "junit"
        }
        if ([int]$junit.risky -gt 0) {
            Add-GutStrictFailure $Report "TEST_FAILURE" "RISKY_TESTS" ("{0} test(s) sans assertion ou statut inconnu." -f $junit.risky) "junit"
        }
        if ([int]$junit.skipped -gt 0) {
            Add-GutStrictFailure $Report "TEST_FAILURE" "SKIPPED_TESTS" ("{0} test(s) ignores." -f $junit.skipped) "junit"
        }

        $failureComparison = Compare-StringSets -Expected $expectedFailures -Observed @($junit.failure_ids)
        if (@($expectedFailures).Count -eq 0 -and @($junit.failure_ids).Count -gt 0) {
            Add-GutStrictFailure $Report "TEST_FAILURE" "TEST_FAILURE" ("Tests en echec: [{0}]." -f ($junit.failure_ids -join ', ')) "junit"
        }
        elseif (-not $failureComparison.equal) {
            Add-GutStrictFailure $Report "EXPECTED_FAILURE_SET_MISMATCH" "EXPECTED_FAILURE_SET_MISMATCH" ("Echecs historiques manquants: [{0}]; nouveaux echecs: [{1}]." -f ($failureComparison.missing -join ', '), ($failureComparison.added -join ', ')) "junit"
        }
        elseif (@($junit.failure_ids).Count -gt 0 -and [int]$junit.failures -ne @($junit.failure_ids).Count) {
            Add-GutStrictFailure $Report "TEST_FAILURE" "NON_TESTCASE_FAILURE" "Des echecs de hooks ne sont pas identifies par des testcase JUnit." "junit"
        }
    }

    if ($summary.present) {
        $Report.counts.assertions_passed = [int]$summary.assertions_passed
        $Report.counts.assertions_total = [int]$summary.assertions_total
        if ([int]$summary.errors -gt 0) {
            Add-GutStrictFailure $Report "UNEXPECTED_ENGINE_ERROR" "SUMMARY_ERRORS" ("Le resume GUT rapporte {0} erreur(s)." -f $summary.errors) "gut"
        }
    }

    if (-not $Report.process.gut_timed_out -and $null -ne $Report.process.gut_exit_code) {
        $rawExit = [int]$Report.process.gut_exit_code
        if ($rawExit -eq 0) {
            if ($junit.valid -and [int]$junit.failures -gt 0) {
                Add-GutStrictFailure $Report "TEST_FAILURE" "FALSE_ZERO_EXIT" "GUT est sorti 0 malgre des echecs JUnit." "gut"
            }
        }
        elseif ($rawExit -eq 1) {
            if (-not $junit.valid -or @($Report.observed_failures).Count -eq 0) {
                Add-GutStrictFailure $Report "TEST_FAILURE" "UNEXPLAINED_FAILURE_EXIT" "GUT est sorti 1 sans ensemble d'echecs JUnit identifiable." "gut"
            }
            elseif (@($Report.failure_codes) -notcontains "EXPECTED_FAILURE_SET_MISMATCH" -and @($expectedFailures).Count -eq 0) {
                Add-GutStrictFailure $Report "TEST_FAILURE" "TEST_FAILURE" "GUT rapporte des tests en echec." "gut"
            }
        }
        else {
            Add-GutStrictFailure $Report "UNEXPECTED_ENGINE_ERROR" "UNEXPECTED_GUT_EXIT" ("GUT est sorti avec le code {0}." -f $rawExit) "gut"
        }
    }
}

function Resolve-AnalysisFile {
    param(
        [string]$FixtureDirectory,
        [object]$Files,
        [string]$Name
    )
    $value = [string](Get-ObjectValue $Files $Name "")
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }
    if ([IO.Path]::IsPathRooted($value)) {
        return [IO.Path]::GetFullPath($value)
    }
    return [IO.Path]::GetFullPath((Join-Path $FixtureDirectory $value))
}

function Read-ExpectedFailures {
    param(
        [string]$Path,
        [string[]]$SelectedScripts
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @()
    }
    if (-not [IO.File]::Exists($Path)) {
        throw "Allowlist d'echecs absente: $Path"
    }
    $items = @(([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json) | ForEach-Object { [string]$_ })
    $selectedNames = @{}
    foreach ($script in $SelectedScripts) {
        $selectedNames[($script.Replace('\', '/') -split '/')[-1]] = $true
    }
    return @($items | Where-Object {
        $separator = $_.IndexOf('::', [StringComparison]::Ordinal)
        $separator -gt 0 -and $selectedNames.ContainsKey($_.Substring(0, $separator))
    } | Sort-Object -Unique)
}

$Report = New-GutStrictReport -RequestedSuiteId $SuiteId
$preferredReportPath = $ReportPath

try {
    if ($MinimumTests -lt 1) {
        throw "MinimumTests doit etre superieur ou egal a 1."
    }
    if ($ImportTimeoutSeconds -lt 1 -or $TestTimeoutSeconds -lt 1) {
        throw "Les timeouts doivent etre superieurs ou egaux a 1 seconde."
    }

    if ($Mode -eq "Analyze") {
        if ([string]::IsNullOrWhiteSpace($AnalysisFixturePath)) {
            throw "AnalysisFixturePath est obligatoire en mode Analyze."
        }
        $fixturePath = [IO.Path]::GetFullPath($AnalysisFixturePath)
        if (-not [IO.File]::Exists($fixturePath)) {
            throw "Fixture d'analyse absente: $fixturePath"
        }
        $fixtureDirectory = [IO.Path]::GetDirectoryName($fixturePath)
        $fixture = [IO.File]::ReadAllText($fixturePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
        $Report.suite_id = [string](Get-ObjectValue $fixture "suite_id" $SuiteId)
        $Report.godot.path = Get-ObjectValue (Get-ObjectValue $fixture "godot" $null) "path" $null
        $Report.godot.version = Get-ObjectValue (Get-ObjectValue $fixture "godot" $null) "version" $null
        $Report.gut_version = [string](Get-ObjectValue $fixture "gut_version" "9.7.1")
        $selection = Get-ObjectValue $fixture "selection" $null
        $Report.selection.directory = Get-ObjectValue $selection "directory" "res://test/unit"
        $Report.selection.prefix = Get-ObjectValue $selection "prefix" "test_"
        $Report.selection.suffix = Get-ObjectValue $selection "suffix" ".gd"
        $Report.selection.include_subdirectories = [bool](Get-ObjectValue $selection "include_subdirectories" $false)
        $selectedScripts = @((Get-ObjectValue $selection "scripts" @()) | ForEach-Object { [string]$_ })
        $Report.selection.scripts_discovered = $selectedScripts
        $Report.selection.scripts_expected = $selectedScripts

        # Synthetic self-tests may exercise production-source discovery without
        # launching Godot. This optional field is deliberately analysis-only;
        # live runs always count the imported project below.
        $discoveryRootValue = [string](Get-ObjectValue $fixture "production_discovery_root" "")
        if (-not [string]::IsNullOrWhiteSpace($discoveryRootValue)) {
            $discoveryRoot = if ([IO.Path]::IsPathRooted($discoveryRootValue)) {
                [IO.Path]::GetFullPath($discoveryRootValue)
            }
            else {
                [IO.Path]::GetFullPath((Join-Path $fixtureDirectory $discoveryRootValue))
            }
            if (-not [IO.Directory]::Exists($discoveryRoot)) {
                throw "Racine de decouverte de production absente: $discoveryRoot"
            }
            $Report.counts.production_scripts_compile_checked = Get-ProductionScriptCount -AbsoluteProjectPath $discoveryRoot
        }

        $expected = Get-ObjectValue $fixture "expected" $null
        $fixtureMinimum = [int](Get-ObjectValue $expected "minimum_tests" 1)
        $fixtureExact = Get-ObjectValue $expected "test_count" $null
        $fixtureExpectedFailures = @((Get-ObjectValue $expected "failures" @()) | ForEach-Object { [string]$_ })
        if ($null -ne $fixtureExact) {
            $Report.counts.tests_expected = [ordered]@{ mode = "exact"; value = [int]$fixtureExact }
        }
        else {
            $Report.counts.tests_expected = [ordered]@{ mode = "minimum"; value = $fixtureMinimum }
        }

        $files = Get-ObjectValue $fixture "files" $null
        $importStdout = Resolve-AnalysisFile $fixtureDirectory $files "import_stdout"
        $importStderr = Resolve-AnalysisFile $fixtureDirectory $files "import_stderr"
        $importEngine = Resolve-AnalysisFile $fixtureDirectory $files "import_engine"
        $gutStdout = Resolve-AnalysisFile $fixtureDirectory $files "gut_stdout"
        $gutStderr = Resolve-AnalysisFile $fixtureDirectory $files "gut_stderr"
        $gutEngine = Resolve-AnalysisFile $fixtureDirectory $files "gut_engine"
        $junitPath = Resolve-AnalysisFile $fixtureDirectory $files "junit"
        $Report.artifacts.import_stdout = $(if ($importStdout) { ConvertTo-Utf8Path $importStdout } else { $null })
        $Report.artifacts.import_stderr = $(if ($importStderr) { ConvertTo-Utf8Path $importStderr } else { $null })
        $Report.artifacts.import_engine = $(if ($importEngine) { ConvertTo-Utf8Path $importEngine } else { $null })
        $Report.artifacts.gut_stdout = $(if ($gutStdout) { ConvertTo-Utf8Path $gutStdout } else { $null })
        $Report.artifacts.gut_stderr = $(if ($gutStderr) { ConvertTo-Utf8Path $gutStderr } else { $null })
        $Report.artifacts.gut_engine = $(if ($gutEngine) { ConvertTo-Utf8Path $gutEngine } else { $null })

        $process = Get-ObjectValue $fixture "process" $null
        $analysis = [ordered]@{
            import_process     = Get-ObjectValue $process "import" $null
            gut_process        = Get-ObjectValue $process "gut" $null
            import_text        = (Read-TextIfExists $importStdout) + "`n" + (Read-TextIfExists $importStderr) + "`n" + (Read-TextIfExists $importEngine)
            gut_text           = (Read-TextIfExists $gutStdout) + "`n" + (Read-TextIfExists $gutStderr) + "`n" + (Read-TextIfExists $gutEngine)
            junit_path         = $junitPath
            expected_scripts   = $selectedScripts
            minimum_tests      = $fixtureMinimum
            expected_test_count = $fixtureExact
            expected_failures  = $fixtureExpectedFailures
        }
        Invoke-GutStrictAnalysis -Report $Report -Analysis $analysis
    }
    else {
        $absoluteProjectPath = [IO.Path]::GetFullPath($ProjectPath)
        if (-not [IO.File]::Exists((Join-Path $absoluteProjectPath "project.godot"))) {
            throw "project.godot absent sous '$absoluteProjectPath'."
        }
        if ([string]::IsNullOrWhiteSpace($GodotPath)) {
            foreach ($candidate in @($env:GODOT4_BIN, $env:GODOT_BIN)) {
                if (-not [string]::IsNullOrWhiteSpace($candidate) -and [IO.File]::Exists($candidate)) {
                    $GodotPath = $candidate
                    break
                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($GodotPath)) {
            foreach ($commandName in @("godot", "godot4")) {
                $command = Get-Command $commandName -ErrorAction SilentlyContinue
                if ($null -ne $command) {
                    $GodotPath = $command.Source
                    break
                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not [IO.File]::Exists($GodotPath)) {
            throw "Executable Godot introuvable. Utilisez -GodotPath, GODOT4_BIN ou GODOT_BIN."
        }
        $GodotPath = [IO.Path]::GetFullPath($GodotPath)
        $Report.godot.path = ConvertTo-Utf8Path $GodotPath

        if ([string]::IsNullOrWhiteSpace($ArtifactsDirectory)) {
            $safeSuite = [regex]::Replace($SuiteId, '[^A-Za-z0-9_.-]', '_')
            $ArtifactsDirectory = Join-Path $absoluteProjectPath ("artifacts\gut-strict\{0}" -f $safeSuite)
        }
        $ArtifactsDirectory = [IO.Path]::GetFullPath($ArtifactsDirectory)
        [IO.Directory]::CreateDirectory($ArtifactsDirectory) | Out-Null
        if ([string]::IsNullOrWhiteSpace($preferredReportPath)) {
            $preferredReportPath = Join-Path $ArtifactsDirectory "gut-strict-report.json"
        }

        $Report.selection.directory = $TestDirectory
        $Report.selection.prefix = $Prefix
        $Report.selection.suffix = $Suffix
        $Report.selection.include_subdirectories = [bool]$IncludeSubdirectories
        $selectedScripts = @(Find-TestScripts -AbsoluteProjectPath $absoluteProjectPath -DirectoryResourcePath $TestDirectory -FilePrefix $Prefix -FileSuffix $Suffix -Recursive ([bool]$IncludeSubdirectories) -ExplicitPaths $TestPath)
        $Report.selection.scripts_discovered = $selectedScripts
        $Report.selection.scripts_expected = $selectedScripts
        if ($selectedScripts.Count -eq 0) {
            Add-GutStrictFailure $Report "SUITE_MISSING" "EMPTY_DISCOVERY" "La selection ne correspond a aucun script de test." "discovery"
        }
        if ($null -ne $ExpectedTestCount) {
            $Report.counts.tests_expected = [ordered]@{ mode = "exact"; value = [int]$ExpectedTestCount }
        }
        else {
            $Report.counts.tests_expected = [ordered]@{ mode = "minimum"; value = $MinimumTests }
        }

        $pluginPath = Join-Path $absoluteProjectPath "addons\gut\plugin.cfg"
        if (-not [IO.File]::Exists($pluginPath)) {
            throw "Plugin GUT absent: $pluginPath"
        }
        $pluginText = [IO.File]::ReadAllText($pluginPath, [Text.Encoding]::UTF8)
        if ($pluginText -notmatch 'version\s*=\s*"(?<version>[^"]+)"') {
            throw "Version GUT illisible dans plugin.cfg."
        }
        $Report.gut_version = $Matches["version"]
        if ($Report.gut_version -ne "9.7.1") {
            throw "GUT 9.7.1 attendu, version observee '$($Report.gut_version)'."
        }

        $versionStdout = Join-Path $ArtifactsDirectory "godot-version.stdout.log"
        $versionStderr = Join-Path $ArtifactsDirectory "godot-version.stderr.log"
        $versionProcess = Invoke-GutStrictProcess -Executable $GodotPath -Arguments @("--version") -WorkingDirectory $absoluteProjectPath -TimeoutSeconds 15 -StdoutPath $versionStdout -StderrPath $versionStderr
        $Report.process.version_exit_code = $versionProcess.exit_code
        if (-not [string]::IsNullOrWhiteSpace([string]$versionProcess.start_error)) {
            Add-GutStrictFailure $Report "PROCESS_START_ERROR" "VERSION_START_ERROR" ([string]$versionProcess.start_error) "version"
        }
        elseif ($versionProcess.timed_out) {
            Add-GutStrictFailure $Report "PROCESS_START_ERROR" "VERSION_TIMEOUT" "La lecture de version Godot a timeout." "version"
        }
        elseif ([int]$versionProcess.exit_code -ne 0) {
            Add-GutStrictFailure $Report "CONFIG_ERROR" "VERSION_EXIT_NONZERO" ("godot --version est sorti {0}." -f $versionProcess.exit_code) "version"
        }
        else {
            $observedVersion = (Read-TextIfExists $versionStdout).Trim()
            $Report.godot.version = $observedVersion
            if ($observedVersion -notmatch $ExpectedGodotVersionPattern) {
                Add-GutStrictFailure $Report "CONFIG_ERROR" "GODOT_VERSION_MISMATCH" ("Version '$observedVersion' hors contrat '$ExpectedGodotVersionPattern'.") "version"
            }
        }

        if (@($Report.failure_codes).Count -eq 0 -and $selectedScripts.Count -gt 0) {
            $importStdout = Join-Path $ArtifactsDirectory "import.stdout.log"
            $importStderr = Join-Path $ArtifactsDirectory "import.stderr.log"
            $importEngine = Join-Path $ArtifactsDirectory "import.engine.log"
            $gutStdout = Join-Path $ArtifactsDirectory "gut.stdout.log"
            $gutStderr = Join-Path $ArtifactsDirectory "gut.stderr.log"
            $gutEngine = Join-Path $ArtifactsDirectory "gut.engine.log"
            $junitPath = Join-Path $ArtifactsDirectory "gut.junit.xml"
            foreach ($stale in @($importEngine, $gutEngine, $junitPath)) {
                if ([IO.File]::Exists($stale)) { [IO.File]::Delete($stale) }
            }
            $Report.artifacts.import_stdout = ConvertTo-Utf8Path $importStdout
            $Report.artifacts.import_stderr = ConvertTo-Utf8Path $importStderr
            $Report.artifacts.import_engine = ConvertTo-Utf8Path $importEngine
            $Report.artifacts.gut_stdout = ConvertTo-Utf8Path $gutStdout
            $Report.artifacts.gut_stderr = ConvertTo-Utf8Path $gutStderr
            $Report.artifacts.gut_engine = ConvertTo-Utf8Path $gutEngine

            $importArguments = @("--headless", "--path", $absoluteProjectPath, "--log-file", (ConvertTo-Utf8Path $importEngine), "--import")
            $importProcess = Invoke-GutStrictProcess -Executable $GodotPath -Arguments $importArguments -WorkingDirectory $absoluteProjectPath -TimeoutSeconds $ImportTimeoutSeconds -StdoutPath $importStdout -StderrPath $importStderr
            $importCombined = (Read-TextIfExists $importStdout) + "`n" + (Read-TextIfExists $importStderr) + "`n" + (Read-TextIfExists $importEngine)
            $importDiagnostics = @(Find-GutDiagnostics -Text $importCombined -Source "import")

            $gutProcess = [ordered]@{ started = $false; start_error = $null; timed_out = $false; killed = $false; exit_code = $null; termination_exit_code = $null }
            if ($importProcess.started -and -not $importProcess.timed_out -and $null -eq $importProcess.start_error -and [int]$importProcess.exit_code -eq 0 -and $importDiagnostics.Count -eq 0) {
                $Report.counts.production_scripts_compile_checked = Get-ProductionScriptCount -AbsoluteProjectPath $absoluteProjectPath
                $Report.counts.test_scripts_compile_checked = $selectedScripts.Count
                $gutArguments = @(
                    "--headless", "--path", $absoluteProjectPath,
                    "--log-file", (ConvertTo-Utf8Path $gutEngine),
                    "--script", "res://addons/gut/gut_cmdln.gd", "--",
                    "-gconfig=", "-gexit", "-gdisable_colors",
                    "-gfailure_error_types", "engine,gut,push_error",
                    "-gjunit_xml_file", (ConvertTo-Utf8Path $junitPath)
                )
                foreach ($scriptPath in $selectedScripts) {
                    $gutArguments += @("-gtest", $scriptPath)
                }
                $gutProcess = Invoke-GutStrictProcess -Executable $GodotPath -Arguments $gutArguments -WorkingDirectory $absoluteProjectPath -TimeoutSeconds $TestTimeoutSeconds -StdoutPath $gutStdout -StderrPath $gutStderr
            }

            $expectedFailurePathAbsolute = ""
            if (-not [string]::IsNullOrWhiteSpace($ExpectedFailuresPath)) {
                $expectedFailurePathAbsolute = if ([IO.Path]::IsPathRooted($ExpectedFailuresPath)) {
                    [IO.Path]::GetFullPath($ExpectedFailuresPath)
                }
                else {
                    [IO.Path]::GetFullPath((Join-Path $absoluteProjectPath $ExpectedFailuresPath))
                }
            }
            $expectedFailures = Read-ExpectedFailures -Path $expectedFailurePathAbsolute -SelectedScripts $selectedScripts
            $analysis = [ordered]@{
                import_process      = $importProcess
                gut_process         = $gutProcess
                import_text         = $importCombined
                gut_text            = (Read-TextIfExists $gutStdout) + "`n" + (Read-TextIfExists $gutStderr) + "`n" + (Read-TextIfExists $gutEngine)
                junit_path          = $junitPath
                expected_scripts    = $selectedScripts
                minimum_tests       = $MinimumTests
                expected_test_count = $ExpectedTestCount
                expected_failures   = $expectedFailures
            }
            Invoke-GutStrictAnalysis -Report $Report -Analysis $analysis
        }
    }
}
catch {
    Add-GutStrictFailure $Report "CONFIG_ERROR" "UNHANDLED_RUNNER_ERROR" $_.Exception.Message "runner"
}
finally {
    Complete-GutStrictReport -Report $Report
    if ([string]::IsNullOrWhiteSpace($preferredReportPath)) {
        $baseDirectory = if (-not [string]::IsNullOrWhiteSpace($ArtifactsDirectory)) {
            [IO.Path]::GetFullPath($ArtifactsDirectory)
        }
        elseif ($Mode -eq "Analyze" -and -not [string]::IsNullOrWhiteSpace($AnalysisFixturePath)) {
            Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($AnalysisFixturePath))) "analysis-output"
        }
        else {
            Join-Path ([IO.Path]::GetTempPath()) "dungeon-draft-gut-strict"
        }
        $preferredReportPath = Join-Path $baseDirectory "gut-strict-report.json"
    }
    $null = Write-GutStrictReport -Report $Report -PreferredPath $preferredReportPath
}

exit $script:GutStrictExitCode
