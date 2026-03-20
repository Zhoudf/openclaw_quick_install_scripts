@echo off
chcp 437 >nul
setlocal enabledelayedexpansion

:: ============================================================
:: Windows WSL + Ubuntu Complete Uninstall Script
:: ============================================================
:: Author: AI 大玩家 Eddie
:: WeChat: dev_eddie
:: ============================================================
:: This script will:
:: 1. Unregister Ubuntu distribution (deletes all data)
:: 2. Optionally disable WSL feature
:: 3. Optionally disable Virtual Machine Platform feature
:: ============================================================

echo.
echo ============================================================
echo   Windows WSL + Ubuntu Complete Uninstall Script
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

:: Warning
echo ============================================================
echo   WARNING
echo ============================================================
echo.
echo This operation will delete the following:
echo - Ubuntu 24.04 distribution and all its data
echo - All WSL Linux distributions (if full uninstall is selected)
echo.
echo [Important] Please ensure you have backed up important data!
echo.
set /p CONTINUE="Continue? (Y/N): "
if /i not "!CONTINUE!"=="Y" (
    echo.
    echo [Info] Uninstall cancelled
    echo.
    pause
    exit /b 0
)

echo.
echo ------------------------------------------------------------
echo [Step 1/4] Checking installed Linux distributions...
echo ------------------------------------------------------------
echo.

:: List installed distributions
wsl --list --verbose

echo.
set /p UNREGISTER_ALL="Uninstall all Linux distributions? (Y/N): "

if /i "!UNREGISTER_ALL!"=="Y" (
    :: Get all distribution names
    for /f "tokens=*" %%i in ('wsl --list --quiet') do (
        if not "%%i"=="" (
            set "DISTRO=%%i"
            echo.
            echo [Info] Unregistering distribution: !DISTRO!
            wsl --unregister !DISTRO!
            if !errorLevel! equ 0 (
                echo [OK] !DISTRO! unregistered
            ) else (
                echo [Warning] !DISTRO! unregister failed
            )
        )
    )
) else (
    :: Only uninstall Ubuntu
    echo.
    echo [Info] Unregistering Ubuntu 24.04...
    wsl --unregister Ubuntu-24.04
    if !errorLevel! equ 0 (
        echo [OK] Ubuntu-24.04 unregistered
    ) else (
        echo [Warning] Ubuntu-24.04 unregister failed, may not be installed
    )

    echo.
    set /p UNREGISTER_UBUNTU="Also unregister other Ubuntu variants? (Y/N): "
    if /i "!UNREGISTER_UBUNTU!"=="Y" (
        wsl --unregister Ubuntu
        wsl --unregister Ubuntu-20.04
        wsl --unregister Ubuntu-22.04
        echo [OK] Attempted to unregister all Ubuntu variants
    )
)

echo.
echo ------------------------------------------------------------
echo [Step 2/4] Closing all WSL instances...
echo ------------------------------------------------------------
wsl --shutdown
echo [OK] All WSL instances closed

echo.
echo ------------------------------------------------------------
echo [Step 3/4] Verifying uninstall status...
echo ------------------------------------------------------------
echo.
echo [Info] Currently installed distributions:
wsl --list --verbose

echo.
echo ------------------------------------------------------------
echo [Step 4/4] Optional: Disable WSL Feature
echo ------------------------------------------------------------
echo.
echo [Note] Disabling WSL feature requires Windows restart to take effect
echo.
set /p DISABLE_WSL="Disable WSL feature? (Y/N): "

if /i "!DISABLE_WSL!"=="Y" (
    echo.
    echo [Info] Disabling WSL feature...
    dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart

    if !errorLevel! equ 0 (
        echo [OK] WSL feature disabled
        set "DISABLED_WSL=1"
    ) else (
        echo [Warning] Failed to disable WSL feature, error code: !errorLevel!
    )

    echo.
    set /p DISABLE_VM="Also disable Virtual Machine Platform feature? (Y/N): "
    if /i "!DISABLE_VM!"=="Y" (
        echo.
        echo [Info] Disabling Virtual Machine Platform feature...
        dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart

        if !errorLevel! equ 0 (
            echo [OK] Virtual Machine Platform feature disabled
        ) else (
            echo [Warning] Failed to disable Virtual Machine Platform feature, error code: !errorLevel!
        )
    )
)

echo.
echo ============================================================
echo   Uninstall Complete!
echo ============================================================
echo.

if defined DISABLED_WSL (
    echo [Important] WSL feature has been disabled, Windows restart required
    echo.
    set /p REBOOT="Restart Windows now? (Y/N): "
    if /i "!REBOOT!"=="Y" (
        echo [Info] Restarting Windows...
        shutdown /r /t 5
        exit /b 0
    )
)

echo.
echo [OK] WSL and Ubuntu have been successfully uninstalled
echo.
echo [Verify Uninstall]
echo - Run: wsl --list --verbose    (should show no distributions or only retained ones)
echo - Run: wsl --status            (Check WSL status)
echo.
echo [Useful Commands]
echo - wsl --install                Reinstall WSL and Ubuntu
echo - wsl --help                   View WSL help
echo.

if not defined DISABLED_WSL (
    echo [Note] WSL feature is still enabled, you can reinstall Ubuntu:
    echo - Run script: install-wsl.bat
    echo - Or manual command: wsl --install -d Ubuntu-24.04
)

echo.
pause
