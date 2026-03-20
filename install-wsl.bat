@echo off
chcp 437 >nul
setlocal enabledelayedexpansion

:: ============================================================
:: Windows WSL + Ubuntu 24.04 Auto Installation Script
:: ============================================================
:: Author: AI 大玩家 Eddie
:: WeChat: dev_eddie
:: ============================================================
:: This script will:
:: 1. Enable WSL feature
:: 2. Enable Virtual Machine Platform feature
:: 3. Install WSL 2
:: 4. Install Ubuntu 24.04 LTS
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

:: Check Windows version
echo [Info] Checking Windows version...
wmic os get Caption, Version | findstr /i "windows" >nul
if %errorLevel% neq 0 (
    echo [Warning] Unable to detect Windows version, continuing...
)

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
    :: Try China mirror first for faster download in mainland China
    set "WSL_URL_CN=https://aka.ms/wslkernelupdate64"
    set "WSL_URL=https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
    echo [Info] Detected 64-bit system
) else (
    set "WSL_URL_CN=https://aka.ms/wslkernelupdatearm64"
    set "WSL_URL=https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_arm64.msi"
    echo [Info] Detected ARM64 system
)

:: Download WSL update package
set "TEMP_DIR=%TEMP%\wsl_install"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
set "WSLInstaller=%TEMP_DIR%\wsl_update.msi"

echo [Info] Option 1: Download from Microsoft CDN (default)
echo [Info] Option 2: Download from China mirror (recommended for mainland China)
echo [Info] Option 3: Skip download (manually install later)
set /p DOWNLOAD_CHOICE="Choose download source (1/2/3, default=2): "

if "!DOWNLOAD_CHOICE!"=="1" (
    echo [Info] Downloading from Microsoft CDN...
    powershell -Command "& {Invoke-WebRequest -Uri '%WSL_URL%' -OutFile '%WSLInstaller%' -UseBasicParsing}"
) else if "!DOWNLOAD_CHOICE!"=="3" (
    echo [Info] Skipping WSL kernel download...
    goto :SKIP_WSL_KERNEL
) else (
    echo [Info] Downloading from China mirror (aka.ms)...
    powershell -Command "& {Invoke-WebRequest -Uri '%WSL_URL_CN%' -OutFile '%WSLInstaller%' -UseBasicParsing}"
    if not exist "%WSLInstaller%" (
        echo [Warning] China mirror failed, trying Microsoft CDN...
        powershell -Command "& {Invoke-WebRequest -Uri '%WSL_URL%' -OutFile '%WSLInstaller%' -UseBasicParsing}"
    )
)

:SKIP_WSL_KERNEL
if exist "%WSLInstaller%" (
    echo [Info] Download complete, installing...
    msiexec /i "%WSLInstaller%" /quiet /norestart
    echo [OK] WSL kernel update installed
) else (
    echo [Warning] Download failed, will try wsl --install command...
)
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
echo [Info] Starting Ubuntu 24.04 LTS installation...
echo [Note] This may take a few minutes, please be patient...
echo.

:: Install Ubuntu 24.04
wsl --install -d Ubuntu-24.04 --no-launch
if %errorLevel% equ 0 (
    echo [OK] Ubuntu 24.04 installed successfully!
) else (
    echo [Warning] Automatic installation may have failed, trying alternative method...
    echo [Info] Using wsl --install default installation...
    wsl --install
    if %errorLevel% equ 0 (
        echo [OK] Ubuntu installed successfully!
    ) else (
        echo [Warning] Installation may be complete, please check manually
    )
)
echo.
echo [Verify] Checking installation status...
wsl --list --verbose
echo.
echo ============================================================
echo   Installation Complete!
echo ============================================================
echo.
echo [OK] WSL and Ubuntu 24.04 have been successfully installed
echo.
echo [Next Steps]
echo 1. First time launching Ubuntu requires setting username and password
echo 2. After launch, continue installing Node.js and OpenClaw
echo.
echo [Methods to Launch Ubuntu]
echo - Method 1: Search "Ubuntu" in Start menu
echo - Method 2: Run in PowerShell: wsl -d Ubuntu-24.04
echo - Method 3: Run in command line: wsl
echo.
echo [Useful Commands]
echo - wsl --list --verbose    List installed Linux distributions
echo - wsl --shutdown          Shutdown all WSL instances
echo - wsl --help              View WSL help
echo.
echo [Note] WSL 2 does not require restart to use
echo.
pause
