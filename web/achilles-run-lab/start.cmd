@echo off
setlocal
where node >nul 2>nul || (echo [ERREUR] Node.js est requis. & pause & exit /b 1)
where npm.cmd >nul 2>nul || (echo [ERREUR] npm est requis. & pause & exit /b 1)
node -e "const major=Number(process.versions.node.split('.')[0]); if(major<22){console.error('[ERREUR] Node.js 22 ou plus recent est requis.'); process.exit(1)}" || (pause & exit /b 1)
if not exist node_modules\ npm.cmd ci || (echo [ERREUR] Installation npm impossible. & pause & exit /b 1)
echo Ouverture de Dungeon Draft - Achilles Web Run Lab...
npm.cmd run dev -- --open
if errorlevel 1 (echo [ERREUR] Le serveur Vite n'a pas pu demarrer. & pause & exit /b 1)
endlocal
