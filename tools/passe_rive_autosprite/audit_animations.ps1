#requires -Version 7.2
param([ValidateSet('before','after')][string]$Phase='before')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$taskRoot = Get-DevRoot
$taskOutput = Join-Path $taskRoot "artifacts/dev/passe_rive_animation_audit/$Phase"
[IO.Directory]::CreateDirectory($taskOutput) | Out-Null
$taskData = Join-Path $taskOutput 'appdata'
[IO.Directory]::CreateDirectory($taskData) | Out-Null
$taskStarted = [DateTime]::UtcNow
$process = Invoke-DevProcess (Resolve-DevGodot) @('--headless','--path',$taskRoot,'res://tools/passe_rive_autosprite/AnimationAudit.tscn','--',"--output=res://artifacts/dev/passe_rive_animation_audit/$Phase") $taskRoot $taskOutput 'engine' 90 @{APPDATA=$taskData;LOCALAPPDATA=$taskData}
$taskReport = Join-Path $taskOutput 'runtime.json'
$errors = @(Get-DevEngineErrors $taskOutput 'engine')
$ok = (Test-DevProcessSuccess $process) -and $errors.Count -eq 0 -and (Test-Path $taskReport) -and (Get-Item $taskReport).LastWriteTimeUtc -ge $taskStarted
$summary = @{ok=$ok;errors=$errors;process=$process;report=$taskReport}
Write-DevJson (Join-Path $taskOutput 'summary.json') $summary
$summary | ConvertTo-Json -Depth 6
if (-not $ok) {exit 1}
