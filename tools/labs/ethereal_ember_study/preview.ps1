param([switch]$Capture, [string]$GodotPath)
$ErrorActionPreference = 'Stop'
$emberRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
if (-not $GodotPath) {
    $GodotPath = (Get-Content -LiteralPath (Join-Path $emberRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
}
$emberOutput = Join-Path $emberRoot 'artifacts/dev/ethereal_ember_study'
[IO.Directory]::CreateDirectory($emberOutput) | Out-Null
$emberLog = if ($Capture) { 'godot.log' } else { 'interactive.log' }
$emberArgs = @('--path', $PSScriptRoot, '--log-file', (Join-Path $emberOutput $emberLog))
if ($Capture) {
    $emberArgs += @('--', '--capture')
    & $GodotPath @emberArgs
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $emberOutput 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'Capture incomplète : consulter godot.log.' }
} else {
    # The user requested a visible interactive spell preview; hide only the console.
    $emberLaunch = [Diagnostics.ProcessStartInfo]::new($GodotPath)
    foreach ($argument in $emberArgs) { $emberLaunch.ArgumentList.Add($argument) }
    $emberLaunch.UseShellExecute = $false
    $emberLaunch.CreateNoWindow = $true
    [Diagnostics.Process]::Start($emberLaunch) | Out-Null
}
