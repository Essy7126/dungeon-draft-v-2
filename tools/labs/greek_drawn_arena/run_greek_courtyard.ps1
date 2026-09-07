param(
    [string]$GodotPath = 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64.exe',
    [switch]$Capture,
    [switch]$Verify,
    [switch]$KeepOpen
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) {
    throw 'The Dungeon Draft project could not be located.'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot executable not found. Pass -GodotPath with the installed executable path.'
}
$launchArgs = @('--path', $projectRoot, '--resolution', '1920x1080',
    'res://tools/labs/greek_drawn_arena/GreekDrawnCourtyard.tscn')
$userArgs = @()
if ($Capture) {
    $userArgs += '--capture'
    if (-not $KeepOpen) { $userArgs += '--capture-quit' }
} elseif ($Verify) {
    $userArgs += '--verify'
}
if ($userArgs.Count -gt 0) { $launchArgs += @('--') + $userArgs }
& $GodotPath @launchArgs
exit $LASTEXITCODE
