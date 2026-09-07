[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Godot\4.7.1\Godot_v4.7.1-stable_win64.exe',
    [string]$Resolution = '1536x1024'
)

$ErrorActionPreference = 'Stop'
$sanctuaryProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
if (-not (Test-Path -LiteralPath (Join-Path $sanctuaryProjectRoot 'project.godot') -PathType Leaf)) {
    throw 'Le projet Dungeon Draft est introuvable.'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot est introuvable. Indiquez son executable avec -GodotPath.'
}
if ($Resolution -notmatch '^\d{3,5}x\d{3,5}$') {
    throw 'La resolution doit prendre la forme 1536x1024.'
}
$sanctuaryArguments = @(
    '--path', $sanctuaryProjectRoot,
    '--rendering-method', 'gl_compatibility',
    '--resolution', $Resolution,
    '--scene', 'res://hub/sanctuary_prototype/SanctuaryPrototype.tscn'
)
& $GodotPath @sanctuaryArguments
exit $LASTEXITCODE
