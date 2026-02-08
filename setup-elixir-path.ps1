# Script to add Elixir and Erlang to PATH and fix execution policy

Write-Host "Setting up Elixir/Erlang environment..." -ForegroundColor Cyan

# Add Elixir to PATH
$elixirPath = "C:\Program Files\Elixir\bin"
if (Test-Path $elixirPath) {
    if ($env:PATH -notlike "*$elixirPath*") {
        $env:PATH += ";$elixirPath"
        Write-Host "Added Elixir to PATH for this session" -ForegroundColor Green
    } else {
        Write-Host "Elixir already in PATH" -ForegroundColor Yellow
    }
} else {
    Write-Host "Elixir not found at $elixirPath" -ForegroundColor Red
}

# Try to find and add Erlang to PATH
$erlangPaths = @(
    "C:\Program Files\Erlang OTP\bin",
    "C:\Program Files (x86)\Erlang OTP\bin",
    "C:\erl*\bin"
)

$erlangFound = $false
foreach ($path in $erlangPaths) {
    if (Test-Path $path) {
        if ($env:PATH -notlike "*$path*") {
            $env:PATH += ";$path"
            Write-Host "Added Erlang to PATH: $path" -ForegroundColor Green
            $erlangFound = $true
            break
        }
    }
}

# If Erlang not found, search for it
if (-not $erlangFound) {
    Write-Host "Searching for Erlang installation..." -ForegroundColor Yellow
    $erlPath = Get-ChildItem "C:\Program Files" -Filter "erl.exe" -Recurse -ErrorAction SilentlyContinue -Depth 2 | Select-Object -First 1
    if ($erlPath) {
        $erlangBin = Split-Path $erlPath.FullName
        if ($env:PATH -notlike "*$erlangBin*") {
            $env:PATH += ";$erlangBin"
            Write-Host "Found and added Erlang: $erlangBin" -ForegroundColor Green
            $erlangFound = $true
        }
    }
}

if (-not $erlangFound) {
    Write-Host "WARNING: Erlang not found. Please install Erlang/OTP from https://www.erlang.org/downloads" -ForegroundColor Red
    Write-Host "Or use the Elixir installer which includes Erlang: https://elixir-lang.org/install.html#windows" -ForegroundColor Yellow
}

# Test mix command
Write-Host "`nTesting mix command..." -ForegroundColor Cyan
try {
    $mixVersion = & "C:\Program Files\Elixir\bin\mix.ps1" --version 2>&1
    Write-Host "Mix is working!" -ForegroundColor Green
    Write-Host $mixVersion
} catch {
    Write-Host "Error running mix: $_" -ForegroundColor Red
}

Write-Host "`nTo make PATH changes permanent, add these directories to your system PATH:" -ForegroundColor Cyan
Write-Host "1. Open System Properties > Environment Variables" -ForegroundColor White
Write-Host "2. Edit the PATH variable" -ForegroundColor White
Write-Host "3. Add: C:\Program Files\Elixir\bin" -ForegroundColor White
if ($erlangFound) {
    Write-Host "4. Add the Erlang bin directory found above" -ForegroundColor White
}

Write-Host "`nTo run mix commands now, use:" -ForegroundColor Cyan
Write-Host 'powershell -ExecutionPolicy Bypass -File "C:\Program Files\Elixir\bin\mix.ps1" <command>' -ForegroundColor Yellow
