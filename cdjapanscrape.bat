@echo off

:: Check for most recent R installation
for /F "tokens=2*" %%A in (
    'reg query "HKLM\SOFTWARE\R-core\R" /v InstallPath ^| findstr /i "InstallPath"'
) do (
    set RVersion=%%B
)

:: Check if RVersion is set
if not defined RVersion (
    echo R is not installed.
    exit /b
)

:: Construct the R executable path based on the installation path
set RExePath=%RVersion%\bin\x64\R.exe

:: Run the R script
"%RExePath%" CMD BATCH scrape.R

:: Capture the exit code
set ExitCode=%errorlevel%

:: Write error to log
if %ExitCode% equ 1 (
    echo Task exited with code 1. Performing additional actions...
    echo Additional actions performed at %date% %time% >> "%~dp0cdjapanerror.log"
    start "" "%~dp0cdjapanerror.log"
)