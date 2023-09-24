@echo off

:: Get the R installation path from the registry
for /F "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\R-core\R" /v Current Version ^| findstr /i "Current Version"') do (
    set RVersion=%%B
)

:: Check if RVersion is set
if not defined RVersion (
    echo R is not installed.
    exit /b
)

:: Construct the R executable path based on the installation path
set RExePath=C:\Program Files\R\R-%RVersion%\bin\x64\R.exe

:: Run the R script
"%RExePath%" CMD BATCH scrape.R

:: Pause to see the output
pause