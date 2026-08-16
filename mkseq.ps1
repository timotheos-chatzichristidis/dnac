# mkseq.ps1 - turn a FASTA into the plain ACGT sequence file that DNA-compression
# papers benchmark on: no header, no newlines, no N, uppercase only.
# Usage: ./mkseq.ps1 chr21.fa bench-external/seq/chr21.seq
param([Parameter(Mandatory)][string]$In, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = "Stop"

if (-not ("SeqClean" -as [type])) {
    Add-Type -TypeDefinition @'
public class SeqClean {
  public static long Run(string inp, string outp){
    var src = System.IO.File.ReadAllBytes(inp);
    var dst = new byte[src.Length];
    long m = 0; bool header = false;
    foreach (var b0 in src) {
      int c = b0;
      if (c == '>' || c == ';') header = true;
      if (c == '\n') { header = false; continue; }
      if (header) continue;
      if (c >= 'a' && c <= 'z') c -= 32;
      if (c=='A'||c=='C'||c=='G'||c=='T') dst[m++] = (byte)c;
    }
    using (var f = System.IO.File.Create(outp)) f.Write(dst, 0, (int)m);
    return m;
  }
}
'@
}
$outDir = Split-Path $Out -Parent
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }
$n = [SeqClean]::Run((Resolve-Path $In).Path, (Join-Path (Resolve-Path (Split-Path $Out -Parent)).Path (Split-Path $Out -Leaf)))
Set-Content "$Out.acgt" $n
"{0} -> {1}  ({2:N0} bases)" -f (Split-Path $In -Leaf), (Split-Path $Out -Leaf), $n
