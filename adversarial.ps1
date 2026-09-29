# adversarial.ps1 - losslessness proof on nasty inputs.
# Every file x every k must roundtrip SHA-256 identical.
# Usage: ./adversarial.ps1 -Exe .\dnac.exe
param([string]$Exe = ".\dnac.exe")
$ErrorActionPreference = "Stop"
$dir = Join-Path ([System.IO.Path]::GetTempPath()) "dnac_adv"
New-Item -ItemType Directory -Force $dir | Out-Null

function W($name, [byte[]]$bytes) {
    $p = Join-Path $dir $name; [System.IO.File]::WriteAllBytes($p, $bytes); return $p
}
$rnd = [System.Random]::new(7)
$files = @()
$files += W "empty.bin"        (New-Object byte[] 0)
$files += W "one_base.fa"      ([System.Text.Encoding]::ASCII.GetBytes("A"))
$files += W "all_bytes.bin"    ([byte[]](0..255))
$files += W "newlines.txt"     ([System.Text.Encoding]::ASCII.GetBytes(("`n" * 5000)))
$files += W "messy.fa"         ([System.Text.Encoding]::ASCII.GetBytes(
    ">chr test`r`nACGTNNNNacgtACGT`r`nNNNNNNNNNNNN`r`nacgtacgtACGTACGT`r`n" * 500))
$b = New-Object byte[] 200000; $rnd.NextBytes($b)
$files += W "random.bin"       $b
$dna = -join (1..200000 | ForEach-Object { "ACGT"[$rnd.Next(0,4)] })
$files += W "random_dna.fa"    ([System.Text.Encoding]::ASCII.GetBytes($dna))
$files += W "repetitive.fa"    ([System.Text.Encoding]::ASCII.GetBytes(("ACGTTGCAAGGCCTTA" * 12500)))
# inverted repeat: a block followed by its reverse complement
$blk = -join (1..100000 | ForEach-Object { "ACGT"[$rnd.Next(0,4)] })
$comp = @{ 'A'='T'; 'C'='G'; 'G'='C'; 'T'='A' }
$rc = -join ($blk.ToCharArray() | ForEach-Object { $comp[$_] })[-1..-($blk.Length)]
$files += W "inverted.fa"      ([System.Text.Encoding]::ASCII.GetBytes($blk + $rc))
# diverged repeat: a block plus a 10%-mutated copy
$mut = $blk.ToCharArray()
for ($i = 0; $i -lt $mut.Length; $i++) { if ($rnd.Next(0,10) -eq 0) { $mut[$i] = "ACGT"[$rnd.Next(0,4)] } }
$files += W "diverged.fa"      ([System.Text.Encoding]::ASCII.GetBytes($blk + (-join $mut)))

$fail = 0; $n = 0
foreach ($f in $files) {
    foreach ($k in @(1, 2, 8, 16, 22, 28)) {
        $c = "$f.$k.dnac"; $r = "$f.$k.rt"
        & $Exe c $f $c $k | Out-Null
        & $Exe d $c $r    | Out-Null
        $h1 = (Get-FileHash $f -Algorithm SHA256).Hash
        $h2 = (Get-FileHash $r -Algorithm SHA256).Hash
        $n++
        if ($h1 -ne $h2) { $fail++; Write-Host ("FAIL {0} k={1}" -f (Split-Path $f -Leaf), $k) -ForegroundColor Red }
        Remove-Item $c, $r -Force
    }
}
# --- compression levels: each level builds a different model set, so each one ---
# --- is a distinct codec and needs its own proof. The decoder gets no hint. -----
foreach ($f in $files) {
    foreach ($lvl in @(1, 2, 3, 4)) {
        $c = "$f.l$lvl.dnac"; $r = "$f.l$lvl.rt"
        & $Exe c $f $c 22 $lvl | Out-Null
        & $Exe d $c $r         | Out-Null
        $h1 = (Get-FileHash $f -Algorithm SHA256).Hash
        $h2 = (Get-FileHash $r -Algorithm SHA256).Hash
        $n++
        if ($h1 -ne $h2) { $fail++; Write-Host ("FAIL {0} level={1}" -f (Split-Path $f -Leaf), $lvl) -ForegroundColor Red }
        Remove-Item $c, $r -Force
    }
}

# --- reference mode: same files, compressed against a reference -----------------
# Covers: unrelated reference, reference shorter/longer than the target, a target
# that IS the reference, and refusing to decompress with the wrong reference.
$refs = @()
$refs += W "ref_small.fa"  ([System.Text.Encoding]::ASCII.GetBytes((">r`n" + ("ACGTTGCAAGGCCTTA" * 100) + "`n")))
$refs += W "ref_messy.fa"  ([System.Text.Encoding]::ASCII.GetBytes(">r desc`nacgtNNNNACGT`r`n" * 200))
$refs += W "ref_dna.fa"    ([System.Text.Encoding]::ASCII.GetBytes($blk))

foreach ($f in $files) {
    foreach ($ref in $refs) {
        $c = "$f.r.dnac"; $r = "$f.r.rt"
        & $Exe cr $f $c $ref 16 | Out-Null
        & $Exe dr $c $r $ref    | Out-Null
        $h1 = (Get-FileHash $f -Algorithm SHA256).Hash
        $h2 = if (Test-Path $r) { (Get-FileHash $r -Algorithm SHA256).Hash } else { "MISSING" }
        $n++
        if ($h1 -ne $h2) { $fail++; Write-Host ("FAIL ref {0} / {1}" -f (Split-Path $f -Leaf), (Split-Path $ref -Leaf)) -ForegroundColor Red }
        Remove-Item $c, $r -Force -ErrorAction SilentlyContinue
    }
}
# --- primed state files: must be interchangeable with the FASTA they came from --
$state = Join-Path $dir "ref_dna.state"
& $Exe prime $refs[2] $state 16 | Out-Null
foreach ($f in $files) {
    # compress with the FASTA, decompress with the state -- and the other way round
    foreach ($pair in @(@($refs[2], $state), @($state, $refs[2]))) {
        $c = "$f.s.dnac"; $r = "$f.s.rt"
        & $Exe cr $f $c $pair[0] 16 | Out-Null
        & $Exe dr $c $r $pair[1]    | Out-Null
        $h1 = (Get-FileHash $f -Algorithm SHA256).Hash
        $h2 = if (Test-Path $r) { (Get-FileHash $r -Algorithm SHA256).Hash } else { "MISSING" }
        $n++
        if ($h1 -ne $h2) { $fail++; Write-Host ("FAIL state {0}" -f (Split-Path $f -Leaf)) -ForegroundColor Red }
        Remove-Item $c, $r -Force -ErrorAction SilentlyContinue
    }
}
# a state and its FASTA must produce the SAME compressed bytes
$c1 = Join-Path $dir "eq_fa.dnac"; $c2 = Join-Path $dir "eq_st.dnac"
& $Exe cr $files[-1] $c1 $refs[2] 16 | Out-Null
& $Exe cr $files[-1] $c2 $state    16 | Out-Null
$n++
if ((Get-FileHash $c1 -Algorithm SHA256).Hash -ne (Get-FileHash $c2 -Algorithm SHA256).Hash) {
    $fail++; Write-Host "FAIL: state-primed stream differs from FASTA-primed" -ForegroundColor Red
}
Remove-Item $c1, $c2, $state -Force -ErrorAction SilentlyContinue

# the wrong reference must be REFUSED, not silently decoded
$c = Join-Path $dir "wrongref.dnac"; $r = Join-Path $dir "wrongref.rt"
& $Exe cr $files[-1] $c $refs[0] 16 | Out-Null
& $Exe dr $c $r $refs[1] 2>$null | Out-Null
$n++
if ($LASTEXITCODE -eq 0) { $fail++; Write-Host "FAIL: wrong reference was accepted" -ForegroundColor Red }
Remove-Item $c, $r -Force -ErrorAction SilentlyContinue

# a state file from an OLDER dnac must be refused, not scraped as if it were a
# FASTA. Dispatch matches the "DNACST" prefix precisely so this cannot go quiet.
$old = Join-Path $dir "old.state"
$junk = New-Object byte[] 4096; $rnd.NextBytes($junk)
[System.IO.File]::WriteAllBytes($old,
    [byte[]](([System.Text.Encoding]::ASCII.GetBytes("DNACST01")) + $junk))
$c = Join-Path $dir "old.dnac"
& $Exe cr $files[-1] $c $old 16 2>$null | Out-Null
$n++
if ($LASTEXITCODE -eq 0) { $fail++; Write-Host "FAIL: a v0.1.x state file was accepted" -ForegroundColor Red }
Remove-Item $old, $c -Force -ErrorAction SilentlyContinue

# a v0.2.x stream carried no table geometry, so no build can know how to size its
# models. It must be refused by magic, not decoded into wrong bytes.
$v02 = Join-Path $dir "v02.dnac"
$j2 = New-Object byte[] 64; $rnd.NextBytes($j2)
[System.IO.File]::WriteAllBytes($v02,
    [byte[]](([System.Text.Encoding]::ASCII.GetBytes("DNCB")) + $j2))
& $Exe d $v02 (Join-Path $dir "v02.out") 2>$null | Out-Null
$n++
if ($LASTEXITCODE -eq 0) { $fail++; Write-Host "FAIL: a v0.2.x stream was accepted" -ForegroundColor Red }
Remove-Item $v02, (Join-Path $dir "v02.out") -Force -ErrorAction SilentlyContinue

# -map is a diagnostic, not part of the format: the same input must compress to
# byte-identical bytes with and without it. Nothing else in this file can catch a
# flag that quietly perturbs the coder, because every other case runs one binary
# with one set of arguments -- the same blind spot that hid three earlier bugs.
$m1 = Join-Path $dir "map_off.dnac"; $m2 = Join-Path $dir "map_on.dnac"
$mt = Join-Path $dir "map.tsv"
& $Exe c $files[-1] $m1 16 | Out-Null
& $Exe c $files[-1] $m2 16 -map $mt | Out-Null
$n++
if ((Get-FileHash $m1 -Algorithm SHA256).Hash -ne (Get-FileHash $m2 -Algorithm SHA256).Hash) {
    $fail++; Write-Host "FAIL: -map changed the compressed bytes" -ForegroundColor Red
}
Remove-Item $m1, $m2, $mt -Force -ErrorAction SilentlyContinue

# --- the case list (v0.10.0): lowercase a/c/g/t outside a '>' line is coded as ---
# --- its uppercase twin plus a list of run lengths (docs/case-list.md). ----------
$lines = for ($i = 0; $i -lt 400; $i++) { $dna.Substring($i * 60, 60) }
$mix = ">soft masked test`n" + (($lines | ForEach-Object -Begin { $j = 0 } -Process {
    $j++; if ($j % 4 -eq 2) { $_.ToLower() } elseif ($j % 4 -eq 3) { $_.Substring(0, 20).ToLower() + $_.Substring(20) } else { $_ } }) -join "`n") + "`n"
$cases = @()
$cases += W "case_mix.fa"   ([System.Text.Encoding]::ASCII.GetBytes($mix))
$cases += W "case_lower.fa" ([System.Text.Encoding]::ASCII.GetBytes(">all lower`n" + $dna.Substring(0, 30000).ToLower() + "`n"))
$cases += W "case_n.fa"     ([System.Text.Encoding]::ASCII.GetBytes(">x`nACGTnnnnNNNNacgtNnNn`r`nacgtacgtACGT`r`n"))
foreach ($f in $cases) {
    foreach ($a in @(@("22"), @("22", "1"), @("22", "4"), @("16", "-j", "3"))) {
        $c = "$f.cl.dnac"; $r = "$f.cl.rt"
        & $Exe c $f $c @a | Out-Null
        & $Exe d $c $r    | Out-Null
        $h1 = (Get-FileHash $f -Algorithm SHA256).Hash
        $h2 = if (Test-Path $r) { (Get-FileHash $r -Algorithm SHA256).Hash } else { "MISSING" }
        $n++
        if ($h1 -ne $h2) { $fail++; Write-Host ("FAIL case {0} {1}" -f (Split-Path $f -Leaf), ($a -join " ")) -ForegroundColor Red }
        Remove-Item $c, $r -Force -ErrorAction SilentlyContinue
    }
}
# lowercase only in a header is NOT a case file: same letter as an uppercase file;
# a case file gets a different one
$hdr = W "case_hdr.fa" ([System.Text.Encoding]::ASCII.GetBytes(">lowercase header acgt`n" + $dna.Substring(0, 3000) + "`n"))
$cu = Join-Path $dir "cu.dnac"; $ch = Join-Path $dir "ch.dnac"; $cm = Join-Path $dir "cm.dnac"
& $Exe c $files[-1] $cu | Out-Null; & $Exe c $hdr $ch | Out-Null; & $Exe c $cases[0] $cm | Out-Null
$lu = [System.IO.File]::ReadAllBytes($cu)[3]; $lh = [System.IO.File]::ReadAllBytes($ch)[3]; $lm = [System.IO.File]::ReadAllBytes($cm)[3]
$n++; if ($lh -ne $lu) { $fail++; Write-Host "FAIL: header-only lowercase changed the stream family" -ForegroundColor Red }
$n++; if ($lm -eq $lu) { $fail++; Write-Host "FAIL: a case file was written in the uppercase family" -ForegroundColor Red }
Remove-Item $cu, $ch, $cm -Force -ErrorAction SilentlyContinue

# --- the codon tracker (docs/codon-impl-prediction.md): a gene-like file whose ----
# --- gate opens is coded with it at level 1 (default) or with -codon at 2-4. -------
# The generator is scripts/genes.awk, ported: same integer LCG, same output bytes.
function Genes([int]$seed, [int]$genes, [int]$bias, [int]$junk) {
    $script:gx = [double]($seed + 1)
    function PmR([int]$m) { $script:gx = ($script:gx * 16807) % 2147483647; return [int][math]::Floor($script:gx / 2147483647 * $m) }
    function Rnd([int]$len) { $sb = [System.Text.StringBuilder]::new(); for ($i = 0; $i -lt $len; $i++) { [void]$sb.Append("ACGT"[(PmR 4)]) }; $sb.ToString() }
    $fav = "GCG CTG AAA GAA ATT GGC CGT ACC GAT CAG AAC GTG TTC CCG TAT CAT TGG AGC ATG TGC".Split(" ")
    $seq = [System.Text.StringBuilder]::new()
    for ($g = 0; $g -lt $genes; $g++) {
        $s = [System.Text.StringBuilder]::new("ATG")
        for ($c = 0; $c -lt 300; $c++) {
            if ((PmR 100) -lt $bias) { [void]$s.Append($fav[(PmR 20)]) }
            else { do { $cd = "" + "ACGT"[(PmR 4)] + "ACGT"[(PmR 4)] + "ACGT"[(PmR 4)] } while ($cd -eq "TAA" -or $cd -eq "TAG" -or $cd -eq "TGA"); [void]$s.Append($cd) }
        }
        [void]$s.Append("TAA"); $gs = $s.ToString()
        if ((PmR 1000) -lt $junk) { $gs = Rnd $gs.Length }
        if ((PmR 2) -eq 1) { $a = $gs.ToCharArray(); [array]::Reverse($a)
            $gs = -join ($a | ForEach-Object { switch ($_) { 'A' {'T'} 'T' {'A'} 'C' {'G'} default {'C'} } }) }
        [void]$seq.Append((Rnd 100)); [void]$seq.Append($gs)
    }
    $all = $seq.ToString()
    $out = [System.Text.StringBuilder]::new(">synthetic gene-like genome seed=$seed junk=$junk`n")
    for ($i = 0; $i -lt $all.Length; $i += 60) { [void]$out.Append($all.Substring($i, [math]::Min(60, $all.Length - $i))).Append("`n") }
    [System.Text.Encoding]::ASCII.GetBytes($out.ToString())
}
$gon = W "g_on.fa" (Genes 1 300 97 0)
$gbelow = W "g_below.fa" (Genes 2 300 97 300)
foreach ($a in @(@("22"), @("22", "1"), @("22", "3", "-codon"), @("16", "1", "-j", "3"))) {
    $c = "$gon.cd.dnac"; $r = "$gon.cd.rt"
    & $Exe c $gon $c @a | Out-Null
    & $Exe d $c $r      | Out-Null
    $h1 = (Get-FileHash $gon -Algorithm SHA256).Hash
    $h2 = if (Test-Path $r) { (Get-FileHash $r -Algorithm SHA256).Hash } else { "MISSING" }
    $n++
    if ($h1 -ne $h2) { $fail++; Write-Host ("FAIL codon g_on.fa {0}" -f ($a -join " ")) -ForegroundColor Red }
    Remove-Item $c, $r -Force -ErrorAction SilentlyContinue
}
$c1 = Join-Path $dir "c1.dnac"; $c3 = Join-Path $dir "c3.dnac"; $cn = Join-Path $dir "cn.dnac"
& $Exe c $gon $c1 22 1 | Out-Null; & $Exe c $gon $c3 22 3 | Out-Null; & $Exe c $gon $cn 22 1 -nocodon | Out-Null
$l1 = [System.IO.File]::ReadAllBytes($c1)[3]; $l3 = [System.IO.File]::ReadAllBytes($c3)[3]; $ln = [System.IO.File]::ReadAllBytes($cn)[3]
$n++; if ($l1 -eq $l3) { $fail++; Write-Host "FAIL: a codon stream was written in the plain family" -ForegroundColor Red }
$n++; if ($ln -ne $l3) { $fail++; Write-Host "FAIL: -nocodon at level 1 did not write the plain family" -ForegroundColor Red }
& $Exe c $gbelow $c1 22 3 | Out-Null; & $Exe c $gbelow $c3 22 3 -codon | Out-Null
$n++; if ((Get-FileHash $c1).Hash -ne (Get-FileHash $c3).Hash) { $fail++; Write-Host "FAIL: -codon changed a file whose gate is shut" -ForegroundColor Red }
Remove-Item $c1, $c3, $cn -Force -ErrorAction SilentlyContinue

# --- truncation (v0.11.0, docs/truncation-prediction.md): a stream cut inside its --
# --- coded body is refused and leaves no output file (it used to decode to wrong --
# --- bytes at exit 0). --------------------------------------------------------------
$cutcases = @(@{ f = $files[-1]; a = @("22") }, @{ f = $gon; a = @("22", "1") }, @{ f = $files[-1]; a = @("16", "-j", "3") })
foreach ($t in $cutcases) {
    $src = $t.f; $a = $t.a
    $c = Join-Path $dir "tc.dnac"; $cut = Join-Path $dir "tcut.dnac"; $o = Join-Path $dir "tcut.out"
    & $Exe c $src $c @a | Out-Null
    $bytes = [System.IO.File]::ReadAllBytes($c)
    foreach ($len in @([int]($bytes.Length / 2), ($bytes.Length - 1))) {
        [System.IO.File]::WriteAllBytes($cut, $bytes[0..($len - 1)])
        Remove-Item $o -Force -ErrorAction SilentlyContinue
        & $Exe d $cut $o 2>$null | Out-Null
        $n++
        if ($LASTEXITCODE -eq 0 -or (Test-Path $o)) { $fail++; Write-Host ("FAIL: truncated stream accepted ({0} of {1}, {2})" -f $len, $bytes.Length, ($a -join " ")) -ForegroundColor Red }
    }
    Remove-Item $c, $cut, $o -Force -ErrorAction SilentlyContinue
}

# --- the checksum (docs/checksum-prediction.md): every stream is 'DNH' and ends in ---
# --- a CRC-64 of the original bytes; a flipped byte anywhere is refused, nothing ------
# --- written. A stream whose 'H' became exactly 'C' reads as an old one, correctly. --
foreach ($t in $cutcases) {
    $src = $t.f; $a = $t.a
    $c = Join-Path $dir "fk.dnac"; $ff = Join-Path $dir "ff.dnac"; $o = Join-Path $dir "ff.out"
    & $Exe c $src $c @a | Out-Null
    $bytes = [System.IO.File]::ReadAllBytes($c)
    $n++; if ([System.Text.Encoding]::ASCII.GetString($bytes, 0, 3) -ne "DNH") { $fail++; Write-Host "FAIL: a new stream is not DNH" -ForegroundColor Red }
    $L = $bytes.Length
    foreach ($p in @(4, [int]($L / 3), [int]($L / 2), ($L - 8), ($L - 1))) {
        $fb = [byte[]]$bytes.Clone(); $fb[$p] = $fb[$p] -bxor 0xFF
        [System.IO.File]::WriteAllBytes($ff, $fb)
        Remove-Item $o -Force -ErrorAction SilentlyContinue
        & $Exe d $ff $o 2>$null | Out-Null
        $n++
        if ($LASTEXITCODE -eq 0 -or (Test-Path $o)) {
            if (-not ((Test-Path $o) -and (Get-FileHash $o).Hash -eq (Get-FileHash $src).Hash)) {
                $fail++; Write-Host ("FAIL: byte {0} of {1} flipped, accepted or output left ({2})" -f $p, $L, ($a -join " ")) -ForegroundColor Red }
        }
    }
    $dg = [byte[]]$bytes.Clone(); $dg[2] = [byte][char]'C'
    [System.IO.File]::WriteAllBytes($ff, $dg)
    Remove-Item $o -Force -ErrorAction SilentlyContinue
    & $Exe d $ff $o 2>$null | Out-Null
    $n++; if (-not ((Test-Path $o) -and (Get-FileHash $o).Hash -eq (Get-FileHash $src).Hash)) { $fail++; Write-Host ("FAIL: H->C downgrade did not decode right ({0})" -f ($a -join " ")) -ForegroundColor Red }
    Remove-Item $c, $ff, $o -Force -ErrorAction SilentlyContinue
}
# stored v0.11.0 streams (tests/v0110/make.sh): decoded and checked against the input
# hashes that make.sh recorded, so no input has to be regenerated here
$fix11 = Join-Path $PSScriptRoot "tests/v0110"
$want = @{}
foreach ($line in Get-Content (Join-Path $fix11 "inputs.sha256")) { $h, $nm = $line -split '\s+\*?', 2; $want[$nm] = $h.ToUpper() }
$g11 = Join-Path $dir "g11.fa"; & $Exe gen $g11 40000 3 | Out-Null
foreach ($s in @(@("plain_l1","g.fa"), @("plain_l3","g.fa"), @("codon_l1","g_on.fa"), @("codon_j3","g_on.fa"), @("codon_case_l1","g_case.fa"), @("ref_l1","m.fa"))) {
    $o = Join-Path $dir "v11.out"; Remove-Item $o -Force -ErrorAction SilentlyContinue
    $f = Join-Path $fix11 ($s[0] + ".dnac")
    if ($s[0] -like "ref_*") { & $Exe dr $f $o $g11 2>$null | Out-Null } else { & $Exe d $f $o 2>$null | Out-Null }
    $n++
    if (-not ((Test-Path $o) -and (Get-FileHash $o).Hash -eq $want[$s[1]])) { $fail++; Write-Host ("FAIL: v0.11.0 stream {0}" -f $s[0]) -ForegroundColor Red }
    Remove-Item $o -Force -ErrorAction SilentlyContinue
}
Remove-Item $g11 -Force -ErrorAction SilentlyContinue

if ($fail -ne 0) { Write-Host "$fail of $n FAILED" -ForegroundColor Red; exit 1 }
Write-Host "$n/$n adversarial roundtrips lossless" -ForegroundColor Green
exit 0   # the wrong-reference test leaves $LASTEXITCODE=1 on purpose
