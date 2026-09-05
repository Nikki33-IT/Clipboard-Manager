param(
    [Parameter(Mandatory = $true)][string]$DownloadUrl,
    [Parameter(Mandatory = $true)][string]$AppDir
)

$ErrorActionPreference = "Stop"

$exeName = "clipvault.exe"
$tempDir = Join-Path $env:TEMP "clipvault_update_$(Get-Random)"
$zipPath = Join-Path $tempDir "update.zip"

Write-Host "==============================================="
Write-Host "  Aktualizacja ClipVault"
Write-Host "==============================================="

try {
    # 1. Poczekaj, aż główny proces aplikacji się faktycznie zamknie
    #    (uruchamiający kod wywołuje exit(0) tuż przed startem tego skryptu).
    Write-Host "[1/5] Oczekiwanie na zamkniecie aplikacji..."
    $maxWait = 10
    $waited = 0
    while ((Get-Process -Name "clipvault" -ErrorAction SilentlyContinue) -and $waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
    }

    # 2. Przygotuj folder tymczasowy i pobierz nową wersję
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    Write-Host "[2/5] Pobieranie nowej wersji..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipPath -UseBasicParsing

    # 3. Kopia zapasowa ustawień i bazy danych (na wszelki wypadek) -
    #    dane użytkownika trzymane są w %APPDATA%, nie w folderze aplikacji,
    #    więc nie zostaną nadpisane, ale i tak zabezpieczamy plik .exe/.dll
    #    starej wersji na wypadek problemów z nową paczką.
    $backupDir = Join-Path $AppDir "_backup_before_update"
    Write-Host "[3/5] Tworzenie kopii zapasowej biezacej wersji..."
    if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    Get-ChildItem -Path $AppDir -Exclude "_backup_before_update", "update.ps1" |
        Copy-Item -Destination $backupDir -Recurse -Force

    # 4. Rozpakuj nową wersję na miejsce starej
    Write-Host "[4/5] Instalowanie nowej wersji..."
    $extractDir = Join-Path $tempDir "extracted"
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    Get-ChildItem -Path $extractDir | ForEach-Object {
        $dest = Join-Path $AppDir $_.Name
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $_.FullName -Destination $AppDir -Recurse -Force
    }

    # 5. Sprzątanie i ponowne uruchomienie aplikacji
    Write-Host "[5/5] Sprzatanie i ponowne uruchamianie..."
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    $newExePath = Join-Path $AppDir $exeName
    if (Test-Path $newExePath) {
        Start-Process -FilePath $newExePath
        Write-Host ""
        Write-Host "Aktualizacja zakonczona pomyslnie."
    } else {
        throw "Nie znaleziono $exeName po rozpakowaniu - sprawdz paczke wydania."
    }
}
catch {
    Write-Host ""
    Write-Host "[BLAD] Aktualizacja nie powiodla sie: $($_.Exception.Message)"
    Write-Host "Przywracanie poprzedniej wersji z kopii zapasowej..."

    if (Test-Path $backupDir) {
        Get-ChildItem -Path $backupDir | ForEach-Object {
            $dest = Join-Path $AppDir $_.Name
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            Copy-Item $_.FullName -Destination $AppDir -Recurse -Force
        }
        Write-Host "Przywrocono poprzednia wersje. Mozesz uruchomic aplikacje ponownie."
    }

    Read-Host "Nacisnij Enter, aby zamknac to okno"
    exit 1
}
