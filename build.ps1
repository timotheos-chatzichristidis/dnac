# build.ps1 - compile dnac on Windows
# Usage:  ./build.ps1

$ErrorActionPreference = "Stop"
$src = Join-Path $PSScriptRoot "dnac.c"
$out = Join-Path $PSScriptRoot "dnac.exe"

function Test-Cmd($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

if (Test-Cmd gcc) {
    Write-Host "Compiling with gcc..." -ForegroundColor Cyan
    & gcc -O3 -Wall -o $out $src -lm
}
elseif (Test-Cmd clang) {
    Write-Host "Compiling with clang..." -ForegroundColor Cyan
    & clang -O3 -Wall -o $out $src -lm
}
elseif (Test-Cmd cl) {
    Write-Host "Compiling with MSVC cl..." -ForegroundColor Cyan
    & cl /O2 /nologo /Fe:$out $src
}
else {
    Write-Host "No C compiler found (gcc / clang / cl)." -ForegroundColor Yellow
    Write-Host "Install one of:" -ForegroundColor Yellow
    Write-Host "  - w64devkit (single zip, has gcc): https://github.com/skeeto/w64devkit/releases"
    Write-Host "  - MSYS2:   winget install -e --id MSYS2.MSYS2   then in its shell: pacman -S mingw-w64-ucrt-x86_64-gcc"
    Write-Host "  - LLVM:    winget install -e --id LLVM.LLVM   (gives clang)"
    exit 1
}

if (Test-Path $out) { Write-Host "OK -> $out" -ForegroundColor Green }
