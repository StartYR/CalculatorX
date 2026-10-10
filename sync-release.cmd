@echo off
setlocal
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
if exist "%~dp0.venv\Scripts\python.exe" (
    "%~dp0.venv\Scripts\python.exe" -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
    if not errorlevel 1 goto use_venv
)
py -3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if not errorlevel 1 goto use_py
python -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if not errorlevel 1 goto use_python
echo Python 3.10 or newer was not found. Install Python, then run this launcher again.
if "%~1"=="" pause
exit /b 1

:use_venv
"%~dp0.venv\Scripts\python.exe" -X utf8 "%~dp0tools\release-sync.py" %*
set "SYNC_EXIT=%errorlevel%"
goto finish

:use_py
py -3 -X utf8 "%~dp0tools\release-sync.py" %*
set "SYNC_EXIT=%errorlevel%"
goto finish

:use_python
python -X utf8 "%~dp0tools\release-sync.py" %*
set "SYNC_EXIT=%errorlevel%"

:finish
if not "%~1"=="" exit /b %SYNC_EXIT%
if not "%SYNC_EXIT%"=="0" pause
exit /b %SYNC_EXIT%
