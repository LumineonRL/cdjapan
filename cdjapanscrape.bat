@echo off

ECHO Activating virtual environment...
REM
CALL venv/Scripts/activate

if %errorlevel% neq 0 (
    ECHO Failed to activate virtual environment. Make sure a 'venv' folder exists.
    goto :end
)

ECHO.
ECHO Running the Python scraper (scrape.py)...
python scrape.py

set ExitCode=%errorlevel%

if %ExitCode% neq 0 (
    echo.
    echo **************************************************
    echo * SCRIPT FAILED with exit code %ExitCode%. Please check logs. *
    echo **************************************************
    echo Run failed at %date% %time% with exit code %ExitCode%. >> "%~dp0log.log"
    start "" "%~dp0log.log"
) else (
    echo.
    echo Script completed successfully.
)

:end
ECHO.
ECHO Script finished. Press any key to exit.
pause >nul
