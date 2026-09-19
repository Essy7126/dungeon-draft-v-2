[CmdletBinding()]
param(
    [string]$DeployRoot = (Join-Path $env:LOCALAPPDATA 'DungeonDraftObservatory'),
    [string]$TargetSha = '',
    [ValidateRange(1, 65535)][int]$Port = 8080,
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'

function Write-AtomicJson {
    param([string]$Path, [object]$Value)
    $temporary = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    [System.IO.File]::WriteAllText($temporary, (($Value | ConvertTo-Json -Depth 20) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) {
        $backup = "$Path.$([Guid]::NewGuid().ToString('N')).bak"
        try { [System.IO.File]::Replace($temporary, $Path, $backup) }
        finally { if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force } }
    }
    else { [System.IO.File]::Move($temporary, $Path) }
}

$configPath = Join-Path $DeployRoot 'config\live-config.json'
if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($config.port) { $Port = [int]$config.port }
}
$activePath = Join-Path $DeployRoot 'state\active.json'
if (-not (Test-Path -LiteralPath $activePath)) { throw 'Aucune release active.' }
$previousActive = Get-Content -LiteralPath $activePath -Raw -Encoding UTF8 | ConvertFrom-Json
$validator = Join-Path $PSScriptRoot 'Test-ObservatoryRelease.ps1'
$valid = @()
foreach ($directory in Get-ChildItem -LiteralPath (Join-Path $DeployRoot 'releases') -Directory | Sort-Object LastWriteTimeUtc -Descending) {
    if ($directory.Name -notmatch '^[0-9a-f]{40}$') { continue }
    try {
        & $validator -ReleasePath $directory.FullName -ExpectedSha $directory.Name | Out-Null
        $valid += [pscustomobject]@{ sha = $directory.Name; path = $directory.FullName; modified_at_utc = $directory.LastWriteTimeUtc.ToString('o') }
    } catch { }
}
if ($ListOnly) { $valid; return }
if (-not $TargetSha) {
    $candidate = $valid | Where-Object { $_.sha -ne $previousActive.active_sha } | Select-Object -First 1
} else {
    $candidate = $valid | Where-Object { $_.sha -eq $TargetSha } | Select-Object -First 1
}
if (-not $candidate) { throw 'Aucune release précédente valide ne correspond.' }
$manifest = Get-Content -LiteralPath (Join-Path $candidate.path 'release.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$newActive = [ordered]@{
    active_sha = $candidate.sha
    release_path = $candidate.path
    published_at_utc = [DateTime]::UtcNow.ToString('o')
    snapshot_sha256 = [string]$manifest.snapshot_sha256
    dist_sha256 = [string]$manifest.dist_sha256
    validation_summary = [ordered]@{ rollback_validation = 'passed' }
    previous_active_sha = [string]$previousActive.active_sha
}
try {
    Write-AtomicJson -Path $activePath -Value $newActive
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/__observatory/healthz" -TimeoutSec 15
    if (-not $health.ok -or $health.active_sha -ne $candidate.sha) { throw 'Health check du rollback invalide.' }
} catch {
    Write-AtomicJson -Path $activePath -Value $previousActive
    throw
}
[pscustomobject]@{ status = 'rolled_back'; active_sha = $candidate.sha; previous_sha = [string]$previousActive.active_sha }
