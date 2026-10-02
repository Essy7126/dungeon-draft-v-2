[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReleasePath,
    [string]$ExpectedSha = ''
)

$ErrorActionPreference = 'Stop'

function Get-ObservatoryDirectoryHash {
    param([Parameter(Mandatory = $true)][string]$Path)
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

$releaseRoot = [System.IO.Path]::GetFullPath($ReleasePath)
$manifestPath = Join-Path $releaseRoot 'release.json'
$distPath = Join-Path $releaseRoot 'dist'
$snapshotPath = Join-Path $distPath 'data\latest.json'
$indexPath = Join-Path $distPath 'index.html'

foreach ($requiredPath in @($manifestPath, $snapshotPath, $indexPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Release incomplète : $([System.IO.Path]::GetFileName($requiredPath)) est absent."
    }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.status -ne 'validated') { throw 'release.json ne porte pas le statut validated.' }
if ($ExpectedSha -and $manifest.source_commit -ne $ExpectedSha) {
    throw "SHA de release inattendu : $($manifest.source_commit)."
}
$snapshot = Get-Content -LiteralPath $snapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($snapshot.meta.source_game_commit -ne $manifest.source_commit) {
    throw 'La provenance du snapshot ne correspond pas à release.json.'
}
$snapshotHash = (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($snapshotHash -ne $manifest.snapshot_sha256) { throw 'Hash SHA256 du snapshot invalide.' }
$distHash = Get-ObservatoryDirectoryHash -Path $distPath
if ($distHash -ne $manifest.dist_sha256) { throw 'Hash SHA256 du dossier dist invalide.' }

$manifestText = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
if ($manifestText -match '(?i)[A-Z]:\\Users\\|/home/[^/]+/') {
    throw 'release.json contient un chemin utilisateur absolu.'
}

[pscustomobject]@{
    valid = $true
    source_commit = [string]$manifest.source_commit
    snapshot_sha256 = $snapshotHash
    dist_sha256 = $distHash
}
