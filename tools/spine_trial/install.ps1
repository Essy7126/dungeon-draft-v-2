#requires -Version 7.2
# Restores pinned third-party tools. Existing character work is never regenerated.
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$settings=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$cache=Join-Path $projectRoot 'artifacts/dev-tools/spine'
[IO.Directory]::CreateDirectory($cache) | Out-Null
foreach($component in @('motion','runtime')){
    $archive=Join-Path $cache ($component+'-pinned.zip')
    if(-not(Test-Path -LiteralPath $archive)){Invoke-WebRequest -Uri $settings."${component}_url" -OutFile $archive}
    if((Get-FileHash -LiteralPath $archive).Hash -ne $settings."${component}_sha256"){throw "$component SHA256 mismatch"}
    if($component -eq 'motion'){
        $source=Join-Path $projectRoot $settings.motion_source
        if(-not(Test-Path -LiteralPath $source)){Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $cache 'source')}
        Push-Location $source
        try {
            npm ci --ignore-scripts --no-audit --no-fund *> (Join-Path $cache 'motion-install.log')
            if($LASTEXITCODE -ne 0){throw 'npm installation failed'}
            npm run build *> (Join-Path $cache 'motion-build.log')
            if($LASTEXITCODE -ne 0){throw 'TypeScript build failed'}
        } finally {Pop-Location}
    } else {
        $destination=Join-Path $projectRoot $settings.runtime_directory
        if(-not(Test-Path -LiteralPath $destination)){Expand-Archive -LiteralPath $archive -DestinationPath $destination}
        Invoke-WebRequest -Uri ('https://raw.githubusercontent.com/EsotericSoftware/spine-runtimes/'+$settings.runtime_commit+'/LICENSE') -OutFile (Join-Path $destination 'SPINE-RUNTIMES-LICENSE.txt')
    }
}
$examples=Join-Path $projectRoot 'artifacts/spine_trial/examples/spineboy'
[IO.Directory]::CreateDirectory($examples) | Out-Null
foreach($name in @('spineboy-pro.json','spineboy.atlas','spineboy.png')){
    $destination=Join-Path $examples $name
    if(-not(Test-Path -LiteralPath $destination)){Invoke-WebRequest -Uri ('https://raw.githubusercontent.com/EsotericSoftware/spine-runtimes/'+$settings.runtime_commit+'/examples/spineboy/export/'+$name) -OutFile $destination}
}
Copy-Item -LiteralPath (Join-Path $examples 'spineboy.atlas') -Destination (Join-Path $examples 'spineboy-pro.atlas') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot ($settings.runtime_directory+'/SPINE-RUNTIMES-LICENSE.txt')) -Destination (Join-Path $examples 'SPINE-RUNTIMES-LICENSE.txt') -Force
Write-Output 'Pinned Spine connector and Godot runtime installed. Run spine.ps1 start.'
