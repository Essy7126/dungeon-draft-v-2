@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launchers\launch_vfx_flipbook_lab.ps1" -Mode Run %*
set "LAUNCHER_EXIT_CODE=%ERRORLEVEL%"
if not "%LAUNCHER_EXIT_CODE%"=="0" (
    echo.
    echo Le laboratoire VFX Flipbook n'a pas pu demarrer. Consultez le message et le log ci-dessus.
    pause
)
exit /b %LAUNCHER_EXIT_CODE%
