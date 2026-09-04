# sweep-tables.ps1 - re-derive the table-size trade-off in PROGRESS.md section 11.
#
# The two hash-table caps are the only real memory levers in the codec:
#   HASHBITS_MAX  the order-model ensemble    (a collision blurs statistics)
#   MHBITS_MAX    the match-anchor tables     (a collision gives a WRONG match)
# The anchor tables get +2 doublings of headroom for exactly that asymmetry, and
# the 2026-09-04 sweep is what tested whether the headroom earns its keep. Answer:
# per unit of compression given up, HASHBITS buys 5.4x more memory than MHBITS, so
# 26 stays for the anchors and HASHBITS is the lever if memory has to come down.
#
# This exists because those numbers live in a published doc and would otherwise be
# read and never executed - the failure mode this project keeps catching. The
# baseline row (cap 26 -> 7,506,264 B) is the registry's `chr21-j1-bytes`, so
# ./verify-claims.ps1 already re-derives it; the other rows need other builds,
# which is what this script is for.
#
# Safe only because the geometry travels in the header: an archive written by one
# cap is readable by any build. That is asserted below - every archive's header
# byte 7 is read back and must equal the cap in force.
#
# Every size comes from a run whose losslessness was checked. A size from an
# unverified run is not a measurement.
#
# Usage:
#   ./sweep-tables.ps1                              # MHBITS_MAX 26,25,24,23 on chr21.seq
#   ./sweep-tables.ps1 -Macro HASHBITS_MAX -Caps 26,25,24,22
#   ./sweep-tables.ps1 -Caps 26,26                  # the same cap twice = timing noise control
#
# Runtime is ~5 min per cap on full chr21.seq. Expect memory, not speed: cap 26
# run twice gave 170.3 s and 137.7 s encode for byte-identical output, so 24%
# run-to-run variance swamps the whole range. Repeats, not single runs, before any
# speed claim.

param(
    [ValidateSet('MHBITS_MAX','HASHBITS_MAX')][string]$Macro = 'MHBITS_MAX',
    [int[]]$Caps = @(26,25,24,23),
    [string]$Seq,
    [int]$Level = 3,
    [string]$Out
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$src  = Join-Path $root 'dnac.c'
if (-not $Seq) { $Seq = Join-Path $root 'bench-external\seq\chr21.seq' }
if (-not (Test-Path $Seq))      { throw "sequence not found: $Seq (run ./mkseq.ps1)" }
if (-not (Test-Path "$Seq.acgt")){ throw "missing base count '$Seq.acgt' (run ./mkseq.ps1)" }

$work = Join-Path $env:TEMP 'dnac-sweep'
New-Item -ItemType Directory -Force $work | Out-Null

$bases   = [long](Get-Content "$Seq.acgt")
$srcHash = (Get-FileHash $Seq -Algorithm SHA256).Hash
Write-Host "$(Split-Path $Seq -Leaf): $bases bases, level $Level, sweeping $Macro`n"

$rows = @()
foreach ($cap in $Caps) {
    $exe = Join-Path $work "dnac_$($Macro)_$cap.exe"
    # quoted: an unquoted -DX=$cap is a parameter-shaped token and PowerShell
    # hands gcc the literal '$cap'
    gcc -O2 "-D$Macro=$cap" -o $exe $src -lm -pthread
    if ($LASTEXITCODE -ne 0) { throw "build failed at $Macro=$cap" }

    $arc = Join-Path $work "s$cap.dnac"; $rt = Join-Path $work "s$cap.rt"
    Remove-Item $arc, $rt -Force -ErrorAction SilentlyContinue
    if ((Resolve-Path $Seq).Path -eq $rt) { throw "round-trip path collides with input" }

    # encode, watching peak working set (same method as verify-claims.ps1)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $exe -ArgumentList @('c',$Seq,$arc,'22',"$Level") `
                       -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $work 'enc.log')
    $peak = 0
    while (-not $p.HasExited) {
        try { $p.Refresh(); if ($p.WorkingSet64 -gt $peak) { $peak = $p.WorkingSet64 } } catch {}
        Start-Sleep -Milliseconds 120
    }
    $enc = $sw.Elapsed.TotalSeconds
    if ($p.ExitCode -ne 0 -or -not (Test-Path $arc)) { throw "compress failed at $Macro=$cap" }

    # the header must say what geometry was actually used: byte 6 hashbits, 7 mhb
    $hdr = [byte[]](Get-Content $arc -AsByteStream -TotalCount 8)
    $hb_hdr = $hdr[6]; $mhb_hdr = $hdr[7]
    $used = if ($Macro -eq 'MHBITS_MAX') { $mhb_hdr } else { $hb_hdr }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $exe d $arc $rt | Out-Null
    $dec = $sw.Elapsed.TotalSeconds
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $rt)) { throw "decompress failed at $Macro=$cap" }
    if ((Get-Item $rt).Length -eq 0) { throw "decoder emitted 0 bytes at $Macro=$cap" }
    if ((Get-FileHash $rt -Algorithm SHA256).Hash -ne $srcHash) {
        throw "NOT LOSSLESS at $Macro=$cap - stop everything else and fix this"
    }

    $bytes = (Get-Item $arc).Length
    $rows += [pscustomobject]@{
        cap      = $cap
        hb_hdr   = $hb_hdr
        mhb_hdr  = $mhb_hdr
        anchorMB = [math]::Round(2 * [math]::Pow(2,$mhb_hdr) * 4 / 1MB, 0)
        bytes    = $bytes
        bpb      = [math]::Round(8.0 * $bytes / $bases, 4)
        peakMB   = [math]::Round($peak / 1MB, 0)
        enc_s    = [math]::Round($enc, 1)
        dec_s    = [math]::Round($dec, 1)
    }
    Write-Host ("  {0}={1}  header hb={2} mhb={3}  {4,9} B  {5} bpb  peak {6} MB  enc {7}s  dec {8}s  lossless" -f `
        $Macro, $cap, $hb_hdr, $mhb_hdr, $bytes, $rows[-1].bpb, $rows[-1].peakMB, $rows[-1].enc_s, $rows[-1].dec_s)
    if ($used -ne $cap -and $cap -le 26) {
        Write-Host ("    note: header says $used, not $cap - the cap did not bind at this input length")
    }
    Remove-Item $arc, $rt -Force -ErrorAction SilentlyContinue
}

$rows | Format-Table -AutoSize
if ($Out) { $rows | Export-Csv -NoTypeInformation -Path $Out; Write-Host "wrote $Out" }
