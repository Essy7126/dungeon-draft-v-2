[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [string]$Remote = 'origin',
    [string]$Branch = 'main',
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [string]$NodePath = 'node.exe',
    [string]$DeployRoot = (Join-Path $env:LOCALAPPDATA 'DungeonDraftObservatory'),
    [ValidateRange(1, 65535)][int]$Port = 8080,
    [ValidateRange(1, 50)][int]$RetentionCount = 5,
    [switch]$FullValidation,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$AllowPreviewBranch
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:CreatedWorktree = ''
$script:TemporaryRelease = ''
$script:Activated = $false
$script:PreviousActive = $null
$script:LockStream = $null
$script:TargetSha = ''
$startedAt = [DateTime]::UtcNow

function Get-UtcNow { [DateTime]::UtcNow.ToString('o') }

function Write-AtomicJson {
    param([string]$Path, [object]$Value)
    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $temporary = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    [System.IO.File]::WriteAllText(
        $temporary,
        (($Value | ConvertTo-Json -Depth 20) + "`n"),
        (New-Object System.Text.UTF8Encoding($false))
    )
    if (Test-Path -LiteralPath $Path) {
        $backup = "$Path.$([Guid]::NewGuid().ToString('N')).bak"
        try { [System.IO.File]::Replace($temporary, $Path, $backup) }
        finally { if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force } }
    } else {
        [System.IO.File]::Move($temporary, $Path)
    }
}

function Invoke-Native {
    param([string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory = '')
    $previous = Get-Location
    try {
        if ($WorkingDirectory) { Set-Location -LiteralPath $WorkingDirectory }
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = & $Executable @Arguments 2>&1
            $exitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previousPreference }
        if ($exitCode -ne 0) {
            throw "Commande échouée ($exitCode) : $Executable $($Arguments -join ' ')`n$($output -join "`n")"
        }
        return ($output -join "`n").Trim()
    } finally {
        Set-Location -LiteralPath $previous
    }
}

function Get-DirectoryHash {
    param([string]$Path)
    $root = [System.IO.Path]::GetFullPath($Path)
    $lines = foreach ($file in Get-ChildItem -LiteralPath $root -File -Recurse | Sort-Object FullName) {
        $relative = $file.FullName.Substring($root.TrimEnd('\').Length).TrimStart('\').Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$relative`0$hash"
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $hasher.Dispose() }
}

function Read-JsonIfPresent {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-UpdateStatus {
    param([string]$Status, [string]$Message, [string]$FailureAt = '')
    $active = Read-JsonIfPresent (Join-Path $DeployRoot 'state\active.json')
    $old = Read-JsonIfPresent (Join-Path $DeployRoot 'state\status.json')
    $value = [ordered]@{
        active_sha = if ($active) { [string]$active.active_sha } else { '' }
        detected_sha = $script:TargetSha
        last_success_at_utc = if ($Status -eq 'current') { Get-UtcNow } elseif ($old) { [string]$old.last_success_at_utc } else { '' }
        last_failure_at_utc = if ($FailureAt) { $FailureAt } elseif ($old) { [string]$old.last_failure_at_utc } else { '' }
        update_status = $Status
        message = $Message
    }
    Write-AtomicJson -Path (Join-Path $DeployRoot 'state\status.json') -Value $value
}

function Add-History {
    param([string]$Status, [string]$Message)
    $historyPath = Join-Path $DeployRoot 'state\history.json'
    $current = Read-JsonIfPresent $historyPath
    $entries = New-Object System.Collections.ArrayList
    if ($current -and $current.entries) {
        foreach ($entry in $current.entries) { [void]$entries.Add($entry) }
    }
    [void]$entries.Add([ordered]@{
        at_utc = Get-UtcNow
        source_commit = $script:TargetSha
        status = $Status
        message = $Message
    })
    while ($entries.Count -gt 100) { $entries.RemoveAt(0) }
    Write-AtomicJson -Path $historyPath -Value ([ordered]@{ entries = $entries })
}

function Test-Health {
    param([string]$ExpectedSha)
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/__observatory/healthz" -TimeoutSec 15
    if (-not $health.ok -or [string]$health.active_sha -ne $ExpectedSha) {
        throw "Health check invalide pour $ExpectedSha."
    }
}

function Remove-CreatedWorktree {
    if (-not $script:CreatedWorktree) { return }
    $worktreesRoot = [System.IO.Path]::GetFullPath((Join-Path $DeployRoot 'worktrees'))
    $target = [System.IO.Path]::GetFullPath($script:CreatedWorktree)
    if (-not $target.StartsWith($worktreesRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refus de nettoyer un worktree hors de DeployRoot/worktrees.'
    }
    try { & $script:GitPath -c core.longpaths=true -C $RepositoryRoot worktree remove --force $target 2>&1 | Out-Null }
    catch { }
    if (Test-Path -LiteralPath $target) {
        if ($env:OS -eq 'Windows_NT') { [System.IO.Directory]::Delete("\\?\$target", $true) }
        else { Remove-Item -LiteralPath $target -Recurse -Force }
    }
    $script:CreatedWorktree = ''
}

foreach ($directory in @('config', 'runtime', 'releases', 'state', 'logs', 'locks', 'worktrees')) {
    [System.IO.Directory]::CreateDirectory((Join-Path $DeployRoot $directory)) | Out-Null
}

$logPath = Join-Path $DeployRoot ("logs\update-{0:yyyyMMdd-HHmmss}-{1}.log" -f [DateTime]::UtcNow, $PID)
Start-Transcript -LiteralPath $logPath -Append | Out-Null

try {
    if ($Branch -ne 'main' -and -not $AllowPreviewBranch) {
        throw 'Une branche autre que main est refusée en mode production.'
    }
    $repo = [System.IO.Path]::GetFullPath($RepositoryRoot)
    if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) { throw 'RepositoryRoot ne désigne pas un dépôt Git.' }
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'GodotPath est introuvable.' }
    $script:GitPath = (Get-Command git.exe -ErrorAction Stop).Source
    $resolvedNode = (Get-Command $NodePath -ErrorAction Stop).Source
    $npmPath = Join-Path (Split-Path -Parent $resolvedNode) 'npm.cmd'
    if (-not (Test-Path -LiteralPath $npmPath -PathType Leaf)) { $npmPath = (Get-Command npm.cmd -ErrorAction Stop).Source }

    $lockPath = Join-Path $DeployRoot 'locks\update.lock'
    try {
        $script:LockStream = New-Object System.IO.FileStream(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    } catch {
        throw 'Une mise à jour Observatory est déjà en cours.'
    }

    Invoke-Native $script:GitPath @('-C', $repo, 'fetch', $Remote, $Branch, '--prune') | Out-Null
    $script:TargetSha = Invoke-Native $script:GitPath @('-C', $repo, 'rev-parse', "$Remote/$Branch`^{commit}")
    if ($script:TargetSha -notmatch '^[0-9a-f]{40}$') { throw 'SHA cible Git invalide.' }
    $activePath = Join-Path $DeployRoot 'state\active.json'
    $script:PreviousActive = Read-JsonIfPresent $activePath
    if ($script:PreviousActive -and $script:PreviousActive.active_sha -eq $script:TargetSha -and -not $Force) {
        Write-UpdateStatus -Status 'current' -Message 'Aucun nouveau commit.'
        Add-History -Status 'no_change' -Message 'Aucun nouveau commit.'
        [pscustomobject]@{ status = 'no_change'; active_sha = $script:TargetSha }
        return
    }
    if ($DryRun) {
        [pscustomobject]@{ status = 'dry_run'; target_sha = $script:TargetSha }
        return
    }

    Write-UpdateStatus -Status 'updating' -Message 'Validation de la release candidate.'
    $script:CreatedWorktree = Join-Path $DeployRoot ("worktrees\update-{0}" -f [Guid]::NewGuid().ToString('N'))
    Invoke-Native $script:GitPath @('-C', $repo, 'worktree', 'add', '--detach', $script:CreatedWorktree, $script:TargetSha) | Out-Null
    $checkoutStatus = Invoke-Native $script:GitPath @('-C', $script:CreatedWorktree, 'status', '--porcelain')
    if ($checkoutStatus) { throw 'Le worktree de publication est sale.' }
    foreach ($required in @(
        'tools\observatory\export_snapshot.gd',
        'tools\observatory\live\Test-ObservatoryRelease.ps1',
        'observatory\package-lock.json'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $script:CreatedWorktree $required))) {
            throw "Le commit cible ne contient pas $required."
        }
    }

    Invoke-Native $GodotPath @('--headless', '--path', $script:CreatedWorktree, '--import', '--quit') | Out-Null
    Invoke-Native $GodotPath @('--headless', '--path', $script:CreatedWorktree, '-s', 'res://tools/observatory/export_snapshot.gd') | Out-Null
    $snapshotPath = Join-Path $script:CreatedWorktree 'observatory\public\data\latest.json'
    $snapshot = Get-Content -LiteralPath $snapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (
        $snapshot.meta.source_game_commit -ne $script:TargetSha -or
        $snapshot.meta.source_worktree_dirty_before_export -ne $false -or
        $snapshot.meta.source_generated_from_clean_checkout -ne $true
    ) { throw "La provenance du snapshot candidate n'est pas certifiée." }

    Invoke-Native $GodotPath @(
        '--headless', '--path', $script:CreatedWorktree,
        '-s', 'res://addons/gut/gut_cmdln.gd',
        '-gdir=res://test/unit/observatory', '-ginclude_subdirs', '-gprefix=test_',
        '-gexit', '-gdisable_colors'
    ) | Out-Null
    $gutWrapper = Join-Path $script:CreatedWorktree 'tools\observatory\ci\Verify-GutBaseline.ps1'
    if (-not (Test-Path -LiteralPath $gutWrapper)) { throw 'Wrapper de baseline GUT absent.' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gutWrapper -GodotPath $GodotPath -ProjectRoot $script:CreatedWorktree
    if ($LASTEXITCODE -ne 0) { throw 'La baseline GUT complète a échoué.' }

    $frontendRoot = Join-Path $script:CreatedWorktree 'observatory'
    Invoke-Native $npmPath @('ci') $frontendRoot | Out-Null
    foreach ($command in @('validate:data', 'lint', 'typecheck', 'test', 'build', 'e2e')) {
        Invoke-Native $npmPath @('run', $command) $frontendRoot | Out-Null
    }
    if ($FullValidation) {
        Invoke-Native $GodotPath @('--headless', '--path', $script:CreatedWorktree, '--editor', '--quit') | Out-Null
    }

    $distSource = Join-Path $frontendRoot 'dist'
    if (-not (Test-Path -LiteralPath (Join-Path $distSource 'index.html') -PathType Leaf)) {
        throw "Le build frontend n'a produit aucun dist valide."
    }
    $snapshotInDist = Join-Path $distSource 'data\latest.json'
    $snapshotHash = (Get-FileHash -LiteralPath $snapshotInDist -Algorithm SHA256).Hash.ToLowerInvariant()
    $distHash = Get-DirectoryHash $distSource
    $godotVersion = (Invoke-Native $GodotPath @('--version')).Split("`n")[0]
    $nodeVersion = Invoke-Native $resolvedNode @('--version')
    $npmVersion = Invoke-Native $npmPath @('--version')

    $script:TemporaryRelease = Join-Path $DeployRoot ("releases\.tmp-{0}" -f [Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($script:TemporaryRelease) | Out-Null
    Copy-Item -LiteralPath $distSource -Destination (Join-Path $script:TemporaryRelease 'dist') -Recurse
    $releaseManifest = [ordered]@{
        source_commit = $script:TargetSha
        source_branch = $Branch
        generated_at_utc = Get-UtcNow
        snapshot_schema_version = [string]$snapshot.meta.schema_version
        snapshot_sha256 = $snapshotHash
        dist_sha256 = $distHash
        godot_version = $godotVersion
        node_version = $nodeVersion
        npm_version = $npmVersion
        gut_summary = [ordered]@{ observatory = 'passed'; baseline = 'passed' }
        frontend_summary = [ordered]@{ validate = 'passed'; lint = 'passed'; typecheck = 'passed'; tests = 'passed'; build = 'passed'; e2e = 'passed' }
        status = 'validated'
    }
    Write-AtomicJson -Path (Join-Path $script:TemporaryRelease 'release.json') -Value $releaseManifest
    & (Join-Path $script:CreatedWorktree 'tools\observatory\live\Test-ObservatoryRelease.ps1') -ReleasePath $script:TemporaryRelease -ExpectedSha $script:TargetSha | Out-Null

    $finalRelease = Join-Path $DeployRoot ("releases\{0}" -f $script:TargetSha)
    if (Test-Path -LiteralPath $finalRelease) {
        & (Join-Path $script:CreatedWorktree 'tools\observatory\live\Test-ObservatoryRelease.ps1') -ReleasePath $finalRelease -ExpectedSha $script:TargetSha | Out-Null
        Remove-Item -LiteralPath $script:TemporaryRelease -Recurse -Force
    } else {
        [System.IO.Directory]::Move($script:TemporaryRelease, $finalRelease)
    }
    $script:TemporaryRelease = ''

    $active = [ordered]@{
        active_sha = $script:TargetSha
        release_path = $finalRelease
        published_at_utc = Get-UtcNow
        snapshot_sha256 = $snapshotHash
        dist_sha256 = $distHash
        validation_summary = [ordered]@{ godot = 'passed'; gut = 'passed'; frontend = 'passed' }
        previous_active_sha = if ($script:PreviousActive) { [string]$script:PreviousActive.active_sha } else { '' }
    }
    Write-AtomicJson -Path $activePath -Value $active
    $script:Activated = $true
    Test-Health -ExpectedSha $script:TargetSha
    Write-UpdateStatus -Status 'current' -Message 'Release publiée et vérifiée.'
    Add-History -Status 'published' -Message 'Release publiée et vérifiée.'

    $protected = @($script:TargetSha)
    if ($script:PreviousActive) { $protected += [string]$script:PreviousActive.active_sha }
    $releaseDirectories = Get-ChildItem -LiteralPath (Join-Path $DeployRoot 'releases') -Directory |
        Where-Object { $_.Name -match '^[0-9a-f]{40}$' } |
        Sort-Object LastWriteTimeUtc -Descending
    $kept = 0
    foreach ($directory in $releaseDirectories) {
        if ($protected -contains $directory.Name -or $kept -lt $RetentionCount) {
            $kept += 1
            continue
        }
        $releaseRoot = [System.IO.Path]::GetFullPath((Join-Path $DeployRoot 'releases'))
        if ($directory.FullName.StartsWith($releaseRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $directory.FullName -Recurse -Force
        }
    }
    [pscustomobject]@{ status = 'published'; active_sha = $script:TargetSha; release = $finalRelease }
} catch {
    $failureAt = Get-UtcNow
    if ($script:Activated) {
        $activePath = Join-Path $DeployRoot 'state\active.json'
        if ($script:PreviousActive) { Write-AtomicJson -Path $activePath -Value $script:PreviousActive }
        elseif (Test-Path -LiteralPath $activePath) { Remove-Item -LiteralPath $activePath -Force }
        $script:Activated = $false
    }
    Write-UpdateStatus -Status 'update_failed' -Message $_.Exception.Message -FailureAt $failureAt
    Add-History -Status 'failed' -Message $_.Exception.Message
    Write-Error $_
    exit 1
} finally {
    if ($script:TemporaryRelease -and (Test-Path -LiteralPath $script:TemporaryRelease)) {
        $tempRoot = [System.IO.Path]::GetFullPath((Join-Path $DeployRoot 'releases'))
        $candidate = [System.IO.Path]::GetFullPath($script:TemporaryRelease)
        if ($candidate.StartsWith($tempRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $candidate -Recurse -Force
        }
    }
    try { Remove-CreatedWorktree } catch { Write-Warning $_.Exception.Message }
    if ($script:LockStream) { $script:LockStream.Dispose() }
    Stop-Transcript | Out-Null
}
