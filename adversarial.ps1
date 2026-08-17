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
    foreach ($lvl in @(1, 2, 3)) {
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

if ($fail -ne 0) { Write-Host "$fail of $n FAILED" -ForegroundColor Red; exit 1 }
Write-Host "$n/$n adversarial roundtrips lossless" -ForegroundColor Green
exit 0   # the wrong-reference test leaves $LASTEXITCODE=1 on purpose
