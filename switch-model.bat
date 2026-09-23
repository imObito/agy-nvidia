@echo off
REM switch-model.bat — Windows model switcher.
REM On Linux/WSL, delegates to switch-model.sh. On Windows, uses PowerShell.
setlocal
if exist "%~dp0switch-model.sh" (
  where bash >nul 2>&1
  if not errorlevel 1 (
    bash "%~dp0switch-model.sh" %*
    exit /b %ERRORLEVEL%
  )
)
where powershell >nul 2>&1
if errorlevel 1 (
  echo PowerShell is required on Windows, or use bash switch-model.sh.
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-model.ps1" %*
exit /b %ERRORLEVEL%
