@echo off
setlocal
where node >nul 2>nul || (echo [ERREUR] Node.js est requis. & pause & exit /b 1)
where npm.cmd >nul 2>nul || (echo [ERREUR] npm est requis. & pause & exit /b 1)
if not exist node_modules\ npm.cmd ci || (pause & exit /b 1)
if not exist dist\index.html npm.cmd run build || (echo [ERREUR] Build impossible. & pause & exit /b 1)
start "" "http://127.0.0.1:4173/?renderer=webgl"
node scripts\serve-dist.mjs
if errorlevel 1 (echo [ERREUR] Le build n'a pas pu etre servi. & pause & exit /b 1)
endlocal
