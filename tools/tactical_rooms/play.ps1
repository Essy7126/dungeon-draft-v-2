#requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('forge','garden','convoy','hourglass','reservoir')][string]$Room = 'forge',
    [string]$GodotPath = ''
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$roomEngine = Resolve-DevGodot $GodotPath
& $roomEngine --path (Get-DevRoot) res://tools/tactical_rooms/Preview.tscn -- "--room=$Room"
exit $LASTEXITCODE
