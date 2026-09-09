#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DevRoot { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')) }
function Get-DevToolchain { Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json }
function Write-DevJson([string]$Path, [object]$Value) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30) + "`n")
}
function New-DevRun([string]$Name) {
    $base = Join-Path (Get-DevRoot) 'artifacts/dev'
    [IO.Directory]::CreateDirectory($base) | Out-Null
    [IO.File]::WriteAllText((Join-Path $base '.gdignore'), '')
    $safeName = [regex]::Replace($Name, '[^A-Za-z0-9_.-]', '_')
    $path = Join-Path $base ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $safeName + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    [IO.Directory]::CreateDirectory($path) | Out-Null
    $head = & git -C (Get-DevRoot) rev-parse HEAD
    $status = @(& git -C (Get-DevRoot) status --porcelain)
    Write-DevJson (Join-Path $path 'context.json') @{ started_at_utc=[DateTime]::UtcNow.ToString('o'); git_head=$head; working_tree=$status; toolchain=(Get-DevToolchain) }
    return $path
}
function Resolve-DevGodot([string]$ExplicitPath = '') {
    $root = Get-DevRoot
    $local = Join-Path $root 'artifacts/dev-tools/local.json'
    $saved = if (Test-Path -LiteralPath $local) { (Get-Content -LiteralPath $local -Raw | ConvertFrom-Json).godot_path } else { '' }
    $candidates = @($ExplicitPath, $env:GODOT4_BIN, $env:GODOT_BIN, $saved)
    foreach ($name in @('godot','godot4')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { $candidates += $command.Source }
    }
    if ($IsWindows) {
        $candidates += Join-Path ([IO.Path]::GetTempPath()) 'dungeon-draft-godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe'
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return [IO.Path]::GetFullPath($candidate) }
    }
    throw 'Godot missing. Use -GodotPath or GODOT4_BIN (Godot 4.7.1).'
}
function Invoke-DevProcess {
    param([string]$Executable, [string[]]$Arguments, [string]$Directory, [string]$LogRoot,
        [string]$Label = 'process', [int]$TimeoutSeconds = 180, [hashtable]$Environment = @{})
    [IO.Directory]::CreateDirectory($LogRoot) | Out-Null
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$Executable; $start.WorkingDirectory=$Directory
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    foreach ($key in $Environment.Keys) { $start.Environment[$key] = $Environment[$key] }
    Write-DevJson (Join-Path $LogRoot "$Label.command.json") @{executable=$Executable;arguments=$Arguments;directory=$Directory;timeout_seconds=$TimeoutSeconds}
    $result = [ordered]@{ started=$false; start_error=$null; timed_out=$false; killed=$false; exit_code=$null; termination_exit_code=$null; duration_ms=0 }
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$start
    $watch=[Diagnostics.Stopwatch]::StartNew()
    try {
        $result.started=$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) { $result.timed_out=$true; $result.killed=$true; $process.Kill($true) }
        $process.WaitForExit()
        $result.termination_exit_code=$process.ExitCode
        if (-not $result.timed_out) { $result.exit_code=$process.ExitCode }
        [IO.File]::WriteAllText((Join-Path $LogRoot "$Label.stdout.log"),$stdout.GetAwaiter().GetResult())
        [IO.File]::WriteAllText((Join-Path $LogRoot "$Label.stderr.log"),$stderr.GetAwaiter().GetResult())
    } catch {
        $result.start_error=$_.Exception.Message
        if ($result.started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
    } finally { $watch.Stop(); $result.duration_ms=$watch.ElapsedMilliseconds; $process.Dispose() }
    Write-DevJson (Join-Path $LogRoot "$Label.process.json") $result
    return $result
}
function Test-DevProcessSuccess([object]$Result) {
    return $Result.started -and -not $Result.start_error -and -not $Result.timed_out -and $null -ne $Result.exit_code -and $Result.exit_code -eq 0
}
function Get-DevEngineErrors([string]$LogRoot, [string]$Label) {
    foreach ($suffix in @('stdout.log','stderr.log','engine.log')) {
        $path=Join-Path $LogRoot "$Label.$suffix"
        if (Test-Path -LiteralPath $path) {
            Select-String -LiteralPath $path -Pattern '^SCRIPT ERROR:','^ERROR:','^WARNING: .*ObjectDB instances were leaked','^Resource still in use:' | ForEach-Object { $_.Line }
        }
    }
}
function Get-DevStrictSummary([string]$ReportPath, [object]$Process) {
    if (-not (Test-Path -LiteralPath $ReportPath)) { throw 'Strict report missing; validation incomplete.' }
    $report=Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
    if ($report.verdict -notin @('PASS','PASS_WITH_EXPECTED_FAILURES','FAIL')) { throw 'Unknown strict verdict.' }
    $passed=(Test-DevProcessSuccess $Process) -and $report.verdict -in @('PASS','PASS_WITH_EXPECTED_FAILURES') -and $report.counts.tests_executed -gt 0
    return [ordered]@{ passed=$passed; verdict=$(if($passed){$report.verdict}else{'FAIL'}); tests=$report.counts.tests_executed; assertions=$report.counts.assertions_passed; failures=@($report.failure_codes); errors=@($report.errors); report=$ReportPath }
}
function Get-DevTestPaths([string]$Target) {
    $root=Get-DevRoot
    $patterns = @(switch ($Target) {
        'smoke' { @('test_champion_codex.gd','test_spell_codex_detail.gd') }
        'monsters' { @('test_catabase_monster*.gd') }
        'terrain' { @('*terrain*.gd') }
        'studio' { @('test_dungeon_draft_studio_2_0.gd') }
        'all' { @('test_*.gd') }
        default { @() }
    })
    if ($patterns.Count -eq 0) {
        $relative=$Target -replace '^res://',''
        if ($relative -notmatch '^test/unit/[^:]+\.gd$' -or $relative -match '(^|/)\.\.(/|$)') { throw 'Use smoke, monsters, terrain, studio, all or an exact test/unit/*.gd path.' }
        if (-not (Test-Path -LiteralPath (Join-Path $root $relative))) { throw "Test missing: $relative" }
        return @('res://' + $relative)
    }
    $found=@(Get-ChildItem -LiteralPath (Join-Path $root 'test/unit') -File -Recurse | Where-Object { $file=$_.Name; @($patterns | Where-Object {$file -like $_}).Count -gt 0 } | ForEach-Object { 'res://' + [IO.Path]::GetRelativePath($root,$_.FullName).Replace('\','/') } | Sort-Object)
    if ($found.Count -eq 0) { throw "No tests matched $Target." }
    return $found
}
function Invoke-DevTests([string]$Godot, [string]$Target, [string]$RunRoot) {
    $root=Get-DevRoot; $chain=Get-DevToolchain; $paths=@(Get-DevTestPaths $Target)
    if([IO.File]::ReadAllText((Join-Path $root 'addons/gut/plugin.cfg')) -notmatch ('version="'+[regex]::Escape($chain.gut_version)+'"')){throw 'Installed GUT version differs from toolchain.json.'}
    $userData=Join-Path $RunRoot 'appdata'; [IO.Directory]::CreateDirectory($userData) | Out-Null
    $environment=@{APPDATA=$userData; LOCALAPPDATA=$userData}
    $versionResult=Invoke-DevProcess $Godot @('--version') $root $RunRoot 'version' 15
    $version=if(Test-Path (Join-Path $RunRoot 'version.stdout.log')){[IO.File]::ReadAllText((Join-Path $RunRoot 'version.stdout.log')).Trim()}else{''}
    if (-not (Test-DevProcessSuccess $versionResult) -or $version -notmatch $chain.godot_version_pattern) { throw "Godot version mismatch: $version" }
    $import=Invoke-DevProcess $Godot @('--headless','--editor','--recovery-mode','--path',$root,'--log-file',(Join-Path $RunRoot 'import.engine.log'),'--import') $root $RunRoot 'import' 240 $environment
    $gut=@{started=$false;start_error=$null;timed_out=$false;killed=$false;exit_code=$null;termination_exit_code=$null}
    if ((Test-DevProcessSuccess $import) -and @(Get-DevEngineErrors $RunRoot 'import').Count -eq 0) {
        $arguments=@('--headless','--path',$root,'--log-file',(Join-Path $RunRoot 'gut.engine.log'),'--script','res://addons/gut/gut_cmdln.gd','--','-gconfig=','-gexit','-gdisable_colors','-gfailure_error_types','engine,gut,push_error','-gjunit_xml_file',(Join-Path $RunRoot 'gut.junit.xml'))
        foreach ($path in $paths) { $arguments+=@('-gtest',$path) }
        $gut=Invoke-DevProcess $Godot $arguments $root $RunRoot 'gut' 900 $environment
    }
    $expected=@{minimum_tests=1;failures=@()}
    # The full CI suite owns its historical allowlist; local runs stay strict.
    $manifest=@{schema_version=1;suite_id=$Target;godot=@{path=$Godot;version=$version};gut_version=$chain.gut_version;
        selection=@{directory='res://test/unit';prefix='test_';suffix='.gd';include_subdirectories=$true;scripts=$paths};expected=$expected;
        process=@{import=$import;gut=$gut};files=@{import_stdout='import.stdout.log';import_stderr='import.stderr.log';import_engine='import.engine.log';gut_stdout='gut.stdout.log';gut_stderr='gut.stderr.log';gut_engine='gut.engine.log';junit='gut.junit.xml'}}
    $inputPath=Join-Path $RunRoot 'strict-input.json'; Write-DevJson $inputPath $manifest
    $reportPath=Join-Path $RunRoot 'gut-strict-report.json'
    $analysis=Invoke-DevProcess (Get-Process -Id $PID).Path @('-NoProfile','-File',(Join-Path $root 'tools/ci/run_gut_strict.ps1'),'-Mode','Analyze','-AnalysisFixturePath',$inputPath,'-ReportPath',$reportPath) $root $RunRoot 'analyzer' 60
    return Get-DevStrictSummary $reportPath $analysis
}
Export-ModuleMember -Function *-Dev*
