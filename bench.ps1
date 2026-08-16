# bench.ps1 - measure one build on one dataset: roundtrip (SHA-256) + bits/base
# Usage: ./bench.ps1 -Exe .\dnac.exe -File .\chr21_slice.fa [-K 20]
param(
    [string]$Exe  = ".\dnac.exe",
    [string]$File = ".\chr21_slice.fa",
    [int]$K = 20,
    [switch]$Fast          # compress only (parameter sweeps); skips the roundtrip proof
)
$ErrorActionPreference = "Stop"
$tmp = [System.IO.Path]::GetTempPath()
$tag = [System.IO.Path]::GetFileNameWithoutExtension($File) + "_" + [System.IO.Path]::GetFileNameWithoutExtension($Exe) + "_k$K"
$cmp = Join-Path $tmp "$tag.dnac"
$rt  = Join-Path $tmp "$tag.rt"

# count ACGT bases once (cached next to the file)
$cntFile = "$File.acgt"
if (Test-Path $cntFile) { $bases = [long](Get-Content $cntFile) }
else {
    # per-byte loops in PowerShell take minutes on a chromosome; compile the count
    if (-not ("BaseCount" -as [type])) {
        Add-Type -TypeDefinition 'public class BaseCount { public static long Of(string p){ var b=System.IO.File.ReadAllBytes(p); long n=0; foreach(var x in b){ if(x==65||x==67||x==71||x==84) n++; } return n; } }'
    }
    $bases = [BaseCount]::Of((Resolve-Path $File).Path)
    Set-Content $cntFile $bases
}

$sw = [Diagnostics.Stopwatch]::StartNew()
& $Exe c $File $cmp $K | Out-Null
$tc = $sw.Elapsed.TotalSeconds; $sw.Restart()
if ($Fast) {
    $sz = (Get-Item $cmp).Length
    "{0,-22} {1,-16} k={2,-3} bpb={3:N4}  size={4}  (compress only, {5:N1}s)" -f `
        [System.IO.Path]::GetFileName($File), [System.IO.Path]::GetFileName($Exe), $K, (8.0*$sz/$bases), $sz, $tc
    Remove-Item $cmp -Force; exit 0
}
& $Exe d $cmp $rt | Out-Null
$td = $sw.Elapsed.TotalSeconds

$h1 = (Get-FileHash $File -Algorithm SHA256).Hash
$h2 = (Get-FileHash $rt   -Algorithm SHA256).Hash
$ok = ($h1 -eq $h2)
$sz = (Get-Item $cmp).Length
$bpb = 8.0 * $sz / $bases

"{0,-22} {1,-16} k={2,-3} bpb={3:N4}  size={4}  lossless={5}  enc={6:N1}s dec={7:N1}s" -f `
    [System.IO.Path]::GetFileName($File), [System.IO.Path]::GetFileName($Exe), $K, $bpb, $sz, $ok, $tc, $td
if (-not $ok) { Write-Host "!! ROUNDTRIP FAILED" -ForegroundColor Red; exit 1 }
Remove-Item $cmp, $rt -Force
