# Publish-Release.ps1
# Automates the release process for USBAnywhere Server v3.0.0
# (c) 2025-2026 oscarlosu-lab - Protocolo Omega

$version = "3.0.0"
$repoRoot = $PSScriptRoot
$projectPath = Join-Path $repoRoot "src\USBAnywhere.Server"
$releasePath = Join-Path $repoRoot "release"

# Inno Setup Compiler Path
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) { $iscc = "${env:ProgramFiles}\Inno Setup 6\ISCC.exe" }

Write-Host "[RELEASE] Starting USBAnywhere Server v$version Release Build..." -ForegroundColor Cyan

# ---------------------------------------------------------
# 0. Clean release folder
# ---------------------------------------------------------

if (Test-Path $releasePath) { Remove-Item $releasePath -Recurse -Force }
New-Item -ItemType Directory -Path "$releasePath\temp_x64\Portable" | Out-Null

# ---------------------------------------------------------
# 1. Build Executable (x64 for server)
# ---------------------------------------------------------

Write-Host "[BUILD] Building x64..." -ForegroundColor Yellow
dotnet publish "$projectPath\USBAnywhere.Server.csproj" `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o "$releasePath\temp_x64\Portable" `
    --nologo

if ($LASTEXITCODE -ne 0) { Write-Error "Build x64 failed"; exit 1 }

# ---------------------------------------------------------
# 2. Prepare Assets
# ---------------------------------------------------------

Write-Host "[ASSETS] Copying assets..." -ForegroundColor Cyan

# Copy drivers folder (usbipd-win MSI + VBoxUSB drivers)
$driversPath = "$repoRoot\portable\drivers"
if (-not (Test-Path $driversPath)) { $driversPath = "$repoRoot\Portable\drivers" }

if (Test-Path $driversPath) {
    $dest = "$releasePath\temp_x64\Portable\drivers"
    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
    Copy-Item "$driversPath\*" $dest -Recurse -Force
    Write-Host "[DRIVERS] Copied drivers folder (usbipd-win.msi + VBoxUSB)" -ForegroundColor Green
}
else {
    Write-Warning "[DRIVERS] drivers folder not found at: $driversPath"
}

# License, Readme, and Changelog
Copy-Item "$repoRoot\LICENSE" "$releasePath\temp_x64\Portable\LICENSE" -Force -ErrorAction SilentlyContinue
Copy-Item "$repoRoot\README.md" "$releasePath\temp_x64\Portable\README.md" -Force -ErrorAction SilentlyContinue
Copy-Item "$repoRoot\CHANGELOG.md" "$releasePath\temp_x64\Portable\CHANGELOG.md" -Force -ErrorAction SilentlyContinue

# Wizard images and Icon for installer
$installerDir = "$repoRoot\installer"
$iconSrc = "$installerDir\icon.ico"
if (-not (Test-Path $iconSrc)) { $iconSrc = "$projectPath\icon.ico" }
if (Test-Path $iconSrc) { 
    Copy-Item $iconSrc "$releasePath\temp_x64\icon.ico" -Force 
}

# ---------------------------------------------------------
# 3. Clean unnecessary files from Portable folder
# ---------------------------------------------------------

Write-Host "[CLEAN] Cleaning unnecessary files..." -ForegroundColor Gray

# Remove .pdb files (debug symbols)
Get-ChildItem "$releasePath\temp_x64\Portable" -Filter "*.pdb" -ErrorAction SilentlyContinue | Remove-Item -Force

# Create portable markers
New-Item -Path "$releasePath\temp_x64\Portable\.portable" -ItemType File -Force | Out-Null
New-Item -Path "$releasePath\temp_x64\Portable\portable.flag" -ItemType File -Force | Out-Null

# ---------------------------------------------------------
# 4. Create ZIP Package (Portable)
# ---------------------------------------------------------

Write-Host "[ZIP] Creating ZIP package (Portable)..." -ForegroundColor Magenta
$x64Zip = "$releasePath\USBAnywhere-Server-v$version-x64-Portable.zip"
Compress-Archive -Path "$releasePath\temp_x64\Portable\*" -DestinationPath $x64Zip -Force

# ---------------------------------------------------------
# 5. Create Setup Installer
# ---------------------------------------------------------

if (Test-Path $iscc) {
    Write-Host "[SETUP] Compiling Setup (x64)..." -ForegroundColor Yellow
    
    # Remove portable markers for installed mode
    Remove-Item "$releasePath\temp_x64\Portable\.portable", "$releasePath\temp_x64\Portable\portable.flag" -Force -ErrorAction SilentlyContinue
    
    # Copy LICENSE, README and CHANGELOG to temp_x64 root
    Copy-Item "$repoRoot\LICENSE" "$releasePath\temp_x64\LICENSE" -Force -ErrorAction SilentlyContinue
    Copy-Item "$repoRoot\README.md" "$releasePath\temp_x64\README.md" -Force -ErrorAction SilentlyContinue
    Copy-Item "$repoRoot\CHANGELOG.md" "$releasePath\temp_x64\CHANGELOG.md" -Force -ErrorAction SilentlyContinue

    $issTemplate = "$repoRoot\installer\USBAnywhere-Server.iss"
    $issDest = "$releasePath\temp_x64\Setup.iss"
    
    if (Test-Path $issTemplate) {
        $issContent = Get-Content $issTemplate -Raw
        $issContent = $issContent -replace '#define MyAppVersion ".*?"', "#define MyAppVersion ""$version"""
        $issContent = $issContent -replace 'OutputDir=.*', "OutputDir=$releasePath"
        Set-Content -Path $issDest -Value $issContent
        
        $proc = Start-Process -FilePath $iscc -ArgumentList "`"$issDest`"" -WorkingDirectory "$releasePath\temp_x64" -PassThru -NoNewWindow -Wait
        
        if ($proc.ExitCode -eq 0) { 
            Write-Host "[OK] Setup (x64) created successfully" -ForegroundColor Green 
        }
        else { 
            Write-Warning "Setup creation failed (Exit: $($proc.ExitCode))" 
        }
    }
    else {
        Write-Warning "[WARN] ISS template not found at: $issTemplate"
    }
}
else {
    Write-Warning "[WARN] ISCC.exe not found. Skipping Installer."
}

# Clean temp build directories
Write-Host "Cleaning temporary folders..." -ForegroundColor Gray
Remove-Item "$releasePath\temp_x64" -Recurse -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------
# 5b. SHA256SUMS.txt Generation
# ---------------------------------------------------------

Write-Host "Generating SHA256SUMS.txt..." -ForegroundColor Cyan
$sumsFile = "$releasePath\SHA256SUMS.txt"
Get-ChildItem $releasePath -File | Where-Object { $_.Extension -in '.zip', '.exe' } | ForEach-Object {
    $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$h  $($_.Name)"
} | Set-Content -Path $sumsFile -Encoding ASCII
Get-Content $sumsFile | ForEach-Object { Write-Host "   $_" }

# ---------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "[OK] Release Build Complete!" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Portable (ZIP):  $x64Zip" -ForegroundColor White

$setupExe = "$releasePath\USBAnywhere-Server_Setup_v$version.exe"
if (Test-Path $setupExe) {
    Write-Host "   Setup (EXE):     $setupExe" -ForegroundColor White
}

Write-Host ""
Write-Host "   Version: $version" -ForegroundColor Gray
Write-Host ""
