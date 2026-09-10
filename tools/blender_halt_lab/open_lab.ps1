#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$BlenderPath='C:/Program Files/Blender Foundation/Blender 5.1/blender.exe',
    [string]$AddonPath='C:/Users/paolo/AppData/Roaming/Blender Foundation/Blender/5.1/scripts/addons/blender_mcp.py'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$profile=Join-Path $root 'artifacts/dev/blender-halt-profile'
if (-not (Test-Path -LiteralPath $BlenderPath)) { throw 'Blender executable missing.' }
if (-not (Test-Path -LiteralPath $AddonPath)) { throw 'Installed compatible Blender MCP addon missing.' }
$listener=Get-NetTCPConnection -LocalPort 9877 -State Listen -ErrorAction SilentlyContinue
if ($listener) { throw 'Port 9877 is already occupied. Check client.py before opening another lab.' }
foreach ($part in @('config','scripts/addons','extensions','logs')) {
    [IO.Directory]::CreateDirectory((Join-Path $profile $part)) | Out-Null
}
# Exact copy of the already installed compatible addon; no shared preferences edited.
Copy-Item -LiteralPath $AddonPath -Destination (Join-Path $profile 'scripts/addons/blender_mcp.py') -Force
$environment=@{
    BLENDER_USER_CONFIG=(Join-Path $profile 'config')
    BLENDER_USER_SCRIPTS=(Join-Path $profile 'scripts')
    BLENDER_USER_EXTENSIONS=(Join-Path $profile 'extensions')
}
$previous=@{}
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
try {
    foreach ($entry in $environment.GetEnumerator()) {
        $previous[$entry.Key]=[Environment]::GetEnvironmentVariable($entry.Key,'Process')
        [Environment]::SetEnvironmentVariable($entry.Key,$entry.Value,'Process')
    }
    $bootstrap=Join-Path $PSScriptRoot 'bootstrap.py'
    $arguments="--factory-startup --window-geometry 850 100 1050 800 --python-exit-code 23 --python `"$bootstrap`""
    # A visible second window was explicitly requested for the map task.
    $process=Start-Process -FilePath $BlenderPath -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Normal -PassThru -RedirectStandardOutput (Join-Path $profile "logs/$stamp.stdout.log") -RedirectStandardError (Join-Path $profile "logs/$stamp.stderr.log")
    @{pid=$process.Id;port=9877;profile=$profile;status='starting';log_stamp=$stamp} | ConvertTo-Json
} finally {
    foreach ($entry in $previous.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key,$entry.Value,'Process')
    }
}
