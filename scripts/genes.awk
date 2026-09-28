# A deterministic, gene-like test genome for the codon tracker's round-trip cases.
#   awk -v seed=1 -v genes=200 -v bias=75 -v junk=0 -f genes.awk > genes.fa
# Genes: ATG + 300 codons (bias % from 20 favoured ones, else any sense codon) + TAA, on a random strand, separated by
# 100 random bases. junk = per-mille of genes replaced by random DNA of the same
# length, which weakens the codon period (used to place a file near the gate).
# Park-Miller LCG in doubles (products stay below 2^53), so every awk agrees; no rand().
function r(m) { x = (x * 16807) % 2147483647; return int(x / 2147483647 * m) }
function rc(s,   i, o, c) { o = ""; for (i = length(s); i >= 1; i--) { c = substr(s, i, 1)
    o = o (c == "A" ? "T" : c == "T" ? "A" : c == "C" ? "G" : "C") } return o }
function rnd(n,   i, o) { o = ""; for (i = 0; i < n; i++) o = o substr("ACGT", r(4) + 1, 1); return o }
BEGIN {
    x = seed + 1
    split("GCG CTG AAA GAA ATT GGC CGT ACC GAT CAG AAC GTG TTC CCG TAT CAT TGG AGC ATG TGC", fav, " ")
    b = "ACGT"
    seq = ""
    for (g = 0; g < genes; g++) {
        s = "ATG"
        for (c = 0; c < 300; c++) {
            if (r(100) < bias) s = s fav[r(20) + 1]
            else { do { cd = substr(b, r(4)+1, 1) substr(b, r(4)+1, 1) substr(b, r(4)+1, 1) }
                   while (cd == "TAA" || cd == "TAG" || cd == "TGA"); s = s cd }
        }
        s = s "TAA"
        if (r(1000) < junk) s = rnd(length(s))
        if (r(2) == 1) s = rc(s)
        seq = seq rnd(100) s
    }
    print ">synthetic gene-like genome seed=" seed " junk=" junk
    for (i = 1; i <= length(seq); i += 60) print substr(seq, i, 60)
}
