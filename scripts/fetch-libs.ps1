# fetch-libs.ps1 - Download Ace3 libraries for local development via junction
# This fetches the latest Ace3 release from GitHub and extracts the required
# libraries into libs/ so the addon loads without relying on other addons.

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$libsDir = Join-Path $root "libs"
$tempZip = Join-Path $env:TEMP "ace3-latest.zip"
$tempDir = Join-Path $env:TEMP "ace3-extract"

# Required libraries (from Ace3 repo)
$requiredLibs = @(
    "LibStub",
    "CallbackHandler-1.0",
    "AceAddon-3.0",
    "AceDB-3.0",
    "AceGUI-3.0"
)

# Additional libraries fetched separately
$extraLibs = @(
    @{ Name = "LibDataBroker-1.1"; Url = "https://github.com/tekkub/libdatabroker-1-1/archive/refs/heads/master.zip"; Inner = "libdatabroker-1-1-master" },
    @{ Name = "LibDBIcon-1.0"; Url = "https://github.com/WoWAddonMirrors/LibDBIcon-1.0/archive/refs/heads/main.zip"; Inner = "LibDBIcon-1.0-main/LibDBIcon-1.0" }
)

Write-Host "Fetching Ace3 from GitHub..." -ForegroundColor Cyan

$ace3ZipUrl = "https://github.com/WoWUIDev/Ace3/archive/refs/heads/master.zip"

Invoke-WebRequest -Uri $ace3ZipUrl -OutFile $tempZip -UseBasicParsing
Write-Host "Downloaded Ace3 archive." -ForegroundColor Green

# Clean and extract
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force

# Find the extracted root (usually ace3-master/)
$extractedRoot = Get-ChildItem $tempDir -Directory | Select-Object -First 1

# Create libs directory
if (-not (Test-Path $libsDir)) {
    New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
}

# Copy each required library
foreach ($lib in $requiredLibs) {
    $src = Join-Path $extractedRoot.FullName $lib
    $dest = Join-Path $libsDir $lib

    if (Test-Path $src) {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $src -Destination $dest -Recurse
        Write-Host "  Installed: $lib" -ForegroundColor White
    } else {
        Write-Host "  WARNING: $lib not found in archive" -ForegroundColor Yellow
    }
}

# Cleanup Ace3 temp files
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# Fetch additional libraries (LibDataBroker, LibDBIcon)
Write-Host ""
Write-Host "Fetching additional libraries..." -ForegroundColor Cyan

foreach ($extra in $extraLibs) {
    $extraZip = Join-Path $env:TEMP "extra-lib.zip"
    $extraDir = Join-Path $env:TEMP "extra-lib-extract"

    Invoke-WebRequest -Uri $extra.Url -OutFile $extraZip -UseBasicParsing

    if (Test-Path $extraDir) { Remove-Item $extraDir -Recurse -Force }
    Expand-Archive -Path $extraZip -DestinationPath $extraDir -Force

    $src = Join-Path $extraDir $extra.Inner
    $dest = Join-Path $libsDir $extra.Name

    if (Test-Path $src) {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $src -Destination $dest -Recurse
        Write-Host "  Installed: $($extra.Name)" -ForegroundColor White
    } else {
        # Fallback: look for the folder by name inside the extracted archive
        $fallback = Get-ChildItem $extraDir -Directory -Recurse -Filter $extra.Name | Select-Object -First 1
        if ($fallback) {
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            Copy-Item $fallback.FullName -Destination $dest -Recurse
            Write-Host "  Installed: $($extra.Name)" -ForegroundColor White
        } else {
            Write-Host "  WARNING: $($extra.Name) not found in archive" -ForegroundColor Yellow
        }
    }

    Remove-Item $extraZip -Force -ErrorAction SilentlyContinue
    Remove-Item $extraDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "All libraries installed to libs/" -ForegroundColor Green
Write-Host "You can now use link-addon.ps1 without lib loading warnings." -ForegroundColor Cyan
