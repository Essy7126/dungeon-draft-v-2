param(
    [string]$Godot = 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe',
    [string]$Batch = 'final_boss_production',
    [switch]$Capture
)
$ErrorActionPreference = 'Stop'
if ($Batch -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Batch must be a simple directory name.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$relative = "artifacts/paris_sprite_validation_v1/$Batch"
$output = Join-Path $repo $relative
New-Item -ItemType Directory -Force -Path $output | Out-Null
$mode = if ($Capture) { '--capture-clip' } else { '--no-screenshots' }
$arguments = @('--path', $repo, '--resolution', '1440x900',
    'res://tools/paris_sprite_validation/FinalBossProductionValidation.tscn', '--',
    $mode, "--artifact-dir=res://$relative")
$process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden `
    -WorkingDirectory $repo -RedirectStandardOutput (Join-Path $output 'stdout.log') `
    -RedirectStandardError (Join-Path $output 'stderr.log') -PassThru
$finished = $process.WaitForExit(180000)
if (-not $finished) {
    $process.Kill()
    $process.WaitForExit()
}
$reportPath = Join-Path $output 'runtime_validation.json'
$report = if (Test-Path -LiteralPath $reportPath) {
    Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
} else { $null }
$runtimeErrors = @(Get-Content -LiteralPath (Join-Path $output 'stderr.log'), (Join-Path $output 'stdout.log') |
    Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:)' -and
        $_ -notmatch 'resources still in use at exit|RID allocations .* were leaked at exit|Pages in use exist at exit in PagedAllocator: N12VariantPools12BucketMediumE' })
$result = [ordered]@{ name = 'final_boss_production'; exit_code = $process.ExitCode; timed_out = -not $finished;
    capture = [bool]$Capture; ok = $finished -and $process.ExitCode -eq 0 -and $null -ne $report -and $report.ok -and $runtimeErrors.Count -eq 0;
    errors = if ($null -ne $report) { @($report.errors) } else { @('missing_runtime_report') };
    runtime_errors = $runtimeErrors; report = "$relative/runtime_validation.json" }
[IO.File]::WriteAllText((Join-Path $output 'summary.json'),
    ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Output ($result | ConvertTo-Json -Depth 4 -Compress)
if (-not $result.ok) { exit 1 }
exit 0
