@echo off
title The Gray Synthesis - 3D Town Mode
echo =====================================================================
echo Starting The Gray Synthesis - Full 3D Town Mode...
echo Controls:
echo   - WASD: Move
echo   - Shift: Sprint
echo   - E: Channel Task Pad
echo   - V: Inspect Secluded Alcove
echo   - R: Civic Shove
echo   - F: Civic Kit Ability
echo   - C: Operative Special Kit
echo =====================================================================
start "" "%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe" scenes/Main3D.tscn
exit /b 0
