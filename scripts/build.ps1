# build.ps1 - Creates dist/ with release and PTR zips ready for CurseForge
# Usage:
#   ./build.ps1                 # build only
#   ./build.ps1 -Bump patch    # 0.1.0 -> 0.1.1, then build
#   ./build.ps1 -Bump minor    # 0.1.0 -> 0.2.0, then build
#   ./build.ps1 -Bump major    # 0.1.0 -> 1.0.0, then build

param(
    [ValidateSet("major", "minor", "patch")]
    [string]$Bump
)

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$tocFile = Join-Path $root "Epithet.toc"

# Interface versions
$INTERFACE_LIVE = "120001"
$INTERFACE_PTR  = "120005"

# --- Version bump ---
if ($Bump) {
    # Read current version from .toc
    $tocContent = Get-Content $tocFile -Raw
    if ($tocContent -match '## Version:\s*(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        $patch = [int]$Matches[3]
    } else {
        throw "Could not parse version from Epithet.toc"
    }

    $old = "$major.$minor.$patch"

    switch ($Bump) {
        "major" { $major++; $minor = 0; $patch = 0 }
        "minor" { $minor++; $patch = 0 }
        "patch" { $patch++ }
    }

    $new = "$major.$minor.$patch"

    # Update .toc
    $tocContent = $tocContent -replace "## Version:\s*$([regex]::Escape($old))", "## Version: $new"
    Set-Content $tocFile $tocContent -NoNewline

    Write-Host "Version bumped: $old -> $new" -ForegroundColor Cyan
}

# --- Build ---
$distDir = Join-Path $root "dist"

# Clean previous build
if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}

# Read version for zip naming
$tocContent = Get-Content $tocFile -Raw
if ($tocContent -match '## Version:\s*(\d+\.\d+\.\d+)') {
    $version = $Matches[1]
} else {
    $version = "unknown"
}

# Build function: creates addon folder, patches interface version, zips it
function Build-Variant {
    param([string]$InterfaceVersion, [string]$Suffix)

    $variantDir = Join-Path $distDir $Suffix
    $addonDir = Join-Path $variantDir "Epithet"

    New-Item -ItemType Directory -Path $addonDir -Force | Out-Null

    # Copy addon files
    Copy-Item (Join-Path $root "Epithet.toc") -Destination $addonDir

    # Copy directories
    Copy-Item (Join-Path $root "core") -Destination $addonDir -Recurse
    Copy-Item (Join-Path $root "data") -Destination $addonDir -Recurse

    # Copy libs if present (populated by .pkgmeta or manual install)
    $libsDir = Join-Path $root "libs"
    if (Test-Path $libsDir) {
        Copy-Item $libsDir -Destination $addonDir -Recurse
    }

    # Patch Interface version in the .toc copy
    $tocPath = Join-Path $addonDir "Epithet.toc"
    $content = Get-Content $tocPath -Raw
    $content = $content -replace '## Interface:\s*\d+', "## Interface: $InterfaceVersion"
    Set-Content $tocPath $content -NoNewline

    # Create zip
    $zipName = "Epithet-$version-$Suffix.zip"
    $zipPath = Join-Path $distDir $zipName
    Compress-Archive -Path $addonDir -DestinationPath $zipPath -Force

    Write-Host "  $zipName (Interface: $InterfaceVersion)" -ForegroundColor White
}

Write-Host ""
Write-Host "Building Epithet v$version..." -ForegroundColor Cyan
Write-Host ""

# Build both variants
Write-Host "Zips:" -ForegroundColor Green
Build-Variant -InterfaceVersion $INTERFACE_LIVE -Suffix "release"
Build-Variant -InterfaceVersion $INTERFACE_PTR  -Suffix "ptr"

# Show contents of the release build
$releaseAddonDir = Join-Path $distDir "release\Epithet"
Write-Host ""
Write-Host "Contents:" -ForegroundColor Green
Get-ChildItem $releaseAddonDir -Recurse | ForEach-Object {
    $rel = $_.FullName.Substring($releaseAddonDir.Length + 1)
    if ($_.PSIsContainer) { Write-Host "  $rel/" } else { Write-Host "  $rel" }
}
Write-Host ""
Write-Host "Ready to upload to CurseForge:" -ForegroundColor Green
Write-Host "  dist/Epithet-$version-release.zip  -> The War Within (live)" -ForegroundColor White
Write-Host "  dist/Epithet-$version-ptr.zip      -> PTR/Beta" -ForegroundColor White
