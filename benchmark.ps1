# benchmark.ps1 - head-to-head against GeCo3 on IDENTICAL inputs.
#
# Published bits/base figures are not comparable across papers: different
# assemblies, different handling of N and line breaks, different denominators.
# The only claim worth making is one measured on the same file, on one machine.
# This script does that, for both reference-free and reference-based modes.
#
# Prereqs: ./dnac.exe built, GeCo3 built in bench-external/GeCo3-master/src,
#          sequences made with ./mkseq.ps1 into bench-external/seq/*.seq
# Usage:   ./benchmark.ps1 [-Quick]
param([switch]$Quick)
$ErrorActionPreference = "Stop"
$root   = $PSScriptRoot
$geco   = Join-Path $root "bench-external\GeCo3-master\src\GeCo3.exe"
$gede   = Join-Path $root "bench-external\GeCo3-master\src\GeDe3.exe"
$dnac   = Join-Path $root "dnac.exe"
$seqDir = Join-Path $root "bench-external\seq"
$work   = Join-Path $root "bench-external\work"
$outMd  = Join-Path $root "bench-external\results.md"
New-Item -ItemType Directory -Force $work | Out-Null

# the GeCo3 authors' own reference-mode templates (benchmark/run_ref.sh)
$PARAMR = "-rm 20:500:1:35:0.95/3:100:0.95 -rm 13:200:1:1:0.95/0:0:0 -rm 10:10:0:0:0.95/0:0:0 -lr 0.03 -hs 64"
$PARAMH = "$PARAMR -tm 4:1:0:1:0.9/0:0:0 -tm 17:100:1:10:0.95/2:20:0.95"

function Bases($seq) { [long](Get-Content "$seq.acgt") }

$rows = @()
function Row($dataset, $tool, $bytes, $bases, $secs, $note) {
    $script:rows += [pscustomobject]@{
        Dataset = $dataset; Tool = $tool; Bytes = $bytes
        Bpb = [math]::Round(8.0 * $bytes / $bases, 4); Seconds = [math]::Round($secs, 1); Note = $note
    }
    "{0,-14} {1,-22} {2,11:N0}  {3:N4} bpb  {4,6:N1}s  {5}" -f $dataset, $tool, $bytes, (8.0*$bytes/$bases), $secs, $note
}

function Run-Dnac($dataset, $seq, $ref) {
    $b = Bases $seq
    $out = Join-Path $work "d.dnac"; $rt = Join-Path $work "d.rt"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if ($ref) { & $dnac cr $seq $out $ref 22 | Out-Null } else { & $dnac c $seq $out 22 | Out-Null }
    $tc = $sw.Elapsed.TotalSeconds; $sw.Restart()
    if ($ref) { & $dnac dr $out $rt $ref | Out-Null } else { & $dnac d $out $rt | Out-Null }
    $td = $sw.Elapsed.TotalSeconds
    $ok = (Get-FileHash $seq -Algorithm SHA256).Hash -eq (Get-FileHash $rt -Algorithm SHA256).Hash
    Row $dataset "dnac k=22" (Get-Item $out).Length $b $tc ("dec {0:N1}s, lossless={1}" -f $td, $ok)
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
}

function Run-Geco($dataset, $seq, $label, $argline, $verify) {
    # GeCo3 treats ':' as its multi-file separator, so a Windows absolute path
    # ("C:\...") is parsed as a file named "C". Everything runs relative, in $work.
    $b = Bases $seq
    $name  = Split-Path $seq -Leaf
    $local = Join-Path $work $name
    Copy-Item $seq $local -Force
    Push-Location $work
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $geco -F @($argline -split ' ' | Where-Object { $_ }) $name 2>&1 | Out-Null
    $tc = $sw.Elapsed.TotalSeconds
    Pop-Location
    $co = "$local.co"
    if (-not (Test-Path $co)) { Write-Host "  (GeCo3 $label produced no output)" -ForegroundColor Yellow; return }
    $note = ""
    if ($verify) {
        $keep = "$local.orig"; Copy-Item $local $keep -Force
        Push-Location $work
        $sw.Restart(); & $gede -F "$name.co" 2>&1 | Out-Null; $td = $sw.Elapsed.TotalSeconds
        Pop-Location
        $ok = (Get-FileHash $keep -Algorithm SHA256).Hash -eq (Get-FileHash $local -Algorithm SHA256).Hash
        $note = "dec {0:N1}s, lossless={1}" -f $td, $ok
        Remove-Item $keep -Force -ErrorAction SilentlyContinue
    }
    Row $dataset "GeCo3 $label" (Get-Item $co).Length $b $tc $note
    Remove-Item $co, $local -Force -ErrorAction SilentlyContinue
}

Write-Host "== reference-free, identical input files ==" -ForegroundColor Cyan
$ecoli = Join-Path $seqDir "ecoli.seq"
Run-Dnac "E. coli"  $ecoli $null
Run-Geco "E. coli"  $ecoli "-l 9"  "-l 9"  $true
Run-Geco "E. coli"  $ecoli "-l 16" "-l 16" $true

if (-not $Quick) {
    $chr21 = Join-Path $seqDir "chr21.seq"
    Run-Dnac "human chr21" $chr21 $null
    Run-Geco "human chr21" $chr21 "-l 9"  "-l 9"  $false
    Run-Geco "human chr21" $chr21 "-l 14" "-l 14" $false
    Run-Geco "human chr21" $chr21 "-l 16" "-l 16" $false
}

Write-Host "`n== reference-based, identical pairs ==" -ForegroundColor Cyan
Copy-Item $ecoli (Join-Path $work "ref.seq") -Force   # relative name for GeCo3
foreach ($pair in @(@("W3110 vs MG1655", "w3110.seq"), @("O157 vs MG1655", "o157.seq"))) {
    $tgt = Join-Path $seqDir $pair[1]
    Run-Dnac $pair[0] $tgt $ecoli
    Run-Geco $pair[0] $tgt "-r (ref models)"    "$PARAMR -r ref.seq"
    Run-Geco $pair[0] $tgt "-r (hybrid models)" "$PARAMH -r ref.seq"
}

$rows | Format-Table -AutoSize
$md = "# dnac vs GeCo3 — same machine, same input files`n`n"
$md += "| dataset | tool | bytes | bits/base | seconds | note |`n|---|---|---:|---:|---:|---|`n"
foreach ($r in $rows) {
    $md += "| {0} | {1} | {2:N0} | {3:N4} | {4:N1} | {5} |`n" -f $r.Dataset, $r.Tool, $r.Bytes, $r.Bpb, $r.Seconds, $r.Note
}
Set-Content $outMd $md
Write-Host "`nwrote $outMd" -ForegroundColor Green
