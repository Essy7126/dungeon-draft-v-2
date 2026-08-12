$ErrorActionPreference = 'Stop'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Node.js est requis.' }
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { throw 'npm est requis.' }
$major = [int]((node --version).TrimStart('v').Split('.')[0])
if ($major -lt 22) { throw 'Node.js 22 ou plus récent est requis.' }
if (-not (Test-Path -LiteralPath 'node_modules')) { & npm.cmd ci; if ($LASTEXITCODE -ne 0) { throw 'Installation npm impossible.' } }
& npm.cmd run dev -- --open
if ($LASTEXITCODE -ne 0) { throw "Le serveur Vite n'a pas pu démarrer." }
