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

# --- verification ------------------------------------------------------------
# Bug found 2026-08-19: this file used to "verify" GeCo3 by hashing a COPY of the
# original against the original -- two files no decoder ever wrote. It printed
# lossless=True for 100% of runs, including ones where GeDe3 produced 0 bytes.
# Everything below exists so that cannot happen again:
#   * the decoded path is passed in explicitly and may never equal the input,
#   * a non-zero exit code, a missing file and an empty file are all failures,
#   * Invoke-Tool keeps the tool's stderr instead of piping it to Out-Null,
#   * Assert-VerifierCanFail runs the whole thing against deliberately broken
#     input at startup and aborts if it reports success.

function Invoke-Tool($exe, $argv, $logName) {
    $log = Join-Path $work $logName
    & $exe @argv *> $log
    return @{ Exit = $LASTEXITCODE; Log = $log }
}

function Check-Roundtrip($orig, $got, $exitCode) {
    if ((Resolve-Path -LiteralPath $orig).Path -eq
        (Resolve-Path -LiteralPath $got -ErrorAction SilentlyContinue).Path) {
        throw "verifier was asked to compare '$orig' with itself - that is the 2026-08-19 bug"
    }
    if ($exitCode -ne 0)       { return @{ ok = $false; why = "decoder exit $exitCode" } }
    if (-not (Test-Path $got)) { return @{ ok = $false; why = "no output file" } }
    $g = Get-Item $got; $o = Get-Item $orig
    if ($g.Length -eq 0)          { return @{ ok = $false; why = "empty output" } }
    if ($g.Length -ne $o.Length)  { return @{ ok = $false; why = "size $($g.Length) vs $($o.Length)" } }
    if ((Get-FileHash $orig -Algorithm SHA256).Hash -ne (Get-FileHash $got -Algorithm SHA256).Hash) {
        return @{ ok = $false; why = "hash mismatch" }
    }
    return @{ ok = $true; why = "" }
}

# Negative control: prove the check above can go red before trusting it green.
function Assert-VerifierCanFail {
    $t = Join-Path $work "_selftest.bin"
    Set-Content -LiteralPath $t -Value "ACGT" -NoNewline
    $missing = Join-Path $work "_selftest.absent"
    Remove-Item $missing -Force -ErrorAction SilentlyContinue
    $empty = Join-Path $work "_selftest.empty"
    Set-Content -LiteralPath $empty -Value "" -NoNewline
    $cases = @(
        @{ n = "non-zero exit"; r = (Check-Roundtrip $t $empty 1) },
        @{ n = "missing file";  r = (Check-Roundtrip $t $missing 0) },
        @{ n = "empty output";  r = (Check-Roundtrip $t $empty 0) }
    )
    foreach ($c in $cases) {
        if ($c.r.ok) { throw "SELF-TEST FAILED: the verifier accepted '$($c.n)'. Fix it before believing any row below." }
    }
    Remove-Item $t, $empty -Force -ErrorAction SilentlyContinue
    Write-Host "verifier self-test: rejects exit code, missing file and empty output (3/3)" -ForegroundColor DarkGray
}

function Run-Dnac($dataset, $seq, $ref) {
    $b = Bases $seq
    $out = Join-Path $work "d.dnac"; $rt = Join-Path $work "d.rt"
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if ($ref) { & $dnac cr $seq $out $ref 22 | Out-Null } else { & $dnac c $seq $out 22 | Out-Null }
    $tc = $sw.Elapsed.TotalSeconds; $sw.Restart()
    if ($ref) { $d = Invoke-Tool $dnac @("dr", $out, $rt, $ref) "dnac.log" }
    else      { $d = Invoke-Tool $dnac @("d",  $out, $rt)       "dnac.log" }
    $td = $sw.Elapsed.TotalSeconds
    $v = Check-Roundtrip $seq $rt $d.Exit
    $note = if ($v.ok) { "dec {0:N1}s, lossless=True" -f $td }
            else       { "dec {0:N1}s, DECODE FAILED ({1})" -f $td, $v.why }
    if (-not $v.ok) { Write-Host "  dnac decode failed on $dataset : $($v.why)" -ForegroundColor Red }
    Row $dataset "dnac k=22" (Get-Item $out).Length $b $tc $note
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
}

function Run-Geco($dataset, $seq, $label, $argline, $verify) {
    # GeCo3 treats ':' as its multi-file separator, so a Windows absolute path
    # ("C:\...") is parsed as a file named "C". Everything runs relative, in $work.
    $b = Bases $seq
    $name  = Split-Path $seq -Leaf
    $local = Join-Path $work $name
    Copy-Item $seq $local -Force
    $co = "$local.co"
    $de = "$local.de"        # GeDe3 strips .co and appends .de (its own docs, msg.c)
    Remove-Item $co, $de -Force -ErrorAction SilentlyContinue
    Push-Location $work
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $c = Invoke-Tool $geco (@("-F") + @($argline -split ' ' | Where-Object { $_ }) + @($name)) "geco.log"
    $tc = $sw.Elapsed.TotalSeconds
    Pop-Location
    if ($c.Exit -ne 0 -or -not (Test-Path $co)) {
        Write-Host "  (GeCo3 $label failed: exit $($c.Exit); see $($c.Log))" -ForegroundColor Yellow; return
    }
    $note = ""
    if ($verify) {
        Push-Location $work
        $sw.Restart(); $d = Invoke-Tool $gede @("-F", "$name.co") "gede.log"
        $td = $sw.Elapsed.TotalSeconds
        Pop-Location
        $v = Check-Roundtrip $local $de $d.Exit
        if ($v.ok) { $note = "dec {0:N1}s, lossless=True" -f $td }
        else {
            $tail = (Get-Content $d.Log -Tail 1 -ErrorAction SilentlyContinue) -join ''
            $note = "DECODE FAILED ({0}) after {1:N1}s" -f $v.why, $td
            Write-Host "  GeDe3 could not decode $dataset $label : $($v.why) | $tail" -ForegroundColor Red
        }
    }
    Row $dataset "GeCo3 $label" (Get-Item $co).Length $b $tc $note
    Remove-Item $co, $de, $local -Force -ErrorAction SilentlyContinue
}

Assert-VerifierCanFail

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
