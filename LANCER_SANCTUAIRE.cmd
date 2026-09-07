@echo off
setlocal
set "SANCTUARY_GODOT=C:\Godot\4.7.1\Godot_v4.7.1-stable_win64.exe"
if not exist "%SANCTUARY_GODOT%" (
    echo Godot est introuvable. Ouvrez hub\sanctuary_prototype\SanctuaryPrototype.tscn dans Godot et appuyez sur F6.
    pause
    exit /b 1
)
start "" "%SANCTUARY_GODOT%" --path "%~dp0." --rendering-method gl_compatibility --resolution 1600x900 --scene res://hub/sanctuary_prototype/SanctuaryPrototype.tscn
endlocal
