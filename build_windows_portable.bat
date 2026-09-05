@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo   Build ClipVault - Windows Portable
echo ===============================================

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter not found in PATH.
    echo Install: https://docs.flutter.dev/get-started/install/windows
    exit /b 1
)

where cl >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] MSVC compiler not detected in PATH.
    echo Make sure Visual Studio 2022 is installed
    echo with the "Desktop development with C++" workload,
    echo and run this script from "Developer Command Prompt for VS 2022".
    echo.
)

echo.
echo [1/5] Fetching dependencies...
call flutter pub get
if %errorlevel% neq 0 goto :error

echo.
echo [2/5] Enabling Windows desktop support...
call flutter config --enable-windows-desktop

echo.
echo [3/5] Running tests...
call flutter test
if %errorlevel% neq 0 (
    echo [WARNING] Tests failed - continuing with the build anyway.
)

echo.
echo [4/5] Building the release version...
call flutter build windows --release
if %errorlevel% neq 0 goto :error

echo.
echo [5/6] Copying the updater script...
copy /Y "windows_update_script\update.ps1" "build\windows\x64\runner\Release\update.ps1" >nul

echo.
echo [6/6] Packing the ZIP...
if not exist "build\releases" mkdir "build\releases"
powershell -Command "Compress-Archive -Path 'build\windows\x64\runner\Release\*' -DestinationPath 'build\releases\ClipVault-Windows-Portable.zip' -Force"

echo.
echo ===============================================
echo   Done! Package:
echo   build\releases\ClipVault-Windows-Portable.zip
echo ===============================================
exit /b 0

:error
echo.
echo [ERROR] Build aborted - see messages above.
exit /b 1
