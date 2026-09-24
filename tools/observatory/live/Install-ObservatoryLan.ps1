[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [string]$NodePath = 'node.exe',
    [string]$DeployRoot = (Join-Path $env:LOCALAPPDATA 'DungeonDraftObservatory'),
    [string]$Remote = 'origin',
    [string]$Branch = 'main',
    [ValidateRange(1, 65535)][int]$Port = 8080,
    [ValidateRange(1, 1440)][int]$PollMinutes = 5,
    [ValidateRange(1, 50)][int]$RetentionCount = 5,
    [switch]$ConfigureFirewall,
    [switch]$NoScheduledTasks,
    [switch]$NoFirewall,
    [switch]$FullValidation
)

$ErrorActionPreference = 'Stop'
$serverTaskName = 'Dungeon Draft Observatory - Server'
$updateTaskName = 'Dungeon Draft Observatory - Update'
$firewallName = "Dungeon Draft Observatory LAN $Port"

function Get-NativeVersion {
    param([string]$Executable, [string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Executable @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($code -ne 0) { throw "Impossible de vérifier $Executable (code $code) : $($output -join "`n")" }
    $firstLine = @($output | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() }) | Select-Object -First 1
    if (-not $firstLine) { throw "Version vide pour $Executable." }
    return $firstLine.Trim()
}

if ($Branch -ne 'main' -and -not $NoScheduledTasks) {
    throw 'Une branche de preview exige -NoScheduledTasks.'
}
if ($Branch -ne 'main' -and -not $NoFirewall) {
    throw 'Une branche de preview exige -NoFirewall.'
}
$repo = [System.IO.Path]::GetFullPath($RepositoryRoot)
if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) { throw 'Dépôt Git introuvable.' }
$gitPath = (Get-Command git.exe -ErrorAction Stop).Source
$resolvedNode = (Get-Command $NodePath -ErrorAction Stop).Source
$npmPath = Join-Path (Split-Path -Parent $resolvedNode) 'npm.cmd'
if (-not (Test-Path -LiteralPath $npmPath)) { $npmPath = (Get-Command npm.cmd -ErrorAction Stop).Source }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'GodotPath introuvable.' }

$gitVersion = Get-NativeVersion -Executable $gitPath -Arguments @('--version')
$nodeVersion = Get-NativeVersion -Executable $resolvedNode -Arguments @('--version')
$npmVersion = Get-NativeVersion -Executable $npmPath -Arguments @('--version')
$godotVersion = Get-NativeVersion -Executable $GodotPath -Arguments @('--version')
if ($godotVersion -notmatch '^4\.7\.1\.') { throw "Godot 4.7.1 stable requis, reçu $godotVersion." }

if ($Branch -eq 'main' -and -not $NoScheduledTasks) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $fetchOutput = & $gitPath -C $repo fetch $Remote main --prune 2>&1
        $fetchCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($fetchCode -ne 0) { throw "Impossible de vérifier origin/main : $($fetchOutput -join "`n")" }
    $installerCommit = (& $gitPath -C $repo rev-parse HEAD).Trim()
    & $gitPath -C $repo merge-base --is-ancestor $installerCommit "$Remote/main"
    if ($LASTEXITCODE -ne 0) {
        throw "Installation permanente refusée : le commit V1.2 courant n'est pas fusionné dans origin/main."
    }
}

foreach ($directory in @('config', 'runtime', 'releases', 'state', 'logs', 'locks', 'worktrees')) {
    [System.IO.Directory]::CreateDirectory((Join-Path $DeployRoot $directory)) | Out-Null
}
$runtimeSource = $PSScriptRoot
foreach ($file in Get-ChildItem -LiteralPath $runtimeSource -File) {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $DeployRoot "runtime\$($file.Name)") -Force
}

$config = [ordered]@{
    repository_root = $repo
    remote = $Remote
    branch = $Branch
    godot_path = [System.IO.Path]::GetFullPath($GodotPath)
    node_path = $resolvedNode
    npm_path = $npmPath
    deploy_root = [System.IO.Path]::GetFullPath($DeployRoot)
    port = $Port
    poll_minutes = $PollMinutes
    retention_count = $RetentionCount
    full_validation = [bool]$FullValidation
    installed_at_utc = [DateTime]::UtcNow.ToString('o')
    versions = [ordered]@{ git = $gitVersion; node = $nodeVersion; npm = $npmVersion; godot = $godotVersion }
}
$configPath = Join-Path $DeployRoot 'config\live-config.json'
[System.IO.File]::WriteAllText(
    $configPath,
    (($config | ConvertTo-Json -Depth 10) + "`n"),
    (New-Object System.Text.UTF8Encoding($false))
)

$serverScript = Join-Path $DeployRoot 'runtime\Start-ObservatoryLan.ps1'
$serverProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $serverScript,
    '-DeployRoot', $DeployRoot
) -WindowStyle Hidden -PassThru
Start-Sleep -Milliseconds 600
if ($serverProcess.HasExited) { throw "Le serveur LAN n'a pas démarré (code $($serverProcess.ExitCode))." }

$updateCommandArguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    (Join-Path $DeployRoot 'runtime\Update-ObservatoryLive.ps1'),
    '-RepositoryRoot', $repo, '-Remote', $Remote, '-Branch', $Branch,
    '-GodotPath', $GodotPath, '-NodePath', $resolvedNode,
    '-DeployRoot', $DeployRoot, '-Port', [string]$Port,
    '-RetentionCount', [string]$RetentionCount, '-Force'
)
if ($FullValidation) { $updateCommandArguments += '-FullValidation' }
if ($Branch -ne 'main') { $updateCommandArguments += '-AllowPreviewBranch' }
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $updateOutput = & "$PSHOME\powershell.exe" @updateCommandArguments 2>&1
    $updateCode = $LASTEXITCODE
} finally { $ErrorActionPreference = $previousPreference }
if ($updateCode -ne 0) {
    $pidPath = Join-Path $DeployRoot 'state\server.pid'
    if (Test-Path -LiteralPath $pidPath) {
        $serverPid = 0
        if ([int]::TryParse((Get-Content -LiteralPath $pidPath -Raw).Trim(), [ref]$serverPid)) {
            Stop-Process -Id $serverPid -Force -ErrorAction SilentlyContinue
        }
    }
    Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
    throw "La première publication a échoué : $($updateOutput -join "`n")"
}

if (-not $NoScheduledTasks) {
    $principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $serverAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$serverScript`" -DeployRoot `"$DeployRoot`""
    $serverTrigger = New-ScheduledTaskTrigger -AtLogOn -User ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $serverSettings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $serverTaskName -Action $serverAction -Trigger $serverTrigger -Principal $principal -Settings $serverSettings -Force | Out-Null

    $updateScript = Join-Path $DeployRoot 'runtime\Update-ObservatoryLive.ps1'
    $updateActionArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$updateScript`" -RepositoryRoot `"$repo`" -Remote `"$Remote`" -Branch main -GodotPath `"$GodotPath`" -NodePath `"$resolvedNode`" -DeployRoot `"$DeployRoot`" -Port $Port -RetentionCount $RetentionCount"
    if ($FullValidation) { $updateActionArguments += ' -FullValidation' }
    $updateAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $updateActionArguments
    $updateLogonTrigger = New-ScheduledTaskTrigger -AtLogOn -User ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $updateTimerTrigger = New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddMinutes(1)) -RepetitionInterval (New-TimeSpan -Minutes $PollMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
    $updateSettings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $updateTaskName -Action $updateAction -Trigger @($updateLogonTrigger, $updateTimerTrigger) -Principal $principal -Settings $updateSettings -Force | Out-Null
}

$firewallStatus = 'NOT_REQUESTED'
if ($ConfigureFirewall -and -not $NoFirewall) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Get-NetFirewallRule -DisplayName $firewallName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName $firewallName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Private -RemoteAddress LocalSubnet | Out-Null
        $firewallStatus = 'CONFIGURED'
    } else {
        $firewallStatus = 'FIREWALL_CONFIGURATION_PENDING'
        Write-Warning "FIREWALL_CONFIGURATION_PENDING"
        Write-Warning "Commande administrateur : New-NetFirewallRule -DisplayName '$firewallName' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Private -RemoteAddress LocalSubnet"
    }
}

[pscustomobject]@{
    status = 'installed'
    deploy_root = $DeployRoot
    url = "http://127.0.0.1:$Port/"
    scheduled_tasks = -not $NoScheduledTasks
    firewall = $firewallStatus
}
