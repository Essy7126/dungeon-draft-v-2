#requires -Version 7.2
param([ValidateSet('entry','combo','shot','hit_death')][string]$Scenario='combo', [ValidateSet('N','E','S','W')][string]$Direction='E', [switch]$TimingOnly, [ValidateSet('base','wrath','chiron','volley','aeacus','counter')][string]$Kit='base')
$ErrorActionPreference='Stop'
$taskRepo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Import-Module (Join-Path $taskRepo 'tools/dev/DevTools.psm1') -Force -DisableNameChecking
$godot = Resolve-DevGodot
$name = if ($Scenario -eq 'entry') {'entry'} else {"${Scenario}_${Direction}_$(if($TimingOnly){'timing'}else{'visual'})"}
if ($Kit -ne 'base') { $name = "${Kit}_$name" }
$relative = "artifacts/dev/passe_rive_autosprite/$name"
$output = Join-Path $taskRepo $relative
[IO.Directory]::CreateDirectory($output) | Out-Null
# Keep Windows shader-cache paths short and isolate every capture's save data.
$captureData = Join-Path $taskRepo ('artifacts/dev/pr-cache/' + [Guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($captureData) | Out-Null
$environment = @{APPDATA=$captureData;LOCALAPPDATA=$captureData}
$arguments = @('--path',$taskRepo,'--position','-16000,-16000','--resolution','1440x900')
if ($Scenario -eq 'entry') {
    $arguments += @('--script','res://tools/passe_rive_autosprite/capture_entry.gd')
} else {
    if ($TimingOnly) { $arguments += '--headless' }
    $arguments += @('res://tools/achilles_kit_sprite_validation/KitSpriteValidation.tscn','--',"--kit=$Kit",'--appearance=passe_rive',"--scenario=$Scenario","--direction=$Direction","--artifact-dir=res://$relative")
    $arguments += $(if ($TimingOnly) {'--no-screenshots'} else {'--capture-clip'})
}
$startedAt = [DateTime]::UtcNow
$process = Invoke-DevProcess $godot $arguments $taskRepo $output 'engine' 150 $environment
$reportPath = Join-Path $output $(if ($Scenario -eq 'entry') {'report.json'} else {'runtime_validation.json'})
$report = if ((Test-Path $reportPath) -and (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -ge $startedAt) {Get-Content $reportPath -Raw | ConvertFrom-Json} else {$null}
$errors = @(Get-DevEngineErrors $output 'engine')
$result = @{ok=(Test-DevProcessSuccess $process) -and $null -ne $report -and $report.ok -and $errors.Count -eq 0;process=$process;report=$reportPath;engine_errors=$errors;appdata=$captureData}
if ($null -ne $report -and $Scenario -ne 'entry') {$result['runtime_errors']=$report.errors}
$result | ConvertTo-Json -Depth 6
Write-DevJson (Join-Path $output 'summary.json') $result
if (-not $result.ok) {exit 1}
