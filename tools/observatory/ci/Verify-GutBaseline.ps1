[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$BaselinePath = '',
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
$project = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not $BaselinePath) { $BaselinePath = Join-Path $project 'tools\observatory\ci\known_gut_failures.json' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $project 'artifacts\observatory-ci\gut' }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Binaire Godot introuvable.' }
if (-not (Test-Path -LiteralPath $BaselinePath -PathType Leaf)) { throw 'Baseline GUT introuvable.' }
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$junitPath = Join-Path $OutputDirectory 'gut-full.xml'
$stdoutPath = Join-Path $OutputDirectory 'gut-full.stdout.log'
$stderrPath = Join-Path $OutputDirectory 'gut-full.stderr.log'
$summaryPath = Join-Path $OutputDirectory 'gut-baseline-summary.json'
foreach ($path in @($junitPath, $stdoutPath, $stderrPath, $summaryPath)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}

$baseline = Get-Content -LiteralPath $BaselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $baseline.verified_at_commit -or -not $baseline.verified_at_utc) { throw 'Métadonnées de baseline GUT incomplètes.' }
$known = @($baseline.test_identifiers | ForEach-Object { [string]$_ })
if ($known.Count -eq 0 -or $known.Count -ne @($known | Select-Object -Unique).Count) {
    throw 'Liste des échecs GUT historiques vide ou dupliquée.'
}
foreach ($identifier in $known) {
    if (-not $baseline.issue_classification.PSObject.Properties[$identifier]) {
        throw "Classification absente pour $identifier."
    }
}

$gitPath = (Get-Command git -ErrorAction Stop).Source
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $gitPath -C $project cat-file -e "$($baseline.verified_at_commit)^{commit}" 2>&1 | Out-Null
    $knownCommitCode = $LASTEXITCODE
    & $gitPath -C $project merge-base --is-ancestor $baseline.verified_at_commit HEAD 2>&1 | Out-Null
    $ancestorCode = $LASTEXITCODE
} finally { $ErrorActionPreference = $previousPreference }
if ($knownCommitCode -ne 0 -or $ancestorCode -ne 0) { throw 'Le commit de baseline GUT n’est pas un ancêtre vérifiable de HEAD.' }

$temporaryParent = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
function Remove-VerifiedTemporaryDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $fullParent = [System.IO.Path]::GetFullPath($temporaryParent).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if (-not $fullPath.StartsWith($fullParent, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refus de nettoyer un chemin hors du dossier temporaire : $fullPath"
    }
    Get-ChildItem -LiteralPath $fullPath -Recurse -Force -ErrorAction Stop | ForEach-Object {
        if ($_.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
            $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
        }
    }
    if ($env:OS -eq 'Windows_NT') { [System.IO.Directory]::Delete("\\?\$fullPath", $true) }
    else { Remove-Item -LiteralPath $fullPath -Recurse -Force }
}
$runId = [Guid]::NewGuid().ToString('N')
$testProject = Join-Path $temporaryParent ("DDO-GUT-{0}" -f $runId)
$worktreeCreated = $false
$output = @()
$rawExitCode = -999
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$oldXdgData = $env:XDG_DATA_HOME
$oldXdgConfig = $env:XDG_CONFIG_HOME
$oldXdgCache = $env:XDG_CACHE_HOME
$profileRoot = Join-Path $temporaryParent ("DDO-GUT-profile-{0}" -f $runId)
[System.IO.Directory]::CreateDirectory($profileRoot) | Out-Null
if ($env:OS -eq 'Windows_NT') {
    $env:APPDATA = $profileRoot
    $env:LOCALAPPDATA = $profileRoot
} else {
    $env:XDG_DATA_HOME = Join-Path $profileRoot 'data'
    $env:XDG_CONFIG_HOME = Join-Path $profileRoot 'config'
    $env:XDG_CACHE_HOME = Join-Path $profileRoot 'cache'
}
$watch = [Diagnostics.Stopwatch]::StartNew()
try {
    $ErrorActionPreference = 'Continue'
    $worktreeOutput = & $gitPath -c core.longpaths=true -C $project worktree add --detach $testProject HEAD 2>&1
    $worktreeCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($worktreeCode -ne 0) { throw "Création du worktree GUT impossible : $($worktreeOutput -join "`n")" }
    $worktreeCreated = $true

    $ErrorActionPreference = 'Continue'
    $importOutput = & $GodotPath --headless --path $testProject --import --quit 2>&1
    $importCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($importCode -ne 0) { throw "Import Godot isolé impossible (code $importCode)." }
    $ErrorActionPreference = 'Continue'
    $worktreeStatus = & $gitPath -c core.quotepath=false -C $testProject status --porcelain 2>&1
    $statusCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($statusCode -ne 0 -or ($worktreeStatus -join '').Trim()) {
        throw "Le worktree GUT isolé est sale après import : $($worktreeStatus -join "`n")"
    }

    $arguments = @(
        '--headless', '--path', $testProject,
        '-s', 'res://addons/gut/gut_cmdln.gd',
        '-gdir=res://test/unit', '-ginclude_subdirs', '-gprefix=test_',
        '-gexit', '-gdisable_colors',
        "-gjunit_xml_file=$($junitPath.Replace('\', '/'))"
    )
    $ErrorActionPreference = 'Continue'
    $output = & $GodotPath @arguments 2>&1
    $rawExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
} finally {
    $watch.Stop()
    $ErrorActionPreference = 'Stop'
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    $env:XDG_DATA_HOME = $oldXdgData
    $env:XDG_CONFIG_HOME = $oldXdgConfig
    $env:XDG_CACHE_HOME = $oldXdgCache
    if ($worktreeCreated) {
        $ErrorActionPreference = 'Continue'
        & $gitPath -c core.longpaths=true -C $project worktree remove --force $testProject 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'
    }
    Remove-VerifiedTemporaryDirectory -Path $testProject
    Remove-VerifiedTemporaryDirectory -Path $profileRoot
}
$stdout = @($importOutput | ForEach-Object { [string]$_ }) + @($output | ForEach-Object { [string]$_ })
[System.IO.File]::WriteAllLines($stdoutPath, $stdout, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText($stderrPath, '', (New-Object System.Text.UTF8Encoding($false)))
if (-not (Test-Path -LiteralPath $junitPath -PathType Leaf)) {
    throw "GUT n’a produit aucun JUnit exploitable (code natif $rawExitCode)."
}

try { [xml]$junit = Get-Content -LiteralPath $junitPath -Raw -Encoding UTF8 }
catch { throw "Rapport JUnit GUT illisible : $($_.Exception.Message)" }
if ($junit.DocumentElement.LocalName -ne 'testsuites') { throw 'Racine JUnit GUT inattendue.' }
$cases = @($junit.SelectNodes('//testcase'))
$declaredTests = 0
$declaredFailures = 0
if (-not [int]::TryParse([string]$junit.DocumentElement.tests, [ref]$declaredTests)) { throw 'Compteur tests JUnit invalide.' }
if (-not [int]::TryParse([string]$junit.DocumentElement.failures, [ref]$declaredFailures)) { throw 'Compteur failures JUnit invalide.' }
if ($cases.Count -ne $declaredTests -or $cases.Count -lt [int]$baseline.minimum_test_count) {
    throw "Liste GUT inexploitable : $($cases.Count) tests lus, $declaredTests déclarés, minimum $($baseline.minimum_test_count)."
}

$identifiers = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$failed = New-Object System.Collections.ArrayList
foreach ($case in $cases) {
    $className = ([string]$case.classname).Replace('\', '/')
    $name = [string]$case.name
    if (-not $className -or -not $name) { throw 'Test JUnit sans classname ou name.' }
    $identifier = "${className}::$name"
    if (-not $identifiers.Add($identifier)) { throw "Identifiant de test JUnit dupliqué : $identifier" }
    if ($case.failure -or $case.error -or [string]$case.status -eq 'fail') { [void]$failed.Add($identifier) }
}
if ($failed.Count -ne $declaredFailures) { throw 'Le compteur d’échecs JUnit ne correspond pas aux cas en échec.' }

$newFailures = @($failed | Where-Object { $known -notcontains $_ } | Sort-Object)
$remainingHistorical = @($failed | Where-Object { $known -contains $_ } | Sort-Object)
$resolvedHistorical = @($known | Where-Object { $failed -notcontains $_ } | Sort-Object)
$summary = [ordered]@{
    status = if ($newFailures.Count -eq 0) { 'accepted_baseline' } else { 'new_failures' }
    verified_at_commit = [string]$baseline.verified_at_commit
    raw_godot_exit_code = $rawExitCode
    duration_ms = $watch.ElapsedMilliseconds
    tests = $cases.Count
    passing_tests = $cases.Count - $failed.Count
    failing_tests = $failed.Count
    remaining_historical_failures = $remainingHistorical
    resolved_historical_failures = $resolvedHistorical
    new_failures = $newFailures
}
[System.IO.File]::WriteAllText($summaryPath, (($summary | ConvertTo-Json -Depth 10) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
$summary | ConvertTo-Json -Depth 10
if ($newFailures.Count -gt 0) { throw "Nouveaux échecs GUT : $($newFailures -join ', ')" }
