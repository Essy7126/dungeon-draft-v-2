#requires -Version 7.2
[CmdletBinding()]
param([ValidateSet('formatter', 'workbench', 'all')][string]$Component = 'formatter')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$installRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$cacheRoot = Join-Path $installRoot 'artifacts/dev-tools'
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
[IO.Directory]::CreateDirectory($cacheRoot) | Out-Null
[IO.File]::WriteAllText((Join-Path $cacheRoot '.gdignore'), '')
function Get-VerifiedArchive([string]$Url, [string]$Hash, [string]$Name) {
    $path = Join-Path $cacheRoot $Name
    if (-not (Test-Path -LiteralPath $path)) { Invoke-WebRequest -Uri $Url -OutFile $path }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $Hash) {
        throw "SHA256 mismatch: $path. Download rejected."
    }
    return $path
}
if ($Component -in @('formatter', 'all')) {
    $platform = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } else { throw 'Unsupported platform.' }
    if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') { throw 'Only x64 packages are pinned.' }
    $archive = Get-VerifiedArchive $lock.formatter."${platform}_url" $lock.formatter."${platform}_sha256" 'formatter.zip'
    $destination = Join-Path $cacheRoot ('formatter-' + $lock.formatter.version)
    Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
    $name = if ($IsWindows) { 'gdscript-formatter.exe' } else { 'gdscript-formatter' }
    $candidates = @(Get-ChildItem -LiteralPath $destination -File -Recurse | Where-Object { $_.Name -like 'gdscript-formatter*' -and $_.Extension -ne '.md' })
    if ($candidates.Count -ne 1) { throw 'Formatter executable is ambiguous.' }
    $target = Join-Path $cacheRoot $name
    Copy-Item -LiteralPath $candidates[0].FullName -Destination $target -Force
    if ($IsLinux) { & chmod +x $target; if ($LASTEXITCODE -ne 0) { throw 'chmod failed.' } }
    & $target --version
    if ($LASTEXITCODE -ne 0) { throw 'Formatter startup failed.' }
}
if ($Component -in @('workbench', 'all')) {
    if (-not $IsWindows) { throw 'Workbench integration is configured for Windows.' }
    $archive = Get-VerifiedArchive $lock.workbench.source_url $lock.workbench.source_sha256 'workbench-source.zip'
    $sourceContainer = Join-Path $cacheRoot ('source-' + $lock.workbench.commit)
    Expand-Archive -LiteralPath $archive -DestinationPath $sourceContainer -Force
    $source = (Get-ChildItem -LiteralPath $sourceContainer -Directory | Select-Object -First 1).FullName
    $goArchive = Get-VerifiedArchive $lock.workbench.go_url $lock.workbench.go_sha256 'go.zip'
    $goRoot = Join-Path $cacheRoot $lock.workbench.go_version
    if (-not (Test-Path -LiteralPath (Join-Path $goRoot 'go/bin/go.exe'))) { Expand-Archive -LiteralPath $goArchive -DestinationPath $goRoot }
    $go = Join-Path $goRoot 'go/bin/go.exe'
    $previousCache = $env:GOCACHE; $previousModules = $env:GOMODCACHE
    $previousToolchain = $env:GOTOOLCHAIN
    $previousTemp = $env:TEMP; $previousTmp = $env:TMP
    try {
        $env:GOCACHE = Join-Path $cacheRoot 'go-build-cache'
        $env:GOMODCACHE = Join-Path $cacheRoot 'go-modules'
        $env:GOTOOLCHAIN = 'local'
        # Keep Go fixtures on a canonical path, avoiding Windows 8.3 aliases.
        $env:TEMP = Join-Path $cacheRoot 'test-temp'; $env:TMP = $env:TEMP
        [IO.Directory]::CreateDirectory($env:TEMP) | Out-Null
        Push-Location $source
        try {
            & $go test ./... *> (Join-Path $cacheRoot 'workbench-tests.log')
            if ($LASTEXITCODE -ne 0) { throw 'Workbench tests failed; see artifacts/dev-tools/workbench-tests.log.' }
            & $go build -buildvcs=false -o (Join-Path $cacheRoot 'gaw.exe') ./cmd/gaw
            if ($LASTEXITCODE -ne 0) { throw 'Workbench build failed.' }
        } finally { Pop-Location }
    } finally {
        $env:GOCACHE = $previousCache; $env:GOMODCACHE = $previousModules; $env:GOTOOLCHAIN = $previousToolchain
        $env:TEMP = $previousTemp; $env:TMP = $previousTmp
    }
    # Never overwrite a locally adapted addon during server installation.
    $relative = 'addons/godot_ai_workbench/transport/workbench_bridge_spec.gd'
    if ((Get-FileHash (Join-Path $installRoot $relative)).Hash -ne (Get-FileHash (Join-Path $source ('client-godot/' + $relative))).Hash) {
        throw 'Server built, but addon protocol differs. Review before enabling.'
    }
    Write-Output ('Workbench built and tested: ' + $lock.workbench.commit)
}
