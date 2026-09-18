#!/bin/sh
# M1, riding (docs/riding-prediction.md): on a cue miss, correct the cue's phase
# by up to RIDE_D either way and KEEP its confidence, instead of decaying it
# towards a fresh search. `ride` is the release source with -DRIDE_D=2, which
# marks its archives experimental so they can never be confused with release
# files; `rel` is the release itself.
#
#   sh scripts/cue/after090-ride.sh [targets|human|heldout|time]...
#
# Everything is measured at LEVEL 3, where the release's per-event figures and
# the CHM13 headline were measured (docs/batch4.md R1-R3). Every archive is
# decoded and cmp-ed before its size is recorded. Sizes go to $WORK/ride/
# sizes.tsv as <label> <case> <level> <bytes>. Timing is a separate section and
# alternates the labels inside each round: a ratio taken across separate
# invocations is not a ratio on a machine with this much noise.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

B=$WORK/ride
mkdir -p "$B"
REL=$(build rel $(defines_for rel))
RIDE=$(build ride $(defines_for ride))
SECTIONS=${*:-targets human heldout time}
has() { case " $SECTIONS " in *" $1 "*) return 0 ;; esac; return 1; }

now() { ${PYTHON:-python} -c 'import time; print("%.3f" % time.time())'; }
el()  { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.2f", b-a}'; }

# rt <label> <case> <level> <target> <ref>: encode, decode, cmp, record
rt() {
  lb=$1; cs=$2; lv=$3; tg=$4; rf=$5
  eval exe=\$$(echo "$lb" | tr a-z A-Z)
  out=$B/$cs.$lb.l$lv.dnac
  "$exe" cr "$tg" "$out" "$rf" 22 "$lv" >/dev/null 2>&1 || { echo "FAIL encode $cs $lb l$lv" >&2; exit 1; }
  "$exe" dr "$out" "$B/back.$lb" "$rf" >/dev/null 2>&1 || { echo "FAIL decode $cs $lb l$lv" >&2; exit 1; }
  cmp -s "$tg" "$B/back.$lb" || { echo "FAIL lossless $cs $lb l$lv" >&2; exit 1; }
  rm -f "$B/back.$lb"
  n=$(wc -c < "$out"); rm -f "$out"
  printf '%s\t%s\t%s\t%s\n' "$lb" "$cs" "$lv" "$n" >> "$B/sizes.tsv"
  echo "  $lb $cs l$lv $n"
}

[ -s "$B/sizes.tsv" ] || : > "$B/sizes.tsv"

if has targets; then
  need "$REF" "sh scripts/get-data.sh"
  need "$TGT/ctl.fa" "sh scripts/cue/make-targets.sh"
  echo "== M1a / M1c: the ten controlled targets at level 3, against a primed MG1655"
  for lb in rel ride; do
    eval exe=\$$(echo "$lb" | tr a-z A-Z)
    st=$B/ref.$lb.l3.state
    "$exe" prime "$REF" "$st" 22 3 >/dev/null 2>&1 || { echo "FAIL prime $lb" >&2; exit 1; }
    for t in ctl sub_1 sub_2 sub_3 ind_1 ind_2 ind_3 hp_1 hp_2 hp_3; do
      rt "$lb" "$t" 3 "$TGT/$t.fa" "$st"
    done
    rm -f "$st"
  done
fi

if has human; then
  need "$HUM/chm13_chr21.fa" "sh scripts/get-data.sh --cue"
  echo "== M1b: CHM13 chr21 against GRCh38 chr21, level 3"
  for lb in rel ride; do rt "$lb" chm13_chr21 3 "$HUM/chm13_chr21.fa" "$HUM/grch38_chr21.fa"; done
fi

if has heldout; then
  need "$HUM/chm13_chr22.fa" "sh scripts/get-data.sh --cue"
  echo "== D-M condition 4: CHM13 chr22, held out, level 3"
  for lb in rel ride; do rt "$lb" chm13_chr22 3 "$HUM/chm13_chr22.fa" "$HUM/grch38_chr22.fa"; done
fi

if has targets || has human || has heldout; then
  echo
  echo "== per event (target - ctl) x 8 / 2000, mean of three seeds, and the pairs"
  awk -F'\t' '{ S[$1 FS $2] = $4 }
    END {
      printf "%-6s %10s %10s %10s %10s\n", "build", "ctl", "sub", "indel", "hp slip"
      for (i = 1; i <= 2; i++) {
        lb = (i == 1) ? "rel" : "ride"
        if (S[lb FS "ctl"] == "") continue
        c = S[lb FS "ctl"]
        for (k = 1; k <= 3; k++) {
          n = (k == 1) ? "sub" : (k == 2) ? "ind" : "hp"
          t = 0; for (s = 1; s <= 3; s++) t += (S[lb FS n "_" s] - c) * 8 / 2000
          v[n] = t / 3
        }
        printf "%-6s %10d %10.2f %10.2f %10.2f\n", lb, c, v["sub"], v["ind"], v["hp"]
      }
      print ""
      printf "%-14s %10s %10s %9s\n", "pair", "rel", "ride", "change"
      for (p = 1; p <= 2; p++) {
        c = (p == 1) ? "chm13_chr21" : "chm13_chr22"
        if (S["rel" FS c] == "" || S["ride" FS c] == "") continue
        printf "%-14s %10d %10d %+8.3f%%\n", c, S["rel" FS c], S["ride" FS c],
               100 * (S["ride" FS c] / S["rel" FS c] - 1)
      }
    }' "$B/sizes.tsv"
fi

if has time; then
  need "$HUM/chm13_chr21.fa" "sh scripts/get-data.sh --cue"
  echo
  echo "== M1d: encode of CHM13 chr21 at level 3, priming inside the time, 3 rounds"
  : > "$B/time.tsv"
  for r in 1 2 3; do
    for lb in rel ride; do
      eval exe=\$$(echo "$lb" | tr a-z A-Z)
      t0=$(now)
      "$exe" cr "$HUM/chm13_chr21.fa" "$B/t.dnac" "$HUM/grch38_chr21.fa" 22 3 >/dev/null 2>&1 \
        || { echo "FAIL $lb round $r" >&2; exit 1; }
      t1=$(now)
      printf '%s\t%s\t%s\t%s\n' "$lb" "$r" "$(el "$t0" "$t1")" "$(wc -c < "$B/t.dnac")" >> "$B/time.tsv"
      echo "  round $r  $lb  $(el "$t0" "$t1") s  $(wc -c < "$B/t.dnac") B"
      rm -f "$B/t.dnac"
    done
  done
  echo
  awk -F'\t' '{ if (m[$1] == "" || $3 < m[$1]) m[$1] = $3 }
    END { printf "  rel  %7.2f s\n  ride %7.2f s   %+.2f%% time\n", m["rel"], m["ride"],
                 100 * (m["ride"] / m["rel"] - 1) }' "$B/time.tsv"
fi

echo "ALL_DONE  ->  $B/sizes.tsv"
