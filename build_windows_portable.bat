@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo   Build ClipVault - Windows Portable
echo ===============================================

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [BLAD] Nie znaleziono Fluttera w PATH.
    echo Zainstaluj: https://docs.flutter.dev/get-started/install/windows
    exit /b 1
)

where cl >nul 2>nul
if %errorlevel% neq 0 (
    echo [UWAGA] Nie wykryto kompilatora MSVC w PATH.
    echo Upewnij sie, ze masz zainstalowane Visual Studio 2022
    echo z komponentem "Desktop development with C++",
    echo i uruchamiasz ten skrypt z "Developer Command Prompt for VS 2022".
    echo.
)

echo.
echo [1/5] Pobieranie zaleznosci...
call flutter pub get
if %errorlevel% neq 0 goto :error

echo.
echo [2/5] Wlaczanie wsparcia Windows desktop...
call flutter config --enable-windows-desktop

echo.
echo [3/5] Uruchamianie testow...
call flutter test
if %errorlevel% neq 0 (
    echo [UWAGA] Testy nie przeszly - kontynuuje build mimo to.
)

echo.
echo [4/5] Budowanie wersji release...
call flutter build windows --release
if %errorlevel% neq 0 goto :error

echo.
echo [5/6] Kopiowanie skryptu aktualizacji...
copy /Y "windows_update_script\update.ps1" "build\windows\x64\runner\Release\update.ps1" >nul

echo.
echo [6/6] Pakowanie do ZIP...
if not exist "build\releases" mkdir "build\releases"
powershell -Command "Compress-Archive -Path 'build\windows\x64\runner\Release\*' -DestinationPath 'build\releases\ClipVault-Windows-Portable.zip' -Force"

echo.
echo ===============================================
echo   Gotowe! Paczka:
echo   build\releases\ClipVault-Windows-Portable.zip
echo ===============================================
exit /b 0

:error
echo.
echo [BLAD] Build przerwany - sprawdz komunikaty powyzej.
exit /b 1
