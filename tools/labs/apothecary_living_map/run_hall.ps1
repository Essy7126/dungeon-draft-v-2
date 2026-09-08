[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [string]$Resolution = '1600x1000'
)

$ErrorActionPreference = 'Stop'
$hallProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
if (-not $GodotPath) {
    $hallCandidates = @(
        'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64.exe',
        'C:/Users/p.montebello/Desktop/Utile/G/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'
    )
    $GodotPath = $hallCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot est introuvable. Utilisez -GodotPath avec son chemin.'
}
if ($Resolution -notmatch '^\d{3,5}x\d{3,5}$') {
    throw 'La résolution doit prendre la forme 1600x1000.'
}
& $GodotPath --path $hallProjectRoot --rendering-method gl_compatibility --resolution $Resolution --scene res://tools/labs/apothecary_living_map/PlayableHall.tscn
exit $LASTEXITCODE
