[CmdletBinding()]
param(
    [string]$DeployRoot = (Join-Path $env:LOCALAPPDATA 'DungeonDraftObservatory')
)

$ErrorActionPreference = 'Stop'
$configPath = Join-Path $DeployRoot 'config\live-config.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw 'Configuration Observatory absente.'
}
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$serverPath = Join-Path $DeployRoot 'runtime\observatory-lan-server.mjs'
if (-not (Test-Path -LiteralPath $serverPath -PathType Leaf)) { throw 'Serveur runtime absent.' }
$server = Start-Process -FilePath ([string]$config.node_path) -ArgumentList @(
    "`"$serverPath`"",
    "`"--deploy-root=$DeployRoot`"",
    '--host=0.0.0.0',
    "--port=$($config.port)"
) -WindowStyle Hidden -PassThru
$pidPath = Join-Path $DeployRoot 'state\server.pid'
[System.IO.File]::WriteAllText($pidPath, ([string]$server.Id + "`n"), (New-Object System.Text.UTF8Encoding($false)))
try {
    $server.WaitForExit()
    exit $server.ExitCode
} finally {
    if (Test-Path -LiteralPath $pidPath) {
        $recordedPid = (Get-Content -LiteralPath $pidPath -Raw).Trim()
        if ($recordedPid -eq [string]$server.Id) { Remove-Item -LiteralPath $pidPath -Force }
    }
}
