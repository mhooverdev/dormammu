# Script to set up Visual Studio Build Tools environment for compiling native dependencies

Write-Host "Searching for Visual Studio Build Tools..." -ForegroundColor Cyan

# Common installation paths
$vsPaths = @(
    "$env:ProgramFiles\Microsoft Visual Studio\2022\BuildTools",
    "$env:ProgramFiles\Microsoft Visual Studio\2022\Community",
    "$env:ProgramFiles\Microsoft Visual Studio\2022\Professional",
    "$env:ProgramFiles\Microsoft Visual Studio\2022\Enterprise",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community"
)

$foundNmake = $null
$vsInstallPath = $null

foreach ($path in $vsPaths) {
    if (Test-Path $path) {
        Write-Host "Found Visual Studio at: $path" -ForegroundColor Green
        
        # Look for nmake in VC Tools (search in common locations first for speed)
        $vcToolsPaths = @(
            "$path\VC\Tools\MSVC\*\bin\Hostx64\x64",
            "$path\VC\Tools\MSVC\*\bin\Hostx86\x64",
            "$path\VC\Auxiliary\Build"
        )
        
        $nmakePath = $null
        foreach ($vcPath in $vcToolsPaths) {
            $resolved = Resolve-Path $vcPath -ErrorAction SilentlyContinue
            if ($resolved) {
                $nmakePath = Get-ChildItem -Path $resolved[0].Path -Filter "nmake.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($nmakePath) { break }
            }
        }
        
        # Fallback to recursive search if not found in common locations
        if (-not $nmakePath) {
            $nmakePath = Get-ChildItem -Path $path -Recurse -Filter "nmake.exe" -ErrorAction SilentlyContinue -Depth 6 | Select-Object -First 1
        }
        
        if ($nmakePath) {
            $foundNmake = $nmakePath.FullName
            $vsInstallPath = $path
            Write-Host "Found nmake at: $foundNmake" -ForegroundColor Green
            break
        }
    }
}

if (-not $foundNmake) {
    Write-Host "`nERROR: nmake.exe not found!" -ForegroundColor Red
    Write-Host "`nPlease ensure Visual Studio Build Tools are installed with C++ build tools." -ForegroundColor Yellow
    Write-Host "`nTo install:" -ForegroundColor Yellow
    Write-Host "1. Download Visual Studio Build Tools from: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor White
    Write-Host "2. Run the installer and select 'Desktop development with C++' workload" -ForegroundColor White
    Write-Host "3. After installation, restart your terminal and run this script again" -ForegroundColor White
    exit 1
}

# Get the directory containing nmake
$nmakeDir = Split-Path $foundNmake -Parent

# Find vcvars64.bat or similar setup script
$vcvarsPath = Get-ChildItem -Path $vsInstallPath -Recurse -Filter "vcvars64.bat" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($vcvarsPath) {
    Write-Host "`nFound vcvars64.bat at: $($vcvarsPath.FullName)" -ForegroundColor Green
    Write-Host "Setting up environment..." -ForegroundColor Cyan
    
    # Call vcvars64.bat to set up the environment
    $vcvarsFile = $vcvarsPath.FullName
    $vcvarsDir = Split-Path $vcvarsFile -Parent
    
    # Create a temporary batch file that calls vcvars64 and then exports all env vars
    $tempBat = [System.IO.Path]::GetTempFileName() + ".bat"
    @"
@echo off
call "$vcvarsFile" >nul 2>&1
set
"@ | Out-File -FilePath $tempBat -Encoding ASCII
    
    Write-Host "Running vcvars64.bat..." -ForegroundColor Gray
    $envVars = cmd /c $tempBat 2>$null
    
    # Clean up temp file
    Remove-Item $tempBat -ErrorAction SilentlyContinue
    
    # Parse and set environment variables
    $varCount = 0
    foreach ($line in $envVars) {
        if ($line -match "^([^=]+)=(.*)$") {
            $varName = $matches[1]
            $varValue = $matches[2]
            [Environment]::SetEnvironmentVariable($varName, $varValue, "Process")
            $varCount++
        }
    }
    
    Write-Host "Environment configured! ($varCount variables set)" -ForegroundColor Green
} else {
    # Fallback: just add nmake directory and common VS paths to PATH
    Write-Host "`nAdding build tools to PATH for this session..." -ForegroundColor Yellow
    
    # Add nmake directory
    $env:PATH = "$nmakeDir;$env:PATH"
    
    # Try to find and add other common VS tool paths
    $vcToolsDir = Split-Path $nmakeDir -Parent
    if (Test-Path "$vcToolsDir\cl.exe") {
        $env:PATH = "$vcToolsDir;$env:PATH"
    }
    
    # Add Windows SDK paths if available
    $sdkPaths = @(
        "$env:ProgramFiles\Windows Kits\10\bin\10.0.*\x64",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.*\x64"
    )
    foreach ($sdkPath in $sdkPaths) {
        $resolved = Resolve-Path $sdkPath -ErrorAction SilentlyContinue
        if ($resolved) {
            $env:PATH = "$($resolved[0].Path);$env:PATH"
        }
    }
    
    Write-Host "Added build tools to PATH" -ForegroundColor Green
}

# Verify nmake is accessible
$nmakeCheck = Get-Command nmake.exe -ErrorAction SilentlyContinue
if (-not $nmakeCheck) {
    # Try adding nmake directory directly if not found
    $env:PATH = "$nmakeDir;$env:PATH"
    $nmakeCheck = Get-Command nmake.exe -ErrorAction SilentlyContinue
}

if ($nmakeCheck) {
    Write-Host ""
    Write-Host "[OK] nmake.exe is now accessible!" -ForegroundColor Green
    Write-Host "Location: $($nmakeCheck.Source)" -ForegroundColor Gray
    Write-Host ""
    
    # Change to project directory
    $projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $projectDir
    
    Write-Host "Compiling bcrypt_elixir..." -ForegroundColor Cyan
    Write-Host ""
    
    # Ensure Elixir/Erlang are in PATH
    $elixirPath = "C:\Program Files\Elixir\bin"
    $erlangPath = "C:\Program Files\Erlang OTP\bin"
    if (Test-Path $elixirPath) { $env:PATH = "$elixirPath;$env:PATH" }
    if (Test-Path $erlangPath) { $env:PATH = "$erlangPath;$env:PATH" }
    
    # Check if mix is available
    $mixCmd = Get-Command mix -ErrorAction SilentlyContinue
    if (-not $mixCmd) {
        $mixCmd = "C:\Program Files\Elixir\bin\mix.ps1"
        if (Test-Path $mixCmd) {
            # Use full path to mix.ps1
            $mixArgs = @("deps.compile", "bcrypt_elixir", "--force")
            & powershell -ExecutionPolicy Bypass -File $mixCmd $mixArgs
        } else {
            Write-Host "[ERROR] Could not find mix or mix.ps1" -ForegroundColor Red
            Write-Host "Please ensure Elixir is installed and in PATH" -ForegroundColor Yellow
            exit 1
        }
    } else {
        # Use mix directly
        & mix deps.compile bcrypt_elixir --force
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[SUCCESS] bcrypt_elixir compiled successfully!" -ForegroundColor Green
        Write-Host "You can now run: mix compile" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "[ERROR] Failed to compile bcrypt_elixir" -ForegroundColor Red
        Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "[ERROR] nmake.exe still not found in PATH" -ForegroundColor Red
    Write-Host "Try restarting your terminal or manually add to PATH:" -ForegroundColor Yellow
    Write-Host "  $nmakeDir" -ForegroundColor White
    exit 1
}
