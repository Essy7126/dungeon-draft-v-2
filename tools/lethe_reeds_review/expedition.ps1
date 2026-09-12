#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [ValidateSet('1600x900', '1920x1080', '1200x896')][string]$Resolution = '1600x900',
    [ValidateRange(0, 55)][int]$WaitForEngineSeconds = 55
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root = Get-DevRoot
$run = New-DevRun 'lethe-reeds-expedition'
$lock = $null
$process = $null
$engineErrors = @()
$checks = [ordered]@{}
$captures = @()
$encounterChecks = @()
try {
    $godot = Resolve-DevGodot $GodotPath
    $deadline = [DateTime]::UtcNow.AddSeconds($WaitForEngineSeconds)
    while (-not $lock) {
        try {
            $lock = [IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),
                [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        } catch [IO.IOException] {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'Engine lock unavailable after the permitted wait' }
            Start-Sleep -Milliseconds 500
        }
    }
    $userdata = Join-Path $run 'userdata'
    [IO.Directory]::CreateDirectory($userdata) | Out-Null
    $environment = @{APPDATA=$userdata; LOCALAPPDATA=$userdata; XDG_DATA_HOME=$userdata}
    $version = Invoke-DevProcess $godot @('--version') $root $run 'version' 15 $environment
    $versionFile = Join-Path $run 'version.stdout.log'
    $versionText = if (Test-Path -LiteralPath $versionFile -PathType Leaf) { [IO.File]::ReadAllText($versionFile).Trim() } else { '' }
    $versionErrors = @(Get-DevEngineErrors $run 'version' | Sort-Object -Unique)
    $checks.version = (Test-DevProcessSuccess $version) -and $versionErrors.Count -eq 0 -and $versionText -match (Get-DevToolchain).godot_version_pattern
    if (-not $checks.version) { throw "Godot version check failed: $($versionErrors -join ' | ')" }
    $relative = 'res://' + [IO.Path]::GetRelativePath($root, $run).Replace('\', '/')
    $arguments = @(
        '--path', $root, '--single-window', '--rendering-method', 'gl_compatibility',
        '--audio-driver', 'Dummy', '--resolution', $Resolution, '--position', '-3000,-3000',
        '--log-file', (Join-Path $run 'preview.engine.log'),
        'res://tools/run_explorer/RunExplorerPreview.tscn', '--',
        "--explorer-output=$relative", '--explorer-seed=2401', '--explorer-node=d05_1',
        '--explorer-mode=play', '--explorer-capture'
    )
    $process = Invoke-DevProcess $godot $arguments $root $run 'preview' 120 $environment
    $engineErrors = @(Get-DevEngineErrors $run 'preview' | Sort-Object -Unique)
    $checks.process = Test-DevProcessSuccess $process
    $checks.engine_logs = $engineErrors.Count -eq 0
    if (-not $checks.process -or -not $checks.engine_logs) { throw "Production capture process failed: $($engineErrors -join ' | ')" }
    $previewFile = Join-Path $run 'preview.json'
    if (-not (Test-Path -LiteralPath $previewFile -PathType Leaf)) { throw 'preview.json missing: incomplete production capture' }
    $preview = Get-Content -LiteralPath $previewFile -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    if ($preview -isnot [Collections.IDictionary]) { throw 'Invalid preview report' }
    $node = $preview['node']
    $checks.ready = $preview['started'] -eq $true -and $preview['ready'] -eq $true
    $checks.current_node = $preview['current_node'] -eq 'd05_1' -and $preview['mode'] -eq 'play'
    $checks.node_identity = $node -is [Collections.IDictionary] -and $node['id'] -eq 'd05_1' -and
        $node['title'] -eq 'Les roseaux du tireur' -and $node['depth'] -eq 5 -and
        $node['kind'] -eq 'normal' -and $node['reward'] -eq 'ranged'
    $checks.scene = $preview['scene'] -eq 'res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn'
    $width, $height = $Resolution.Split('x') | ForEach-Object { [int]$_ }
    $reportedSize = @($preview['resolution'])
    $checks.resolution = $reportedSize.Count -eq 2 -and $reportedSize[0] -eq $width -and $reportedSize[1] -eq $height
    $actualUserdata = [IO.Path]::GetFullPath([string]$preview['isolated_userdata']).Replace('\', '/').TrimEnd('/')
    $expectedUserdata = [IO.Path]::GetFullPath($userdata).Replace('\', '/').TrimEnd('/') + '/'
    $checks.isolated_userdata = $actualUserdata.StartsWith($expectedUserdata, [StringComparison]::OrdinalIgnoreCase)

    $preparationFile = Join-Path $run 'preparation.json'
    if (-not (Test-Path -LiteralPath $preparationFile -PathType Leaf)) { throw 'Preparation fixture checkpoint missing' }
    $envelope = Get-Content -LiteralPath $preparationFile -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    if ($envelope -isnot [Collections.IDictionary] -or $envelope['payload'] -isnot [string]) { throw 'Invalid preparation envelope' }
    $payloadBytes = [Text.Encoding]::UTF8.GetBytes($envelope['payload'])
    $payloadHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($payloadBytes)).ToLowerInvariant()
    $checks.fixture_integrity = $payloadHash -ceq $envelope['sha256']
    $snapshot = $envelope['payload'] | ConvertFrom-Json -AsHashtable
    if ($snapshot -isnot [Collections.IDictionary] -or $snapshot['session'] -isnot [Collections.IDictionary]) { throw 'Invalid expedition fixture snapshot' }
    $route = $snapshot['session']['route']
    $checks.fixture_route = $route -is [Collections.IDictionary] -and $route['seed'] -eq 2401 -and
        $route['current_node_id'] -eq 'd05_1' -and $route['phase'] -eq 'combat' -and
        @($route['completed_node_ids']) -contains 'd04_2'

    # Current Explorer reports expose route state, not the instantiated enemy roster.
    # Validate a catalog-style pack if a future report includes its roles explicitly.
    foreach ($document in @(@{name='preview'; value=$preview}, @{name='preparation'; value=$snapshot})) {
        foreach ($key in @('pack', 'encounter')) {
            $pack = $document.value[$key]
            if ($pack -is [Collections.IDictionary] -and $pack.Contains('roles')) {
                $roles = @($pack['roles'])
                $valid = $roles.Count -eq 3 -and @($roles | Where-Object { $_ -ne 'archer' }).Count -eq 0
                if ($pack.Contains('name')) { $valid = $valid -and $pack['name'] -eq 'Les roseaux sifflants' }
                if ($pack.Contains('count')) { $valid = $valid -and $pack['count'] -eq 3 }
                $encounterChecks += @{source=($document.name + '.' + $key); passed=$valid; roles=$roles}
                if (-not $valid) { throw 'The reported encounter is not the expected three archers' }
            }
        }
    }
    $captures = @(Get-ChildItem -LiteralPath $run -Filter 'capture-*.png' -File | Sort-Object Name)
    $checks.capture_present = $captures.Count -gt 0
    if (-not $checks.capture_present) { throw 'No production capture PNG was written' }
    Add-Type -AssemblyName System.Drawing
    foreach ($capture in $captures) {
        if ($capture.Length -le 0) { throw "Empty capture: $($capture.FullName)" }
        $bitmap = $null
        try {
            $bitmap = [Drawing.Image]::FromFile($capture.FullName)
            if ($bitmap.Width -ne $width -or $bitmap.Height -ne $height) { throw "Capture resolution mismatch: $($capture.FullName)" }
        } finally { if ($bitmap) { $bitmap.Dispose() } }
    }
    $checks.capture_resolution = $true
    $failed = @($checks.Keys | Where-Object { $checks[$_] -ne $true })
    if ($failed.Count -gt 0) { throw "Production evidence failed: $($failed -join ', ')" }
    Write-DevJson (Join-Path $run 'summary.json') @{
        passed=$true; reports=$run; node_id='d05_1'; title='Les roseaux du tireur'; seed=2401;
        resolution=$Resolution; checks=$checks; process=$process; errors=$engineErrors;
        preview=$previewFile; preparation=$preparationFile; captures=@($captures.FullName);
        encounter=@{reported=($encounterChecks.Count -gt 0); checks=$encounterChecks;
            expected_roles=@('archer','archer','archer');
            note='Explorer currently reports route state only; absent roster evidence is not a roster validation.'}
    }
    Get-Content -LiteralPath (Join-Path $run 'summary.json') -Encoding utf8
} catch {
    Write-DevJson (Join-Path $run 'summary.json') @{
        passed=$false; reports=$run; node_id='d05_1'; seed=2401; resolution=$Resolution;
        checks=$checks; process=$process; errors=$engineErrors; error=$_.Exception.Message;
        captures=@($captures | ForEach-Object { $_.FullName }); encounter_checks=$encounterChecks
    }
    Get-Content -LiteralPath (Join-Path $run 'summary.json') -Encoding utf8
    exit 1
} finally { if ($lock) { $lock.Dispose() } }
