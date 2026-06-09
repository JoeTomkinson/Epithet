# link-ptr.ps1 - Link the dist/ptr build into the WoW PTR AddOns folder
# Use this to test the packaged PTR distribution before uploading.
# Run build.ps1 first to generate dist/ptr/Epithet.

$addonsPath = "A:\Blizzard\World of Warcraft\_ptr_\Interface\Addons"
$linkPath = Join-Path $addonsPath "Epithet"
$root = Split-Path $PSScriptRoot -Parent
$targetPath = Join-Path $root "dist\ptr\Epithet"

if (-not (Test-Path $targetPath)) {
    Write-Host "ERROR: dist/ptr/Epithet does not exist. Run build.ps1 first." -ForegroundColor Red
    exit 1
}

if (Test-Path $linkPath) {
    $item = Get-Item $linkPath -Force
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        $existingTarget = $item.Target
        if ($existingTarget -eq $targetPath) {
            Write-Host "Junction already points to PTR dist: $linkPath" -ForegroundColor Yellow
            exit 0
        }
        Write-Host "Removing existing junction: $linkPath -> $existingTarget" -ForegroundColor Yellow
        Remove-Item $linkPath -Force
    } else {
        Write-Host "WARNING: $linkPath exists and is not a symlink. Remove it manually first." -ForegroundColor Red
        exit 1
    }
}

New-Item -ItemType Junction -Path $linkPath -Target $targetPath | Out-Null
Write-Host "Junction created: $linkPath -> $targetPath" -ForegroundColor Green
Write-Host "You are now testing the PTR distribution package." -ForegroundColor Cyan
