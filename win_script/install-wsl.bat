@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: Windows WSL + Ubuntu 24.04 Auto Installation Script
:: ============================================================
:: Author: Eddie
:: ============================================================

echo.
echo ============================================================
echo   Windows WSL + Ubuntu 24.04 Auto Installation Script
echo ============================================================
echo.

:: Check administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [Error] Please run this script as administrator!
    echo.
    echo Usage:
    echo 1. Right-click this script
    echo 2. Select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo [OK] Running as administrator
echo.

:: Step 1: Enable WSL feature
echo ------------------------------------------------------------
echo [Step 1/4] Enabling WSL feature...
echo ------------------------------------------------------------
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
if %errorLevel% equ 0 (
    echo [OK] WSL feature enabled
) else (
    echo [Error] Failed to enable WSL feature, error code: %errorLevel%
    pause
    exit /b 1
)
echo.

:: Step 2: Enable Virtual Machine Platform feature
echo ------------------------------------------------------------
echo [Step 2/4] Enabling Virtual Machine Platform feature...
echo ------------------------------------------------------------
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
if %errorLevel% equ 0 (
    echo [OK] Virtual Machine Platform feature enabled
) else (
    echo [Error] Failed to enable Virtual Machine Platform feature, error code: %errorLevel%
    pause
    exit /b 1
)
echo.

:: Step 3: Download and install WSL kernel update
echo ------------------------------------------------------------
echo [Step 3/4] Installing WSL kernel update...
echo ------------------------------------------------------------
echo [Info] Downloading WSL2 kernel installer...

:: Check system architecture
wmic os get osarchitecture | findstr /i "64" >nul
if %errorLevel% equ 0 (
    set "WSLInstaller=%TEMP%\wsl_update_x64.msi"
    echo [Info] Detected 64-bit system
) else (
    set "WSLInstaller=%TEMP%\wsl_update_arm64.msi"
    echo [Info] Detected ARM64 system
)

echo [Info] Option 1: Download from Microsoft CDN (default)
echo [Info] Option 2: Download from China mirror (recommended for China)
echo [Info] Option 3: Skip download (manually install later)
set /p DOWNLOAD_CHOICE="Choose download source (1/2/3, default=2): "

if "%DOWNLOAD_CHOICE%"=="3" goto SKIP_WSL_KERNEL
if "%DOWNLOAD_CHOICE%"=="1" goto DOWNLOAD_MICROSOFT

echo [Info] Downloading from China mirror (aka.ms)...
powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/wslkernelupdate64' -OutFile '%WSLInstaller%' -UseBasicParsing"
if not exist "%WSLInstaller%" (
    echo [Warning] China mirror failed, trying Microsoft CDN...
    goto DOWNLOAD_MICROSOFT
)
goto INSTALL_WSL

:DOWNLOAD_MICROSOFT
echo [Info] Downloading from Microsoft CDN...
powershell -Command "Invoke-WebRequest -Uri 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi' -OutFile '%WSLInstaller%' -UseBasicParsing"
goto INSTALL_WSL

:SKIP_WSL_KERNEL
echo [Info] Skipping WSL kernel download...
goto CONTINUE_INSTALL

:INSTALL_WSL
if exist "%WSLInstaller%" (
    echo [Info] Download complete, installing...
    msiexec /i "%WSLInstaller%" /quiet /norestart
    echo [OK] WSL kernel update installed
) else (
    echo [Warning] Download failed, will try wsl --install command...
)

:CONTINUE_INSTALL
echo.

:: Step 4: Set WSL default version to 2
echo ------------------------------------------------------------
echo [Step 4/4] Setting WSL default version and installing Ubuntu 24.04...
echo ------------------------------------------------------------

:: Wait a moment to ensure features are enabled
timeout /t 3 /nobreak >nul

:: Set WSL 2 as default version
echo [Info] Setting WSL 2 as default version...
wsl --set-default-version 2
if %errorLevel% equ 0 (
    echo [OK] WSL 2 set successfully
) else (
    echo [Warning] Failed to set WSL 2, may already be set
)

echo.
echo [Info] Installing Ubuntu LTS...
echo [Note] This may take a few minutes, please be patient...
echo.

:: Method 1: Try installing from Microsoft Store using winget
echo [Info] Trying winget installation method...
winget install --id Canonical.Ubuntu -e --silent --accept-package-agreements --accept-source-agreements 2>nul
if %errorLevel% equ 0 (
    echo [OK] Ubuntu installed successfully via winget!
    goto LAUGH_CHECK
)

:: Method 2: Try wsl --install with distribution name (use "Ubuntu" not "Ubuntu-24.04")
echo [Info] Trying wsl --install method...
wsl --install --distribution Ubuntu 2>nul
if %errorLevel% equ 0 (
    echo [OK] Ubuntu installed successfully!
    goto LAUGH_CHECK
)

:: Method 3: List available distributions and install
echo [Info] Checking available distributions...
wsl --list --online
echo.
echo [Info] If Ubuntu-24.04 is listed above, run manually:
echo        wsl --install -d Ubuntu-24.04
echo.
echo [Info] Or install from Microsoft Store:
echo        https://aka.ms/wslstore

:LAUGH_CHECK
echo.
echo [Verify] Checking installation status...
wsl --list --verbose
echo.
echo ============================================================
echo   Installation Complete!
echo ============================================================
echo.
echo [OK] WSL 2 has been set up successfully
echo.
echo [Next Steps]
echo 1. If Ubuntu is listed above, launch it to complete setup
echo 2. First launch requires setting username and password
echo 3. After setup, continue installing Node.js and OpenClaw
echo.
echo [Methods to Launch Ubuntu]
echo - Method 1: Search "Ubuntu" in Start menu
echo - Method 2: Run in PowerShell: wsl -d Ubuntu-24.04
echo - Method 3: Run in command line: wsl
echo.
echo [Useful Commands]
echo - wsl --list --verbose    List installed Linux distributions
echo - wsl --list --online     Show available distributions
echo - wsl --shutdown          Shutdown all WSL instances
echo - wsl --help              View WSL help
echo.
echo [Note] WSL 2 does not require restart to use
echo.
pause
