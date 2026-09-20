param([switch]$Capture, [string]$GodotPath)
$ErrorActionPreference = 'Stop'
$healRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
if (-not $GodotPath) {
    $healConfig = Get-Content -LiteralPath (Join-Path $healRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json
    $GodotPath = $healConfig.godot_path
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Indiquer le moteur Godot avec -GodotPath.' }
$healOutput = Join-Path $healRoot 'artifacts/dev/heal_vfx_study'
New-Item -ItemType Directory -Path $healOutput -Force | Out-Null
$healArgs = @('--path', $PSScriptRoot, '--log-file', (Join-Path $healOutput 'interactive.log'))
if ($Capture) { $healArgs += @('--', '--capture') }
& $GodotPath @healArgs
if ($LASTEXITCODE -ne 0) { throw "Godot a retourné le code $LASTEXITCODE." }
if ($Capture) {
    if (Select-String -LiteralPath (Join-Path $healOutput 'interactive.log') -Pattern 'ERROR:|SCRIPT ERROR:' -Quiet) {
        throw 'Consulter interactive.log : diagnostic moteur présent.'
    }
    & node (Join-Path $PSScriptRoot 'assemble.cjs') --encode
    if ($LASTEXITCODE -ne 0) { throw 'Assemblage de la capture incomplet.' }
}
