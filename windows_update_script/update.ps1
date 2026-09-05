param(
    [Parameter(Mandatory = $true)][string]$DownloadUrl,
    [Parameter(Mandatory = $true)][string]$AppDir
)

$ErrorActionPreference = "Stop"

$exeName = "clipvault.exe"
$tempDir = Join-Path $env:TEMP "clipvault_update_$(Get-Random)"
$zipPath = Join-Path $tempDir "update.zip"

Write-Host "==============================================="
Write-Host "  ClipVault update"
Write-Host "==============================================="

try {
    # 1. Wait until the main app process actually exits
    #    (the calling code runs exit(0) right before starting this script).
    Write-Host "[1/5] Waiting for the app to close..."
    $maxWait = 10
    $waited = 0
    while ((Get-Process -Name "clipvault" -ErrorAction SilentlyContinue) -and $waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
    }

    # 2. Prepare a temp folder and download the new version
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    Write-Host "[2/5] Downloading the new version..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipPath -UseBasicParsing

    # 3. Back up settings and database (just in case) - user data lives
    #    in %APPDATA%, not in the app folder, so it will not be overwritten,
    #    but we still protect the old .exe/.dll in case the new pack is bad.
    $backupDir = Join-Path $AppDir "_backup_before_update"
    Write-Host "[3/5] Backing up the current version..."
    if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    Get-ChildItem -Path $AppDir -Exclude "_backup_before_update", "update.ps1" |
        Copy-Item -Destination $backupDir -Recurse -Force

    # 4. Unpack the new version over the old one
    Write-Host "[4/5] Installing the new version..."
    $extractDir = Join-Path $tempDir "extracted"
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    Get-ChildItem -Path $extractDir | ForEach-Object {
        $dest = Join-Path $AppDir $_.Name
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $_.FullName -Destination $AppDir -Recurse -Force
    }

    # 5. Clean up and relaunch the app
    Write-Host "[5/5] Cleaning up and relaunching..."
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    $newExePath = Join-Path $AppDir $exeName
    if (Test-Path $newExePath) {
        Start-Process -FilePath $newExePath
        Write-Host ""
        Write-Host "Update finished successfully."
    } else {
        throw "Missing $exeName after unpacking - check the release package."
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Update failed: $($_.Exception.Message)"
    Write-Host "Restoring the previous version from backup..."

    if (Test-Path $backupDir) {
        Get-ChildItem -Path $backupDir | ForEach-Object {
            $dest = Join-Path $AppDir $_.Name
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            Copy-Item $_.FullName -Destination $AppDir -Recurse -Force
        }
        Write-Host "Previous version restored. You can relaunch the app."
    }

    Read-Host "Press Enter to close this window"
    exit 1
}
