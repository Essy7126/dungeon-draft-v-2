[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$DeployRoot = (Join-Path $env:LOCALAPPDATA 'DungeonDraftObservatory'),
    [ValidateRange(1, 65535)][int]$Port = 8080,
    [switch]$RemoveFirewall,
    [switch]$RemoveData
)

$ErrorActionPreference = 'Stop'

function Remove-ObservatoryDataTree {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($env:OS -ne 'Windows_NT') {
        Remove-Item -LiteralPath $Path -Recurse -Force
        return
    }
    $extendedPath = "\\?\$Path"
    foreach ($file in [System.IO.Directory]::EnumerateFiles(
        $extendedPath,
        '*',
        [System.IO.SearchOption]::AllDirectories
    )) {
        if ([System.IO.File]::GetAttributes($file) -band [System.IO.FileAttributes]::ReadOnly) {
            [System.IO.File]::SetAttributes($file, [System.IO.FileAttributes]::Normal)
        }
    }
    [System.IO.Directory]::Delete($extendedPath, $true)
}

$pidPath = Join-Path $DeployRoot 'state\server.pid'
if (Test-Path -LiteralPath $pidPath -PathType Leaf) {
    $recordedPid = 0
    if ([int]::TryParse((Get-Content -LiteralPath $pidPath -Raw).Trim(), [ref]$recordedPid)) {
        $serverProcess = Get-Process -Id $recordedPid -ErrorAction SilentlyContinue
        $serverCommand = Get-CimInstance Win32_Process -Filter "ProcessId = $recordedPid" -ErrorAction SilentlyContinue
        $expectedServer = Join-Path $DeployRoot 'runtime\observatory-lan-server.mjs'
        $isExactServer = $serverProcess -and
            $serverProcess.ProcessName -eq 'node' -and
            $serverCommand.CommandLine -and
            $serverCommand.CommandLine.Contains($expectedServer) -and
            $serverCommand.CommandLine.Contains("--deploy-root=$DeployRoot")
        if ($isExactServer -and $PSCmdlet.ShouldProcess("PID $recordedPid", 'Arrêter le serveur Observatory')) {
            Stop-Process -Id $recordedPid
        }
    }
    if ($PSCmdlet.ShouldProcess($pidPath, 'Supprimer le PID Observatory')) {
        Remove-Item -LiteralPath $pidPath -Force
    }
}
$taskNames = @('Dungeon Draft Observatory - Server', 'Dungeon Draft Observatory - Update')
foreach ($taskName in $taskNames) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task -and $PSCmdlet.ShouldProcess($taskName, 'Supprimer la tâche planifiée')) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}
if ($RemoveFirewall) {
    $firewallName = "Dungeon Draft Observatory LAN $Port"
    if ($PSCmdlet.ShouldProcess($firewallName, 'Supprimer la règle pare-feu')) {
        Get-NetFirewallRule -DisplayName $firewallName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    }
}
if ($RemoveData -and (Test-Path -LiteralPath $DeployRoot)) {
    $absolute = [System.IO.Path]::GetFullPath($DeployRoot)
    $localAppData = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA)
    if (-not $absolute.StartsWith($localAppData.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refus de supprimer un DeployRoot hors LOCALAPPDATA.'
    }
    if ($PSCmdlet.ShouldProcess($absolute, 'Supprimer les données Observatory')) {
        Remove-ObservatoryDataTree -Path $absolute
    }
}
[pscustomobject]@{ status = 'uninstalled'; data_preserved = -not $RemoveData }
