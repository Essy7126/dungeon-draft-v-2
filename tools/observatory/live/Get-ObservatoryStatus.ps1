[CmdletBinding()]
param(
    [string]$DeployRoot = (Join-Path $env:LOCALAPPDATA 'DungeonDraftObservatory'),
    [ValidateRange(1, 65535)][int]$Port = 8080
)

$ErrorActionPreference = 'Stop'
$configPath = Join-Path $DeployRoot 'config\live-config.json'
$activePath = Join-Path $DeployRoot 'state\active.json'
$statusPath = Join-Path $DeployRoot 'state\status.json'
$config = if (Test-Path -LiteralPath $configPath) { Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
if ($config -and $config.port) { $Port = [int]$config.port }
$active = if (Test-Path -LiteralPath $activePath) { Get-Content -LiteralPath $activePath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
$status = if (Test-Path -LiteralPath $statusPath) { Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
$health = $null
try { $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/__observatory/healthz" -TimeoutSec 3 }
catch { }

[pscustomobject]@{
    configured = $null -ne $config
    active_sha = if ($active) { [string]$active.active_sha } else { '' }
    update_status = if ($status) { [string]$status.update_status } else { 'unknown' }
    detected_sha = if ($status) { [string]$status.detected_sha } else { '' }
    last_success_at_utc = if ($status) { [string]$status.last_success_at_utc } else { '' }
    last_failure_at_utc = if ($status) { [string]$status.last_failure_at_utc } else { '' }
    message = if ($status) { [string]$status.message } else { 'Statut local absent.' }
    server_online = $null -ne $health -and $health.ok -eq $true
    url = "http://127.0.0.1:$Port/"
}
