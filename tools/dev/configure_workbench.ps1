#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$executable=Join-Path $projectRoot 'artifacts/dev-tools/gaw.exe'
if(-not(Test-Path -LiteralPath $executable)){throw 'Install Workbench first: ./dev.ps1 install workbench'}
$names=@(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'workbench-tools.json') -Raw | ConvertFrom-Json)
$configPath=Join-Path $projectRoot '.codex/config.toml'
if(Test-Path -LiteralPath $configPath){
    $existing=[IO.File]::ReadAllText($configPath)
    if($existing -match '(?m)^\[mcp_servers\.godot_workbench\]'){
        Write-Output 'Workbench is already configured. Existing settings preserved.'
        exit 0
    }
}else{$existing=''}
# JSON-quoted strings are valid TOML basic strings; no shell interpolation occurs.
$section=@(
    '[mcp_servers.godot_workbench]',
    ('command = '+($executable | ConvertTo-Json -Compress)),
    ('cwd = '+($projectRoot | ConvertTo-Json -Compress)),
    'args = ["--tool-mode", "lite"]',
    'startup_timeout_sec = 30',
    'tool_timeout_sec = 60',
    ('enabled_tools = '+(ConvertTo-Json -InputObject $names -Compress))
) -join "`n"
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($configPath)) | Out-Null
[IO.File]::WriteAllText($configPath,$existing.TrimEnd()+"`n`n"+$section+"`n")
Write-Output "Workbench configured with $($names.Count) tools. Reload the MCP connection."
