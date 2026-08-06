[CmdletBinding()]
param(
    [string]$TemporaryParent = $env:TEMP,
    [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'
$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$updateScript = Join-Path $sourceRoot 'Update-ObservatoryLive.ps1'
$rollbackScript = Join-Path $sourceRoot 'Rollback-Observatory.ps1'
$releaseValidator = Join-Path $sourceRoot 'Test-ObservatoryRelease.ps1'
$startScript = Join-Path $sourceRoot 'Start-ObservatoryLan.ps1'
$serverScript = Join-Path $sourceRoot 'observatory-lan-server.mjs'
$testRoot = Join-Path $TemporaryParent ("DungeonDraftObservatoryV12Tests-é-{0}" -f [Guid]::NewGuid().ToString('N'))
$deployRoot = Join-Path $testRoot 'déploiement'
$authorRoot = Join-Path $testRoot 'auteur'
$remoteRoot = Join-Path $testRoot 'remote.git'
$toolRoot = Join-Path $testRoot 'outils'
$results = New-Object System.Collections.ArrayList
$serverProcess = $null
$originalFakeGodotMode = $env:FAKE_GODOT_MODE
$originalFakeNpmMode = $env:FAKE_NPM_MODE

function Add-Result {
    param([string]$Name, [scriptblock]$Body)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        & $Body
        [void]$results.Add([pscustomobject]@{ case = $Name; status = 'passed'; duration_ms = $watch.ElapsedMilliseconds })
    } catch {
        [void]$results.Add([pscustomobject]@{ case = $Name; status = 'failed'; duration_ms = $watch.ElapsedMilliseconds; message = $_.Exception.Message })
        throw
    } finally {
        $watch.Stop()
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Git {
    param([string]$Root, [string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git.exe -C $Root @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($code -ne 0) { throw "Git a échoué : $($output -join "`n")" }
    return ($output -join "`n").Trim()
}

function Invoke-UpdateChild {
    param(
        [string]$Branch = 'main',
        [string]$Remote = 'origin',
        [switch]$AllowPreview,
        [switch]$ExpectFailure,
        [switch]$Force
    )
    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $updateScript,
        '-RepositoryRoot', $authorRoot,
        '-Remote', $Remote,
        '-Branch', $Branch,
        '-GodotPath', (Join-Path $toolRoot 'fake-godot.ps1'),
        '-NodePath', (Join-Path $toolRoot 'fake-node.cmd'),
        '-DeployRoot', $deployRoot,
        '-Port', [string]$script:Port,
        '-RetentionCount', '2'
    )
    if ($AllowPreview) { $arguments += '-AllowPreviewBranch' }
    if ($Force) { $arguments += '-Force' }
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & "$PSHOME\powershell.exe" @arguments 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($ExpectFailure) {
        if ($code -eq 0) { throw "La mise à jour devait échouer : $($output -join "`n")" }
    } elseif ($code -ne 0) {
        throw "La mise à jour a échoué ($code) : $($output -join "`n")"
    }
    return ($output -join "`n")
}

function New-FakeCommit {
    param([string]$Message)
    $marker = Join-Path $authorRoot 'observatory\marker.txt'
    [System.IO.File]::AppendAllText($marker, "$Message`n", (New-Object System.Text.UTF8Encoding($false)))
    Invoke-Git $authorRoot @('add', 'observatory/marker.txt') | Out-Null
    Invoke-Git $authorRoot @('commit', '-m', $Message) | Out-Null
    Invoke-Git $authorRoot @('push', 'origin', 'main') | Out-Null
    return Invoke-Git $authorRoot @('rev-parse', 'HEAD')
}

try {
    [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory($toolRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory($deployRoot) | Out-Null

    Add-Result 'syntaxe PowerShell 5.1 compatible' {
        foreach ($script in Get-ChildItem -LiteralPath $sourceRoot -Filter '*.ps1' -File) {
            $tokens = $null
            $errors = $null
            [void][Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors)
            Assert-True ($errors.Count -eq 0) "$($script.Name) contient une erreur de syntaxe."
        }
    }

    $fakeGodot = @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Remaining)
if ($Remaining -contains '--version') { '4.7.1.stable.fake'; exit 0 }
if ($env:FAKE_GODOT_MODE -eq 'godot_fail') { exit 17 }
$pathIndex = [Array]::IndexOf($Remaining, '--path')
if ($pathIndex -lt 0) { exit 0 }
$projectRoot = $Remaining[$pathIndex + 1]
if (($Remaining -join ' ') -match 'export_snapshot\.gd') {
    if ($env:FAKE_GODOT_MODE -eq 'export_fail') { exit 18 }
    $sha = (& git.exe -C $projectRoot rev-parse HEAD).Trim()
    if ($env:FAKE_GODOT_MODE -eq 'provenance_bad') { $sha = '0000000000000000000000000000000000000000' }
    $target = Join-Path $projectRoot 'observatory\public\data\latest.json'
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    $snapshot = [ordered]@{ meta = [ordered]@{
        schema_version = '3.0.0'
        source_game_commit = $sha
        source_worktree_dirty_before_export = $false
        source_generated_from_clean_checkout = $true
    } }
    [System.IO.File]::WriteAllText($target, (($snapshot | ConvertTo-Json -Depth 10) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}
exit 0
'@
    [System.IO.File]::WriteAllText((Join-Path $toolRoot 'fake-godot.ps1'), $fakeGodot, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $toolRoot 'fake-node.cmd'), "@echo off`r`necho v24.0.0`r`n", [Text.Encoding]::ASCII)
    $fakeNpm = @'
@echo off
if "%1"=="--version" echo 11.0.0& exit /b 0
if "%1"=="run" if "%2"=="test" if "%FAKE_NPM_MODE%"=="fail" exit /b 19
if "%1"=="run" if "%2"=="build" (
  if "%FAKE_NPM_MODE%"=="no_dist" exit /b 0
  if not exist dist\data mkdir dist\data
  copy /Y public\data\latest.json dist\data\latest.json >nul
  > dist\index.html echo ^<!doctype html^>^<title^>Fixture Observatory^</title^>
)
echo fake npm %*
exit /b 0
'@
    [System.IO.File]::WriteAllText((Join-Path $toolRoot 'npm.cmd'), $fakeNpm, [Text.Encoding]::ASCII)

    & git.exe init --bare $remoteRoot | Out-Null
    & git.exe init -b main $authorRoot | Out-Null
    Invoke-Git $authorRoot @('config', 'user.email', 'observatory@example.invalid') | Out-Null
    Invoke-Git $authorRoot @('config', 'user.name', 'Observatory Automation Test') | Out-Null
    Invoke-Git $authorRoot @('remote', 'add', 'origin', $remoteRoot) | Out-Null
    foreach ($directory in @(
        'tools\observatory\live', 'tools\observatory\ci',
        'observatory\public\data'
    )) { [System.IO.Directory]::CreateDirectory((Join-Path $authorRoot $directory)) | Out-Null }
    Copy-Item -LiteralPath $releaseValidator -Destination (Join-Path $authorRoot 'tools\observatory\live\Test-ObservatoryRelease.ps1')
    [System.IO.File]::WriteAllText((Join-Path $authorRoot 'tools\observatory\export_snapshot.gd'), "extends SceneTree`n", (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $authorRoot 'tools\observatory\ci\Verify-GutBaseline.ps1'), "exit 0`n", (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $authorRoot 'observatory\package-lock.json'), "{}`n", (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $authorRoot 'observatory\marker.txt'), "initial`n", (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $authorRoot 'observatory\public\data\latest.json'), "{}`n", (New-Object System.Text.UTF8Encoding($false)))
    Invoke-Git $authorRoot @('add', 'tools/observatory/export_snapshot.gd', 'tools/observatory/live/Test-ObservatoryRelease.ps1', 'tools/observatory/ci/Verify-GutBaseline.ps1', 'observatory/package-lock.json', 'observatory/marker.txt', 'observatory/public/data/latest.json') | Out-Null
    Invoke-Git $authorRoot @('commit', '-m', 'fixture initial') | Out-Null
    Invoke-Git $authorRoot @('push', '-u', 'origin', 'main') | Out-Null
    $firstSha = Invoke-Git $authorRoot @('rev-parse', 'HEAD')

    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $script:Port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    $listener.Stop()
    $realNode = (Get-Command node.exe -ErrorAction Stop).Source
    $serverProcess = Start-Process -FilePath $realNode -ArgumentList @(
        "`"$serverScript`"", "`"--deploy-root=$deployRoot`"", '--host=127.0.0.1', "--port=$script:Port"
    ) -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 500
    Assert-True (-not $serverProcess.HasExited) 'Le serveur de fixture ne démarre pas.'

    Add-Result 'refus branche de feature en production' {
        Invoke-UpdateChild -Branch 'feature/test' -ExpectFailure | Out-Null
    }
    Add-Result 'première publication atomique et provenance exacte' {
        Invoke-UpdateChild | Out-Null
        $active = Get-Content -LiteralPath (Join-Path $deployRoot 'state\active.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-True ($active.active_sha -eq $firstSha) 'Le premier SHA actif est incorrect.'
        $activeIndex = Join-Path ([string]$active.release_path) 'dist\index.html'
        Assert-True (Test-Path -LiteralPath $activeIndex) "Le dist actif est incomplet : $activeIndex"
        Assert-True ((Get-ChildItem -LiteralPath (Join-Path $deployRoot 'releases') -Directory -Filter '.tmp-*').Count -eq 0) 'Une release temporaire subsiste.'
    }
    Add-Result 'no-op lorsque le SHA est inchangé' {
        $output = Invoke-UpdateChild
        Assert-True ($output -match 'no_change') 'La seconde exécution n’est pas un no-op.'
    }
    Add-Result 'verrou concurrent' {
        $lockPath = Join-Path $deployRoot 'locks\update.lock'
        $lock = New-Object IO.FileStream($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try { Invoke-UpdateChild -Force -ExpectFailure | Out-Null }
        finally { $lock.Dispose() }
    }

    $secondSha = New-FakeCommit 'fixture second'
    Add-Result 'nouvelle release et rétention' {
        Invoke-UpdateChild | Out-Null
        $active = Get-Content -LiteralPath (Join-Path $deployRoot 'state\active.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-True ($active.active_sha -eq $secondSha) 'La deuxième release n’est pas active.'
        Assert-True ((Get-ChildItem -LiteralPath (Join-Path $deployRoot 'releases') -Directory | Where-Object Name -Match '^[0-9a-f]{40}$').Count -le 2) 'La rétention n’est pas bornée.'
    }

    $thirdSha = New-FakeCommit 'fixture invalid'
    Add-Result 'échec npm conserve la dernière release valide' {
        $env:FAKE_NPM_MODE = 'fail'
        try { Invoke-UpdateChild -ExpectFailure | Out-Null }
        finally { $env:FAKE_NPM_MODE = $null }
        $active = Get-Content -LiteralPath (Join-Path $deployRoot 'state\active.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-True ($active.active_sha -eq $secondSha) 'L’échec npm a remplacé la release valide.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $deployRoot "releases\$thirdSha"))) 'Une release npm invalide a été publiée.'
    }
    Add-Result 'provenance incorrecte refusée' {
        $env:FAKE_GODOT_MODE = 'provenance_bad'
        try { Invoke-UpdateChild -ExpectFailure | Out-Null }
        finally { $env:FAKE_GODOT_MODE = $null }
    }
    Add-Result 'échec export Godot refusé' {
        $env:FAKE_GODOT_MODE = 'export_fail'
        try { Invoke-UpdateChild -ExpectFailure | Out-Null }
        finally { $env:FAKE_GODOT_MODE = $null }
    }
    Add-Result 'échec Godot refusé' {
        $env:FAKE_GODOT_MODE = 'godot_fail'
        try { Invoke-UpdateChild -ExpectFailure | Out-Null }
        finally { $env:FAKE_GODOT_MODE = $null }
    }
    Add-Result 'dist absent refusé' {
        $env:FAKE_NPM_MODE = 'no_dist'
        try { Invoke-UpdateChild -ExpectFailure | Out-Null }
        finally { $env:FAKE_NPM_MODE = $null }
    }
    Add-Result 'origin main indisponible' {
        Invoke-UpdateChild -Remote 'remote-absent' -ExpectFailure | Out-Null
    }
    Add-Result 'Git indisponible' {
        $savedPath = $env:PATH
        $env:PATH = ''
        try { Invoke-UpdateChild -ExpectFailure | Out-Null }
        finally { $env:PATH = $savedPath }
    }
    Add-Result 'configuration serveur absente' {
        $emptyRoot = Join-Path $testRoot 'sans-config'
        [System.IO.Directory]::CreateDirectory($emptyRoot) | Out-Null
        $ErrorActionPreference = 'Continue'
        $output = & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $startScript -DeployRoot $emptyRoot 2>&1
        Assert-True ($LASTEXITCODE -ne 0) "Start aurait dû refuser la configuration absente : $output"
    }
    Add-Result 'release incomplète et hash altéré refusés' {
        $ErrorActionPreference = 'Continue'
        $incomplete = Join-Path $testRoot 'release-incomplète'
        [System.IO.Directory]::CreateDirectory($incomplete) | Out-Null
        & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $releaseValidator -ReleasePath $incomplete 2>&1 | Out-Null
        Assert-True ($LASTEXITCODE -ne 0) 'Une release incomplète a été acceptée.'
        $validRelease = Join-Path $testRoot 'release-hash-altéré'
        Copy-Item -LiteralPath (Join-Path $deployRoot "releases\$secondSha") -Destination $validRelease -Recurse
        [System.IO.File]::AppendAllText((Join-Path $validRelease 'dist\index.html'), 'altéré')
        & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $releaseValidator -ReleasePath $validRelease -ExpectedSha $secondSha 2>&1 | Out-Null
        Assert-True ($LASTEXITCODE -ne 0) 'Un hash dist altéré a été accepté.'
        Invoke-UpdateChild -Force | Out-Null
    }
    Add-Result 'rollback validé sans reconstruction' {
        $output = & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $rollbackScript -DeployRoot $deployRoot -TargetSha $secondSha -Port $script:Port 2>&1
        Assert-True ($LASTEXITCODE -eq 0) "Rollback échoué : $($output -join "`n")"
        $active = Get-Content -LiteralPath (Join-Path $deployRoot 'state\active.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-True ($active.active_sha -eq $secondSha) 'Le rollback n’a pas activé la release précédente.'
    }
    Add-Result 'refus explicite d’un worktree sale et contrats d’échec' {
        $text = Get-Content -LiteralPath $updateScript -Raw -Encoding UTF8
        foreach ($needle in @(
            "status', '--porcelain", 'source_worktree_dirty_before_export',
            'source_generated_from_clean_checkout', 'Le build frontend n',
            'Write-AtomicJson -Path $activePath', 'PreviousActive', 'update.lock'
        )) { Assert-True ($text.Contains($needle)) "Contrat absent du script : $needle" }
    }

    $failed = @($results | Where-Object status -EQ 'failed')
    [pscustomobject]@{
        status = if ($failed.Count -eq 0) { 'passed' } else { 'failed' }
        cases = $results.Count
        passed = @($results | Where-Object status -EQ 'passed').Count
        failed = $failed.Count
        temporary_path_cleaned_by_finally = $true
        results = $results
    } | ConvertTo-Json -Depth 10
} finally {
    $env:FAKE_GODOT_MODE = $originalFakeGodotMode
    $env:FAKE_NPM_MODE = $originalFakeNpmMode
    if ($serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force
        $serverProcess.WaitForExit()
    }
    $absoluteRoot = [System.IO.Path]::GetFullPath($testRoot)
    $absoluteParent = [System.IO.Path]::GetFullPath($TemporaryParent)
    if (-not $KeepArtifacts -and
        (Test-Path -LiteralPath $absoluteRoot) -and
        $absoluteRoot.StartsWith($absoluteParent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -and
        [System.IO.Path]::GetFileName($absoluteRoot).StartsWith('DungeonDraftObservatoryV12Tests-é-')
    ) { Remove-Item -LiteralPath $absoluteRoot -Recurse -Force }
}
