<#
.SYNOPSIS
  Measures what each of the codec's prediction inputs is actually worth.

.DESCRIPTION
  The round-trip suites run ONE binary with ONE configuration, so they cannot
  see anything that varies BETWEEN model sets; verify-claims.ps1 defends the
  published numbers but not the design behind them. This is the instrument for
  the third question: which model earns what.

  It drives the two compile-time hooks in dnac.c:

    -DDNAC_ABLATE=<mask>  zero the stretch of every input whose bit is set. The
                          input stops contributing AND stops learning, while the
                          tables, hashing and memory stay exactly as they were --
                          so the result is the value of the INPUT, not of the
                          memory it occupied. Deleting entries from
                          MASTER_ORDER_LIST cannot separate those two.
    -DDNAC_DIAG           dump each input's mean contribution and the
                          correlation matrix between inputs. Byte-identical to
                          a normal build; it only reads what the mixer computed.

  Input order at level 3, k=22 (15 inputs):
    0..9   order models 1 2 3 4 6 8 11 14 18 22
    10,11  substitution-tolerant models, orders 16 and 20
    12,13  forward match models, MMIN=13 and MMIN2=16
    14     reverse-complement match model

.PARAMETER Mode
  loo   leave-one-out: every input removed on its own (default)
  diag  correlation matrix and per-input contribution
  mask  one explicit mask, given by -Mask

.PARAMETER File
  Sequence to measure. Defaults to chr21_slice.fa, which is what the published
  ablation figures in README.md and docs/model-ablation.md use.

.EXAMPLE
  ./ablate.ps1                                  # leave-one-out on chr21_slice.fa
  ./ablate.ps1 -Mode diag -File ecoli.fa        # the redundancy map
  ./ablate.ps1 -Mode mask -Mask 0xC00           # drop both tolerant models

.NOTES
  Sizes only. Timings are deliberately not reported here, for the same reason
  verify-claims.ps1 refuses them: run-to-run noise on this codec was measured at
  24% on identical input for byte-identical output, which is wider than every
  effect in the table below. Time a candidate by hand on an idle machine with
  ./bench.ps1, three runs, and quote the minimum.
#>
[CmdletBinding()]
param(
    [ValidateSet('loo','diag','mask')] [string] $Mode = 'loo',
    [string] $File = 'chr21_slice.fa',
    [string] $Mask = '0',
    [int]    $Level = 3,
    [int]    $K = 22,
    [string] $Cc = 'gcc',
    [switch] $KeepWork
)

$ErrorActionPreference = 'Stop'
# Byte counts here are quoted in docs/model-ablation.md, which groups with commas.
[Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$work = Join-Path $root '.ablate'
$src  = Join-Path $root 'dnac.c'
$seq  = if ([IO.Path]::IsPathRooted($File)) { $File } else { Join-Path $root $File }

if (-not (Test-Path $seq)) { throw "no such sequence file: $seq" }
if (-not (Test-Path $src)) { throw "dnac.c not found next to ablate.ps1" }
New-Item -ItemType Directory -Force -Path $work | Out-Null

# Labels for the inputs, in the order mix_predict fills them.
$LABEL = @('order 1','order 2','order 3','order 4','order 6','order 8',
           'order 11','order 14','order 18','order 22',
           'tolerant 16','tolerant 20','match 13','match 16','rev-comp')

function Build([string] $name, [string[]] $defs) {
    $exe = Join-Path $work "$name.exe"
    $args = @('-O2','-o', $exe, $src, '-lm') + $defs
    $log = & $Cc @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$Cc failed for ${name}:`n$log" }
    $exe
}

# Compress, and REFUSE to return a size that has not been shown to be lossless.
# A number from a run whose round-trip was never checked is not a measurement --
# the same rule verify-claims.ps1 follows.
function SizeOfBuild([string] $exe, [string] $tag) {
    $out = Join-Path $work "$tag.dnac"
    $rt  = Join-Path $work "$tag.out"
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    & $exe c $seq $out $K $Level | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { throw "compress failed: $tag" }
    & $exe d $out $rt | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $rt) -or (Get-Item $rt).Length -eq 0) {
        throw "decompress failed: $tag"
    }
    if ((Get-FileHash $seq -Algorithm SHA256).Hash -ne (Get-FileHash $rt -Algorithm SHA256).Hash) {
        throw "NOT LOSSLESS: $tag"
    }
    $n = (Get-Item $out).Length
    Remove-Item $out, $rt -Force -ErrorAction SilentlyContinue
    $n
}

Write-Host ""
Write-Host "ablation of $(Split-Path $seq -Leaf) at level $Level, k=$K" -ForegroundColor Cyan
Write-Host ""

if ($Mode -eq 'diag') {
    $exe = Build 'diag' @('-DDNAC_DIAG')
    $out = Join-Path $work 'diag.dnac'
    $err = Join-Path $work 'diag.txt'
    $p = Start-Process -FilePath $exe -ArgumentList @('c', $seq, $out, $K, $Level) `
                       -NoNewWindow -Wait -PassThru -RedirectStandardError $err `
                       -RedirectStandardOutput (Join-Path $work 'diag.log')
    if ($p.ExitCode -ne 0) { throw "diag run failed" }

    # A DIAG build must not change the bitstream. If it does, the instrument is
    # lying about the thing it is measuring.
    $ref = Build 'plain' @()
    $refOut = Join-Path $work 'plain.dnac'
    & $ref c $seq $refOut $K $Level | Out-Null
    if ((Get-Item $out).Length -ne (Get-Item $refOut).Length -or
        (Get-FileHash $out -Algorithm SHA256).Hash -ne (Get-FileHash $refOut -Algorithm SHA256).Hash) {
        throw "the DIAG build changed the archive -- the instrument is not inert"
    }
    Write-Host "DIAG build verified byte-identical to a normal build." -ForegroundColor Green
    Write-Host ""
    Get-Content $err | ForEach-Object {
        if     ($_ -match '^IN\s+(\d+)') { "{0,-13} {1}" -f $LABEL[[int]$Matches[1]], $_ }
        else   { $_ }
    }
    if (-not $KeepWork) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
    return
}

if ($Mode -eq 'mask') {
    $m = [Convert]::ToUInt32($Mask.Replace('0x',''), $(if ($Mask -like '0x*') { 16 } else { 10 }))
    $base = SizeOfBuild (Build 'base' @()) 'base'
    $abl  = SizeOfBuild (Build 'mask' @("-DDNAC_ABLATE=$m")) 'mask'
    $dropped = @(0..14 | Where-Object { $m -band (1 -shl $_) } | ForEach-Object { $LABEL[$_] })
    Write-Host ("baseline          {0,10:N0} B" -f $base)
    Write-Host ("mask 0x{0:X}       {1,10:N0} B  {2,9:N3}%" -f $m, $abl, (100.0 * ($abl - $base) / $base))
    Write-Host ("removed: {0}" -f ($dropped -join ', '))
    if (-not $KeepWork) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
    return
}

# --- leave-one-out ------------------------------------------------------------
# Read the row for what an input is worth ON ITS OWN. It is NOT the value of a
# group: the mixer reroutes around any single missing input, so leave-one-out
# systematically UNDERSTATES what a set of them is worth together. Measured on
# chr21: removing five inputs costs 1.47x the sum of removing each alone, and
# removing the two match models costs 2.4x. Use -Mode mask for a real candidate.
$base = SizeOfBuild (Build 'base' @()) 'base'
Write-Host ("baseline (all inputs)  {0,10:N0} B" -f $base)
Write-Host ""
Write-Host ("{0,-13} {1,10} {2,10}" -f 'input','bytes','cost')
Write-Host ("-" * 35)

$rows = foreach ($i in 0..14) {
    $n = SizeOfBuild (Build "a$i" @("-DDNAC_ABLATE=$(1 -shl $i)")) "a$i"
    $pct = 100.0 * ($n - $base) / $base
    Write-Host ("{0,-13} {1,10:N0} {2,9:N3}%" -f $LABEL[$i], $n, $pct)
    [pscustomobject]@{ Input = $LABEL[$i]; Bytes = $n; CostPct = [math]::Round($pct, 3) }
}

Write-Host ""
Write-Host "every row above round-tripped before its size was reported." -ForegroundColor Green
if (-not $KeepWork) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
$rows
