[CmdletBinding()]
param(
    [ValidateSet("Run", "Edit", "Smoke")]
    [string]$Mode = "Run",

    [string]$GodotPath = "",

    [switch]$NoPrompt,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArguments = @()
)

$ErrorActionPreference = "Stop"
if ($Mode -eq "Smoke") {
    $NoPrompt = $true
}
$labScene = "res://tools/labs/vfx_flipbook_foundation/VFXFlipbookFoundationLab.tscn"
$smokeScript = "res://tools/labs/vfx_flipbook_foundation/smoke_vfx_flipbook_lab.gd"
$projectRoot = ""
$stateDirectory = ""
$logDirectory = ""
$cachePath = ""
$logPath = "indisponible (initialisation non terminee)"
$transcriptStarted = $false
$resolvedGodot = $null
$nativeExitCode = $null
$exitCode = 1


function Test-GodotExecutable {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $versionJob = $null
    try {
        $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
        $versionJob = Start-Job -ScriptBlock {
            param([string]$Executable)
            $output = @(& $Executable --version 2>&1)
            [PSCustomObject]@{
                Version = ($output -join " ").Trim()
                ExitCode = $LASTEXITCODE
            }
        } -ArgumentList $resolvedPath
        $completedJob = Wait-Job -Job $versionJob -Timeout 10
        if ($null -eq $completedJob) {
            Stop-Job -Job $versionJob -ErrorAction SilentlyContinue
            return $null
        }
        $versionResult = Receive-Job -Job $versionJob -ErrorAction Stop
        $version = [string]$versionResult.Version
        $versionExitCode = [int]$versionResult.ExitCode
        if ($versionExitCode -ne 0 -or $version -notmatch '^4\.7(?:\.|$)') {
            return $null
        }
        return [PSCustomObject]@{
            Path = $resolvedPath
            Version = $version
            Source = $Source
        }
    } catch {
        return $null
    } finally {
        if ($null -ne $versionJob) {
            Remove-Job -Job $versionJob -Force -ErrorAction SilentlyContinue
        }
    }
}


function Resolve-GodotExecutable {
    param(
        [string]$ExplicitPath,
        [string]$CacheFile,
        [switch]$DisablePrompt
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $explicit = Test-GodotExecutable -Path $ExplicitPath -Source "argument -GodotPath"
        if ($null -eq $explicit) {
            throw "Le chemin Godot explicite est absent, invalide ou n'est pas une version 4.7 : $ExplicitPath"
        }
        return $explicit
    }

    $candidates = New-Object System.Collections.Generic.List[object]
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT4_BIN)) {
        $candidates.Add([PSCustomObject]@{ Path = $env:GODOT4_BIN; Source = "GODOT4_BIN" })
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        $candidates.Add([PSCustomObject]@{ Path = $env:GODOT_BIN; Source = "GODOT_BIN" })
    }
    if (Test-Path -LiteralPath $CacheFile -PathType Leaf) {
        $cached = (Get-Content -Raw -LiteralPath $CacheFile).Trim()
        if (-not [string]::IsNullOrWhiteSpace($cached)) {
            $candidates.Add([PSCustomObject]@{ Path = $cached; Source = "cache utilisateur" })
        }
    }
    foreach ($commandName in @("godot", "godot4")) {
        $command = Get-Command $commandName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) {
            $candidates.Add([PSCustomObject]@{ Path = $command.Source; Source = "Get-Command $commandName" })
        }
    }

    $usualDirectories = New-Object System.Collections.Generic.List[string]
    $usualDirectoryDefinitions = @(
        [PSCustomObject]@{ Base = $env:ProgramFiles; Relative = "Godot" },
        [PSCustomObject]@{ Base = ${env:ProgramFiles(x86)}; Relative = "Godot" },
        [PSCustomObject]@{ Base = $env:LOCALAPPDATA; Relative = "Programs\Godot" },
        [PSCustomObject]@{ Base = $env:USERPROFILE; Relative = "scoop\apps\godot\current" },
        [PSCustomObject]@{ Base = $env:SystemDrive; Relative = "Godot" }
    )
    foreach ($entry in $usualDirectoryDefinitions) {
        if ([string]::IsNullOrWhiteSpace([string]$entry.Base)) {
            continue
        }
        $root = Join-Path ([string]$entry.Base) ([string]$entry.Relative)
        if (-not $usualDirectories.Contains($root)) {
            $usualDirectories.Add($root)
        }
    }
    foreach ($directory in $usualDirectories) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            continue
        }
        $executables = @(
            Get-ChildItem -LiteralPath $directory -Filter "*.exe" -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^Godot.*4\.7|^godot(?:4)?\.exe$' } |
                Sort-Object @{ Expression = { if ($_.Name -match 'console') { 0 } else { 1 } } }, FullName
        )
        foreach ($executable in $executables) {
            $candidates.Add([PSCustomObject]@{ Path = $executable.FullName; Source = "repertoire Windows usuel" })
        }
    }

    $seen = @{}
    foreach ($candidate in $candidates) {
        $key = [string]$candidate.Path
        if ($seen.ContainsKey($key)) {
            continue
        }
        $seen[$key] = $true
        $valid = Test-GodotExecutable -Path $candidate.Path -Source $candidate.Source
        if ($null -ne $valid) {
            return $valid
        }
    }

    if (-not $DisablePrompt -and [Environment]::UserInteractive) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Title = "Selectionner Godot 4.7"
            $dialog.Filter = "Godot 4.7 (Godot*.exe)|Godot*.exe|Executables (*.exe)|*.exe"
            $dialog.CheckFileExists = $true
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $manual = Test-GodotExecutable -Path $dialog.FileName -Source "selection manuelle"
                if ($null -ne $manual) {
                    return $manual
                }
                throw "L'executable selectionne n'est pas une version Godot 4.7 valide."
            }
        } catch {
            if ($_.Exception.Message -like "*version Godot 4.7 valide*") {
                throw
            }
        }
    }
    throw "Godot 4.7 est introuvable. Utilisez -GodotPath, GODOT4_BIN ou GODOT_BIN."
}


function Format-PowerShellLiteral {
    param([string]$Value)

    return ("'{0}'" -f $Value.Replace("'", "''"))
}


function Format-ManualCommand {
    param([string]$Executable, [string[]]$Arguments)

    $formatted = foreach ($argument in $Arguments) {
        Format-PowerShellLiteral -Value $argument
    }
    return ('& {0} {1}' -f (Format-PowerShellLiteral -Value $Executable), ($formatted -join " "))
}


try {
    $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
    $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        $localAppData = $env:TEMP
    }
    $stateDirectory = Join-Path $localAppData "DungeonDraft"
    $logDirectory = Join-Path $stateDirectory "logs"
    $cachePath = Join-Path $stateDirectory "godot_path.txt"
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
    $logPath = Join-Path $logDirectory ("vfx_flipbook_lab_{0}_{1}.log" -f $Mode.ToLowerInvariant(), $timestamp)
    Start-Transcript -Path $logPath -Force | Out-Null
    $transcriptStarted = $true
    Write-Host "Dungeon Draft - VFX Flipbook Foundation Lab"
    Write-Host "Mode : $Mode"
    Write-Host "Projet : $projectRoot"
    Write-Host "Log : $logPath"

    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "project.godot") -PathType Leaf)) {
        throw "project.godot est absent de la racine calculee : $projectRoot"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "tools\labs\vfx_flipbook_foundation\VFXFlipbookFoundationLab.tscn") -PathType Leaf)) {
        throw "La scene du laboratoire est absente."
    }

    $resolvedGodot = Resolve-GodotExecutable -ExplicitPath $GodotPath -CacheFile $cachePath -DisablePrompt:$NoPrompt
    Set-Content -LiteralPath $cachePath -Value $resolvedGodot.Path -Encoding UTF8
    Write-Host ("Godot : {0}" -f $resolvedGodot.Path)
    Write-Host ("Version : {0}" -f $resolvedGodot.Version)
    Write-Host ("Detection : {0}" -f $resolvedGodot.Source)

    $forwardedArguments = New-Object System.Collections.Generic.List[string]
    foreach ($argument in $GodotArguments) {
        if (-not [string]::IsNullOrWhiteSpace($argument)) {
            $forwardedArguments.Add($argument)
        }
    }
    $arguments = switch ($Mode) {
        "Run" { @("--path", $projectRoot, "--scene", $labScene) }
        "Edit" { @("--editor", "--path", $projectRoot, "--scene", $labScene) }
        "Smoke" { @("--headless", "--path", $projectRoot, "--script", $smokeScript) }
    }
    $arguments += $forwardedArguments.ToArray()
    Write-Host ("Commande manuelle : {0}" -f (Format-ManualCommand $resolvedGodot.Path $arguments))

    & $resolvedGodot.Path @arguments
    $nativeExitCode = $LASTEXITCODE
    if ($nativeExitCode -ne 0) {
        throw "Godot a termine avec le code $nativeExitCode."
    }
    Write-Host "VFX Flipbook Lab : succes ($Mode)."
    $exitCode = 0
} catch {
    Write-Host ""
    Write-Host ("ERREUR : {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host "Log : $logPath"
    Write-Host ("Commande du lanceur : powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"{0}`" -Mode {1} -GodotPath `"C:\chemin\vers\Godot.exe`"" -f $PSCommandPath, $Mode)
    if ($null -ne $nativeExitCode -and $nativeExitCode -ne 0) {
        $exitCode = $nativeExitCode
    } else {
        $exitCode = 1
    }
} finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}

exit $exitCode
