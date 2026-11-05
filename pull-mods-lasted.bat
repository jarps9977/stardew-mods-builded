@echo off
setlocal
rem Double-click launcher: fetches the latest pull-mods-lasted.ps1 from GitHub and runs it.
set "URL=https://raw.githubusercontent.com/jarps9977/stardew-mods-builded/main/pull-mods-lasted.ps1"
set "PS1=%TEMP%\pull-mods-lasted.ps1"

echo Fetching latest installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = 'Tls12'; Invoke-WebRequest -Uri $env:URL -OutFile $env:PS1 -UseBasicParsing; exit 0 } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }"
if errorlevel 1 goto :fallback
goto :run

:fallback
rem Offline: use the script next to this .bat if present.
if exist "%~dp0pull-mods-lasted.ps1" (
    echo Download failed. Using local copy.
    set "PS1=%~dp0pull-mods-lasted.ps1"
    goto :run
)
echo FAILED: could not download installer.
pause
exit /b 1

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
endlocal
