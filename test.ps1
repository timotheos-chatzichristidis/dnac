# test.ps1 - end-to-end demo: build -> generate -> compress -> verify -> compare
# Usage:  ./test.ps1            (2,000,000 bases, k=11)
#         ./test.ps1 5000000 12 (custom size and order)

param(
    [long]$Bases = 2000000,
    [int]$K = 16
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$exe = Join-Path $PSScriptRoot "dnac.exe"

if (-not (Test-Path $exe)) { & (Join-Path $PSScriptRoot "build.ps1") }

Write-Host "`n[1/5] Generating $Bases bases of structured DNA..." -ForegroundColor Cyan
& $exe gen sample.fa $Bases 1

Write-Host "[2/5] Compressing (k=$K)..." -ForegroundColor Cyan
& $exe c sample.fa sample.dnac $K

Write-Host "[3/5] Decompressing..." -ForegroundColor Cyan
& $exe d sample.dnac roundtrip.fa

Write-Host "[4/5] Verifying lossless roundtrip..." -ForegroundColor Cyan
$h1 = (Get-FileHash sample.fa   -Algorithm SHA256).Hash
$h2 = (Get-FileHash roundtrip.fa -Algorithm SHA256).Hash
if ($h1 -eq $h2) { Write-Host "    ROUNDTRIP IDENTICAL (SHA-256 match)" -ForegroundColor Green }
else { Write-Host "    MISMATCH! decompression differs" -ForegroundColor Red; exit 1 }

Write-Host "[5/5] Comparing against zip (Deflate)..." -ForegroundColor Cyan
if (Test-Path sample.zip) { Remove-Item sample.zip }
Compress-Archive -Path sample.fa -DestinationPath sample.zip -CompressionLevel Optimal

$orig = (Get-Item sample.fa).Length
$ours = (Get-Item sample.dnac).Length
$zip  = (Get-Item sample.zip).Length
function bpb($bytes) { return [math]::Round($bytes * 8.0 / $Bases, 3) }

Write-Host ""
Write-Host ("{0,-18} {1,12} {2,12} {3,10}" -f "method","bytes","bits/base","ratio")
Write-Host ("{0,-18} {1,12:N0} {2,12} {3,10}" -f "original (.fa)", $orig, "-", "1.00x")
Write-Host ("{0,-18} {1,12:N0} {2,12} {3,9}x" -f "zip / Deflate", $zip, (bpb $zip), [math]::Round($orig/$zip,2))
Write-Host ("{0,-18} {1,12:N0} {2,12} {3,9}x" -f "dnac (k=$K)", $ours, (bpb $ours), [math]::Round($orig/$ours,2)) -ForegroundColor Green
Write-Host "`nTip: try a REAL genome (FASTA from NCBI) and rerun: .\dnac.exe c real.fa real.dnac 12" -ForegroundColor DarkGray
