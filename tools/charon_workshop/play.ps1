#requires -Version 7.2
[CmdletBinding()]
param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$charonEngine = Resolve-DevGodot $GodotPath
& $charonEngine --path (Get-DevRoot) res://tools/charon_workshop/charon_lab.tscn
exit $LASTEXITCODE
