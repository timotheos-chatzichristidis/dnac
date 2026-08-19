# verify-claims.ps1 - re-derive every published number and diff it against the docs.
#
# WHY THIS EXISTS
# Five times in three days a revisit found a wrong published figure, and every
# one had the same shape: the number was only ever READ, never EXECUTED. The
# codec itself has never been wrong in these passes, because the codec is the one
# thing a check runs on every commit. So: anything we assert in public gets a row
# here, and this script runs it.
#
# Each claim carries TWO independent detectors:
#   ANCHOR  the exact sentence must still exist in the doc. If someone edits the
#           number by hand, the anchor stops matching and the claim goes red --
#           you cannot change a published figure without coming through here.
#   VALUE   the recipe is executed now and compared against what the doc says.
#           Catches the opposite drift: the code moved, the doc did not (that is
#           how the v0.2.0 level byte and the v0.3.0 geometry bytes made every
#           absolute byte count stale, twice).
#
# Tiers:  fast  (~2 min, E. coli scale)   -- run before every commit that touches
#                                            dnac.c or the docs
#         slow  (~15 min, full chr21)     -- run before tagging a release
#         extern(needs GeCo3 built)       -- run before changing a head-to-head claim
#
# Usage:  ./verify-claims.ps1 [-Tier fast|slow|extern|all] [-SelfTest] [-Only <id>]
#
# -SelfTest injects a fault into each detector and fails if the detector stays
# green. A check nobody has watched go red is decoration; see the 2026-08-19 note
# in benchmark.ps1.

param(
    [ValidateSet('fast','slow','extern','all')][string]$Tier = 'fast',
    [switch]$SelfTest,
    [string]$Only
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dnac = Join-Path $root 'dnac.exe'
$work = Join-Path $root 'bench-external\work'
New-Item -ItemType Directory -Force $work | Out-Null
if (-not (Test-Path $dnac)) { throw "dnac.exe not found - run ./build.ps1 first" }

# --- measurement helpers ------------------------------------------------------

function Bases($seq) {
    $a = "$seq.acgt"
    if (-not (Test-Path $a)) { throw "missing base count '$a' (run ./mkseq.ps1)" }
    [long](Get-Content $a)
}

# Compress and return the stored size in bytes. Always round-trips: a size from a
# run whose losslessness was not checked is not a measurement, it is a number.
function Size($inFile, $ref, $level) {
    $out = Join-Path $work 'vc.dnac'; $rt = Join-Path $work 'vc.rt'
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    $lvl = if ($level) { "$level" } else { '3' }
    if ($ref) { & $dnac cr $inFile $out $ref 22 $lvl | Out-Null }
    else      { & $dnac c  $inFile $out 22 $lvl      | Out-Null }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { throw "compress failed: $inFile" }
    if ($ref) { & $dnac dr $out $rt $ref | Out-Null } else { & $dnac d $out $rt | Out-Null }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $rt)) { throw "decompress failed: $inFile" }
    if ((Get-FileHash $inFile -Algorithm SHA256).Hash -ne (Get-FileHash $rt -Algorithm SHA256).Hash) {
        throw "NOT LOSSLESS on $inFile - stop everything else and fix this"
    }
    $n = (Get-Item $out).Length
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    $n
}

function Bpb($bytes, $bases) { [math]::Round(8.0 * $bytes / $bases, 4) }

$S = { param($n) Join-Path $root "bench-external\seq\$n" }   # plain-ACGT .seq files
$F = { param($n) Join-Path $root $n }                        # FASTA files in the repo root

# --- the registry -------------------------------------------------------------
# anchor = a substring that must appear verbatim in doc. Keep it tight enough
# that editing the number breaks it, loose enough to survive reflowing prose.

$claims = @(
  @{ id='ecoli-seq-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| E. coli (4,641,652 bases) | **dnac `-l 3`** | **1.8833**'
     expect=1.8833
     measure={ Bpb (Size (& $S 'ecoli.seq') $null 3) (Bases (& $S 'ecoli.seq')) } }

  @{ id='w3110-seq-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| W3110 vs MG1655 (near-identical strains) | **1,088 B** |'
     expect=1088
     measure={ Size (& $S 'w3110.seq') (& $S 'ecoli.seq') 3 } }

  @{ id='o157-seq-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged strains) | **361,399 B** |'
     expect=361399
     measure={ Size (& $S 'o157.seq') (& $S 'ecoli.seq') 3 } }

  @{ id='w3110-fa-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='1,944 bytes for a 4.6 Mbp genome'
     expect=1944
     measure={ Size (& $F 'w3110.fa') (& $F 'ecoli.fa') 3 } }

  @{ id='ecoli-fa-alone-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.001
     anchor='| E. coli W3110 (real strain) | E. coli MG1655 | 1.880 |'
     expect=1.880
     measure={ Bpb (Size (& $F 'w3110.fa') $null 3) (Bases (& $F 'w3110.fa')) } }

  @{ id='ecoli-ind-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.0005
     anchor='| E. coli, simulated individual | E. coli MG1655 | 1.885 | **0.0219**'
     expect=0.0219
     measure={ Bpb (Size (& $F 'ecoli_ind.fa') (& $F 'ecoli.fa') 3) (Bases (& $F 'ecoli_ind.fa')) } }

  @{ id='o157-fa-ref-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.001
     anchor='| E. coli O157:H7 (real, diverged strain) | E. coli MG1655 | 1.812 | **0.519**'
     expect=0.519
     measure={ Bpb (Size (& $F 'o157.fa') (& $F 'ecoli.fa') 3) (Bases (& $F 'o157.fa')) } }

  @{ id='chr21-fa-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0005
     anchor='| **dnac** (k=22)                | **1.546**'
     expect=1.546
     measure={ Bpb (Size (& $F 'chr21.fa') $null 3) (Bases (& $F 'chr21.fa')) } }

  @{ id='chr21-seq-l3-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| human chr21 (40,088,619 bases) | **dnac `-l 3`** (default) | **1.4979**'
     expect=1.4979
     measure={ Bpb (Size (& $S 'chr21.seq') $null 3) (Bases (& $S 'chr21.seq')) } }

  @{ id='chr21-seq-l1-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| | **dnac `-l 1`** | **1.5065**'
     expect=1.5065
     measure={ Bpb (Size (& $S 'chr21.seq') $null 1) (Bases (& $S 'chr21.seq')) } }

  @{ id='chr21-ind-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0005
     anchor='chr21 | 1.508 | **0.0238**'
     expect=0.0238
     measure={ Bpb (Size (& $F 'chr21_ind.fa') (& $F 'chr21.fa') 3) (Bases (& $F 'chr21_ind.fa')) } }
)

# --- runner -------------------------------------------------------------------

function Check-Anchor($c) {
    $p = Join-Path $root $c.doc
    if (-not (Test-Path $p)) { return @{ ok=$false; why="doc '$($c.doc)' not found" } }
    if ((Get-Content $p -Raw).Contains($c.anchor)) { return @{ ok=$true } }
    @{ ok=$false; why="anchor text is no longer in $($c.doc): '$($c.anchor)'" }
}

function Run-Claim($c) {
    # Measure first even when the anchor is missing: when a claim goes red you
    # want the number to write into the doc, not just the news that it is wrong.
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try   { $m = & $c.measure }
    catch { return [pscustomobject]@{ id=$c.id; tier=$c.tier; status='ERROR'; expected=$c.expect; measured=''; note=$_.Exception.Message } }
    $a = Check-Anchor $c
    if (-not $a.ok) { return [pscustomobject]@{ id=$c.id; tier=$c.tier; status='ANCHOR'; expected=$c.expect; measured=$m; note=$a.why } }
    $d = [math]::Abs([double]$m - [double]$c.expect)
    $ok = $d -le [double]$c.tol
    [pscustomobject]@{
        id = $c.id; tier = $c.tier; status = $(if ($ok) { 'OK' } else { 'DRIFT' })
        expected = $c.expect; measured = $m
        note = $(if ($ok) { "{0:N1}s" -f $sw.Elapsed.TotalSeconds } else { "off by $d $($c.unit) - doc says $($c.expect), code says $m" })
    }
}

# Negative control: prove both detectors can go red before trusting either green.
if ($SelfTest) {
    Write-Host "self-test: injecting faults into both detectors" -ForegroundColor Cyan
    $fakeDoc = @{ id='selftest-anchor'; tier='fast'; doc='README.md'; unit='B'; tol=0
                  anchor='THIS SENTENCE IS NOT IN THE README'; expect=1; measure={ 1 } }
    $r1 = Run-Claim $fakeDoc
    if ($r1.status -ne 'ANCHOR') { throw "SELF-TEST FAILED: a missing anchor was not detected (got '$($r1.status)')" }

    $fakeVal = @{ id='selftest-value'; tier='fast'; doc='README.md'; unit='B'; tol=0
                  anchor='# dnac'; expect=1; measure={ 999 } }
    $r2 = Run-Claim $fakeVal
    if ($r2.status -ne 'DRIFT') { throw "SELF-TEST FAILED: a wrong value was not detected (got '$($r2.status)')" }

    $fakeErr = @{ id='selftest-error'; tier='fast'; doc='README.md'; unit='B'; tol=0
                  anchor='# dnac'; expect=1; measure={ throw 'boom' } }
    $r3 = Run-Claim $fakeErr
    if ($r3.status -ne 'ERROR') { throw "SELF-TEST FAILED: a failing recipe was not detected (got '$($r3.status)')" }

    Write-Host "self-test: ANCHOR, DRIFT and ERROR all detected (3/3)`n" -ForegroundColor Green
}

$sel = $claims | Where-Object { ($Tier -eq 'all' -or $_.tier -eq $Tier) -and (-not $Only -or $_.id -eq $Only) }
if (-not $sel) { throw "no claims selected (tier=$Tier, only=$Only)" }
Write-Host "verifying $($sel.Count) claim(s), tier=$Tier`n" -ForegroundColor Cyan

$results = foreach ($c in $sel) { Write-Host "  $($c.id) ..." -NoNewline; $r = Run-Claim $c; Write-Host " $($r.status)"; $r }
Write-Host ''
$results | Format-Table -AutoSize

$bad = @($results | Where-Object { $_.status -ne 'OK' })
if ($bad) {
    Write-Host "$($bad.Count) claim(s) NOT verified - the docs and the code disagree." -ForegroundColor Red
    Write-Host "Fix the doc (or the code) and re-run. Do not publish while this is red." -ForegroundColor Red
    exit 1
}
Write-Host "all $($results.Count) claim(s) reproduce." -ForegroundColor Green
