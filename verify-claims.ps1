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
#         meta  (needs bench-external/seq/meta.seq, ~25 min) -- the "Where this
#           loses" table: the metagenome bake-off against gzip/bzip2/zstd/xz.
#           These are the only rows here defending a number a COMPETITOR set, and
#           they exist because an unverified losing number rots exactly as fast as
#           an unverified winning one. Get the data with
#           `sh scripts/get-data.sh --meta` and copy data/meta.seq into
#           bench-external/seq/. xz is resolved by its --version string, because a
#           busybox applet named xz that cannot compress usually wins on PATH.
#         extern(needs GeCo3 built, ~10 min) -- the COMPETITOR's columns. Until
#           2026-08-20 nothing re-ran these, which meant the only figures in the
#           README nobody checked were the comparative claims -- the ones a reader
#           is most entitled to distrust. Run before touching a head-to-head claim.
#
# Usage:  ./verify-claims.ps1 [-Tier fast|slow|extern|all] [-SelfTest] [-Only <id>]
#         ./verify-claims.ps1 -Tier meta              # ~25 min, the losing columns
#         ./verify-claims.ps1 -AnchorsOnly -Tier all     # seconds: after editing a doc,
#           checks every claim's sentence is still there without re-measuring anything.
#           Catches a hand-edited figure immediately; it does NOT prove the value.
#
# -SelfTest injects a fault into each detector and fails if the detector stays
# green. A check nobody has watched go red is decoration; see the 2026-08-19 note
# in benchmark.ps1.

param(
    [ValidateSet('fast','slow','extern','meta','all')][string]$Tier = 'fast',
    [switch]$SelfTest,
    [switch]$AnchorsOnly,
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
function Size($inFile, $ref, $level, $blocks) {
    $out = Join-Path $work 'vc.dnac'; $rt = Join-Path $work 'vc.rt'
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    $lvl = if ($level) { "$level" } else { '3' }
    $jarg = if ($blocks) { @('-j', "$blocks") } else { @() }
    if ($ref) { & $dnac cr $inFile $out $ref 22 $lvl @jarg | Out-Null }
    else      { & $dnac c  $inFile $out 22 $lvl @jarg      | Out-Null }
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

# Peak working set of one compress run, in MB. Not as deterministic as a byte
# count -- the OS decides what to keep resident -- so these rows carry a percentage
# tolerance rather than an exact one. They exist because a memory figure in the
# README was wrong once (an E. coli measurement generalised to chromosome scale),
# and because 4.75 GB is the difference between "runs on a laptop" and "does not".
function PeakMB($inFile, $level, $blocks) {
    $out = Join-Path $work 'vc.peak'
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    $args = @('c', $inFile, $out, '22', "$level")
    if ($blocks) { $args += @('-j', "$blocks") }
    $p = Start-Process -FilePath $dnac -ArgumentList $args -PassThru -NoNewWindow `
                       -RedirectStandardOutput (Join-Path $work 'peak.log')
    $m = 0
    while (-not $p.HasExited) {
        try { $p.Refresh(); if ($p.WorkingSet64 -gt $m) { $m = $p.WorkingSet64 } } catch {}
        Start-Sleep -Milliseconds 120
    }
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    [math]::Round($m / 1MB, 0)
}

# A general-purpose compressor, round-tripped like everything else. These rows
# exist because the README's "Where this loses" table is the only place the
# project reports a competitor beating it on something, and an unverified losing
# number rots exactly as fast as an unverified winning one.
# w64devkit ships a busybox xz that can only DECOMPRESS, so xz is resolved to a
# real XZ Utils binary rather than trusted from PATH order.
# Find an xz that can COMPRESS. Several toolchains ship a busybox applet named
# xz that only decompresses (w64devkit does), and it usually wins on PATH, so
# identify the real one by what `--version` reports rather than by where it sits.
# Override with $env:DNAC_XZ when it lives somewhere unusual.
function Resolve-Xz {
    $cands = @()
    if ($env:DNAC_XZ) { $cands += $env:DNAC_XZ }
    $cands += (Get-Command xz -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
    $cands += @(
        'C:/Program Files/Git/mingw64/bin/xz.exe',
        'C:/laragon/bin/git/mingw64/bin/xz.exe',
        '/usr/bin/xz'
    )
    foreach ($c in $cands) {
        if (-not $c -or -not (Test-Path $c)) { continue }
        $v = & $c --version 2>&1 | Out-String
        if ($v -match 'XZ Utils') { return $c }
    }
    $null
}

function Ext($tool, $inFile) {
    $out = Join-Path $work 'vc.ext'; $rt = Join-Path $work 'vc.extrt'
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    if ((Resolve-Path $inFile).Path -eq $rt) { throw "round-trip path collides with input" }
    $xz = Resolve-Xz
    switch ($tool) {
        'gzip'  { & gzip -9 -c $inFile > $out;                 & gzip  -dc $out > $rt }
        'bzip2' { & bzip2 -9 -c $inFile > $out;                & bzip2 -dc $out > $rt }
        'zstd'  { & zstd -19 --long=27 -q -f -o $out $inFile;  & zstd -d --long=27 -q -f -o $rt $out }
        'xz'    { if (-not $xz) { throw "no XZ Utils xz found - a busybox applet cannot compress; set DNAC_XZ" }
                  & $xz -9e -T1 -c $inFile > $out;             & $xz -dc $out > $rt }
        default { throw "unknown tool $tool" }
    }
    if (-not (Test-Path $out) -or (Get-Item $out).Length -eq 0) { throw "$tool produced nothing" }
    if (-not (Test-Path $rt)  -or (Get-Item $rt).Length  -eq 0) { throw "$tool decompressed to nothing" }
    if ((Get-FileHash $inFile -Algorithm SHA256).Hash -ne (Get-FileHash $rt -Algorithm SHA256).Hash) {
        throw "$tool was NOT LOSSLESS on $inFile"
    }
    $n = (Get-Item $out).Length
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    $n
}

# GeCo3, run exactly as benchmark.ps1 does: relative paths inside $work, because
# GeCo3 treats ':' as its multi-file separator and would read "C:\..." as a file
# named "C". Returns the stored size of the .co, or throws.
function Geco($seq, $argline, $refseq) {
    $geco = Join-Path $root 'bench-external\GeCo3-master\src\GeCo3.exe'
    if (-not (Test-Path $geco)) { throw "GeCo3 is not built (bench-external/GeCo3-master/src)" }
    $name  = Split-Path $seq -Leaf
    $local = Join-Path $work $name
    Copy-Item $seq $local -Force
    if ($refseq) { Copy-Item $refseq (Join-Path $work 'ref.seq') -Force }
    $co = "$local.co"
    Remove-Item $co -Force -ErrorAction SilentlyContinue
    Push-Location $work
    try {
        & $geco -F @($argline -split ' ' | Where-Object { $_ }) $name *> (Join-Path $work 'geco.log')
        $ex = $LASTEXITCODE
    } finally { Pop-Location }
    if ($ex -ne 0 -or -not (Test-Path $co)) { throw "GeCo3 failed (exit $ex); see bench-external/work/geco.log" }
    $n = (Get-Item $co).Length
    Remove-Item $co, $local -Force -ErrorAction SilentlyContinue
    $n
}

# the GeCo3 authors' own reference-mode templates, from their benchmark/run_ref.sh
$PARAMR = '-rm 20:500:1:35:0.95/3:100:0.95 -rm 13:200:1:1:0.95/0:0:0 -rm 10:10:0:0:0.95/0:0:0 -lr 0.03 -hs 64'
$PARAMH = "$PARAMR -tm 4:1:0:1:0.9/0:0:0 -tm 17:100:1:10:0.95/2:20:0.95"

# Priming pass -> size of the saved model memory, in MB (decimal, as the README
# writes it). Deterministic, unlike a timing, which is why it belongs here.
function State($ref) {
    $st = Join-Path $work 'vc.state'
    Remove-Item $st -Force -ErrorAction SilentlyContinue
    & $dnac prime $ref $st 22 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $st)) { throw "prime failed: $ref" }
    $mb = [math]::Round((Get-Item $st).Length / 1e6, 0)
    Remove-Item $st -Force -ErrorAction SilentlyContinue
    $mb
}

# NOT verified here, deliberately: every WALL-CLOCK figure in the README (46.6 s,
# 88.7 s, 98 s priming, 188 s -> 83 s, the GeCo3 columns). They depend on the
# machine and on what else is running -- a contended run reads 106 s where an
# idle one reads 98 s, and a "fix" based on that would be a new wrong number.
# Timings are re-measured by hand on an idle machine via ./bench.ps1 and are
# stated as one machine's numbers. Sizes are deterministic; times are not.

$S = { param($n) Join-Path $root "bench-external\seq\$n" }   # plain-ACGT .seq files
$F = { param($n) Join-Path $root $n }                        # FASTA files in the repo root

# --- the registry -------------------------------------------------------------
# anchor = a substring that must appear verbatim in doc. Keep it tight enough
# that editing the number breaks it, loose enough to survive reflowing prose.

$claims = @(

  # --- "Where this loses": the metagenome bake-off. 200,000,000 bases of ENA
  # DRR003618, fetched by `sh scripts/get-data.sh --meta` and copied to
  # bench-external/seq/meta.seq. These are the only rows here where the number
  # being defended is one a competitor set.
  @{ id='meta-dnac-l3-bytes'; tier='meta'; doc='README.md'; unit='B'; tol=0
     anchor='| **dnac -l3** | 17,323,036 |'
     expect=17323036
     measure={ Size (& $S 'meta.seq') $null 3 } }

  @{ id='meta-dnac-l1-bytes'; tier='meta'; doc='README.md'; unit='B'; tol=0
     anchor='| **dnac -l1** | 17,653,816 |'
     expect=17653816
     measure={ Size (& $S 'meta.seq') $null 1 } }

  @{ id='meta-zstd-bytes'; tier='meta'; doc='README.md'; unit='B'; tol=0
     anchor='| zstd -19 --long=27 | 25,427,359 |'
     expect=25427359
     measure={ Ext 'zstd' (& $S 'meta.seq') } }

  @{ id='meta-xz-bytes'; tier='meta'; doc='README.md'; unit='B'; tol=0
     anchor='| xz -9e | 25,072,456 |'
     expect=25072456
     measure={ Ext 'xz' (& $S 'meta.seq') } }

  @{ id='meta-bzip2-bytes'; tier='meta'; doc='README.md'; unit='B'; tol=0
     anchor='| bzip2 -9 | 46,527,654 |'
     expect=46527654
     measure={ Ext 'bzip2' (& $S 'meta.seq') } }

  @{ id='meta-gzip-bytes'; tier='meta'; doc='README.md'; unit='B'; tol=0
     anchor='| gzip -9 | 49,936,274 |'
     expect=49936274
     measure={ Ext 'gzip' (& $S 'meta.seq') } }

  @{ id='ecoli-seq-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| E. coli (4,641,652 bases) | **dnac `-l 3`** | **1.8833**'
     expect=1.8833
     measure={ Bpb (Size (& $S 'ecoli.seq') $null 3) (Bases (& $S 'ecoli.seq')) } }

  @{ id='w3110-seq-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| W3110 vs MG1655 (near-identical strains) | **1,060 B** |'
     expect=1060
     measure={ Size (& $S 'w3110.seq') (& $S 'ecoli.seq') 3 } }

  @{ id='o157-seq-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged strains) | **361,417 B** |'
     expect=361417
     measure={ Size (& $S 'o157.seq') (& $S 'ecoli.seq') 3 } }

  @{ id='w3110-fa-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='1,931 bytes for a 4.6 Mbp genome'
     expect=1931
     measure={ Size (& $F 'w3110.fa') (& $F 'ecoli.fa') 3 } }

  @{ id='ecoli-fa-alone-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.001
     anchor='| E. coli W3110 (real strain) | E. coli MG1655 | 1.880 |'
     expect=1.880
     measure={ Bpb (Size (& $F 'w3110.fa') $null 3) (Bases (& $F 'w3110.fa')) } }

  @{ id='ecoli-ind-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.00006
     anchor='| E. coli, simulated individual | E. coli MG1655 | 1.885 | **0.0217**'
     expect=0.0217
     measure={ Bpb (Size (& $F 'ecoli_ind.fa') (& $F 'ecoli.fa') 3) (Bases (& $F 'ecoli_ind.fa')) } }

  @{ id='o157-fa-ref-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.001
     anchor='| E. coli O157:H7 (real, diverged strain) | E. coli MG1655 | 1.812 | **0.519**'
     expect=0.519
     measure={ Bpb (Size (& $F 'o157.fa') (& $F 'ecoli.fa') 3) (Bases (& $F 'o157.fa')) } }

  # State-file sizes were wrong in the README until 2026-08-19 (523 -> 616 MB,
  # 941 -> 1,255 MB) and nothing here would have caught it, because no row
  # covered them. Any number we publish needs a row; that is the whole point.
  @{ id='ecoli-state-bytes'; tier='fast'; doc='README.md'; unit='MB'; tol=1
     anchor='(616 MB for E. coli, 1,255 MB for chr21'
     expect=616
     measure={ State (& $F 'ecoli.fa') } }

  @{ id='chr21-state-bytes'; tier='slow'; doc='README.md'; unit='MB'; tol=1
     anchor='1,255 MB for chr21'
     expect=1255
     measure={ State (& $F 'chr21.fa') } }

  # -j sizes are published, so they are executed like every other figure. The
  # block count is part of the format, so these also prove the split itself.
  @{ id='ecoli-j2-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| 2 | 1,100,603 | +0.72% |'
     expect=1100603
     measure={ Size (& $S 'ecoli.seq') $null 3 2 } }

  @{ id='ecoli-j8-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| 8 | 1,116,080 | +2.14% |'
     expect=1116080
     measure={ Size (& $S 'ecoli.seq') $null 3 8 } }

  @{ id='chr21-ind-alone-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='(0.1% SNPs + indels) | chr21 | 1.504 |'
     expect=1.504
     measure={ Bpb (Size (& $F 'chr21_ind.fa') $null 3) (Bases (& $F 'chr21_ind.fa')) } }

  @{ id='unrelated-ref-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='| E. coli MG1655 | *human chr21* (unrelated!) | 1.885 | 1.889 |'
     expect=1.889
     measure={ Bpb (Size (& $F 'ecoli.fa') (& $F 'chr21.fa') 3) (Bases (& $F 'ecoli.fa')) } }

  @{ id='slice-l1-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| 1 `fast` | 6 orders, 2 mixing experts, no IR, no tolerant models | 10.4 s | 1.7190 |'
     expect=1.719
     measure={ Bpb (Size (& $F 'chr21_slice.fa') $null 1) (Bases (& $F 'chr21_slice.fa')) } }

  @{ id='slice-l2-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| 2 `balanced` | all orders, 4 experts, no IR, no tolerant models | 14.9 s | 1.7175 |'
     expect=1.7175
     measure={ Bpb (Size (& $F 'chr21_slice.fa') $null 2) (Bases (& $F 'chr21_slice.fa')) } }

  @{ id='slice-l3-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| 3 `max` (default) | everything | 21.7 s | 1.7126 |'
     expect=1.7126
     measure={ Bpb (Size (& $F 'chr21_slice.fa') $null 3) (Bases (& $F 'chr21_slice.fa')) } }

  # The level paragraph's load-bearing number: what IR training and the tolerant
  # models are worth in SIZE. Nothing else here defends it, and it is the half of
  # that paragraph a check can hold -- the other half was a timing, which is why
  # it went stale unnoticed (it said ~21% of the run each; a paired ablation
  # measures 11-13% for IR training). Per-model splits need a compiler and live
  # in docs/model-ablation.md, re-derived by ./ablate.ps1.
  @{ id='slice-l3-vs-l2-pct'; tier='fast'; doc='README.md'; unit='%'; tol=0.002
     anchor='worth 0.289% of compressed size'
     expect=0.289
     measure={
        $l3 = Size (& $F 'chr21_slice.fa') $null 3
        $l2 = Size (& $F 'chr21_slice.fa') $null 2
        [math]::Round(100.0 * ($l2 - $l3) / $l3, 3) } }

  # Level 4 (light). Three rows because the claim has three independent halves --
  # the bits/base it costs, the bytes on a whole chromosome (where the cost is
  # largest), and the memory it saves, which is the reason it exists. The RAM
  # rows carry a wide tolerance for the same reason the -j ones do: peak working
  # set is sampled, not exact.
  @{ id='slice-l4-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| 4 `light` | 8 orders, 4 experts, IR, no tolerant models | 16.2 s | 1.7146 |'
     expect=1.7146
     measure={ Bpb (Size (& $F 'chr21_slice.fa') $null 4) (Bases (& $F 'chr21_slice.fa')) } }

  @{ id='ecoli-l4-ram'; tier='fast'; doc='README.md'; unit='MB'; tol=65
     anchor='| E. coli, 4.6 Mbp | 603 MB | **507 MB** | 1.8834 | +0.006% |'
     expect=507
     measure={ PeakMB (& $S 'ecoli.seq') 4 $null } }

  @{ id='chr21-l4-ram'; tier='slow'; doc='README.md'; unit='MB'; tol=130
     anchor='| chr21, 40 Mbp | 1,254 MB | **869 MB** | 1.5020 | +0.270% |'
     expect=869
     measure={ PeakMB (& $S 'chr21.seq') 4 $null } }

  @{ id='chr21-l4-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| chr21, 40 Mbp | 1,254 MB | **869 MB** | 1.5020 | +0.270% |'
     expect=1.5020
     measure={ Bpb (Size (& $S 'chr21.seq') $null 4) (Bases (& $S 'chr21.seq')) } }

  @{ id='sliceseq-l3-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| chr21 slice (9,836,065 bases) | **dnac `-l 3`** | **1.7114** |'
     expect=1.7114
     measure={ Bpb (Size (& $S 'chr21slice.seq') $null 3) (Bases (& $S 'chr21slice.seq')) } }

  @{ id='sliceseq-l1-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| | **dnac `-l 1`** | 1.7178 |'
     expect=1.7178
     measure={ Bpb (Size (& $S 'chr21slice.seq') $null 1) (Bases (& $S 'chr21slice.seq')) } }

  @{ id='ecoli-j4-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| 4 | 1,108,086 | +1.41% |'
     expect=1108086
     measure={ Size (& $S 'ecoli.seq') $null 3 4 } }

  @{ id='chr21-j1-bytes'; tier='slow'; doc='README.md'; unit='B'; tol=0
     anchor='| 1 | 7,506,264 | 112.6 s | 83.5 s |'
     expect=7506264
     measure={ Size (& $S 'chr21.seq') $null 3 1 } }

  @{ id='chr21-j8-bytes'; tier='slow'; doc='README.md'; unit='B'; tol=0
     anchor='| 8 | 7,836,217 | **22.2 s** | **22.0 s** |'
     expect=7836217
     measure={ Size (& $S 'chr21.seq') $null 3 8 } }

  @{ id='chr21-seq-l2-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| | **dnac `-l 2`** | **1.5039** |'
     expect=1.5039
     measure={ Bpb (Size (& $S 'chr21.seq') $null 2) (Bases (& $S 'chr21.seq')) } }

  @{ id='ram-ecoli-j1'; tier='fast'; doc='README.md'; unit='MB'; tol=65
     anchor='| E. coli, 4.6 Mbp (580 kbase blocks) | 603 MB |'
     expect=603
     measure={ PeakMB (& $S 'ecoli.seq') 3 1 } }

  @{ id='ram-ecoli-j8'; tier='fast'; doc='README.md'; unit='MB'; tol=65
     anchor='| E. coli, 4.6 Mbp (580 kbase blocks) | 603 MB | 650 MB |'
     expect=650
     measure={ PeakMB (& $S 'ecoli.seq') 3 8 } }

  @{ id='ram-chr21-j1'; tier='slow'; doc='README.md'; unit='MB'; tol=130
     anchor='| human chr21, 40 Mbp (5 Mbase blocks) | 1,253 MB |'
     expect=1253
     measure={ PeakMB (& $S 'chr21.seq') 3 1 } }

  @{ id='ram-chr21-j8'; tier='slow'; doc='README.md'; unit='MB'; tol=480
     anchor='| human chr21, 40 Mbp (5 Mbase blocks) | 1,253 MB | 4,751 MB |'
     expect=4751
     measure={ PeakMB (& $S 'chr21.seq') 3 8 } }

  @{ id='geco-ecoli-l9-bpb'; tier='extern'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| GeCo3 `-l 9` | 1.8903 |'
     expect=1.8903
     measure={ Bpb (Geco (& $S 'ecoli.seq') '-l 9') (Bases (& $S 'ecoli.seq')) } }

  @{ id='geco-ecoli-l16-bpb'; tier='extern'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| GeCo3 `-l 16` | 1.8913 |'
     expect=1.8913
     measure={ Bpb (Geco (& $S 'ecoli.seq') '-l 16') (Bases (& $S 'ecoli.seq')) } }

  @{ id='geco-w3110-ref-bytes'; tier='extern'; doc='README.md'; unit='B'; tol=0
     anchor='| W3110 vs MG1655 (near-identical strains) | **1,060 B** | 1,404 B |'
     expect=1404
     measure={ Geco (& $S 'w3110.seq') "$PARAMR -r ref.seq" (& $S 'ecoli.seq') } }

  @{ id='geco-w3110-hybrid-bytes'; tier='extern'; doc='README.md'; unit='B'; tol=0
     anchor='| W3110 vs MG1655 (near-identical strains) | **1,060 B** | 1,404 B | 1,319 B |'
     expect=1319
     measure={ Geco (& $S 'w3110.seq') "$PARAMH -r ref.seq" (& $S 'ecoli.seq') } }

  @{ id='geco-o157-ref-bytes'; tier='extern'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged strains) | **361,417 B** | 431,652 B |'
     expect=431652
     measure={ Geco (& $S 'o157.seq') "$PARAMR -r ref.seq" (& $S 'ecoli.seq') } }

  @{ id='geco-o157-hybrid-bytes'; tier='extern'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged strains) | **361,417 B** | 431,652 B | 365,401 B |'
     expect=365401
     measure={ Geco (& $S 'o157.seq') "$PARAMH -r ref.seq" (& $S 'ecoli.seq') } }

  @{ id='geco-slice-l14-bpb'; tier='extern'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| | GeCo3 `-l 14` | 1.7195 |'
     expect=1.7195
     measure={ Bpb (Geco (& $S 'chr21slice.seq') '-l 14') (Bases (& $S 'chr21slice.seq')) } }

  @{ id='geco-slice-l16-bpb'; tier='extern'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| | GeCo3 `-l 16` | 1.7163 |'
     expect=1.7163
     measure={ Bpb (Geco (& $S 'chr21slice.seq') '-l 16') (Bases (& $S 'chr21slice.seq')) } }

  @{ id='geco-chr21-l9-bpb'; tier='extern'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| | GeCo3 `-l 9` | 1.5177 |'
     expect=1.5177
     measure={ Bpb (Geco (& $S 'chr21.seq') '-l 9') (Bases (& $S 'chr21.seq')) } }

  @{ id='geco-chr21-l14-bpb'; tier='extern'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| | GeCo3 `-l 14` | 1.5092 |'
     expect=1.5092
     measure={ Bpb (Geco (& $S 'chr21.seq') '-l 14') (Bases (& $S 'chr21.seq')) } }

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

  @{ id='chr21-ind-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.00006
     anchor='chr21 | 1.504 | **0.0227**'
     expect=0.0227
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
    if ($AnchorsOnly) {
        $a = Check-Anchor $c
        return [pscustomobject]@{ id=$c.id; tier=$c.tier; status=$(if ($a.ok) { 'OK' } else { 'ANCHOR' })
                                  expected=$c.expect; measured='(not measured)'; note=$(if ($a.ok) { 'anchor present' } else { $a.why }) }
    }
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

# @() is load-bearing: a single hashtable's .Count is its KEY count, so an
# unwrapped one-claim selection reported "verifying 8 claim(s)".
$sel = @($claims | Where-Object { ($Tier -eq 'all' -or $_.tier -eq $Tier) -and (-not $Only -or $_.id -eq $Only) })
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
if ($AnchorsOnly) {
    Write-Host "all $($results.Count) anchor(s) present. NOTHING WAS MEASURED - this proves only that
the sentences are still in the docs, not that the numbers are still true." -ForegroundColor Yellow
} else {
    Write-Host "all $($results.Count) claim(s) reproduce." -ForegroundColor Green
}
