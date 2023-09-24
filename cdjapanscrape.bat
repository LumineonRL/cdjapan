@echo off

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