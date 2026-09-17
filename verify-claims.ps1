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
#         slow  (2 h 52 min measured -- it was ~15 min before the cue rows
#                added the real human pairs) -- run before tagging a release
#         meta  (needs bench-external/seq/meta.seq, ~25 min) -- the "Where this
#           loses" table: the metagenome bake-off against gzip/bzip2/zstd/xz.
#           These are the only rows here defending a number a COMPETITOR set, and
#           they exist because an unverified losing number rots exactly as fast as
#           an unverified winning one. Get the data with
#           `sh scripts/get-data.sh --meta` and copy data/meta.seq into
#           bench-external/seq/. xz is resolved by its --version string, because a
#           busybox applet named xz that cannot compress usually wins on PATH.
#         cue   (needs a compiler and the cue data, 65 min measured) -- every figure in
#           docs/nudge.md, docs/cue*.md, docs/remaining.md and docs/speed.md that
#           is E. coli-scale. It is its own tier rather than part of `fast`
#           because `fast` is a pre-commit gate and a gate nobody can afford to
#           run stops being run. These rows COMPILE the build they defend, from
#           4932ffe's source (see PinnedFile), and they leave primed states and -map
#           files in bench-external/work/cue -- 7.9 GB measured, all disposable
#           (the states are 616 MB each, one per build and level).
#           Get the data with `sh scripts/get-data.sh --cue` and
#           `sh scripts/cue/make-targets.sh`.
#         b4    (needs a compiler, git, a POSIX sh and the cue data) -- docs/batch4.md:
#           the v0.9.0 format change (the run-time cue against the compiled one,
#           the cue switched off against the v0.8.0 tag, the stream families)
#           and the cue documents' claims re-measured at the release settings,
#           with the `rel` and `v08` builds of the working tree.
#         cue3  (needs a compiler and the cue data, ~90 min) -- docs/batch3.md:
#           the parameter sweep, the add-back and the held-out chromosome, all at
#           LEVEL 1 in reference mode, which is where Batch 2 put the cue's
#           default. Like `cue` these rows compile the builds they defend (nine
#           of them touch the real human pair), so run them alone. The timings in
#           that document have no rows, deliberately: 24% noise.
#         extern(needs GeCo3 built, ~10 min) -- the COMPETITOR's columns. Until
#           2026-08-20 nothing re-ran these, which meant the only figures in the
#           README nobody checked were the comparative claims -- the ones a reader
#           is most entitled to distrust. Run before touching a head-to-head claim.
#
# Usage:  ./verify-claims.ps1 [-Tier fast|slow|extern|meta|cue|cue3|all] [-SelfTest] [-Only <id>]
#         ./verify-claims.ps1 -Tier meta              # ~25 min, the losing columns
#         ./verify-claims.ps1 -Tier all -Only 'rf-*'  # one batch's rows, wherever
#           they live: -Only is a wildcard, and one process shares its measurements.
#         ./verify-claims.ps1 -AnchorsOnly -Tier all     # seconds: after editing a doc,
#           checks every claim's sentence is still there without re-measuring anything.
#           Catches a hand-edited figure immediately; it does NOT prove the value.
#
# -SelfTest injects a fault into each detector and fails if the detector stays
# green. A check nobody has watched go red is decoration; see the 2026-08-19 note
# in benchmark.ps1.

param(
    [ValidateSet('fast','slow','extern','meta','cue','cue3','b4','b5','all')][string]$Tier = 'fast',
    [switch]$SelfTest,
    [switch]$AnchorsOnly,
    [string]$Only
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$work = Join-Path $root 'bench-external\work'
New-Item -ItemType Directory -Force $work | Out-Null
# Since Batch 5, README.md describes v0.9.0, so the rows that defend it run the
# RELEASE build: dnac.c with no flags at all, the cue on, level 3 without a
# reference and level 1 with one. That is the binary a reader of the README
# would build, which is the only build whose figures the README may print.
#
# $v08 is the same source configured as v0.8.0 (the cue off, v0.8.0's default
# level everywhere). It is byte-identical to the v0.8.0 tag
# (docs/batch4-prediction.md P2, checked by scripts/cue/batch4.sh), and it stays
# for the handful of rows whose claim IS a comparison with v0.8.0 -- "-4.02%
# against v0.8.0's default" cannot be re-derived by one build alone.
#
# Both are compiled from THIS checkout, so a change to dnac.c reaches every row.
$dnac = Join-Path $work 'dnac_rel.exe'
$v08  = Join-Path $work 'dnac_v08.exe'
if (-not $AnchorsOnly) {
    $cc  = if ($env:DNAC_CC) { $env:DNAC_CC } else { 'gcc' }
    $log = & $cc -O3 -Wall -o $dnac (Join-Path $root 'dnac.c') -lm 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dnac)) { throw "$cc failed building the release dnac (set DNAC_CC):`n$log" }
    $log = & $cc -O3 -Wall -o $v08 (Join-Path $root 'dnac.c') -lm '-DCUE_DEFAULT=0' '-DREF_LEVEL_DEFAULT=3' 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $v08)) { throw "$cc failed building the v0.8.0-configured dnac (set DNAC_CC):`n$log" }
}

# --- measurement helpers ------------------------------------------------------

function Bases($seq) {
    $a = "$seq.acgt"
    if (-not (Test-Path $a)) { throw "missing base count '$a' (run ./mkseq.ps1)" }
    [long](Get-Content $a)
}

# Compress and return the stored size in bytes. Always round-trips: a size from a
# run whose losslessness was not checked is not a measurement, it is a number.
function Size($inFile, $ref, $level, $blocks, $exe) {
    # $exe: an experiment build (the cue rows below). Default is the repository's
    # own dnac.exe, which is what every pre-v0.9.0 row measures.
    if (-not $exe) { $exe = $dnac }
    $out = Join-Path $work 'vc.dnac'; $rt = Join-Path $work 'vc.rt'
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    $lvl = if ($level) { "$level" } else { '3' }
    $jarg = if ($blocks) { @('-j', "$blocks") } else { @() }
    if ($ref) { & $exe cr $inFile $out $ref 22 $lvl @jarg | Out-Null }
    else      { & $exe c  $inFile $out 22 $lvl @jarg      | Out-Null }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { throw "compress failed: $inFile" }
    if ($ref) { & $exe dr $out $rt $ref | Out-Null } else { & $exe d $out $rt | Out-Null }
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
function State($ref, $level) {
    $st = Join-Path $work 'vc.state'
    Remove-Item $st -Force -ErrorAction SilentlyContinue
    # No level means "whatever the CLI picks", which is the figure a reader gets
    # and which v0.9.0 moved from 3 to 1 for `prime`. Rows that want the other
    # one say so.
    if ($level) { & $dnac prime $ref $st 22 $level | Out-Null }
    else        { & $dnac prime $ref $st 22        | Out-Null }
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


# --- the cue (v0.9.0, branch `nudge`) -----------------------------------------
# The figures in docs/nudge.md, docs/cue*.md, docs/real-human.md,
# docs/competitors.md, docs/remaining.md and docs/speed.md were measured with
# builds that do not exist until someone compiles them: the cue lived behind
# -DDNAC_CUE until v0.9.0, and every ablation behind another flag. So these rows
# COMPILE the build they are defending -- from the source that measured it,
# 4932ffe, since that flag is gone -- exactly as ./ablate.ps1 does, and measure
# it here.
#
# Three things make that affordable. A build is compiled once per run; the
# E. coli reference is primed once per build (a state and its FASTA give
# byte-identical archives, so this changes no number); and every size is
# memoised, because one byte count feeds several published figures -- the size
# itself, the cost per event derived from it, and the percentage against v0.8.0.
#
# `base` is the unflagged build, and every "against v0.8.0" figure on this branch
# rests on it being v0.8.0. Two things hold that premise here. -SelfTest asserts
# that the flag actually reaches the compiler -- that `cue` and `base` do NOT
# produce the same bytes -- which is the failure that would silently turn every
# comparison below into a comparison of a build with itself. What is NOT checked
# yet is `base` against a STORED v0.8.0 archive; that needs the archives, and it
# is Batch 4's job (docs/v0.9.0-plan.md).
$cueWork    = Join-Path $work 'cue'
$cueTargets = Join-Path $root 'bench-external\cue\ecoli-targets'
$cueHuman   = Join-Path $root 'bench-external\cue\human'
$script:CueExeMemo   = @{}
$script:CueStateMemo = @{}
$script:CueSizeMemo  = @{}
$script:CueMapMemo   = @{}

# The flags each label in the docs was built with. Kept in step with
# scripts/cue/common.sh, which is the shell-side copy of the same table.
function CueDefs($label) {
    switch ($label) {
        'rel'       { @() }                                   # working tree: see $TreeLabels
        'v08'       { @('-DCUE_DEFAULT=0','-DREF_LEVEL_DEFAULT=3') }
        'exp'       { @('-DCUE_MINLEN=16') }
        # Batch 5's W5: the release with four mixer experts at level 1, which is
        # what the whole level-1 penalty on a near-identical pair turns out to be.
        'rel_x4'    { @('-DL1_NMIX=4') }
        'base'      { @() }
        'cue'       { @('-DDNAC_CUE') }
        'noroom'    { @('-DDNAC_CUE','-DCUE_ROOM=0') }
        'mf'        { @('-DDNAC_CUE','-DCUE_MIXFREE=1') }
        'mf_noroom' { @('-DDNAC_CUE','-DCUE_ROOM=0','-DCUE_MIXFREE=1') }
        'cue2'      { @('-DDNAC_CUE','-DCUE_BACK=1') }
        'cue_L2'    { @('-DDNAC_CUE','-DCUE_L=2') }
        'cue_L4'    { @('-DDNAC_CUE','-DCUE_L=4') }
        'cue_D6'    { @('-DDNAC_CUE','-DCUE_D=6') }
        'cue_D20'   { @('-DDNAC_CUE','-DCUE_D=20') }
        'cue_S8'    { @('-DDNAC_CUE','-DCUE_SWITCH=8') }
        'cue_S16'   { @('-DDNAC_CUE','-DCUE_SWITCH=16') }
        'cue_M8'    { @('-DDNAC_CUE','-DCUE_MINLEN=8') }
        'cue_M24'   { @('-DDNAC_CUE','-DCUE_MINLEN=24') }
        'cue_M4'    { @('-DDNAC_CUE','-DCUE_MINLEN=4') }
        'cue_M2'    { @('-DDNAC_CUE','-DCUE_MINLEN=2') }
        'cue_M4x4'  { @('-DDNAC_CUE','-DCUE_MINLEN=4','-DL1_NMIX=4') }
        'cue_M4stcm'{ @('-DDNAC_CUE','-DCUE_MINLEN=4','-DL1_STCM=1') }
        'cue_x4'    { @('-DDNAC_CUE','-DL1_NMIX=4') }
        'cue_ir'    { @('-DDNAC_CUE','-DL1_IR=1') }
        'cue_stcm'  { @('-DDNAC_CUE','-DL1_STCM=1') }
        'cue_ord'   { @('-DDNAC_CUE','-DL1_ORDERS=1') }
        'base_x4'   { @('-DL1_NMIX=4') }
        'nudge'     { @('-DDNAC_NUDGE','-DNUDGE_L=5','-DNUDGE_D=12') }
        default {
            if ($label -match '^L(\d+)D(\d+)$') { @('-DDNAC_NUDGE', "-DNUDGE_L=$($Matches[1])", "-DNUDGE_D=$($Matches[2])") }
            else { throw "unknown cue build label '$label'" }
        }
    }
}

# The labels above are RECORDS: experiments run before v0.9.0 made the cue a
# run-time feature. `-DDNAC_CUE`, the nudge and the alternating deck no longer
# exist in dnac.c, and CUE_MINLEN's default moved, so every label compiles the
# source that measured it -- 4932ffe, the last one that measured anything on the
# branch -- and the rows that defend them never see a later change to dnac.c
# (docs/batch4-prediction.md F6). scripts/cue/common.sh pins the same revision.
# The link from these records to the shipping code is a byte-identity check
# (scripts/cue/batch4.sh), not a relabel.
$script:PinnedRev = '4932ffe'
# ...except these two, which are v0.9.0's own builds from the working tree: `rel`
# the release, `v08` the cue switched off (byte-identical to the v0.8.0 tag).
# scripts/cue/common.sh has the same list in TREE_LABELS.
$script:TreeLabels = @('rel', 'v08', 'exp', 'rel_x4')   # exp/rel_x4: experimental builds
function PinnedFile($path) {
    New-Item -ItemType Directory -Force $cueWork | Out-Null
    $dst = Join-Path $cueWork ("pin_$($script:PinnedRev)_" + ($path -replace '[\\/]', '_'))
    if (-not (Test-Path $dst) -or (Get-Item $dst).Length -eq 0) {
        # cmd's redirection, not PowerShell's: the pipeline would re-encode the bytes
        cmd /c "git -C `"$root`" show $($script:PinnedRev):$path > `"$dst`""
        if ($LASTEXITCODE -ne 0 -or (Get-Item $dst).Length -eq 0) { throw "git show $($script:PinnedRev):$path failed" }
    }
    $dst
}

function CueExe($label) {
    if ($script:CueExeMemo.ContainsKey($label)) { return $script:CueExeMemo[$label] }
    New-Item -ItemType Directory -Force $cueWork | Out-Null
    $cc  = if ($env:DNAC_CC) { $env:DNAC_CC } else { 'gcc' }
    $exe = Join-Path $cueWork "dnac_$label.exe"
    $src = if ($label -in $script:TreeLabels) { Join-Path $root 'dnac.c' } else { PinnedFile 'dnac.c' }
    $log = & $cc @('-O3','-o',$exe,$src,'-lm') @(CueDefs $label) 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$cc failed for '$label' (set DNAC_CC if gcc is elsewhere):`n$log" }
    $script:CueExeMemo[$label] = $exe
    $exe
}

# One priming pass of E. coli MG1655 per build and level, reused by all ten
# targets. The level is part of the state: a state primed at one level refuses
# to decode a stream written at another, which is why it travels in the name.
function CueState($label, $level) {
    if (-not $level) { $level = 3 }
    $key = "$label|$level"
    if ($script:CueStateMemo.ContainsKey($key)) { return $script:CueStateMemo[$key] }
    $st = Join-Path $cueWork "ref_$label.l$level.state"
    # A record's source is pinned, so its state on disk is still its own. A
    # working-tree label's is not: dnac.c may have changed since it was primed.
    if ($label -in $script:TreeLabels) { Remove-Item $st -Force -ErrorAction SilentlyContinue }
    if (-not (Test-Path $st)) {
        & (CueExe $label) prime (& $F 'ecoli.fa') $st 22 "$level" | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $st)) { throw "prime failed for '$label' at level $level" }
    }
    $script:CueStateMemo[$key] = $st
    $st
}

function CueSize($label, $inFile, $ref, $level) {
    $key = "$label|$inFile|$ref|$level"
    if ($script:CueSizeMemo.ContainsKey($key)) { return $script:CueSizeMemo[$key] }
    $n = Size $inFile $ref $level $null (CueExe $label)
    $script:CueSizeMemo[$key] = $n
    $n
}

# One of the ten controlled targets, against the primed E. coli reference.
function CueTarget($label, $target, $level) {
    if (-not $level) { $level = 3 }
    $fa = Join-Path $cueTargets "$target.fa"
    if (-not (Test-Path $fa)) { throw "missing $target.fa - run: sh scripts/cue/make-targets.sh" }
    CueSize $label $fa (CueState $label $level) $level
}

# The three real and simulated E. coli pairs, against the same primed reference.
function CueReal($label, $name, $level) {
    if (-not $level) { $level = 3 }
    CueSize $label (& $F "$name.fa") (CueState $label $level) $level
}

# The simulated human individual, against chr21 itself (no state: one target).
function CueChr21Ind($label, $level) {
    CueSize $label (& $F 'chr21_ind.fa') (& $F 'chr21.fa') $(if ($level) { $level } else { 3 })
}

# Cost per event in bits: (target - zero-event control) x 8 / 2,000 events,
# meaned over the three seeds. The control is what makes this a cost per event
# and not a file size -- it is the same genome with no events in it, so
# everything the codec pays for the genome itself cancels.
function CuePerEvent($label, $kind, $level) {
    $ctl = CueTarget $label 'ctl' $level
    $v = 1,2,3 | ForEach-Object { ((CueTarget $label "${kind}_$_" $level) - $ctl) * 8.0 / 2000.0 }
    [math]::Round(($v | Measure-Object -Average).Average, 2)
}

function CuePct($a, $b) { [math]::Round(100.0 * ($b / $a - 1.0), 2) }   # b against a, per cent

# --- Batch 5 (docs/batch5.md) -------------------------------------------------
# The controlled divergence gradient that settled the reference-mode default.
# The target is DERIVED here rather than stored: `dnac mut` at <rate> per-mille,
# seed 42, on MG1655 -- so these rows re-derive the input as well as the number,
# and a change to `mut` cannot slip past them. Deterministic, so it is cached.
$script:MutMemo = @{}
function MutTarget($rate) {
    if ($script:MutMemo.ContainsKey($rate)) { return $script:MutMemo[$rate] }
    $t = Join-Path $work "mut_$rate.fa"
    if (-not (Test-Path $t) -or (Get-Item $t).Length -eq 0) {
        $raw = "$t.raw"
        & $dnac mut (& $F 'ecoli.fa') $raw $rate 42 | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $raw)) { throw "dnac mut failed at $rate per-mille" }
        # `mut` records the INPUT'S PATH in the FASTA header, and that header is
        # compressed with the sequence -- so 'C:\...\ecoli.fa' and 'C:/.../ecoli.fa'
        # are the same genome in a different archive (2 bytes at level 3, 7 at
        # level 1). The header is overwritten with a canonical one, exactly as
        # scripts/cue/batch5-w3110.sh does, so this row and that script agree.
        # Byte surgery, not ReadAllLines/WriteAllLines: the latter would write
        # CRLF on Windows and turn every line of the FASTA into a different
        # line, which is a different file again. Replace the first line only.
        $bytes = [System.IO.File]::ReadAllBytes($raw)
        $nl    = [Array]::IndexOf($bytes, [byte]10)
        if ($nl -lt 0) { throw "no newline in $raw" }
        $head  = [System.Text.Encoding]::ASCII.GetBytes(">mut_${rate}_seed42`n")
        $fs    = [System.IO.File]::Create($t)
        try { $fs.Write($head, 0, $head.Length); $fs.Write($bytes, $nl + 1, $bytes.Length - $nl - 1) }
        finally { $fs.Dispose() }
        Remove-Item $raw -Force -ErrorAction SilentlyContinue
    }
    $script:MutMemo[$rate] = $t
    $t
}

# What level 1 costs against level 3 on that target: bytes, or per cent.
function MutPenalty($rate, $what) {
    $t  = MutTarget $rate
    $l3 = Size $t (& $F 'ecoli.fa') 3
    $l1 = Size $t (& $F 'ecoli.fa') 1
    if ($what -eq 'pct') { CuePct $l3 $l1 } else { $l1 - $l3 }
}

# The level the CLI picks when the user names none -- read back out of the
# header, which is the only place that cannot be talked into agreeing. Byte 5 is
# the level (magic, k, level, hashbits, mhb, length), in both modes.
function DefaultLevel($ref) {
    $in  = Join-Path $work 'lvl.fa'
    $out = Join-Path $work 'lvl.dnac'
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $in)) { & $dnac gen $in 200000 7 | Out-Null }
    if ($ref) { & $dnac cr $in $out $ref 22 | Out-Null } else { & $dnac c $in $out 22 | Out-Null }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { throw "compress failed while reading the default level" }
    $b = [System.IO.File]::ReadAllBytes($out)[5]
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    [int]$b
}

# The bit-cost map, bucketed into 1,000-base windows, for the real human pair.
# -map reads probabilities the coder computed anyway and touches no model state,
# so the archive is byte-identical with and without it (both round-trip suites
# assert exactly that) and the paired size rows below are the losslessness check
# for these runs.
function CueMap($label, $target, $ref, $level) {
    if (-not $level) { $level = 3 }
    $key = "$label|$target|$level"
    if ($script:CueMapMemo.ContainsKey($key)) { return $script:CueMapMemo[$key] }
    New-Item -ItemType Directory -Force $cueWork | Out-Null
    # level 3 keeps the name every earlier run cached under
    $sfx = if ($level -eq 3) { '' } else { ".l$level" }
    $map = Join-Path $cueWork "$target.$label$sfx.map.tsv"
    if ($label -in $script:TreeLabels) { Remove-Item $map -Force -ErrorAction SilentlyContinue }   # see CueState
    if (-not (Test-Path $map)) {
        $tmp = Join-Path $cueWork 'map.dnac'
        & (CueExe $label) cr (Join-Path $cueHuman "$target.fa") $tmp (Join-Path $cueHuman "$ref.fa") 22 $level -map $map -mapw 1000 | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $map)) { throw "-map run failed: $target ($label)" }
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
    # bits_per_base comes from the file rather than bits/1000: the last window
    # of a chromosome is a short one (chr21's is 682 bases), and dividing it by
    # a thousand anyway would put it in the wrong class.
    $rows = @(Import-Csv $map -Delimiter "`t" | ForEach-Object {
        [pscustomobject]@{ bits = [double]$_.bits; bpb = [double]$_.bits_per_base } })
    $script:CueMapMemo[$key] = $rows
    $rows
}

# The split docs/real-human.md reports: windows are classed ONCE, by what
# v0.8.0 paid for them (shared < 0.2 bits/base, diverged 0.2-1.0, novel >= 1.0),
# and the same windows are then summed for both builds. Classing each build on
# its own numbers would move the goalposts with the result.
# $level (Batch 4): the two builds' level. The CLASSES stay v0.8.0's at level 3
# whatever it is, so a level-1 split sums the same windows as the level-3 one,
# compared against v0.8.0 at level 1 (`v08`, which is v0.8.0's bytes, P2).
function CueWindowSums($target, $ref, $klass, $label, $half, $level) {
    if (-not $label) { $label = 'cue' }
    if (-not $level) { $level = 3 }
    $k = CueMap 'base' $target $ref 3
    $b = if ($level -eq 3) { $k } else { CueMap 'v08' $target $ref $level }
    $c = CueMap $label  $target $ref $level
    if ($b.Count -ne $c.Count -or $k.Count -ne $c.Count) { throw "map lengths differ for $target ($($k.Count) / $($b.Count) / $($c.Count))" }
    $sb = 0.0; $sc = 0.0; $n = 0
    $lo = 0; $hi = $b.Count
    if ($half -eq 'first')  { $hi = [int]($b.Count / 2) }
    if ($half -eq 'second') { $lo = [int]($b.Count / 2) }
    for ($i = $lo; $i -lt $hi; $i++) {
        $bpb = $k[$i].bpb        # the CLASS is v0.8.0's at level 3, whatever level is summed
        $in = switch ($klass) {
            'shared'   { $bpb -lt 0.2 }
            'diverged' { $bpb -ge 0.2 -and $bpb -lt 1.0 }
            'novel'    { $bpb -ge 1.0 }
            'all'      { $true }
        }
        if ($in) { $sb += $b[$i].bits; $sc += $c[$i].bits; $n++ }
    }
    @{ base = $sb; cue = $sc; windows = $n; total = $b.Count }
}

function CueWindows($target, $ref, $klass, $label, $half, $level) {
    $w = CueWindowSums $target $ref $klass $label $half $level
    [math]::Round(100.0 * ($w.cue / $w.base - 1.0), 2)
}

# The osmosis: cost per event in the FIRST and the SECOND half of each target.
# The arithmetic lives in scripts/cue/halves.py -- the same script that produced
# the published table -- because the event positions come from the seeded draw
# that built the targets, and a second implementation of that would be a second
# thing to get wrong. Returns kind -> @{ first; second; ratio }.
function CueHalves($label) {
    $key = "halves|$label"
    if ($script:CueMapMemo.ContainsKey($key)) { return $script:CueMapMemo[$key] }
    New-Item -ItemType Directory -Force $cueWork | Out-Null
    $exe = CueExe $label; $st = CueState $label 3
    foreach ($t in @('ctl','hp_1','hp_2','hp_3','ind_1','ind_2','ind_3','sub_1','sub_2','sub_3')) {
        $map = Join-Path $cueWork "$t.$label.map.tsv"
        if ($label -in $script:TreeLabels) { Remove-Item $map -Force -ErrorAction SilentlyContinue }   # see CueState
        if (Test-Path $map) { continue }
        $tmp = Join-Path $cueWork 'm.dnac'
        & $exe cr (Join-Path $cueTargets "$t.fa") $tmp $st 22 3 -map $map -mapw 1000 | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $map)) { throw "-map run failed: $t ($label)" }
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
    $py = if ($env:PYTHON) { $env:PYTHON } else { 'python' }
    $env:TGT = $cueTargets; $env:REF = (& $F 'ecoli.fa')
    $out = & $py (Join-Path $root 'scripts\cue\halves.py') $label $cueWork 2>&1
    if ($LASTEXITCODE -ne 0) { throw "halves.py failed for '$label' (set PYTHON if python is elsewhere):`n$out" }
    $h = @{}
    foreach ($line in $out) {
        $f = "$line" -split "`t"
        if ($f.Count -ge 5) { $h[$f[1]] = @{ first = [double]$f[2]; second = [double]$f[3]; ratio = [double]$f[4] } }
    }
    if (-not $h.ContainsKey('hp')) { throw "halves.py produced nothing usable for '$label':`n$out" }
    $script:CueMapMemo[$key] = $h
    $h
}

# Losslessness of an experiment build, run through the round-trip suite CI runs
# on the default build -- 4932ffe's 203-case copy for a record's build, the
# current one for v0.9.0's. Returns the number of round-trips that passed, so a
# claim of "203/203" is a number this can be wrong about, not a promise.
function Resolve-Sh {
    if ($env:DNAC_SH) { return $env:DNAC_SH }
    $cands = @('C:/Program Files/Git/bin/sh.exe', 'C:/Program Files/Git/usr/bin/sh.exe',
               'C:/laragon/bin/git/usr/bin/sh.exe', 'C:/laragon/bin/git/bin/sh.exe', '/usr/bin/sh')
    $cands += (Get-Command sh -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
    foreach ($c in $cands) {
        if (-not $c -or -not (Test-Path $c)) { continue }
        # The probe is /dev/urandom: a busybox sh wins on PATH inside a toolchain
        # and cannot run the suite, which needs it for the random cases.
        & $c -c 'head -c 4 /dev/urandom > /dev/null 2>&1' 2>$null
        if ($LASTEXITCODE -eq 0) { return $c }
    }
    $null
}

# $suite: the suite to run. A record's build runs the suite of its own revision,
# because the current one asserts v0.9.0 behaviour (per-mode default level, the
# stream families, stored v0.8.0 streams) that a pre-v0.9.0 build rightly fails.
function CueRoundtripExe($exe, $suite) {
    $sh = Resolve-Sh
    if (-not $sh) { throw "no POSIX sh with /dev/urandom found - set DNAC_SH" }
    if (-not $suite) { $suite = Join-Path $root 'scripts/roundtrip.sh' }
    $out = & $sh $suite $exe 2>&1 | Out-String
    if ($out -match '(\d+)/(\d+) adversarial round-trips lossless') { return [int]$Matches[1] }
    throw "roundtrip.sh did not report a clean count for '$exe':`n$out"
}

function CueRoundtrip($label) { CueRoundtripExe (CueExe $label) (PinnedFile 'scripts/roundtrip.sh') }

# zstd's --patch-from: the trivial diff, and the answer to "what does the most
# ordinary tool do with the same two files?" Round-tripped like everything else.
function ZstdPatch($inFile, $ref) {
    $out = Join-Path $work 'vc.zst'; $rt = Join-Path $work 'vc.zstrt'
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    & zstd -q -f -19 --long=27 --patch-from=$ref $inFile -o $out | Out-Null
    if (-not (Test-Path $out)) { throw "zstd --patch-from produced nothing" }
    & zstd -q -f -d --long=27 --patch-from=$ref $out -o $rt | Out-Null
    if ((Get-FileHash $inFile -Algorithm SHA256).Hash -ne (Get-FileHash $rt -Algorithm SHA256).Hash) {
        throw "zstd --patch-from was NOT LOSSLESS on $inFile"
    }
    $n = (Get-Item $out).Length
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    $n
}

# HRCM, the reference-based FASTA specialist, run in its own directory because
# it writes beside its inputs. Its round-trip is reported as the doc reports it:
# sequence, header and line layout come back, the file's final empty line does
# not, so this compares the decompressed file against the input WITH that line
# removed and fails if anything else differs.
function Hrcm($target, $ref) {
    $h = Join-Path $root 'bench-external\cue\hrcm\hrcm.exe'
    if (-not (Test-Path $h)) { throw "HRCM is not built (bench-external/cue/hrcm) - see scripts/cue/hrcm-windows.patch" }
    $d = Join-Path $work 'hrcm'
    Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $d | Out-Null
    Copy-Item $target $d; Copy-Item $ref $d
    $t = Split-Path $target -Leaf; $r = Split-Path $ref -Leaf
    Push-Location $d
    try {
        & $h compress -r $r -t $t *> 'c.log'
        $co = [IO.Path]::ChangeExtension($t, '.7z')
        if (-not (Test-Path $co)) { throw "HRCM produced nothing; see $d/c.log" }
        New-Item -ItemType Directory -Force 'dd' | Out-Null
        Copy-Item $co 'dd'; Copy-Item $r 'dd'
        Push-Location 'dd'
        try { & $h decompress -r $r -t $co *> 'd.log' } finally { Pop-Location }
        $back = Join-Path 'dd' ([IO.Path]::ChangeExtension($t, '.fasta'))
        if (-not (Test-Path $back)) { throw "HRCM did not decompress; see $d/dd/d.log" }
        $a = [IO.File]::ReadAllBytes((Resolve-Path $t)); $b = [IO.File]::ReadAllBytes((Resolve-Path $back))
        $trim = $a.Length - $b.Length
        if ($trim -lt 0 -or $trim -gt 1) { throw "HRCM round-trip differs by $trim bytes, not the known trailing newline" }
        for ($i = 0; $i -lt $b.Length; $i++) { if ($a[$i] -ne $b[$i]) { throw "HRCM round-trip differs at byte $i" } }
        (Get-Item $co).Length
    } finally { Pop-Location }
}

# Plain mode, no reference: the mode docs/reference-free.md measures, and the
# one the README's headline lives in. Nothing to prime, so these are the
# cheapest cue measurements here -- and the ones that decide whether the cue is
# safe to leave on when there is no reference at all.
function CuePlain($label, $seq, $level) {
    if (-not $level) { $level = 3 }
    CueSize $label (& $S "$seq.seq") $null $level
}

function CueHuman($label, $target, $ref, $level) {
    CueSize $label (Join-Path $cueHuman "$target") (Join-Path $cueHuman "$ref") $(if ($level) { $level } else { 3 })
}

# Batch 4's identity checks (scripts/cue/batch4.sh), run once per process. The
# script builds from three sources -- the v0.8.0 tag, the pinned 4932ffe and the
# working tree -- and prints one PASS/FAIL line per check, so each row below reads
# one count out of it. A lossless failure anywhere stops the run instead of
# lowering a count, because a count can go down for a reason a row would accept.
$script:B4Memo = $null
function B4Identity {
    if ($script:B4Memo) { return $script:B4Memo }
    $sh = Resolve-Sh
    if (-not $sh) { throw "no POSIX sh with /dev/urandom found - set DNAC_SH" }
    $env:CC = $(if ($env:DNAC_CC) { $env:DNAC_CC } else { 'gcc' }) -replace '\\', '/'
    $out = & $sh (Join-Path $root 'scripts/cue/batch4.sh') 2>&1 | Out-String
    $code = $LASTEXITCODE
    if ($out -match 'FAIL lossless') { throw "NOT LOSSLESS in scripts/cue/batch4.sh - stop everything else and fix this:`n$out" }
    $r = @{
        code  = $code
        p1    = ([regex]::Matches($out, '(?m)^PASS identical but the magic ')).Count
        p2    = ([regex]::Matches($out, '(?m)^PASS identical \S+ v080 = v08')).Count
        fails = ([regex]::Matches($out, '(?m)^FAIL ')).Count
        p5    = ([regex]::Matches($out, '(?m)^PASS refused: (v0\.8\.0 decoder|release decoder|experimental decoder), ')).Count
        p6    = ([regex]::Matches($out, '(?m)^PASS (P6 release \+ v0\.8\.0 state reads|refused: a v0\.8\.0 state against)')).Count
    }
    if ($out -match 'P0 decoder exit=(\d+) output=(\w+)') { $r.p0exit = [int]$Matches[1]; $r.p0out = $Matches[2] }
    else { throw "batch4.sh printed no P0 line:`n$out" }
    if ($out -match 'P7 v0\.8\.0 (\d+) B, release (\d+) B') { $r.p7old = [int]$Matches[1]; $r.p7new = [int]$Matches[2] }
    else { throw "batch4.sh printed no P7 line:`n$out" }
    $script:B4Memo = $r
    $r
}

$S = { param($n) Join-Path $root "bench-external\seq\$n" }   # plain-ACGT .seq files
# FASTA inputs. They live in the repository root on the machine the figures were
# measured on, and in ./data on a fresh checkout, because that is where
# scripts/get-data.sh puts what it fetches -- so look in both, root first.
# scripts/cue/common.sh has the same fallback, for the same reason.
$F = { param($n)
        $p = Join-Path $root $n
        if (Test-Path $p) { $p } else { Join-Path $root "data\$n" } }

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
     anchor='| E. coli (4,641,652 bases) | **dnac `-l 3`** | **1.8832**'
     expect=1.8832
     measure={ Bpb (Size (& $S 'ecoli.seq') $null 3) (Bases (& $S 'ecoli.seq')) } }

  @{ id='w3110-seq-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| W3110 vs MG1655 (near-identical strains) | 1,280 B | **1,063 B** | 1,404 B | 1,319 B |'
     expect=1063
     measure={ Size (& $S 'w3110.seq') (& $S 'ecoli.seq') 3 } }

  @{ id='o157-seq-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged strains) | 361,611 B | **360,752 B** | 431,652 B | 365,401 B |'
     expect=360752
     measure={ Size (& $S 'o157.seq') (& $S 'ecoli.seq') 3 } }

  @{ id='w3110-fa-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='1,916 bytes for a 4.6 Mbp genome'
     expect=1916
     measure={ Size (& $F 'w3110.fa') (& $F 'ecoli.fa') 3 } }

  @{ id='ecoli-fa-alone-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.001
     anchor='| E. coli W3110 (real strain) | E. coli MG1655 | 1.880 |'
     expect=1.880
     measure={ Bpb (Size (& $F 'w3110.fa') $null 3) (Bases (& $F 'w3110.fa')) } }

  @{ id='ecoli-ind-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.00006
     anchor='| E. coli, simulated individual | E. coli MG1655 | 1.886 | 0.0210 | **0.0208** | 91× |'
     expect=0.0208
     measure={ Bpb (Size (& $F 'ecoli_ind.fa') (& $F 'ecoli.fa') 3) (Bases (& $F 'ecoli_ind.fa')) } }

  @{ id='o157-fa-ref-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.001
     anchor='| E. coli O157:H7 (real, diverged strain) | E. coli MG1655 | 1.812 | 0.5189 | **0.5176** | 3.5× |'
     expect=0.5176
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
     anchor='| 2 | 1,100,595 | +0.73% |'
     expect=1100595
     measure={ Size (& $S 'ecoli.seq') $null 3 2 } }

  @{ id='ecoli-j8-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| 8 | 1,116,227 | +2.16% |'
     expect=1116227
     measure={ Size (& $S 'ecoli.seq') $null 3 8 } }

  @{ id='chr21-ind-alone-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='(0.1% SNPs + indels) | chr21 | 1.502 |'
     expect=1.502
     measure={ Bpb (Size (& $F 'chr21_ind.fa') $null 3) (Bases (& $F 'chr21_ind.fa')) } }

  @{ id='unrelated-ref-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='| E. coli MG1655 | *human chr21* (unrelated!) | 1.885 | 1.891 | 1.889 | +0.23% (degrades gracefully) |'
     expect=1.889
     measure={ Bpb (Size (& $F 'ecoli.fa') (& $F 'chr21.fa') 3) (Bases (& $F 'ecoli.fa')) } }

  @{ id='slice-l1-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| 1 `fast` | 6 orders, 2 mixing experts, no IR, no tolerant models | @@L1T@@ s | 1.7180 |'
     expect=1.718
     measure={ Bpb (Size (& $F 'chr21_slice.fa') $null 1) (Bases (& $F 'chr21_slice.fa')) } }

  @{ id='slice-l2-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| 2 `balanced` | all orders, 4 experts, no IR, no tolerant models | @@L2T@@ s | 1.7166 |'
     expect=1.7166
     measure={ Bpb (Size (& $F 'chr21_slice.fa') $null 2) (Bases (& $F 'chr21_slice.fa')) } }

  @{ id='slice-l3-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| 3 `max` (default without a reference) | everything | @@L3T@@ s | 1.7116 |'
     expect=1.7116
     measure={ Bpb (Size (& $F 'chr21_slice.fa') $null 3) (Bases (& $F 'chr21_slice.fa')) } }

  # The level paragraph's load-bearing number: what IR training and the tolerant
  # models are worth in SIZE. Nothing else here defends it, and it is the half of
  # that paragraph a check can hold -- the other half was a timing, which is why
  # it went stale unnoticed (it said ~21% of the run each; a paired ablation
  # measures 11-13% for IR training). Per-model splits need a compiler and live
  # in docs/model-ablation.md, re-derived by ./ablate.ps1.
  @{ id='slice-l3-vs-l2-pct'; tier='fast'; doc='README.md'; unit='%'; tol=0.002
     anchor='worth 0.291% of compressed size'
     expect=0.291
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
     anchor='| 4 `light` | 8 orders, 4 experts, IR, no tolerant models | @@L4T@@ s | 1.7137 |'
     expect=1.7137
     measure={ Bpb (Size (& $F 'chr21_slice.fa') $null 4) (Bases (& $F 'chr21_slice.fa')) } }

  @{ id='ecoli-l4-ram'; tier='fast'; doc='README.md'; unit='MB'; tol=65
     anchor='| E. coli, 4.6 Mbp | 604 MB | **508 MB** | 1.8834 | +0.008% |'
     expect=508
     measure={ PeakMB (& $S 'ecoli.seq') 4 $null } }

  @{ id='chr21-l4-ram'; tier='slow'; doc='README.md'; unit='MB'; tol=130
     anchor='| chr21, 40 Mbp | @@RAMC21L3@@ MB | **@@RAMC21L4@@ MB** | 1.5003 | +0.266% |'
     expect=869
     measure={ PeakMB (& $S 'chr21.seq') 4 $null } }

  @{ id='chr21-l4-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| chr21, 40 Mbp | @@RAMC21L3@@ MB | **@@RAMC21L4@@ MB** | 1.5003 | +0.266% |'
     expect=1.5003
     measure={ Bpb (Size (& $S 'chr21.seq') $null 4) (Bases (& $S 'chr21.seq')) } }

  @{ id='sliceseq-l3-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| chr21 slice (9,836,065 bases) | **dnac `-l 3`** | **1.7105** |'
     expect=1.7105
     measure={ Bpb (Size (& $S 'chr21slice.seq') $null 3) (Bases (& $S 'chr21slice.seq')) } }

  @{ id='sliceseq-l1-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| | **dnac `-l 1`** | 1.7168 |'
     expect=1.7168
     measure={ Bpb (Size (& $S 'chr21slice.seq') $null 1) (Bases (& $S 'chr21slice.seq')) } }

  @{ id='ecoli-j4-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| 4 | 1,108,139 | +1.42% |'
     expect=1108139
     measure={ Size (& $S 'ecoli.seq') $null 3 4 } }

  @{ id='chr21-j1-bytes'; tier='slow'; doc='README.md'; unit='B'; tol=0
     anchor='| 1 | 7,498,339 |'
     expect=7498339
     measure={ Size (& $S 'chr21.seq') $null 3 1 } }

  @{ id='chr21-j8-bytes'; tier='slow'; doc='README.md'; unit='B'; tol=0
     anchor='| 8 | 7,828,539 |'
     expect=7828539
     measure={ Size (& $S 'chr21.seq') $null 3 8 } }

  @{ id='chr21-seq-l2-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=6e-05
     anchor='| | **dnac `-l 2`** | **1.5023** |'
     expect=1.5023
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
     anchor='| W3110 vs MG1655 (near-identical strains) | 1,280 B | **1,063 B** | 1,404 B | 1,319 B |'
     expect=1404
     measure={ Geco (& $S 'w3110.seq') "$PARAMR -r ref.seq" (& $S 'ecoli.seq') } }

  @{ id='geco-w3110-hybrid-bytes'; tier='extern'; doc='README.md'; unit='B'; tol=0
     anchor='| W3110 vs MG1655 (near-identical strains) | 1,280 B | **1,063 B** | 1,404 B | 1,319 B |'
     expect=1319
     measure={ Geco (& $S 'w3110.seq') "$PARAMH -r ref.seq" (& $S 'ecoli.seq') } }

  @{ id='geco-o157-ref-bytes'; tier='extern'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged strains) | 361,611 B | **360,752 B** | 431,652 B | 365,401 B |'
     expect=431652
     measure={ Geco (& $S 'o157.seq') "$PARAMR -r ref.seq" (& $S 'ecoli.seq') } }

  @{ id='geco-o157-hybrid-bytes'; tier='extern'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged strains) | 361,611 B | **360,752 B** | 431,652 B | 365,401 B |'
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
     anchor='| **dnac** (k=22, default)       | **@@CHR21FADEF@@**   | **1.8845** | this project |'
     also=@(@{ doc='README.md'; anchor='1.5447 + the cue (v0.9.0)' })
     expect=1.5447
     measure={ Bpb (Size (& $F 'chr21.fa') $null 3) (Bases (& $F 'chr21.fa')) } }

  @{ id='chr21-seq-l3-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| human chr21 (40,088,619 bases) | **dnac `-l 3`** (default) | **1.4964**'
     expect=1.4964
     measure={ Bpb (Size (& $S 'chr21.seq') $null 3) (Bases (& $S 'chr21.seq')) } }

  @{ id='chr21-seq-l1-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0002
     anchor='| | **dnac `-l 1`** | **1.5048**'
     expect=1.5048
     measure={ Bpb (Size (& $S 'chr21.seq') $null 1) (Bases (& $S 'chr21.seq')) } }

  @{ id='chr21-ind-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.00006
     anchor='| chr21 of a simulated individual (0.1% SNPs + indels) | chr21 | 1.502 | 0.0203 | **0.0201** | 75× |'
     expect=0.0201
     measure={ Bpb (Size (& $F 'chr21_ind.fa') (& $F 'chr21.fa') 3) (Bases (& $F 'chr21_ind.fa')) } }

  # --- v0.9.0, branch `nudge`: the cue --------------------------------------
  # Every figure in docs/nudge.md, docs/cue*.md, docs/real-human.md,
  # docs/competitors.md, docs/remaining.md and docs/speed.md that a machine can
  # re-derive. Deliberately absent: every WALL-CLOCK figure in those documents,
  # for the reason given further up -- a timing on this machine varies by 24%,
  # and a row that cannot go red for the right reason will one day go red for
  # the wrong one. The builds these rows compile are listed in CueDefs.

  # ---- docs/cue.md

  @{ id='cue-base-sub-bits'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| v0.8.0 | 14.64 | 48.25 | 31.43 | — | — | — |'
     expect=14.64
     measure={ CuePerEvent 'base' 'sub' } }

  @{ id='cue-base-ind-bits'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| v0.8.0 | 14.64 | 48.25 | 31.43 | — | — | — |'
     expect=48.25
     measure={ CuePerEvent 'base' 'ind' } }

  @{ id='cue-base-hp-bits'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| v0.8.0 | 14.64 | 48.25 | 31.43 | — | — | — |'
     expect=31.43
     measure={ CuePerEvent 'base' 'hp' } }

  @{ id='cue-sub-bits'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| **P2** | substitution in [14.49, 14.79] | **held**: 14.65 (v0.8.0: 14.64) |'
     expect=14.65
     measure={ CuePerEvent 'cue' 'sub' } }

  @{ id='cue-ind-bits'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| **P3** | random indel ≤ 37.6 bits | **held**: **28.75** (−40% on v0.8.0, better than every nudge) |'
     expect=28.75
     measure={ CuePerEvent 'cue' 'ind' } }

  @{ id='cue-hp-bits'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| **P1** | homopolymer slip ≤ 10 bits | **failed**: 11.78, over the whole file. **8.63 in its second half** |'
     expect=11.78
     measure={ CuePerEvent 'cue' 'hp' } }

  @{ id='cue-ctl-delta'; tier='cue'; doc='docs/cue.md'; unit='B'; tol=0
     anchor='| **P4** | lossless, control < 0.1%, FASTA = state | **held**: all round-trip, control −1 B, identical |'
     expect=-1
     measure={ (CueTarget 'cue' 'ctl') - (CueTarget 'base' 'ctl') } }

  @{ id='cue-o157-pct'; tier='cue'; doc='docs/cue.md'; unit='%'; tol=0.005
     anchor='| **P5** | O157 ≤ +0.1% | **held**: −0.13% |'
     expect=-0.13
     measure={ CuePct (CueReal 'base' 'o157') (CueReal 'cue' 'o157') } }

  @{ id='cue-ecoliind-pct'; tier='cue'; doc='docs/cue.md'; unit='%'; tol=0.005
     anchor='| **cue** | **14.65** | **28.75** | 11.78 | **−0.13%** | **−3.19%** | **−8.70%** |'
     expect=-3.19
     measure={ CuePct (CueReal 'base' 'ecoli_ind') (CueReal 'cue' 'ecoli_ind') } }

  @{ id='cue-w3110-bytes'; tier='cue'; doc='docs/cue.md'; unit='B'; tol=0
     anchor='W3110 against MG1655: 1,927 B against 1,931 (−0.21%).'
     expect=1927
     measure={ CueReal 'cue' 'w3110' } }

  @{ id='cue-w3110-pct'; tier='cue'; doc='docs/cue.md'; unit='%'; tol=0.005
     anchor='W3110 against MG1655: 1,927 B against 1,931 (−0.21%).'
     expect=-0.21
     measure={ CuePct (CueReal 'base' 'w3110') (CueReal 'cue' 'w3110') } }

  @{ id='cue-halves-base-hp-1st'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| homopolymer slip | 32.90 → 30.05 | 0.913 | 14.99 → **8.63** | **0.576** |'
     expect=32.9
     measure={ (CueHalves 'base')['hp'].first } }

  @{ id='cue-halves-base-hp-2nd'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| homopolymer slip | 32.90 → 30.05 | 0.913 | 14.99 → **8.63** | **0.576** |'
     expect=30.05
     measure={ (CueHalves 'base')['hp'].second } }

  @{ id='cue-halves-base-hp-ratio'; tier='cue'; doc='docs/cue.md'; unit=''; tol=0.001
     anchor='| homopolymer slip | 32.90 → 30.05 | 0.913 | 14.99 → **8.63** | **0.576** |'
     expect=0.913
     measure={ (CueHalves 'base')['hp'].ratio } }

  @{ id='cue-halves-cue-hp-1st'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| homopolymer slip | 32.90 → 30.05 | 0.913 | 14.99 → **8.63** | **0.576** |'
     expect=14.99
     measure={ (CueHalves 'cue')['hp'].first } }

  @{ id='cue-halves-cue-hp-2nd'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| homopolymer slip | 32.90 → 30.05 | 0.913 | 14.99 → **8.63** | **0.576** |'
     expect=8.63
     measure={ (CueHalves 'cue')['hp'].second } }

  @{ id='cue-halves-cue-hp-ratio'; tier='cue'; doc='docs/cue.md'; unit=''; tol=0.001
     anchor='| homopolymer slip | 32.90 → 30.05 | 0.913 | 14.99 → **8.63** | **0.576** |'
     expect=0.576
     measure={ (CueHalves 'cue')['hp'].ratio } }

  @{ id='cue-halves-base-ind-1st'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| random indel | 49.77 → 48.19 | 0.968 | 32.20 → **26.90** | **0.835** |'
     expect=49.77
     measure={ (CueHalves 'base')['ind'].first } }

  @{ id='cue-halves-base-ind-2nd'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| random indel | 49.77 → 48.19 | 0.968 | 32.20 → **26.90** | **0.835** |'
     expect=48.19
     measure={ (CueHalves 'base')['ind'].second } }

  @{ id='cue-halves-base-ind-ratio'; tier='cue'; doc='docs/cue.md'; unit=''; tol=0.001
     anchor='| random indel | 49.77 → 48.19 | 0.968 | 32.20 → **26.90** | **0.835** |'
     expect=0.968
     measure={ (CueHalves 'base')['ind'].ratio } }

  @{ id='cue-halves-cue-ind-1st'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| random indel | 49.77 → 48.19 | 0.968 | 32.20 → **26.90** | **0.835** |'
     expect=32.2
     measure={ (CueHalves 'cue')['ind'].first } }

  @{ id='cue-halves-cue-ind-2nd'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| random indel | 49.77 → 48.19 | 0.968 | 32.20 → **26.90** | **0.835** |'
     expect=26.9
     measure={ (CueHalves 'cue')['ind'].second } }

  @{ id='cue-halves-cue-ind-ratio'; tier='cue'; doc='docs/cue.md'; unit=''; tol=0.001
     anchor='| random indel | 49.77 → 48.19 | 0.968 | 32.20 → **26.90** | **0.835** |'
     expect=0.835
     measure={ (CueHalves 'cue')['ind'].ratio } }

  @{ id='cue-halves-sub-1st'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| substitution | 15.27 → 15.48 | 1.014 | 15.27 → 15.48 | 1.014 |'
     expect=15.27
     measure={ (CueHalves 'cue')['sub'].first } }

  @{ id='cue-halves-sub-2nd'; tier='cue'; doc='docs/cue.md'; unit='bits'; tol=0.005
     anchor='| substitution | 15.27 → 15.48 | 1.014 | 15.27 → 15.48 | 1.014 |'
     expect=15.48
     measure={ (CueHalves 'cue')['sub'].second } }

  @{ id='cue-halves-nudge-ratio'; tier='cue'; doc='docs/cue.md'; unit=''; tol=0.001
     anchor='The nudge does not have this property (0.916). It jumps, so it has nothing to'
     expect=0.916
     measure={ (CueHalves 'L6D12')['hp'].ratio } }

  @{ id='cue-chr21ind-bytes'; tier='slow'; doc='docs/cue.md'; unit='B'; tol=0
     anchor='| | `chr21_ind` ≤ −3.0% | **held**: **−8.70%** (113,925 → 104,013 B) |'
     expect=104013
     measure={ CueChr21Ind 'cue' } }

  @{ id='cue-base-chr21ind-bytes'; tier='slow'; doc='docs/cue.md'; unit='B'; tol=0
     anchor='| | `chr21_ind` ≤ −3.0% | **held**: **−8.70%** (113,925 → 104,013 B) |'
     expect=113925
     measure={ CueChr21Ind 'base' } }

  @{ id='cue-chr21ind-pct'; tier='slow'; doc='docs/cue.md'; unit='%'; tol=0.005
     anchor='| | `chr21_ind` ≤ −3.0% | **held**: **−8.70%** (113,925 → 104,013 B) |'
     expect=-8.7
     measure={ CuePct (CueChr21Ind 'base') (CueChr21Ind 'cue') } }

  # ---- docs/nudge.md

  @{ id='nudge-sub-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| **5** | **12** | 15.65 | 33.27 | 6.76 | +2.07% | −1.89% |'
     expect=15.65
     measure={ CuePerEvent 'nudge' 'sub' } }

  @{ id='nudge-ind-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| **5** | **12** | 15.65 | 33.27 | 6.76 | +2.07% | −1.89% |'
     expect=33.27
     measure={ CuePerEvent 'nudge' 'ind' } }

  @{ id='nudge-hp-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| **5** | **12** | 15.65 | 33.27 | 6.76 | +2.07% | −1.89% |'
     expect=6.76
     measure={ CuePerEvent 'nudge' 'hp' } }

  @{ id='nudge-o157-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| **5** | **12** | 15.65 | 33.27 | 6.76 | +2.07% | −1.89% |'
     expect=2.07
     measure={ CuePct (CueReal 'base' 'o157') (CueReal 'nudge' 'o157') } }

  @{ id='nudge-ecoliind-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| **5** | **12** | 15.65 | 33.27 | 6.76 | +2.07% | −1.89% |'
     expect=-1.89
     measure={ CuePct (CueReal 'base' 'ecoli_ind') (CueReal 'nudge' 'ecoli_ind') } }

  @{ id='nudge-w3110-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| | W3110 not worse than +1% | **held**: −0.73% |'
     expect=-0.73
     measure={ CuePct (CueReal 'base' 'w3110') (CueReal 'nudge' 'w3110') } }

  @{ id='nudge-chr21ind-pct'; tier='slow'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| **P5** | `chr21_ind`, `ecoli_ind` ≥ 5% smaller | **failed**: −1.50%, −1.89% |'
     expect=-1.5
     measure={ CuePct (CueChr21Ind 'base') (CueChr21Ind 'nudge') } }

  @{ id='nudge-l6d12-sub-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 6 | 12 | 14.94 | 37.63 | 6.78 | +0.55% | **−2.38%** |'
     expect=14.94
     measure={ CuePerEvent 'L6D12' 'sub' } }

  @{ id='nudge-l6d12-ind-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 6 | 12 | 14.94 | 37.63 | 6.78 | +0.55% | **−2.38%** |'
     expect=37.63
     measure={ CuePerEvent 'L6D12' 'ind' } }

  @{ id='nudge-l6d12-hp-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 6 | 12 | 14.94 | 37.63 | 6.78 | +0.55% | **−2.38%** |'
     expect=6.78
     measure={ CuePerEvent 'L6D12' 'hp' } }

  @{ id='nudge-l6d12-o157-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 6 | 12 | 14.94 | 37.63 | 6.78 | +0.55% | **−2.38%** |'
     expect=0.55
     measure={ CuePct (CueReal 'base' 'o157') (CueReal 'L6D12' 'o157') } }

  @{ id='nudge-l6d12-ecoliind-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 6 | 12 | 14.94 | 37.63 | 6.78 | +0.55% | **−2.38%** |'
     expect=-2.38
     measure={ CuePct (CueReal 'base' 'ecoli_ind') (CueReal 'L6D12' 'ecoli_ind') } }

  @{ id='nudge-l8d12-sub-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 8 | 12 | 14.72 | 43.80 | 12.69 | −0.12% | −1.51% |'
     expect=14.72
     measure={ CuePerEvent 'L8D12' 'sub' } }

  @{ id='nudge-l8d12-ind-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 8 | 12 | 14.72 | 43.80 | 12.69 | −0.12% | −1.51% |'
     expect=43.8
     measure={ CuePerEvent 'L8D12' 'ind' } }

  @{ id='nudge-l8d12-hp-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 8 | 12 | 14.72 | 43.80 | 12.69 | −0.12% | −1.51% |'
     expect=12.69
     measure={ CuePerEvent 'L8D12' 'hp' } }

  @{ id='nudge-l8d12-o157-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 8 | 12 | 14.72 | 43.80 | 12.69 | −0.12% | −1.51% |'
     expect=-0.12
     measure={ CuePct (CueReal 'base' 'o157') (CueReal 'L8D12' 'o157') } }

  @{ id='nudge-l8d12-ecoliind-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 8 | 12 | 14.72 | 43.80 | 12.69 | −0.12% | −1.51% |'
     expect=-1.51
     measure={ CuePct (CueReal 'base' 'ecoli_ind') (CueReal 'L8D12' 'ecoli_ind') } }

  @{ id='nudge-l5d4-sub-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 5 | 4 | 15.01 | 33.09 | 6.82 | +0.50% | −0.95% |'
     expect=15.01
     measure={ CuePerEvent 'L5D4' 'sub' } }

  @{ id='nudge-l5d4-ind-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 5 | 4 | 15.01 | 33.09 | 6.82 | +0.50% | −0.95% |'
     expect=33.09
     measure={ CuePerEvent 'L5D4' 'ind' } }

  @{ id='nudge-l5d4-hp-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 5 | 4 | 15.01 | 33.09 | 6.82 | +0.50% | −0.95% |'
     expect=6.82
     measure={ CuePerEvent 'L5D4' 'hp' } }

  @{ id='nudge-l5d4-o157-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 5 | 4 | 15.01 | 33.09 | 6.82 | +0.50% | −0.95% |'
     expect=0.5
     measure={ CuePct (CueReal 'base' 'o157') (CueReal 'L5D4' 'o157') } }

  @{ id='nudge-l5d4-ecoliind-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 5 | 4 | 15.01 | 33.09 | 6.82 | +0.50% | −0.95% |'
     expect=-0.95
     measure={ CuePct (CueReal 'base' 'ecoli_ind') (CueReal 'L5D4' 'ecoli_ind') } }

  @{ id='nudge-l6d4-sub-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 6 | 4 | 14.72 | 37.56 | 6.80 | +0.02% | −0.99% |'
     expect=14.72
     measure={ CuePerEvent 'L6D4' 'sub' } }

  @{ id='nudge-l6d4-ind-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 6 | 4 | 14.72 | 37.56 | 6.80 | +0.02% | −0.99% |'
     expect=37.56
     measure={ CuePerEvent 'L6D4' 'ind' } }

  @{ id='nudge-l6d4-hp-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 6 | 4 | 14.72 | 37.56 | 6.80 | +0.02% | −0.99% |'
     expect=6.8
     measure={ CuePerEvent 'L6D4' 'hp' } }

  @{ id='nudge-l6d4-o157-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 6 | 4 | 14.72 | 37.56 | 6.80 | +0.02% | −0.99% |'
     expect=0.02
     measure={ CuePct (CueReal 'base' 'o157') (CueReal 'L6D4' 'o157') } }

  @{ id='nudge-l6d4-ecoliind-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 6 | 4 | 14.72 | 37.56 | 6.80 | +0.02% | −0.99% |'
     expect=-0.99
     measure={ CuePct (CueReal 'base' 'ecoli_ind') (CueReal 'L6D4' 'ecoli_ind') } }

  @{ id='nudge-l8d4-sub-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 8 | 4 | 14.71 | 43.77 | 12.66 | −0.15% | −0.50% |'
     expect=14.71
     measure={ CuePerEvent 'L8D4' 'sub' } }

  @{ id='nudge-l8d4-ind-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 8 | 4 | 14.71 | 43.77 | 12.66 | −0.15% | −0.50% |'
     expect=43.77
     measure={ CuePerEvent 'L8D4' 'ind' } }

  @{ id='nudge-l8d4-hp-bits'; tier='cue'; doc='docs/nudge.md'; unit='bits'; tol=0.005
     anchor='| 8 | 4 | 14.71 | 43.77 | 12.66 | −0.15% | −0.50% |'
     expect=12.66
     measure={ CuePerEvent 'L8D4' 'hp' } }

  @{ id='nudge-l8d4-o157-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 8 | 4 | 14.71 | 43.77 | 12.66 | −0.15% | −0.50% |'
     expect=-0.15
     measure={ CuePct (CueReal 'base' 'o157') (CueReal 'L8D4' 'o157') } }

  @{ id='nudge-l8d4-ecoliind-pct'; tier='cue'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='| 8 | 4 | 14.71 | 43.77 | 12.66 | −0.15% | −0.50% |'
     expect=-0.5
     measure={ CuePct (CueReal 'base' 'ecoli_ind') (CueReal 'L8D4' 'ecoli_ind') } }

  @{ id='nudge-l6d12-chr21ind-bytes'; tier='slow'; doc='docs/nudge.md'; unit='B'; tol=0
     anchor='   individual this setting gives **110,508 B against 113,925 B, −3.00%**'
     expect=110508
     measure={ CueChr21Ind 'L6D12' } }

  @{ id='nudge-l6d12-chr21ind-pct'; tier='slow'; doc='docs/nudge.md'; unit='%'; tol=0.005
     anchor='   individual this setting gives **110,508 B against 113,925 B, −3.00%**'
     expect=-3.0
     measure={ CuePct (CueChr21Ind 'base') (CueChr21Ind 'L6D12') } }

  # ---- docs/cue-room.md

  @{ id='room-noroom-ind-bits'; tier='cue'; doc='docs/cue-room.md'; unit='bits'; tol=0.005
     anchor='| **H1** | indel and slip ≥ 5% dearer | **failed, inverted**: indel 28.34 (−1.4%), slip 11.04 (−6.3%) |'
     expect=28.34
     measure={ CuePerEvent 'noroom' 'ind' } }

  @{ id='room-noroom-hp-bits'; tier='cue'; doc='docs/cue-room.md'; unit='bits'; tol=0.005
     anchor='| **H1** | indel and slip ≥ 5% dearer | **failed, inverted**: indel 28.34 (−1.4%), slip 11.04 (−6.3%) |'
     expect=11.04
     measure={ CuePerEvent 'noroom' 'hp' } }

  @{ id='room-noroom-sub-bits'; tier='cue'; doc='docs/cue-room.md'; unit='bits'; tol=0.005
     anchor='| **H3** | substitutions within ±1% | **held**: 14.73 (+0.5%) |'
     expect=14.73
     measure={ CuePerEvent 'noroom' 'sub' } }

  @{ id='room-noroom-ratio'; tier='cue'; doc='docs/cue-room.md'; unit=''; tol=0.001
     anchor='| **H2** | slip learning weaker: 2nd ÷ 1st > 0.70 | **failed**: 0.610 (with room: 0.576) |'
     expect=0.61
     measure={ (CueHalves 'noroom')['hp'].ratio } }

  @{ id='room-noroom-hp-1st'; tier='cue'; doc='docs/cue-room.md'; unit='bits'; tol=0.005
     anchor='fills faster. That shows as a cheaper first half (slip 13.73 against 14.99'
     expect=13.73
     measure={ (CueHalves 'noroom')['hp'].first } }

  @{ id='room-noroom-hp-2nd'; tier='cue'; doc='docs/cue-room.md'; unit='bits'; tol=0.005
     anchor='bits), with the second half almost the same (8.38 against 8.63).'
     expect=8.38
     measure={ (CueHalves 'noroom')['hp'].second } }

  @{ id='room-noroom-chr21ind-bytes'; tier='slow'; doc='docs/cue-room.md'; unit='B'; tol=0
     anchor='| **H4** | `chr21_ind` loses ≥ 1 point | **failed**: 104,125 B against 104,013 (+0.11%) |'
     expect=104125
     measure={ CueChr21Ind 'noroom' } }

  @{ id='room-noroom-chm13-bytes'; tier='slow'; doc='docs/cue-room.md'; unit='B'; tol=0
     anchor='CHM13 whole file: 551,753 B against 551,594 (+0.03%).'
     expect=551753
     measure={ CueHuman 'noroom' 'chm13_chr21.fa' 'grch38_chr21.fa' } }

  @{ id='room-noroom-shared-pct'; tier='slow'; doc='docs/cue-room.md'; unit='%'; tol=0.005
     anchor='| **H5** | CHM13 shared windows lose ≥ 1 point | **failed**: −18.14% against −18.27% |'
     expect=-18.14
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'shared' 'noroom' } }

  # ---- docs/cue-back.md

  @{ id='back-cue2-sub-bits'; tier='cue'; doc='docs/cue-back.md'; unit='bits'; tol=0.005
     anchor='| **B1** | controlled targets within ±2% of the single-deck cue | **held**: substitution 14.71 (+0.4%), random indel 28.85 (+0.3%), slip 11.82 (+0.3%) |'
     expect=14.71
     measure={ CuePerEvent 'cue2' 'sub' } }

  @{ id='back-cue2-ind-bits'; tier='cue'; doc='docs/cue-back.md'; unit='bits'; tol=0.005
     anchor='| **B1** | controlled targets within ±2% of the single-deck cue | **held**: substitution 14.71 (+0.4%), random indel 28.85 (+0.3%), slip 11.82 (+0.3%) |'
     expect=28.85
     measure={ CuePerEvent 'cue2' 'ind' } }

  @{ id='back-cue2-hp-bits'; tier='cue'; doc='docs/cue-back.md'; unit='bits'; tol=0.005
     anchor='| **B1** | controlled targets within ±2% of the single-deck cue | **held**: substitution 14.71 (+0.4%), random indel 28.85 (+0.3%), slip 11.82 (+0.3%) |'
     expect=11.82
     measure={ CuePerEvent 'cue2' 'hp' } }

  @{ id='back-cue2-chr21ind-bytes'; tier='slow'; doc='docs/cue-back.md'; unit='B'; tol=0
     anchor='| **B2** | `chr21_ind` within ±0.5% | **held**: 104,140 B against 104,013 (+0.12%) |'
     expect=104140
     measure={ CueChr21Ind 'cue2' } }

  @{ id='back-cue2-shared-pct'; tier='slow'; doc='docs/cue-back.md'; unit='%'; tol=0.005
     anchor='| **B3** | real pair, shared windows ≥ 0.5% better than the single deck | **failed**: −18.38% against −18.27%, an extra 0.1% |'
     expect=-18.38
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'shared' 'cue2' } }

  @{ id='back-cue2-chm13-bytes'; tier='slow'; doc='docs/cue-back.md'; unit='B'; tol=0
     anchor='Real pair, whole file: 551,539 B against 551,594 (−0.01%).'
     expect=551539
     measure={ CueHuman 'cue2' 'chm13_chr21.fa' 'grch38_chr21.fa' } }

  # ---- docs/real-human.md

  @{ id='rh-base-bytes'; tier='slow'; doc='docs/real-human.md'; unit='B'; tol=0
     anchor='| **R1** | whole chromosome ≥ 1.0% smaller | **held**: 586,615 → **551,594 B, −5.97%** |'
     expect=586615
     measure={ CueHuman 'base' 'chm13_chr21.fa' 'grch38_chr21.fa' } }

  @{ id='rh-cue-bytes'; tier='slow'; doc='docs/real-human.md'; unit='B'; tol=0
     anchor='| **R1** | whole chromosome ≥ 1.0% smaller | **held**: 586,615 → **551,594 B, −5.97%** |'
     expect=551594
     measure={ CueHuman 'cue' 'chm13_chr21.fa' 'grch38_chr21.fa' } }

  @{ id='rh-pct'; tier='slow'; doc='docs/real-human.md'; unit='%'; tol=0.005
     anchor='| **R1** | whole chromosome ≥ 1.0% smaller | **held**: 586,615 → **551,594 B, −5.97%** |'
     expect=-5.97
     measure={ CuePct (CueHuman 'base' 'chm13_chr21.fa' 'grch38_chr21.fa') (CueHuman 'cue' 'chm13_chr21.fa' 'grch38_chr21.fa') } }

  @{ id='rh-shared-pct'; tier='slow'; doc='docs/real-human.md'; unit='%'; tol=0.005
     anchor='| **R2** | shared windows ≥ 5% fewer bits | **held**: **−18.27%** |'
     expect=-18.27
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'shared' } }

  @{ id='rh-novel-pct'; tier='slow'; doc='docs/real-human.md'; unit='%'; tol=0.005
     anchor='| **R3** | novel windows within ±1% | **held**: −0.00% (1,082,312 → 1,082,291 bits) |'
     expect=-0.0
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'novel' } }

  @{ id='rh-r4-first-pct'; tier='slow'; doc='docs/real-human.md'; unit='%'; tol=0.005
     anchor='| **R4** | gain larger in the second half of the shared set | **held**: −13.26% first half, **−23.21%** second |'
     expect=-13.26
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'shared' 'cue' 'first' } }

  @{ id='rh-r4-second-pct'; tier='slow'; doc='docs/real-human.md'; unit='%'; tol=0.005
     anchor='| **R4** | gain larger in the second half of the shared set | **held**: −13.26% first half, **−23.21%** second |'
     expect=-23.21
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'shared' 'cue' 'second' } }

  @{ id='rh-win-shared-count'; tier='slow'; doc='docs/real-human.md'; unit='windows'; tol=0
     anchor='| shared (< 0.2) | 39,888 | 1,189,954 | 972,579 | **−18.27%** |'
     expect=39888
     measure={ (CueWindowSums 'chm13_chr21' 'grch38_chr21' 'shared').windows } }

  @{ id='rh-win-shared-base-bits'; tier='slow'; doc='docs/real-human.md'; unit='bits'; tol=1
     anchor='| shared (< 0.2) | 39,888 | 1,189,954 | 972,579 | **−18.27%** |'
     expect=1189954
     measure={ [math]::Round((CueWindowSums 'chm13_chr21' 'grch38_chr21' 'shared').base, 0) } }

  @{ id='rh-win-shared-cue-bits'; tier='slow'; doc='docs/real-human.md'; unit='bits'; tol=1
     anchor='| shared (< 0.2) | 39,888 | 1,189,954 | 972,579 | **−18.27%** |'
     expect=972579
     measure={ [math]::Round((CueWindowSums 'chm13_chr21' 'grch38_chr21' 'shared').cue, 0) } }

  @{ id='rh-win-shared-pct'; tier='slow'; doc='docs/real-human.md'; unit='%'; tol=0.005
     anchor='| shared (< 0.2) | 39,888 | 1,189,954 | 972,579 | **−18.27%** |'
     expect=-18.27
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'shared' } }

  @{ id='rh-win-diverged-count'; tier='slow'; doc='docs/real-human.md'; unit='windows'; tol=0
     anchor='| diverged (0.2 – 1.0) | 4,512 | 2,351,053 | 2,288,286 | −2.67% |'
     expect=4512
     measure={ (CueWindowSums 'chm13_chr21' 'grch38_chr21' 'diverged').windows } }

  @{ id='rh-win-diverged-base-bits'; tier='slow'; doc='docs/real-human.md'; unit='bits'; tol=1
     anchor='| diverged (0.2 – 1.0) | 4,512 | 2,351,053 | 2,288,286 | −2.67% |'
     expect=2351053
     measure={ [math]::Round((CueWindowSums 'chm13_chr21' 'grch38_chr21' 'diverged').base, 0) } }

  @{ id='rh-win-diverged-cue-bits'; tier='slow'; doc='docs/real-human.md'; unit='bits'; tol=1
     anchor='| diverged (0.2 – 1.0) | 4,512 | 2,351,053 | 2,288,286 | −2.67% |'
     expect=2288286
     measure={ [math]::Round((CueWindowSums 'chm13_chr21' 'grch38_chr21' 'diverged').cue, 0) } }

  @{ id='rh-win-diverged-pct'; tier='slow'; doc='docs/real-human.md'; unit='%'; tol=0.005
     anchor='| diverged (0.2 – 1.0) | 4,512 | 2,351,053 | 2,288,286 | −2.67% |'
     expect=-2.67
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'diverged' } }

  @{ id='rh-win-novel-count'; tier='slow'; doc='docs/real-human.md'; unit='windows'; tol=0
     anchor='| novel (≥ 1.0) | 691 | 1,082,312 | 1,082,291 | −0.00% |'
     expect=691
     measure={ (CueWindowSums 'chm13_chr21' 'grch38_chr21' 'novel').windows } }

  @{ id='rh-win-novel-base-bits'; tier='slow'; doc='docs/real-human.md'; unit='bits'; tol=1
     anchor='| novel (≥ 1.0) | 691 | 1,082,312 | 1,082,291 | −0.00% |'
     expect=1082312
     measure={ [math]::Round((CueWindowSums 'chm13_chr21' 'grch38_chr21' 'novel').base, 0) } }

  @{ id='rh-win-novel-cue-bits'; tier='slow'; doc='docs/real-human.md'; unit='bits'; tol=1
     anchor='| novel (≥ 1.0) | 691 | 1,082,312 | 1,082,291 | −0.00% |'
     expect=1082291
     measure={ [math]::Round((CueWindowSums 'chm13_chr21' 'grch38_chr21' 'novel').cue, 0) } }

  @{ id='rh-win-novel-pct'; tier='slow'; doc='docs/real-human.md'; unit='%'; tol=0.005
     anchor='| novel (≥ 1.0) | 691 | 1,082,312 | 1,082,291 | −0.00% |'
     expect=-0.0
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'novel' } }

  @{ id='rh-win-all-count'; tier='slow'; doc='docs/real-human.md'; unit='windows'; tol=0
     anchor='| all | 45,091 | 4,623,320 | 4,343,157 | −6.06% |'
     expect=45091
     measure={ (CueWindowSums 'chm13_chr21' 'grch38_chr21' 'all').windows } }

  @{ id='rh-win-all-base-bits'; tier='slow'; doc='docs/real-human.md'; unit='bits'; tol=1
     anchor='| all | 45,091 | 4,623,320 | 4,343,157 | −6.06% |'
     expect=4623320
     measure={ [math]::Round((CueWindowSums 'chm13_chr21' 'grch38_chr21' 'all').base, 0) } }

  @{ id='rh-win-all-cue-bits'; tier='slow'; doc='docs/real-human.md'; unit='bits'; tol=1
     anchor='| all | 45,091 | 4,623,320 | 4,343,157 | −6.06% |'
     expect=4343157
     measure={ [math]::Round((CueWindowSums 'chm13_chr21' 'grch38_chr21' 'all').cue, 0) } }

  @{ id='rh-win-all-pct'; tier='slow'; doc='docs/real-human.md'; unit='%'; tol=0.005
     anchor='| all | 45,091 | 4,623,320 | 4,343,157 | −6.06% |'
     expect=-6.06
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'all' } }

  # ---- docs/remaining.md

  @{ id='rem-roundtrip-base'; tier='cue'; doc='docs/remaining.md'; unit='round-trips'; tol=0
     anchor='| **T1** | every new build passes `scripts/roundtrip.sh` | **held**: 203/203 for base, cue, cue without room, alternating cue, nudge L5D12, nudge L6D12 |'
     expect=203
     measure={ CueRoundtrip 'base' } }

  @{ id='rem-roundtrip-cue'; tier='cue'; doc='docs/remaining.md'; unit='round-trips'; tol=0
     anchor='| **T1** | every new build passes `scripts/roundtrip.sh` | **held**: 203/203 for base, cue, cue without room, alternating cue, nudge L5D12, nudge L6D12 |'
     expect=203
     measure={ CueRoundtrip 'cue' } }

  @{ id='rem-roundtrip-noroom'; tier='cue'; doc='docs/remaining.md'; unit='round-trips'; tol=0
     anchor='| **T1** | every new build passes `scripts/roundtrip.sh` | **held**: 203/203 for base, cue, cue without room, alternating cue, nudge L5D12, nudge L6D12 |'
     expect=203
     measure={ CueRoundtrip 'noroom' } }

  @{ id='rem-roundtrip-cue2'; tier='cue'; doc='docs/remaining.md'; unit='round-trips'; tol=0
     anchor='| **T1** | every new build passes `scripts/roundtrip.sh` | **held**: 203/203 for base, cue, cue without room, alternating cue, nudge L5D12, nudge L6D12 |'
     expect=203
     measure={ CueRoundtrip 'cue2' } }

  @{ id='rem-roundtrip-nudge'; tier='cue'; doc='docs/remaining.md'; unit='round-trips'; tol=0
     anchor='| **T1** | every new build passes `scripts/roundtrip.sh` | **held**: 203/203 for base, cue, cue without room, alternating cue, nudge L5D12, nudge L6D12 |'
     expect=203
     measure={ CueRoundtrip 'nudge' } }

  @{ id='rem-roundtrip-l6d12'; tier='cue'; doc='docs/remaining.md'; unit='round-trips'; tol=0
     anchor='| **T1** | every new build passes `scripts/roundtrip.sh` | **held**: 203/203 for base, cue, cue without room, alternating cue, nudge L5D12, nudge L6D12 |'
     expect=203
     measure={ CueRoundtrip 'L6D12' } }

  @{ id='rem-mf-ind-bits'; tier='cue'; doc='docs/remaining.md'; unit='bits'; tol=0.005
     anchor='| no | yes (`mf`) | 27.78 | 10.49 | 14.63 | 104,007 |'
     expect=27.78
     measure={ CuePerEvent 'mf' 'ind' } }

  @{ id='rem-mf-hp-bits'; tier='cue'; doc='docs/remaining.md'; unit='bits'; tol=0.005
     anchor='| no | yes (`mf`) | 27.78 | 10.49 | 14.63 | 104,007 |'
     expect=10.49
     measure={ CuePerEvent 'mf' 'hp' } }

  @{ id='rem-mf-sub-bits'; tier='cue'; doc='docs/remaining.md'; unit='bits'; tol=0.005
     anchor='| no | yes (`mf`) | 27.78 | 10.49 | 14.63 | 104,007 |'
     expect=14.63
     measure={ CuePerEvent 'mf' 'sub' } }

  @{ id='rem-mf-chr21ind-bytes'; tier='slow'; doc='docs/remaining.md'; unit='B'; tol=0
     anchor='| no | yes (`mf`) | 27.78 | 10.49 | 14.63 | 104,007 |'
     expect=104007
     measure={ CueChr21Ind 'mf' } }

  @{ id='rem-mf_noroom-ind-bits'; tier='cue'; doc='docs/remaining.md'; unit='bits'; tol=0.005
     anchor='| no | no (`mf_noroom`) | **27.41** | **9.78** | 14.68 | 104,082 |'
     expect=27.41
     measure={ CuePerEvent 'mf_noroom' 'ind' } }

  @{ id='rem-mf_noroom-hp-bits'; tier='cue'; doc='docs/remaining.md'; unit='bits'; tol=0.005
     anchor='| no | no (`mf_noroom`) | **27.41** | **9.78** | 14.68 | 104,082 |'
     expect=9.78
     measure={ CuePerEvent 'mf_noroom' 'hp' } }

  @{ id='rem-mf_noroom-sub-bits'; tier='cue'; doc='docs/remaining.md'; unit='bits'; tol=0.005
     anchor='| no | no (`mf_noroom`) | **27.41** | **9.78** | 14.68 | 104,082 |'
     expect=14.68
     measure={ CuePerEvent 'mf_noroom' 'sub' } }

  @{ id='rem-mf_noroom-chr21ind-bytes'; tier='slow'; doc='docs/remaining.md'; unit='B'; tol=0
     anchor='| no | no (`mf_noroom`) | **27.41** | **9.78** | 14.68 | 104,082 |'
     expect=104082
     measure={ CueChr21Ind 'mf_noroom' } }

  @{ id='rem-chr22-base-bytes'; tier='slow'; doc='docs/remaining.md'; unit='B'; tol=0
     anchor='| **file** | 794,330 B | 748,025 B | **−5.83%** |'
     expect=794330
     measure={ CueHuman 'base' 'chm13_chr22.fa' 'grch38_chr22.fa' } }

  @{ id='rem-chr22-cue-bytes'; tier='slow'; doc='docs/remaining.md'; unit='B'; tol=0
     anchor='| **file** | 794,330 B | 748,025 B | **−5.83%** |'
     expect=748025
     measure={ CueHuman 'cue' 'chm13_chr22.fa' 'grch38_chr22.fa' } }

  @{ id='rem-chr22-pct'; tier='slow'; doc='docs/remaining.md'; unit='%'; tol=0.005
     anchor='| **file** | 794,330 B | 748,025 B | **−5.83%** |'
     expect=-5.83
     measure={ CuePct (CueHuman 'base' 'chm13_chr22.fa' 'grch38_chr22.fa') (CueHuman 'cue' 'chm13_chr22.fa' 'grch38_chr22.fa') } }

  @{ id='rem-chr22-shared-pct'; tier='slow'; doc='docs/remaining.md'; unit='%'; tol=0.005
     anchor='| shared windows (< 0.2 b/b, 85.8% of windows, 25.3% of bits) | | | **−16.24%** |'
     expect=-16.24
     measure={ CueWindows 'chm13_chr22' 'grch38_chr22' 'shared' } }

  @{ id='rem-chr22-shared-winpct'; tier='slow'; doc='docs/remaining.md'; unit='%'; tol=0.05
     anchor='| shared windows (< 0.2 b/b, 85.8% of windows, 25.3% of bits) | | | **−16.24%** |'
     expect=85.8
     measure={ $w = CueWindowSums 'chm13_chr22' 'grch38_chr22' 'shared'; [math]::Round(100.0 * $w.windows / $w.total, 1) } }

  @{ id='rem-chr22-shared-bitpct'; tier='slow'; doc='docs/remaining.md'; unit='%'; tol=0.05
     anchor='| shared windows (< 0.2 b/b, 85.8% of windows, 25.3% of bits) | | | **−16.24%** |'
     expect=25.3
     measure={ $w = CueWindowSums 'chm13_chr22' 'grch38_chr22' 'shared'; $a = CueWindowSums 'chm13_chr22' 'grch38_chr22' 'all'; [math]::Round(100.0 * $w.base / $a.base, 1) } }

  @{ id='rem-chr22-diverged-pct'; tier='slow'; doc='docs/remaining.md'; unit='%'; tol=0.005
     anchor='| diverged (0.2–1.0 b/b, 51.3% of bits) | | | −3.49% |'
     expect=-3.49
     measure={ CueWindows 'chm13_chr22' 'grch38_chr22' 'diverged' } }

  @{ id='rem-chr22-diverged-bitpct'; tier='slow'; doc='docs/remaining.md'; unit='%'; tol=0.05
     anchor='| diverged (0.2–1.0 b/b, 51.3% of bits) | | | −3.49% |'
     expect=51.3
     measure={ $w = CueWindowSums 'chm13_chr22' 'grch38_chr22' 'diverged'; $a = CueWindowSums 'chm13_chr22' 'grch38_chr22' 'all'; [math]::Round(100.0 * $w.base / $a.base, 1) } }

  @{ id='rem-chr22-novel-pct'; tier='slow'; doc='docs/remaining.md'; unit='%'; tol=0.005
     anchor='| novel (≥ 1.0 b/b, 23.4% of bits) | | | −0.01% |'
     expect=-0.01
     measure={ CueWindows 'chm13_chr22' 'grch38_chr22' 'novel' } }

  @{ id='rem-chr22-novel-bitpct'; tier='slow'; doc='docs/remaining.md'; unit='%'; tol=0.05
     anchor='| novel (≥ 1.0 b/b, 23.4% of bits) | | | −0.01% |'
     expect=23.4
     measure={ $w = CueWindowSums 'chm13_chr22' 'grch38_chr22' 'novel'; $a = CueWindowSums 'chm13_chr22' 'grch38_chr22' 'all'; [math]::Round(100.0 * $w.base / $a.base, 1) } }

  # ---- docs/speed.md

  @{ id='speed-ecoli_ind-l3-bytes'; tier='cue'; doc='docs/speed.md'; unit='B'; tol=0
     anchor='| `ecoli_ind` | 12,580 B, 8.86 s | −3.19%, 8.96 s | +0.23%, 4.06 s | **−2.23%, 4.12 s** |'
     expect=12580
     measure={ CueReal 'base' 'ecoli_ind' 3 } }

  @{ id='speed-ecoli_ind-cue-l3-pct'; tier='cue'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| `ecoli_ind` | 12,580 B, 8.86 s | −3.19%, 8.96 s | +0.23%, 4.06 s | **−2.23%, 4.12 s** |'
     expect=-3.19
     measure={ CuePct (CueReal 'base' 'ecoli_ind' 3) (CueReal 'cue' 'ecoli_ind' 3) } }

  @{ id='speed-ecoli_ind-base-l1-pct'; tier='cue'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| `ecoli_ind` | 12,580 B, 8.86 s | −3.19%, 8.96 s | +0.23%, 4.06 s | **−2.23%, 4.12 s** |'
     expect=0.23
     measure={ CuePct (CueReal 'base' 'ecoli_ind' 3) (CueReal 'base' 'ecoli_ind' 1) } }

  @{ id='speed-ecoli_ind-cue-l1-pct'; tier='cue'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| `ecoli_ind` | 12,580 B, 8.86 s | −3.19%, 8.96 s | +0.23%, 4.06 s | **−2.23%, 4.12 s** |'
     expect=-2.23
     measure={ CuePct (CueReal 'base' 'ecoli_ind' 3) (CueReal 'cue' 'ecoli_ind' 1) } }

  @{ id='speed-ind_1-l3-bytes'; tier='cue'; doc='docs/speed.md'; unit='B'; tol=0
     anchor='| `ind_1` | 53,178 B, 8.80 s | −9.18%, 8.96 s | +0.27%, 4.01 s | **−7.66%, 4.07 s** |'
     expect=53178
     measure={ CueTarget 'base' 'ind_1' 3 } }

  @{ id='speed-ind_1-cue-l3-pct'; tier='cue'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| `ind_1` | 53,178 B, 8.80 s | −9.18%, 8.96 s | +0.27%, 4.01 s | **−7.66%, 4.07 s** |'
     expect=-9.18
     measure={ CuePct (CueTarget 'base' 'ind_1' 3) (CueTarget 'cue' 'ind_1' 3) } }

  @{ id='speed-ind_1-base-l1-pct'; tier='cue'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| `ind_1` | 53,178 B, 8.80 s | −9.18%, 8.96 s | +0.27%, 4.01 s | **−7.66%, 4.07 s** |'
     expect=0.27
     measure={ CuePct (CueTarget 'base' 'ind_1' 3) (CueTarget 'base' 'ind_1' 1) } }

  @{ id='speed-ind_1-cue-l1-pct'; tier='cue'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| `ind_1` | 53,178 B, 8.80 s | −9.18%, 8.96 s | +0.27%, 4.01 s | **−7.66%, 4.07 s** |'
     expect=-7.66
     measure={ CuePct (CueTarget 'base' 'ind_1' 3) (CueTarget 'cue' 'ind_1' 1) } }

  @{ id='speed-hp_1-l3-bytes'; tier='cue'; doc='docs/speed.md'; unit='B'; tol=0
     anchor='| `hp_1` | 48,994 B, 8.82 s | −10.00%, 8.98 s | +0.26%, 4.08 s | **−8.54%, 4.14 s** |'
     expect=48994
     measure={ CueTarget 'base' 'hp_1' 3 } }

  @{ id='speed-hp_1-cue-l3-pct'; tier='cue'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| `hp_1` | 48,994 B, 8.82 s | −10.00%, 8.98 s | +0.26%, 4.08 s | **−8.54%, 4.14 s** |'
     expect=-10.0
     measure={ CuePct (CueTarget 'base' 'hp_1' 3) (CueTarget 'cue' 'hp_1' 3) } }

  @{ id='speed-hp_1-base-l1-pct'; tier='cue'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| `hp_1` | 48,994 B, 8.82 s | −10.00%, 8.98 s | +0.26%, 4.08 s | **−8.54%, 4.14 s** |'
     expect=0.26
     measure={ CuePct (CueTarget 'base' 'hp_1' 3) (CueTarget 'base' 'hp_1' 1) } }

  @{ id='speed-hp_1-cue-l1-pct'; tier='cue'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| `hp_1` | 48,994 B, 8.82 s | −10.00%, 8.98 s | +0.26%, 4.08 s | **−8.54%, 4.14 s** |'
     expect=-8.54
     measure={ CuePct (CueTarget 'base' 'hp_1' 3) (CueTarget 'cue' 'hp_1' 1) } }

  @{ id='speed-rh-base-bytes'; tier='slow'; doc='docs/speed.md'; unit='B'; tol=0
     anchor='| v0.8.0 level 3 (today''s default) | 586,615 B | 206.9 s |'
     expect=586615
     measure={ CueHuman 'base' 'chm13_chr21.fa' 'grch38_chr21.fa' } }

  @{ id='speed-rh-cue-bytes'; tier='slow'; doc='docs/speed.md'; unit='B'; tol=0
     anchor='| cue level 3 | 551,594 B (−5.97%) | ~193 s |'
     expect=551594
     measure={ CueHuman 'cue' 'chm13_chr21.fa' 'grch38_chr21.fa' } }

  @{ id='speed-rh-cue-l1-bytes'; tier='slow'; doc='docs/speed.md'; unit='B'; tol=0
     anchor='| **cue level 1** | **568,133 B (−3.15%)** | **85.8 s (2.4x faster)** |'
     expect=568133
     measure={ CueHuman 'cue' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  @{ id='speed-rh-cue-l1-pct'; tier='slow'; doc='docs/speed.md'; unit='%'; tol=0.005
     anchor='| **cue level 1** | **568,133 B (−3.15%)** | **85.8 s (2.4x faster)** |'
     expect=-3.15
     measure={ CuePct (CueHuman 'base' 'chm13_chr21.fa' 'grch38_chr21.fa') (CueHuman 'cue' 'chm13_chr21.fa' 'grch38_chr21.fa' 1) } }

  # ---- docs/competitors.md

  @{ id='comp-zstd-fa-bytes'; tier='extern'; doc='docs/competitors.md'; unit='B'; tol=0
     anchor='| zstd -19 --long=27 --patch-from | 3,143,939 | 5.70x larger | yes |'
     expect=3143939
     measure={ ZstdPatch (Join-Path $cueHuman 'chm13_chr21.fa') (Join-Path $cueHuman 'grch38_chr21.fa') } }

  @{ id='comp-hrcm-fa-bytes'; tier='extern'; doc='docs/competitors.md'; unit='B'; tol=0
     anchor='| HRCM | 1,438,137 | 2.61x larger | sequence, header and line layout yes; drops the file''s final empty line |'
     expect=1438137
     measure={ Hrcm (Join-Path $cueHuman 'chm13_chr21.fa') (Join-Path $cueHuman 'grch38_chr21.fa') } }

  @{ id='comp-dnac-base-fa-bytes'; tier='slow'; doc='docs/competitors.md'; unit='B'; tol=0
     anchor='| dnac v0.8.0 | 586,615 | 1.06x | yes |'
     expect=586615
     measure={ CueHuman 'base' 'chm13_chr21.fa' 'grch38_chr21.fa' } }

  @{ id='comp-dnac-cue-fa-bytes'; tier='slow'; doc='docs/competitors.md'; unit='B'; tol=0
     anchor='| **dnac + cue** | **551,594** | — | yes |'
     expect=551594
     measure={ CueHuman 'cue' 'chm13_chr21.fa' 'grch38_chr21.fa' } }

  @{ id='comp-zstd-seq-bytes'; tier='extern'; doc='docs/competitors.md'; unit='B'; tol=0
     anchor='| zstd -19 --long=27 --patch-from | 882,586 | 1.62x larger | yes |'
     expect=882586
     measure={ ZstdPatch (Join-Path $cueHuman 'chm13_chr21.seq') (Join-Path $cueHuman 'grch38_chr21.seq') } }

  @{ id='comp-geco-ref-bytes'; tier='extern'; doc='docs/competitors.md'; unit='B'; tol=0
     anchor='| GeCo3, reference template (`$PARAMR`) | 1,243,961 | 2.28x larger | **unverified** (GeDe3 broken on this machine) |'
     expect=1243961
     measure={ Geco (Join-Path $cueHuman 'chm13_chr21.seq') "$PARAMR -r ref.seq" (Join-Path $cueHuman 'grch38_chr21.seq') } }

  @{ id='comp-geco-hybrid-bytes'; tier='extern'; doc='docs/competitors.md'; unit='B'; tol=0
     anchor='| GeCo3, hybrid template (`$PARAMH`) | 877,373 | 1.61x larger | **unverified** |'
     expect=877373
     measure={ Geco (Join-Path $cueHuman 'chm13_chr21.seq') "$PARAMH -r ref.seq" (Join-Path $cueHuman 'grch38_chr21.seq') } }

  @{ id='comp-dnac-base-seq-bytes'; tier='slow'; doc='docs/competitors.md'; unit='B'; tol=0
     anchor='| dnac v0.8.0 | 581,022 | 1.06x | yes |'
     expect=581022
     measure={ CueHuman 'base' 'chm13_chr21.seq' 'grch38_chr21.seq' } }

  @{ id='comp-dnac-cue-seq-bytes'; tier='slow'; doc='docs/competitors.md'; unit='B'; tol=0
     anchor='| **dnac + cue** | **545,982** | — | yes |'
     expect=545982
     measure={ CueHuman 'cue' 'chm13_chr21.seq' 'grch38_chr21.seq' } }

  # ---- docs/reference-free.md (Batch 2: the cue where the README's headline
  # lives). Plain mode, so these rows need no reference and no primed state --
  # the cheapest cue rows here, and the ones that say the mechanism is safe in
  # the mode it was never measured in.

  @{ id='rf-ecoli-l3-base'; tier='cue'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| E. coli | 4,641,652 | 3 | 1,092,692 | 1,092,606 | **−0.008%** |'
     expect=1092692
     measure={ CuePlain 'base' 'ecoli' 3 } }

  @{ id='rf-ecoli-l3-cue'; tier='cue'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| E. coli | 4,641,652 | 3 | 1,092,692 | 1,092,606 | **−0.008%** |'
     expect=1092606
     measure={ CuePlain 'cue' 'ecoli' 3 } }

  @{ id='rf-ecoli-l3-pct'; tier='cue'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| E. coli | 4,641,652 | 3 | 1,092,692 | 1,092,606 | **−0.008%** |'
     expect=-0.008
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'ecoli' 3) / (CuePlain 'base' 'ecoli' 3) - 1.0), 3) } }

  @{ id='rf-ecoli-l1-base'; tier='cue'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| | | 1 | 1,093,749 | 1,093,906 | +0.014% |'
     expect=1093749
     measure={ CuePlain 'base' 'ecoli' 1 } }

  @{ id='rf-ecoli-l1-cue'; tier='cue'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| | | 1 | 1,093,749 | 1,093,906 | +0.014% |'
     expect=1093906
     measure={ CuePlain 'cue' 'ecoli' 1 } }

  @{ id='rf-ecoli-l1-pct'; tier='cue'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| | | 1 | 1,093,749 | 1,093,906 | +0.014% |'
     expect=0.014
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'ecoli' 1) / (CuePlain 'base' 'ecoli' 1) - 1.0), 3) } }

  @{ id='rf-chr21slice-l3-base'; tier='slow'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| chr21 slice | 9,836,065 | 3 | 2,104,223 | 2,104,040 | −0.009% |'
     expect=2104223
     measure={ CuePlain 'base' 'chr21slice' 3 } }

  @{ id='rf-chr21slice-l3-cue'; tier='slow'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| chr21 slice | 9,836,065 | 3 | 2,104,223 | 2,104,040 | −0.009% |'
     expect=2104040
     measure={ CuePlain 'cue' 'chr21slice' 3 } }

  @{ id='rf-chr21slice-l3-pct'; tier='slow'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| chr21 slice | 9,836,065 | 3 | 2,104,223 | 2,104,040 | −0.009% |'
     expect=-0.009
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'chr21slice' 3) / (CuePlain 'base' 'chr21slice' 3) - 1.0), 3) } }

  @{ id='rf-chr21slice-l1-base'; tier='slow'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| | | 1 | 2,112,100 | 2,112,092 | −0.000% |'
     expect=2112100
     measure={ CuePlain 'base' 'chr21slice' 1 } }

  @{ id='rf-chr21slice-l1-cue'; tier='slow'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| | | 1 | 2,112,100 | 2,112,092 | −0.000% |'
     expect=2112092
     measure={ CuePlain 'cue' 'chr21slice' 1 } }

  @{ id='rf-chr21slice-l1-pct'; tier='slow'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| | | 1 | 2,112,100 | 2,112,092 | −0.000% |'
     expect=-0.0
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'chr21slice' 1) / (CuePlain 'base' 'chr21slice' 1) - 1.0), 3) } }

  @{ id='rf-chr21-l3-base'; tier='slow'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| **chr21** | 40,088,619 | **3** | **7,506,264** | **7,502,884** | **−0.045%** |'
     expect=7506264
     measure={ CuePlain 'base' 'chr21' 3 } }

  @{ id='rf-chr21-l3-cue'; tier='slow'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| **chr21** | 40,088,619 | **3** | **7,506,264** | **7,502,884** | **−0.045%** |'
     expect=7502884
     measure={ CuePlain 'cue' 'chr21' 3 } }

  @{ id='rf-chr21-l3-pct'; tier='slow'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| **chr21** | 40,088,619 | **3** | **7,506,264** | **7,502,884** | **−0.045%** |'
     expect=-0.045
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'chr21' 3) / (CuePlain 'base' 'chr21' 3) - 1.0), 3) } }

  @{ id='rf-chr21-l1-base'; tier='slow'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| | | 1 | 7,549,315 | 7,546,232 | −0.041% |'
     expect=7549315
     measure={ CuePlain 'base' 'chr21' 1 } }

  @{ id='rf-chr21-l1-cue'; tier='slow'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| | | 1 | 7,549,315 | 7,546,232 | −0.041% |'
     expect=7546232
     measure={ CuePlain 'cue' 'chr21' 1 } }

  @{ id='rf-chr21-l1-pct'; tier='slow'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| | | 1 | 7,549,315 | 7,546,232 | −0.041% |'
     expect=-0.041
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'chr21' 1) / (CuePlain 'base' 'chr21' 1) - 1.0), 3) } }

  @{ id='rf-meta-l3-base'; tier='meta'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| metagenome | 200,000,000 | 3 | 17,323,036 | 17,318,948 | −0.024% |'
     expect=17323036
     measure={ CuePlain 'base' 'meta' 3 } }

  @{ id='rf-meta-l3-cue'; tier='meta'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| metagenome | 200,000,000 | 3 | 17,323,036 | 17,318,948 | −0.024% |'
     expect=17318948
     measure={ CuePlain 'cue' 'meta' 3 } }

  @{ id='rf-meta-l3-pct'; tier='meta'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| metagenome | 200,000,000 | 3 | 17,323,036 | 17,318,948 | −0.024% |'
     expect=-0.024
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'meta' 3) / (CuePlain 'base' 'meta' 3) - 1.0), 3) } }

  @{ id='rf-meta-l1-base'; tier='meta'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| | | 1 | 17,653,816 | 17,650,900 | −0.017% |'
     expect=17653816
     measure={ CuePlain 'base' 'meta' 1 } }

  @{ id='rf-meta-l1-cue'; tier='meta'; doc='docs/reference-free.md'; unit='B'; tol=0
     anchor='| | | 1 | 17,653,816 | 17,650,900 | −0.017% |'
     expect=17650900
     measure={ CuePlain 'cue' 'meta' 1 } }

  @{ id='rf-meta-l1-pct'; tier='meta'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| | | 1 | 17,653,816 | 17,650,900 | −0.017% |'
     expect=-0.017
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'meta' 1) / (CuePlain 'base' 'meta' 1) - 1.0), 3) } }

  @{ id='rf-ecoli-l1cue-vs-l3'; tier='cue'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| E. coli | +0.111% |'
     expect=0.111
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'ecoli' 1) / (CuePlain 'base' 'ecoli' 3) - 1.0), 3) } }

  @{ id='rf-chr21slice-l1cue-vs-l3'; tier='slow'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| chr21 slice | +0.374% |'
     expect=0.374
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'chr21slice' 1) / (CuePlain 'base' 'chr21slice' 3) - 1.0), 3) } }

  @{ id='rf-chr21-l1cue-vs-l3'; tier='slow'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| chr21 | +0.532% |'
     expect=0.532
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'chr21' 1) / (CuePlain 'base' 'chr21' 3) - 1.0), 3) } }

  @{ id='rf-meta-l1cue-vs-l3'; tier='meta'; doc='docs/reference-free.md'; unit='%'; tol=0.0005
     anchor='| metagenome | +1.893% |'
     expect=1.893
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'meta' 1) / (CuePlain 'base' 'meta' 3) - 1.0), 3) } }

  @{ id='rf-chr21-l3-cue-bpb'; tier='slow'; doc='docs/reference-free.md'; unit='bpb'; tol=6e-05
     anchor='In bits/base: chr21 1.4979 → 1.4973, E. coli 1.8833 → 1.8831, the metagenome'
     expect=1.4973
     measure={ Bpb (CuePlain 'cue' 'chr21' 3) (Bases (& $S 'chr21.seq')) } }

  @{ id='rf-ecoli-l3-cue-bpb'; tier='cue'; doc='docs/reference-free.md'; unit='bpb'; tol=6e-05
     anchor='In bits/base: chr21 1.4979 → 1.4973, E. coli 1.8833 → 1.8831, the metagenome'
     expect=1.8831
     measure={ Bpb (CuePlain 'cue' 'ecoli' 3) (Bases (& $S 'ecoli.seq')) } }
  # ---- docs/batch3.md (Batch 3: the sweep, the add-back, the held-out
  # chromosome). Everything here is LEVEL 1 in REFERENCE mode unless the id says
  # plain, because that is the default Batch 2 chose for a reference and the
  # regime the sweep was run in. The timings in that document get no rows.

  # the screen: cost per event on the ten controlled E. coli targets, level 1
  @{ id='b3-screen-base-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| v0.8.0 | 14.75 | 48.85 | 31.97 | +2.51% | +0.13% |'
     expect=48.85
     measure={ CuePerEvent 'base' 'ind' 1 } }

  @{ id='b3-screen-base-sub'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| v0.8.0 | 14.75 | 48.85 | 31.97 | +2.51% | +0.13% |'
     expect=14.75
     measure={ CuePerEvent 'base' 'sub' 1 } }

  @{ id='b3-screen-cue-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| **`cue` (centre)** | **14.65** | **31.99** | **14.70** | — | — |'
     expect=31.99
     measure={ CuePerEvent 'cue' 'ind' 1 } }

  @{ id='b3-screen-cue-sub'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| **`cue` (centre)** | **14.65** | **31.99** | **14.70** | — | — |'
     expect=14.65
     measure={ CuePerEvent 'cue' 'sub' 1 } }

  @{ id='b3-screen-cue-hp'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| **`cue` (centre)** | **14.65** | **31.99** | **14.70** | — | — |'
     expect=14.70
     measure={ CuePerEvent 'cue' 'hp' 1 } }

  @{ id='b3-screen-m8-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `cue_M8` | 14.74 | 30.43 | 14.61 | −0.44% | −0.05% |'
     expect=30.43
     measure={ CuePerEvent 'cue_M8' 'ind' 1 } }

  @{ id='b3-screen-m24-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `cue_M24` | 14.70 | 35.74 | 14.88 | +0.40% | +0.03% |'
     expect=35.74
     measure={ CuePerEvent 'cue_M24' 'ind' 1 } }

  @{ id='b3-screen-s8-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `cue_S8` | 14.71 | 30.63 | 13.28 | **−1.99%** | −0.11% |'
     expect=30.63
     measure={ CuePerEvent 'cue_S8' 'ind' 1 } }

  @{ id='b3-screen-s8-ecoliind-pct'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.005
     anchor='| `cue_S8` | 14.71 | 30.63 | 13.28 | **−1.99%** | −0.11% |'
     expect=-1.99
     measure={ CuePct (CueReal 'cue' 'ecoli_ind' 1) (CueReal 'cue_S8' 'ecoli_ind' 1) } }

  @{ id='b3-screen-d6-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `cue_D6` | 14.70 | 31.08 | 14.62 | +1.16% | +0.01% |'
     expect=31.08
     measure={ CuePerEvent 'cue_D6' 'ind' 1 } }

  @{ id='b3-screen-l2-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `cue_L2` | 14.79 | 29.95 | 14.23 | +0.55% | +0.03% |'
     expect=29.95
     measure={ CuePerEvent 'cue_L2' 'ind' 1 } }

  @{ id='b3-screen-mfnoroom-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `mf_noroom` | 14.70 | **28.31** | **10.80** | −1.04% | −0.01% |'
     expect=28.31
     measure={ CuePerEvent 'mf_noroom' 'ind' 1 } }

  @{ id='b3-screen-mfnoroom-hp'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `mf_noroom` | 14.70 | **28.31** | **10.80** | −1.04% | −0.01% |'
     expect=10.80
     measure={ CuePerEvent 'mf_noroom' 'hp' 1 } }

  # the real human pair at level 1: the centre, the sweep down CUE_MINLEN, and
  # the four add-backs. One measurement per build, memoised.
  @{ id='b3-chm13-base-l1'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| v0.8.0 level 1 | 602,170 | 813,961 |'
     expect=602170
     measure={ CueHuman 'base' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  @{ id='b3-chm13-cue-l1'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| **16 (centre)** | **568,133** | — | **104,784** | — |'
     expect=568133
     measure={ CueHuman 'cue' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  @{ id='b3-chm13-m8'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| 8 | 564,805 | −0.586% | 102,969 | −1.732% |'
     expect=564805
     measure={ CueHuman 'cue_M8' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  @{ id='b3-chm13-m4'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| **4** | **563,031** | **−0.898%** | 101,517 | −3.118% |'
     expect=563031
     measure={ CueHuman 'cue_M4' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  @{ id='b3-chm13-m4-pct'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='| **4** | **563,031** | **−0.898%** | 101,517 | −3.118% |'
     expect=-0.898
     measure={ [math]::Round(100.0 * ((CueHuman 'cue_M4' 'chm13_chr21.fa' 'grch38_chr21.fa' 1) / (CueHuman 'cue' 'chm13_chr21.fa' 'grch38_chr21.fa' 1) - 1.0), 3) } }

  @{ id='b3-chm13-m2'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| 2 | 563,188 | −0.870% | **99,594** | **−4.953%** |'
     expect=563188
     measure={ CueHuman 'cue_M2' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  @{ id='b3-chr21ind-cue-l1'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| **16 (centre)** | **568,133** | — | **104,784** | — |'
     expect=104784
     measure={ CueChr21Ind 'cue' 1 } }

  @{ id='b3-chr21ind-m4'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| **4** | **563,031** | **−0.898%** | 101,517 | −3.118% |'
     expect=101517
     measure={ CueChr21Ind 'cue_M4' 1 } }

  @{ id='b3-chr21ind-m2'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| 2 | 563,188 | −0.870% | **99,594** | **−4.953%** |'
     expect=99594
     measure={ CueChr21Ind 'cue_M2' 1 } }

  @{ id='b3-addback-stcm'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| `cue_stcm` (tolerant models) | 122.87 s | 561,172 | −1.225% | +29.0% | **no** |'
     expect=561172
     measure={ CueHuman 'cue_stcm' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  @{ id='b3-addback-ir'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| `cue_ir` (other-strand training) | 108.51 s | 564,985 | −0.554% | +13.9% | **no** |'
     expect=564985
     measure={ CueHuman 'cue_ir' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  @{ id='b3-addback-x4'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| `cue_x4` (four mixer experts) | 115.32 s | 565,162 | −0.523% | +21.1% | **no** |'
     expect=565162
     measure={ CueHuman 'cue_x4' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  @{ id='b3-addback-ord'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| `cue_ord` (master order set) | 110.34 s | 565,530 | −0.458% | +15.8% | **no** |'
     expect=565530
     measure={ CueHuman 'cue_ord' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  # the held-out chromosome, used once
  @{ id='b3-chr22-base-l1'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| v0.8.0 level 1 | 602,170 | 813,961 |'
     expect=813961
     measure={ CueHuman 'base' 'chm13_chr22.fa' 'grch38_chr22.fa' 1 } }

  @{ id='b3-chr22-cue-l1'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| `cue` (centre) | 568,133 (−5.65%) | 768,104 (−5.63%) |'
     expect=768104
     measure={ CueHuman 'cue' 'chm13_chr22.fa' 'grch38_chr22.fa' 1 } }

  @{ id='b3-chr22-m4-pct'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='| **`cue_M4`** | **−0.898% vs centre** | **−0.839% vs centre** |'
     expect=-0.839
     measure={ [math]::Round(100.0 * ((CueHuman 'cue_M4' 'chm13_chr22.fa' 'grch38_chr22.fa' 1) / (CueHuman 'cue' 'chm13_chr22.fa' 'grch38_chr22.fa' 1) - 1.0), 3) } }

  @{ id='b3-chr22-m8-pct'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='| `cue_M8` | −0.586% vs centre | −0.579% vs centre |'
     expect=-0.579
     measure={ [math]::Round(100.0 * ((CueHuman 'cue_M8' 'chm13_chr22.fa' 'grch38_chr22.fa' 1) / (CueHuman 'cue' 'chm13_chr22.fa' 'grch38_chr22.fa' 1) - 1.0), 3) } }

  # plain mode: the winner where the mechanism is quiet (D1's second gate)
  @{ id='b3-plain-m4-chr21-l3'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='| 3 | **`cue_M4`** | −0.0052% | **−0.1056%** |'
     expect=-0.1056
     measure={ [math]::Round(100.0 * ((CuePlain 'cue_M4' 'chr21' 3) / (CuePlain 'base' 'chr21' 3) - 1.0), 4) } }

  @{ id='b3-plain-m4-ecoli-l3'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='| 3 | **`cue_M4`** | −0.0052% | **−0.1056%** |'
     expect=-0.0052
     measure={ [math]::Round(100.0 * ((CuePlain 'cue_M4' 'ecoli' 3) / (CuePlain 'base' 'ecoli' 3) - 1.0), 4) } }

  @{ id='b3-plain-m8-chr21-l3'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='| 3 | `cue_M8` | −0.0081% | −0.0745% |'
     expect=-0.0745
     measure={ [math]::Round(100.0 * ((CuePlain 'cue_M8' 'chr21' 3) / (CuePlain 'base' 'chr21' 3) - 1.0), 4) } }

  @{ id='b3-plain-m4-chr21-l1'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='| 1 | **`cue_M4`** | +0.0096% | **−0.1131%** |'
     expect=-0.1131
     measure={ [math]::Round(100.0 * ((CuePlain 'cue_M4' 'chr21' 1) / (CuePlain 'base' 'chr21' 1) - 1.0), 4) } }

  @{ id='b3-plain-m4-l1-vs-l3'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='+0.460% against level 3 reference-free on chr21 (the centre was +0.532%), so'
     expect=0.460
     measure={ [math]::Round(100.0 * ((CuePlain 'cue_M4' 'chr21' 1) / (CuePlain 'base' 'chr21' 3) - 1.0), 3) } }

  # P13: the cue's gain at level 1 reference-free, two experts against four
  @{ id='b3-p13-chr21-2x'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.00005
     anchor='| chr21 | −0.0408% | −0.0404% |'
     expect=-0.0408
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'chr21' 1) / (CuePlain 'base' 'chr21' 1) - 1.0), 4) } }

  @{ id='b3-p13-chr21-4x'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.00005
     anchor='| chr21 | −0.0408% | −0.0404% |'
     expect=-0.0404
     measure={ [math]::Round(100.0 * ((CuePlain 'cue_x4' 'chr21' 1) / (CuePlain 'base_x4' 'chr21' 1) - 1.0), 4) } }

  @{ id='b3-p13-ecoli-2x'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.00005
     anchor='| E. coli | **+0.0144%** (a loss) | **−0.0048%** (a gain) |'
     expect=0.0144
     measure={ [math]::Round(100.0 * ((CuePlain 'cue' 'ecoli' 1) / (CuePlain 'base' 'ecoli' 1) - 1.0), 4) } }

  @{ id='b3-p13-ecoli-4x'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.00005
     anchor='| E. coli | **+0.0144%** (a loss) | **−0.0048%** (a gain) |'
     expect=-0.0048
     measure={ [math]::Round(100.0 * ((CuePlain 'cue_x4' 'ecoli' 1) / (CuePlain 'base_x4' 'ecoli' 1) - 1.0), 4) } }

  @{ id='b3-p13-basex4-chr21-l1'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='— a real but tiny effect, for +21% time.'
     expect=-0.025
     measure={ [math]::Round(100.0 * ((CuePlain 'base_x4' 'chr21' 1) / (CuePlain 'base' 'chr21' 1) - 1.0), 3) } }

  # P14: every build of this batch round-trips
  @{ id='b3-roundtrip-m4'; tier='cue3'; doc='docs/batch3.md'; unit='round-trips'; tol=0
     anchor='**held**: 203/203 on ten builds (`cue_M8`, `cue_M4`, `cue_M2`, `cue_x4`, `cue_ir`, `cue_stcm`, `cue_ord`, `base_x4`, `cue_S8`, `mf_noroom`)'
     expect=203
     measure={ CueRoundtrip 'cue_M4' } }

  @{ id='b3-roundtrip-stcm'; tier='cue3'; doc='docs/batch3.md'; unit='round-trips'; tol=0
     anchor='**held**: 203/203 on ten builds (`cue_M8`, `cue_M4`, `cue_M2`, `cue_x4`, `cue_ir`, `cue_stcm`, `cue_ord`, `base_x4`, `cue_S8`, `mf_noroom`)'
     expect=203
     measure={ CueRoundtrip 'cue_stcm' } }

  @{ id='b3-roundtrip-ord'; tier='cue3'; doc='docs/batch3.md'; unit='round-trips'; tol=0
     anchor='**held**: 203/203 on ten builds (`cue_M8`, `cue_M4`, `cue_M2`, `cue_x4`, `cue_ir`, `cue_stcm`, `cue_ord`, `base_x4`, `cue_S8`, `mf_noroom`)'
     expect=203
     measure={ CueRoundtrip 'cue_ord' } }
  # the adopted value, per event, and the substitution invariant at the bottom
  # of the axis: lowering CUE_MINLEN must not make substitutions dearer.
  @{ id='b3-screen-m4-sub'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `cue_M4` | **14.58** | 30.02 | 14.46 | −0.78% | −0.06% |'
     expect=14.58
     measure={ CuePerEvent 'cue_M4' 'sub' 1 } }

  @{ id='b3-screen-m4-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `cue_M4` | **14.58** | 30.02 | 14.46 | −0.78% | −0.06% |'
     expect=30.02
     measure={ CuePerEvent 'cue_M4' 'ind' 1 } }

  @{ id='b3-screen-m2-ind'; tier='cue3'; doc='docs/batch3.md'; unit='bits'; tol=0.005
     anchor='| `cue_M2` | 14.68 | 29.87 | 14.42 | −1.89% | −0.07% |'
     expect=29.87
     measure={ CuePerEvent 'cue_M2' 'ind' 1 } }

  # the fourth corner on the real pair, which is what completes P7
  @{ id='b3-noroom-chm13-pct'; tier='cue3'; doc='docs/batch3.md'; unit='%'; tol=0.0005
     anchor='`mf_noroom` −0.070%, `noroom` −0.007% |'
     expect=-0.007
     measure={ [math]::Round(100.0 * ((CueHuman 'noroom' 'chm13_chr21.fa' 'grch38_chr21.fa' 1) / (CueHuman 'cue' 'chm13_chr21.fa' 'grch38_chr21.fa' 1) - 1.0), 3) } }

  # the negative control: E. coli against ITSELF. The cue is not silent there
  # (that expectation was wrong) -- it is 0.7% smaller, and these rows are what
  # will notice if that ever turns into a cost.
  @{ id='b3-negctl-base'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| v0.8.0 | 1,456 |'
     expect=1456
     measure={ CueSize 'base' (& $F 'ecoli.fa') (& $F 'ecoli.fa') 1 } }

  @{ id='b3-negctl-cue'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| `cue` | 1,454 |'
     expect=1454
     measure={ CueSize 'cue' (& $F 'ecoli.fa') (& $F 'ecoli.fa') 1 } }

  @{ id='b3-negctl-m4'; tier='cue3'; doc='docs/batch3.md'; unit='B'; tol=0
     anchor='| `cue_M4` | **1,446** |'
     expect=1446
     measure={ CueSize 'cue_M4' (& $F 'ecoli.fa') (& $F 'ecoli.fa') 1 } }

  # --- Batch 4: integration and format (docs/batch4.md). The identity rows read
  # scripts/cue/batch4.sh, which builds from the v0.8.0 tag, the pinned 4932ffe
  # and the working tree; the size rows use `rel` and `v08`, the two labels that
  # compile the working tree.

  # P0: before v0.9.0 a cue archive carried v0.8.0's magic, and the unflagged
  # build decoded it to wrong bytes at exit 0. The row is 0 only if BOTH halves
  # of that still reproduce on 4932ffe: exit 0, and output that is not the input.
  @{ id='b4-p0-hazard'; tier='b4'; doc='docs/batch4.md'; unit='exit'; tol=0
     anchor='**the decoder exits 0 and writes wrong'
     expect=0
     measure={ $b = B4Identity; if ($b.p0out -eq 'wrong') { $b.p0exit } else { 99 } } }

  # P1: the run-time cue writes the compiled cue's bytes, but the magic, on five
  # cases for two parameter sets.
  @{ id='b4-p1-identity'; tier='b4'; doc='docs/batch4.md'; unit='pairs'; tol=0
     anchor='**all ten pairs identical but the magic**'
     expect=10
     measure={ (B4Identity).p1 } }

  # P2: the cue switched off writes the v0.8.0 tag's bytes, on seven cases.
  @{ id='b4-p2-v080'; tier='b4'; doc='docs/batch4.md'; unit='cases'; tol=0
     anchor='**all seven archives identical, byte for byte.**'
     expect=7
     measure={ (B4Identity).p2 } }

  # P7: E. coli against itself, both sides round-tripped by batch4.sh.
  @{ id='b4-p7-v080'; tier='b4'; doc='docs/batch4.md'; unit='B'; tol=0
     anchor='**v0.8.0 1,456 B, release 1,446 B**'
     expect=1456
     measure={ (B4Identity).p7old } }

  @{ id='b4-p7-rel'; tier='b4'; doc='docs/batch4.md'; unit='B'; tol=0
     anchor='**v0.8.0 1,456 B, release 1,446 B**'
     expect=1446
     measure={ (B4Identity).p7new } }

  # P5, P6: which decoder accepts which stream, and a state primed by v0.8.0
  @{ id='b4-p5-refusals'; tier='b4'; doc='docs/batch4.md'; unit='refusals'; tol=0
     anchor='**P5 held: all six refusals.**'
     expect=6
     measure={ (B4Identity).p5 } }

  @{ id='b4-p6-v080-state'; tier='b4'; doc='docs/batch4.md'; unit='checks'; tol=0
     anchor='**P6 held, both halves.** A state primed by v0.8.0 itself (`DNACST02`) decodes a'
     expect=2
     measure={ (B4Identity).p6 } }

  # P8: the CURRENT suite, on the three families (each asserts its own rules)
  @{ id='b4-p8-rt-rel'; tier='b4'; doc='docs/batch4.md'; unit='round-trips'; tol=0
     anchor='**229/229 on the release build, 229/229 on the cue switched off,'
     expect=229
     measure={ CueRoundtripExe (CueExe 'rel') } }

  @{ id='b4-p8-rt-v08'; tier='b4'; doc='docs/batch4.md'; unit='round-trips'; tol=0
     anchor='**229/229 on the release build, 229/229 on the cue switched off,'
     expect=229
     measure={ CueRoundtripExe (CueExe 'v08') } }

  @{ id='b4-p8-rt-exp'; tier='b4'; doc='docs/batch4.md'; unit='round-trips'; tol=0
     anchor='229/229 on an experimental build (`-DCUE_MINLEN=16`).**'
     expect=229
     measure={ CueRoundtripExe (CueExe 'exp') } }

  # P3: the release's size on the real pair at its default level
  @{ id='b4-p3-chm13-l1'; tier='b4'; doc='docs/batch4.md'; unit='B'; tol=0
     anchor='CHM13 chr21 against GRCh38 chr21 at level 1, the release build: **563,031 B**,'
     also=@(@{ doc='README.md'; anchor='| FASTA | 1,438,137 B (HRCM) | 547,019 B — **2.63x** | 563,031 B — **2.55x** |' })
     expect=563031
     measure={ CueHuman 'rel' 'chm13_chr21.fa' 'grch38_chr21.fa' 1 } }

  # R1: per event at the release settings, level 3 (the records' level) and 1
  @{ id='b4-r1-v08-ind-l3'; tier='b4'; doc='docs/batch4.md'; unit='bits'; tol=0.005
     anchor='| 3 | v0.8.0 | 14.64 | **48.25** | 31.43 |'
     also=@(@{ doc='README.md'; anchor='| **random indel** | 48.25 bits | **26.90 bits** | −44% |' })
     expect=48.25
     measure={ CuePerEvent 'v08' 'ind' 3 } }

  @{ id='b4-r1-v08-sub-l3'; tier='b4'; doc='docs/batch4.md'; unit='bits'; tol=0.005
     anchor='| 3 | v0.8.0 | 14.64 | **48.25** | 31.43 |'
     also=@(@{ doc='README.md'; anchor='| substitution | 14.64 bits | 14.75 bits |' })
     expect=14.64
     measure={ CuePerEvent 'v08' 'sub' 3 } }

  @{ id='b4-r1-rel-sub-l3'; tier='b4'; doc='docs/batch4.md'; unit='bits'; tol=0.005
     anchor='| 3 | release | 14.75 | **26.90** | **11.60** |'
     also=@(@{ doc='README.md'; anchor='| substitution | 14.64 bits | 14.75 bits |' })
     expect=14.75
     measure={ CuePerEvent 'rel' 'sub' 3 } }

  @{ id='b4-r1-rel-ind-l3'; tier='b4'; doc='docs/batch4.md'; unit='bits'; tol=0.005
     anchor='| 3 | release | 14.75 | **26.90** | **11.60** |'
     also=@(@{ doc='README.md'; anchor='| **random indel** | 48.25 bits | **26.90 bits** | −44% |' }; @{ doc='README.md'; anchor='costs 26.9 bits instead of 48.25' })
     expect=26.90
     measure={ CuePerEvent 'rel' 'ind' 3 } }

  @{ id='b4-r1-rel-hp-l3'; tier='b4'; doc='docs/batch4.md'; unit='bits'; tol=0.005
     anchor='| 3 | release | 14.75 | **26.90** | **11.60** |'
     also=@(@{ doc='README.md'; anchor='| **slip inside a homopolymer** | 31.43 bits | **11.60 bits** | −63% |' })
     expect=11.60
     measure={ CuePerEvent 'rel' 'hp' 3 } }

  @{ id='b4-r1-rel-ind-l1'; tier='b4'; doc='docs/batch4.md'; unit='bits'; tol=0.005
     anchor='| 1 | release | 14.58 | 30.02 | 14.46 |'
     expect=30.02
     measure={ CuePerEvent 'rel' 'ind' 1 } }

  @{ id='b4-r1-osmosis-rel'; tier='b4'; doc='docs/batch4.md'; unit='ratio'; tol=0.0005
     anchor='43%** (ratio 0.571), against 9% without the cue (ratio 0.913)'
     also=@(@{ doc='README.md'; anchor='**a fall of 43%**' })
     expect=0.571
     measure={ (CueHalves 'rel').hp.ratio } }

  @{ id='b4-r1-osmosis-v08'; tier='b4'; doc='docs/batch4.md'; unit='ratio'; tol=0.0005
     anchor='against 9% without the cue (ratio 0.913)'
     also=@(@{ doc='README.md'; anchor='cue the same measurement falls 9%' })
     expect=0.913
     measure={ (CueHalves 'v08').hp.ratio } }

  # R2, R3, and the level-1 default against v0.8.0's level 3
  @{ id='b4-r2-chr21ind-l3'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| `chr21_ind` | 3 | 113,925 | 100,806 | **−11.52%** | −11.52% |'
     also=@(@{ doc='README.md'; anchor='**−11.52%**' })
     expect=-11.52
     measure={ CuePct (CueChr21Ind 'v08' 3) (CueChr21Ind 'rel' 3) } }

  @{ id='b4-r3-chm13-l3'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| CHM13 chr21 | 3 | 586,615 | 547,019 | **−6.75%** | −6.75% |'
     also=@(@{ doc='README.md'; anchor='| whole file | **−6.75%** | **−6.57%** |' })
     expect=-6.75
     measure={ CuePct (CueHuman 'v08' 'chm13_chr21.fa' 'grch38_chr21.fa' 3) (CueHuman 'rel' 'chm13_chr21.fa' 'grch38_chr21.fa' 3) } }

  @{ id='b4-r7-chm13-l1-vs-l3'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| CHM13 chr21 | 1 | 602,170 | 563,031 | −6.50% | **−4.02%** |'
     expect=-4.02
     measure={ CuePct (CueHuman 'v08' 'chm13_chr21.fa' 'grch38_chr21.fa' 3) (CueHuman 'rel' 'chm13_chr21.fa' 'grch38_chr21.fa' 1) } }

  # the loss: the level-1 default on the near-identical bacterial pair
  @{ id='b4-w3110-default-loss'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| W3110 | 1 | 2,130 | 2,121 | −0.42% | **+9.84%** |'
     also=@(@{ doc='README.md'; anchor='| **W3110 vs MG1655** (near-identical) | 1,931 B | **2,121 B — +9.84%** | **1,916 B** |' })
     expect=9.84
     measure={ CuePct (CueReal 'v08' 'w3110' 3) (CueReal 'rel' 'w3110' 1) } }

  # R4, R5: the window split at the release settings (classes fixed by v0.8.0
  # at level 3), and the chr22 file
  @{ id='b4-r4-chr21-shared-l3'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| chr21 | 3 | **−19.36%** | −3.55% | **−0.26%** | −6.85% | −6.75% |'
     also=@(@{ doc='README.md'; anchor='| on *shared* sequence (< 0.2 bits/base) | **−19.36%** | **−16.90%** |' })
     expect=-19.36
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'shared' 'rel' $null 3 } }

  @{ id='b4-r4-chr21-novel-l3'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| chr21 | 3 | **−19.36%** | −3.55% | **−0.26%** | −6.85% | −6.75% |'
     also=@(@{ doc='README.md'; anchor='| on sequence one of them lacks (≥ 1.0) | −0.26% | −0.23% |' })
     expect=-0.26
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'novel' 'rel' $null 3 } }

  @{ id='b4-r4-chr21-shared-l1'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| chr21 | 1 | −18.46% | −3.60% | −0.34% | −6.60% | −6.50% |'
     expect=-18.46
     measure={ CueWindows 'chm13_chr21' 'grch38_chr21' 'shared' 'rel' $null 1 } }

  @{ id='b4-r5-chr22-shared-l3'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| chr22 | 3 | **−16.90%** | −4.51% | **−0.23%** | −6.64% | **−6.57%** |'
     also=@(@{ doc='README.md'; anchor='| on *shared* sequence (< 0.2 bits/base) | **−19.36%** | **−16.90%** |' })
     expect=-16.90
     measure={ CueWindows 'chm13_chr22' 'grch38_chr22' 'shared' 'rel' $null 3 } }

  @{ id='b4-r5-chr22-novel-l3'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| chr22 | 3 | **−16.90%** | −4.51% | **−0.23%** | −6.64% | **−6.57%** |'
     also=@(@{ doc='README.md'; anchor='| on sequence one of them lacks (≥ 1.0) | −0.26% | −0.23% |' })
     expect=-0.23
     measure={ CueWindows 'chm13_chr22' 'grch38_chr22' 'novel' 'rel' $null 3 } }

  @{ id='b4-r5-chr22-file-l3'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| chr22 | 3 | **−16.90%** | −4.51% | **−0.23%** | −6.64% | **−6.57%** |'
     also=@(@{ doc='README.md'; anchor='| whole file | **−6.75%** | **−6.57%** |' })
     expect=-6.57
     measure={ CuePct (CueHuman 'v08' 'chm13_chr22.fa' 'grch38_chr22.fa' 3) (CueHuman 'rel' 'chm13_chr22.fa' 'grch38_chr22.fa' 3) } }

  # R6: the release against the competitor table's plain-ACGT pair, both levels
  # (the FASTA sizes are b4-p3 and b4-r3's; the competitors' own bytes are extern rows)
  @{ id='b4-r6-seq-l3'; tier='b4'; doc='docs/batch4.md'; unit='B'; tol=0
     anchor='| **541,353 B, 1.621x** | **557,497 B, 1.574x** |'
     also=@(@{ doc='README.md'; anchor='| plain ACGT | 877,373 B (GeCo3 hybrid, unverified) | 541,353 B — **1.62x** | 557,497 B — **1.57x** |' })
     expect=541353
     measure={ CueHuman 'rel' 'chm13_chr21.seq' 'grch38_chr21.seq' 3 } }

  @{ id='b4-r6-seq-l1'; tier='b4'; doc='docs/batch4.md'; unit='B'; tol=0
     anchor='| **541,353 B, 1.621x** | **557,497 B, 1.574x** |'
     also=@(@{ doc='README.md'; anchor='| plain ACGT | 877,373 B (GeCo3 hybrid, unverified) | 541,353 B — **1.62x** | 557,497 B — **1.57x** |' })
     expect=557497
     measure={ CueHuman 'rel' 'chm13_chr21.seq' 'grch38_chr21.seq' 1 } }

  @{ id='b4-r6-fa-l3'; tier='b4'; doc='docs/batch4.md'; unit='B'; tol=0
     anchor='| **547,019 B, 2.629x** | **563,031 B, 2.554x** |'
     also=@(@{ doc='README.md'; anchor='| FASTA | 1,438,137 B (HRCM) | 547,019 B — **2.63x** | 563,031 B — **2.55x** |' })
     expect=547019
     measure={ CueHuman 'rel' 'chm13_chr21.fa' 'grch38_chr21.fa' 3 } }

  @{ id='b4-o157-default'; tier='b4'; doc='docs/batch4.md'; unit='%'; tol=0.005
     anchor='| O157 | 1 | 363,532 | 362,862 | −0.18% | **+0.05%** |'
     also=@(@{ doc='README.md'; anchor='| O157:H7 vs MG1655 (diverged) | 362,666 B | 362,862 B — +0.05% | 362,006 B |' })
     expect=0.05
     measure={ CuePct (CueReal 'v08' 'o157' 3) (CueReal 'rel' 'o157' 1) } }

  # The first row of the reference table: the real human pair, and what that
  # chromosome costs with no reference at all (the denominator of the 14.3x).
  @{ id='chm13-alone-bpb'; tier='b4'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='| **CHM13 chr21 (a real second person)** | GRCh38 chr21 | 1.390 | **0.0999** | **0.0971** | 14.3× — 547,019 bytes for a chromosome |'
     expect=1.390
     measure={ Bpb (CueSize 'rel' (Join-Path $cueHuman 'chm13_chr21.fa') $null 3) 45090688 } }

  @{ id='chm13-default-bpb'; tier='b4'; doc='README.md'; unit='bpb'; tol=0.00006
     anchor='| **CHM13 chr21 (a real second person)** | GRCh38 chr21 | 1.390 | **0.0999** | **0.0971** | 14.3× — 547,019 bytes for a chromosome |'
     expect=0.0999
     measure={ Bpb (CueHuman 'rel' 'chm13_chr21.fa' 'grch38_chr21.fa' 1) 45090688 } }

  @{ id='chm13-l3-bpb'; tier='b4'; doc='README.md'; unit='bpb'; tol=0.00006
     anchor='| **CHM13 chr21 (a real second person)** | GRCh38 chr21 | 1.390 | **0.0999** | **0.0971** | 14.3× — 547,019 bytes for a chromosome |'
     expect=0.0971
     measure={ Bpb (CueHuman 'rel' 'chm13_chr21.fa' 'grch38_chr21.fa' 3) 45090688 } }

  # The headline table's other cells. None of them had a row until Batch 5, and
  # the E. coli one was wrong because of it: it printed the plain-ACGT figure in
  # a table whose note said FASTA. Every cell now re-derives.
  @{ id='ecoli-fa-headline-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='| **dnac** (k=22, default)       | **@@CHR21FADEF@@**   | **1.8845** | this project |'
     expect=1.8845
     measure={ Bpb (Size (& $F 'ecoli.fa') $null 3) (Bases (& $F 'ecoli.fa')) } }

  @{ id='ecoli-fa-gzip-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='| gzip `-9`                      | 2.2544      | 2.3769  | barely models DNA |'
     expect=2.3769
     measure={ Bpb (Ext 'gzip' (& $F 'ecoli.fa')) (Bases (& $F 'ecoli.fa')) } }

  @{ id='chr21-fa-gzip-bpb'; tier='slow'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='| gzip `-9`                      | 2.2544      | 2.3769  | barely models DNA |'
     expect=2.2544
     measure={ Bpb (Ext 'gzip' (& $F 'chr21.fa')) (Bases (& $F 'chr21.fa')) } }

  # The margin over GeCo3 reference-free, which two other sentences lean on and
  # which no row defended before Batch 5. It moved with v0.9.0 (0.7% -> 0.85%)
  # because the cue is a small gain in plain mode too.
  @{ id='geco-margin-pct'; tier='extern'; doc='README.md'; unit='%'; tol=0.005
     also=@(@{ doc='README.md'; anchor='the whole margin this project has is 0.85%' })
     anchor='against a 0.85% margin'
     expect=0.85
     measure={
        $d = Bpb (Size (& $S 'chr21.seq') $null 3) (Bases (& $S 'chr21.seq'))
        $g = Bpb (Geco (& $S 'chr21.seq') '-l 14') (Bases (& $S 'chr21.seq'))
        [math]::Round(100.0 * ($g - $d) / $g, 2) } }

  # The three places the cue costs something, named in the README so they are
  # not rounded away. Each is a level or a mode no other row covers.
  @{ id='ecoli-cue-l1-plain-pct'; tier='fast'; doc='README.md'; unit='%'; tol=0.0005
     anchor='**+0.010% on E. coli at level 1**'
     expect=0.010
     measure={
        $b = Size (& $S 'ecoli.seq') $null 1 $null $v08
        $r = Size (& $S 'ecoli.seq') $null 1
        [math]::Round(100.0 * ($r / $b - 1.0), 3) } }

  @{ id='ecoli-cue-j8-pct'; tier='fast'; doc='README.md'; unit='%'; tol=0.0005
     anchor='**+0.013% at `-j 8`**'
     expect=0.013
     measure={
        $b = Size (& $S 'ecoli.seq') $null 3 8 $v08
        $r = Size (& $S 'ecoli.seq') $null 3 8
        [math]::Round(100.0 * ($r / $b - 1.0), 3) } }

  @{ id='w3110-seq-cue-loss-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='1,060** on the plain-ACGT W3110 pair at level 3'
     expect=3
     measure={ (Size (& $S 'w3110.seq') (& $S 'ecoli.seq') 3) - (Size (& $S 'w3110.seq') (& $S 'ecoli.seq') 3 $null $v08) } }

  # The chr21 block table's other three rows. They were published without a row
  # until Batch 5, like the headline table's E. coli cell.
  @{ id='chr21-j2-bytes'; tier='slow'; doc='README.md'; unit='B'; tol=0
     anchor='| 2 | 7,687,850 |'
     expect=7687850
     measure={ Size (& $S 'chr21.seq') $null 3 2 } }

  @{ id='chr21-j4-bytes'; tier='slow'; doc='README.md'; unit='B'; tol=0
     anchor='| 4 | 7,732,528 |'
     expect=7732528
     measure={ Size (& $S 'chr21.seq') $null 3 4 } }

  @{ id='chr21-j16-bytes'; tier='slow'; doc='README.md'; unit='B'; tol=0
     anchor='| 16 | 7,907,062 |'
     expect=7907062
     measure={ Size (& $S 'chr21.seq') $null 3 16 } }

  # --- Batch 5: the figures the v0.9.0 README added -------------------------
  # Every one of these is measured by the RELEASE build ($dnac), which is what a
  # reader of the README would build. The rows that state a comparison with
  # v0.8.0 pass $v08 for that side and say so.

  @{ id='ecoli-j1-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| 1 (default) | 1,092,635 | — |'
     expect=1092635
     measure={ Size (& $S 'ecoli.seq') $null 3 } }

  @{ id='ecoli-ind-alone-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='| E. coli, simulated individual | E. coli MG1655 | 1.886 |'
     expect=1.886
     measure={ Bpb (Size (& $F 'ecoli_ind.fa') $null 3) (Bases (& $F 'ecoli_ind.fa')) } }

  @{ id='o157-alone-bpb'; tier='fast'; doc='README.md'; unit='bpb'; tol=0.0006
     anchor='| E. coli O157:H7 (real, diverged strain) | E. coli MG1655 | 1.812 |'
     expect=1.812
     measure={ Bpb (Size (& $F 'o157.fa') $null 3) (Bases (& $F 'o157.fa')) } }

  # The loss the release ships with, in the units the README states it in.
  @{ id='w3110-fa-default-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| **W3110 vs MG1655** (near-identical) | 1,931 B | **2,121 B — +9.84%** | **1,916 B** |'
     expect=2121
     measure={ Size (& $F 'w3110.fa') (& $F 'ecoli.fa') 1 } }

  @{ id='w3110-fa-v08-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| **W3110 vs MG1655** (near-identical) | 1,931 B | **2,121 B — +9.84%** | **1,916 B** |'
     expect=1931
     measure={ Size (& $F 'w3110.fa') (& $F 'ecoli.fa') 3 $null $v08 } }

  @{ id='o157-fa-default-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged) | 362,666 B | 362,862 B — +0.05% | 362,006 B |'
     expect=362862
     measure={ Size (& $F 'o157.fa') (& $F 'ecoli.fa') 1 } }

  @{ id='o157-fa-v08-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged) | 362,666 B | 362,862 B — +0.05% | 362,006 B |'
     expect=362666
     measure={ Size (& $F 'o157.fa') (& $F 'ecoli.fa') 3 $null $v08 } }

  @{ id='w3110-seq-default-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| W3110 vs MG1655 (near-identical strains) | 1,280 B | **1,063 B** | 1,404 B | 1,319 B |'
     expect=1280
     measure={ Size (& $S 'w3110.seq') (& $S 'ecoli.seq') 1 } }

  @{ id='o157-seq-default-bytes'; tier='fast'; doc='README.md'; unit='B'; tol=0
     anchor='| O157:H7 vs MG1655 (diverged strains) | 361,611 B | **360,752 B** | 431,652 B | 365,401 B |'
     expect=361611
     measure={ Size (& $S 'o157.seq') (& $S 'ecoli.seq') 1 } }

  # What the cue is worth on the two bacterial pairs, stated as percentages in
  # the cue section.
  @{ id='ecoliind-cue-pct'; tier='fast'; doc='README.md'; unit='%'; tol=0.005
     anchor='a simulated E. coli individual −4.21%'
     expect=-4.21
     measure={ CuePct (Size (& $F 'ecoli_ind.fa') (& $F 'ecoli.fa') 3 $null $v08) (Size (& $F 'ecoli_ind.fa') (& $F 'ecoli.fa') 3) } }

  @{ id='o157-cue-pct'; tier='fast'; doc='README.md'; unit='%'; tol=0.005
     anchor='the diverged O157:H7 pair −0.18%'
     expect=-0.18
     measure={ CuePct (Size (& $F 'o157.fa') (& $F 'ecoli.fa') 3 $null $v08) (Size (& $F 'o157.fa') (& $F 'ecoli.fa') 3) } }

  # Reference-free the cue is worth almost nothing, which is a README claim and
  # therefore executed like any other. Three decimals: two would round the
  # E. coli figure to zero and hide its sign.
  @{ id='ecoli-cue-plain-pct'; tier='fast'; doc='README.md'; unit='%'; tol=0.0005
     anchor='−0.005% on'
     expect=-0.005
     measure={
        $b = Size (& $S 'ecoli.seq') $null 3 $null $v08
        $r = Size (& $S 'ecoli.seq') $null 3
        [math]::Round(100.0 * ($r / $b - 1.0), 3) } }

  # --- W: the experiment that settled the default (docs/batch5.md) ----------
  # The gradient target is derived here, by the release build, from the same
  # reference and seed the document names, so the row re-derives the INPUT as
  # well as the number and a changed `mut` cannot pass unnoticed.
  @{ id='w5-mut005-penalty-bytes'; tier='b5'; doc='README.md'; unit='B'; tol=0
     also=@(@{ doc='docs/batch5.md'; anchor='| `mut` 0.05 ‰ | 2,018 | 2,013 | **−5 B** | **−0.25%** | 232 | 23 |' })
     anchor='**level 1 is 5 bytes smaller, where W3110'
     expect=-5
     measure={ MutPenalty '0.05' 'bytes' } }

  @{ id='w5-mut50-penalty-pct'; tier='b5'; doc='README.md'; unit='%'; tol=0.005
     also=@(@{ doc='docs/batch5.md'; anchor='| `mut` 5.0 ‰ | 42,933 | 43,710 | 777 B | +1.81% | 23,208 | 2,320 |' })
     anchor='−0.25%, +0.74%, +1.21% and +1.81%'
     expect=1.81
     measure={ MutPenalty '5.0' 'pct' } }

  @{ id='w5-w3110-penalty-bytes'; tier='b5'; doc='README.md'; unit='B'; tol=0
     also=@(@{ doc='docs/batch5.md'; anchor='| **W3110** | 1,916 | 2,121 | **205 B** | **+10.70%** | | |' })
     anchor='**level 1 is 5 bytes smaller, where W3110'
     expect=205
     measure={ (Size (& $F 'w3110.fa') (& $F 'ecoli.fa') 1) - (Size (& $F 'w3110.fa') (& $F 'ecoli.fa') 3) } }

  # W5: the whole gap is the mixer's expert count. An experimental build, which
  # marks its own archives, so it can never be confused with the release.
  @{ id='w5-x4-w3110-bytes'; tier='b5'; doc='README.md'; unit='B'; tol=0
     also=@(@{ doc='docs/batch5.md'; anchor='| **four mixer experts (`L1_NMIX=4`)** | **1,907** | **104%** |' })
     anchor='W3110 2,121 → 1,907 B; a simulated E. coli individual 12,204 → 12,051 B,'
     expect=1907
     measure={ Size (& $F 'w3110.fa') (& $F 'ecoli.fa') 1 $null (CueExe 'rel_x4') } }

  @{ id='w5-x4-ecoliind-bytes'; tier='b5'; doc='README.md'; unit='B'; tol=0
     also=@(@{ doc='docs/batch5.md'; anchor='| `ecoli_ind` (simulated individual) | 12,204 | **12,051** | 12,051 |' })
     anchor='W3110 2,121 → 1,907 B; a simulated E. coli individual 12,204 → 12,051 B,'
     expect=12051
     measure={ Size (& $F 'ecoli_ind.fa') (& $F 'ecoli.fa') 1 $null (CueExe 'rel_x4') } }

  # The per-mode default itself: what the CLI picks when the user says nothing.
  # Nothing else here can see it, because every other row names a level.
  @{ id='default-level-plain'; tier='fast'; doc='README.md'; unit='level'; tol=0
     anchor='**Since v0.9.0 the default is per mode: level 3 without a reference, level 1'
     expect=3
     measure={ DefaultLevel $null } }

  @{ id='default-level-ref'; tier='fast'; doc='README.md'; unit='level'; tol=0
     anchor='**Since v0.9.0 the default is per mode: level 3 without a reference, level 1'
     expect=1
     measure={ DefaultLevel (& $F 'ecoli.fa') } }
)

# --- runner -------------------------------------------------------------------

# A claim may be stated in more than one document -- the release figures live in
# docs/batch4.md as the record of the run that produced them AND in README.md as
# what the codec does now. Re-measuring them twice would double the cost of the
# most expensive tier for no extra information, so a row carries an optional
# `also` list of @{doc; anchor}: the same measured value, held against a second
# sentence in a second file. Every one of them has to match, so editing either
# copy by hand turns the claim red. The self-test breaks this path too.
function Check-Anchor($c) {
    foreach ($a in @(@{ doc=$c.doc; anchor=$c.anchor }) + @($c.also | Where-Object { $_ })) {
        $p = Join-Path $root $a.doc
        if (-not (Test-Path $p)) { return @{ ok=$false; why="doc '$($a.doc)' not found" } }
        if (-not (Get-Content $p -Raw).Contains($a.anchor)) {
            return @{ ok=$false; why="anchor text is no longer in $($a.doc): '$($a.anchor)'" }
        }
    }
    @{ ok=$true }
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

    # Batch 5 let one row hold its value against a SECOND document (`also`), so
    # the release figures are anchored in README.md as well as in the record that
    # produced them. A detector nobody has watched go red is decoration, so the
    # second anchor is broken here exactly like the first.
    $fakeAlso = @{ id='selftest-also'; tier='fast'; doc='README.md'; unit='B'; tol=0
                   anchor='# dnac'; expect=1; measure={ 1 }
                   also=@(@{ doc='docs/batch4.md'; anchor='THIS SENTENCE IS NOT IN BATCH 4' }) }
    $r4 = Run-Claim $fakeAlso
    if ($r4.status -ne 'ANCHOR') { throw "SELF-TEST FAILED: a missing SECOND anchor was not detected (got '$($r4.status)')" }

    Write-Host "self-test: ANCHOR, DRIFT, ERROR and the second anchor all detected (4/4)`n" -ForegroundColor Green
    # The cue rows brought four new ways to be wrong that the three detectors
    # above cannot see, because all three assume the MEASUREMENT is of what it
    # says it is. Each is broken here on purpose. Only when a cue tier is
    # actually going to run: these compile and compress, unlike the three above.
    if ($Tier -in @('cue','cue3','b4','b5','slow','all')) {
        Write-Host "self-test: the cue machinery" -ForegroundColor Cyan

        # 1. An unknown build label must stop the run, not quietly measure the
        #    default build and report its number against someone else's claim.
        $r4 = Run-Claim @{ id='selftest-cue-label'; tier='cue'; doc='README.md'; unit='B'; tol=0
                           anchor='# dnac'; expect=1; measure={ CueExe 'no-such-build' } }
        if ($r4.status -ne 'ERROR') { throw "SELF-TEST FAILED: an unknown build label was accepted (got '$($r4.status)')" }

        # 2. THE ONE THAT MATTERS. Every figure on this branch is a comparison
        #    between two builds of one source file. If the flag never reaches the
        #    compiler -- a typo in CueDefs, a Makefile that ignores it, a cached
        #    binary -- both sides are the same build, every difference is zero,
        #    and nothing else here would notice: the anchors still match, the
        #    recipes still run, and the numbers are all "unchanged", which is
        #    exactly what a failed experiment also looks like.
        #    Since v0.9.0 this is also what guards the PIN: the working tree has
        #    no -DDNAC_CUE, so if the records' labels ever compiled it instead of
        #    4932ffe, `base` and `cue` would both be the release build and this
        #    would go red. The same question for v0.9.0's own two labels: the
        #    run-time switch must actually switch.
        $ctlBase = CueTarget 'base' 'ctl'
        $ctlCue  = CueTarget 'cue'  'ctl'
        if ($ctlBase -eq $ctlCue) {
            throw "SELF-TEST FAILED: -DDNAC_CUE produced the same archive as the unflagged build ($ctlBase B). Either the flag is not reaching the compiler or the records are no longer compiled from $($script:PinnedRev), so every cue figure below is a build compared with itself."
        }
        Write-Host "  the cue flag changes the output ($ctlBase -> $ctlCue B on the control)" -ForegroundColor Gray
        $ctlV08 = CueTarget 'v08' 'ctl'
        $ctlRel = CueTarget 'rel' 'ctl'
        if ($ctlV08 -eq $ctlRel) {
            throw "SELF-TEST FAILED: the release build and the cue-off build wrote the same archive ($ctlRel B): the run-time switch is not switching."
        }
        if ($ctlV08 -ne $ctlBase) {
            throw "SELF-TEST FAILED: the cue-off build of the working tree ($ctlV08 B) is not v0.8.0 ($ctlBase B, from $($script:PinnedRev))."
        }
        Write-Host "  the run-time switch changes the output ($ctlV08 -> $ctlRel B), and off it is v0.8.0" -ForegroundColor Gray

        # 3. A wrong value on a REAL cue measurement (free: both sizes are memoised).
        $r5 = Run-Claim @{ id='selftest-cue-value'; tier='cue'; doc='README.md'; unit='B'; tol=0
                           anchor='# dnac'; expect=1; measure={ CueTarget 'base' 'ctl' } }
        if ($r5.status -ne 'DRIFT') { throw "SELF-TEST FAILED: a wrong cue value was not detected (got '$($r5.status)')" }

        # 4. The round-trip rows report a COUNT parsed out of another script's
        #    output. A parser that returns 203 whatever happened would make the
        #    one claim that must never be wrong unfalsifiable, so it is fed
        #    something that is not a codec at all.
        $notACodec = Join-Path $cueWork 'not-a-codec.exe'
        New-Item -ItemType Directory -Force $cueWork | Out-Null
        Set-Content -Path $notACodec -Value 'this is not a program' -Encoding ascii
        $r6 = Run-Claim @{ id='selftest-cue-roundtrip'; tier='cue'; doc='README.md'; unit='round-trips'; tol=0
                           anchor='# dnac'; expect=203; measure={ CueRoundtripExe $notACodec }.GetNewClosure() }
        Remove-Item $notACodec -Force -ErrorAction SilentlyContinue
        if ($r6.status -eq 'OK') { throw "SELF-TEST FAILED: roundtrip.sh reported 203/203 for a file that is not a codec" }

        # 5. The build-flag table exists twice -- here (CueDefs) and in
        #    scripts/cue/common.sh, which the shell scripts use. Two copies that
        #    quietly disagree would mean the published figures and the scripts
        #    that produced them measured different builds. They are compared.
        $sh = Resolve-Sh
        if (-not $sh) {
            Write-Host "  NOTE: no POSIX sh found, so CueDefs was NOT compared against scripts/cue/common.sh" -ForegroundColor Yellow
        } else {
            foreach ($lbl in @('rel','v08','exp','base','cue','noroom','mf','mf_noroom','cue2','nudge','L6D12','L8D4',
                               'cue_L2','cue_D6','cue_S8','cue_M8','cue_M4','cue_M2','cue_M24',
                               'cue_x4','cue_ir','cue_stcm','cue_ord','base_x4')) {
                $mine  = ((CueDefs $lbl) -join ' ').Trim()
                $their = (& $sh (Join-Path $root 'scripts/cue/defines.sh') $lbl 2>&1 | Out-String).Trim()
                if ($mine -ne $their) {
                    throw "SELF-TEST FAILED: build '$lbl' is '$mine' here and '$their' in scripts/cue/common.sh"
                }
            }
            Write-Host "  the build-flag table agrees with scripts/cue/common.sh (24 labels)" -ForegroundColor Gray
        }

        Write-Host "self-test: unknown build, silent flag, wrong value, a fake codec and a drifting flag table all detected (5/5)`n" -ForegroundColor Green
    }
}

# @() is load-bearing: a single hashtable's .Count is its KEY count, so an
# unwrapped one-claim selection reported "verifying 8 claim(s)".
# -Only takes a wildcard, so a batch's own rows can be run in ONE process --
# which matters because sizes are memoised per run: "-Only rf-*" measures each
# file once and lets ten rows read it, where ten separate -Only runs would
# measure it ten times.
$sel = @($claims | Where-Object { ($Tier -eq 'all' -or $_.tier -eq $Tier) -and (-not $Only -or $_.id -like $Only) })
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
