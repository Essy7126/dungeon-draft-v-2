# Run the unchanged Studio service in a minimal, separate project. This does not
# import, open or mutate the main project while its shared engine lock is held.
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$isolationRoot = Join-Path $projectRoot 'artifacts/dev/class_card_vfx/convergence/workshop_project'
[IO.Directory]::CreateDirectory($isolationRoot) | Out-Null
function Copy-ExactTree([string]$source, [string]$destination) {
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
        $output = Join-Path $destination $relative
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output)) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $output -Force
    }
}
$service = 'addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd'
$exporter = 'tools/class_card_vfx/convergence/export_workshop.gd'
foreach ($relative in @($service, $exporter, 'vfx/class_cards/convergence/provenance.json')) {
    $output = Join-Path $isolationRoot $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output)) | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $output -Force
}
$renders = 'artifacts/dev/class_card_vfx/convergence/render'
Copy-ExactTree (Join-Path $projectRoot $renders) (Join-Path $isolationRoot $renders)
@'
config_version=5
[application]
config/name="Convergence VFX Studio export"
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $isolationRoot 'project.godot')
$godotPath = (Get-Content (Join-Path $projectRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
$logPath = Join-Path $isolationRoot 'export.log'
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $isolationRoot 'appdata'
    $env:LOCALAPPDATA = $env:APPDATA
    [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
    & $godotPath --headless --path $isolationRoot --script ('res://' + $exporter) *> $logPath
    $exportExit = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
if ($exportExit -ne 0 -or (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'Isolated Studio export failed.' }
$jsonLine = Get-Content -LiteralPath $logPath | Where-Object { $_.StartsWith('{"clips":') -or $_.StartsWith('{"ok":') } | Select-Object -Last 1
$result = $jsonLine | ConvertFrom-Json
if (-not $result.ok -or $result.clips.Count -ne 4) { throw 'Four complete clip exports are required.' }
foreach ($clip in $result.clips) {
    if (-not $clip.ok -or -not $clip.pixel_roundtrip) { throw 'Studio did not verify pixel roundtrip.' }
    $relative = $clip.directory.Replace('res://', '')
    if (-not $relative.StartsWith('artifacts/sprite_workshop/convergence_')) { throw 'Unexpected export destination.' }
    Copy-ExactTree (Join-Path $isolationRoot $relative) (Join-Path $projectRoot $relative)
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $isolationRoot 'art/source/sprite_workshop') -Filter 'convergence_*.json') {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $projectRoot ('art/source/sprite_workshop/' + $file.Name)) -Force
}
$serviceHash = (Get-FileHash -LiteralPath (Join-Path $projectRoot $service) -Algorithm SHA256).Hash
if ($serviceHash -ne (Get-FileHash -LiteralPath (Join-Path $isolationRoot $service) -Algorithm SHA256).Hash) { throw 'Studio service changed during export.' }
@{passed=$true;isolated_project=$isolationRoot;unchanged_studio_service_sha256=$serviceHash;clips=$result.clips} | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $projectRoot 'artifacts/dev/class_card_vfx/convergence/workshop_report.json')
@{passed=$true;clips=$result.clips.Count;pixel_roundtrip=$true} | ConvertTo-Json


