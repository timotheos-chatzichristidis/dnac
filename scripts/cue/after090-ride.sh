#!/bin/sh
# M1, riding (docs/riding-prediction.md): on a cue miss, correct the cue's phase
# by up to RIDE_D either way and KEEP its confidence, instead of decaying it
# towards a fresh search. `ride` is the release source with -DRIDE_D=2, which
# marks its archives experimental so they can never be confused with release
# files; `rel` is the release itself.
#
#   sh scripts/cue/after090-ride.sh [targets|pairs|human|heldout|time]...
#   LABELS="rel ride_l8" sh scripts/cue/after090-ride.sh targets human
#
# LABELS chooses which builds to run (default "rel ride"). `ride_l8` is the
# post-hoc probe of docs/after-090-riding.md: the same riding behind a stricter
# test to ride ON (RIDE_L=8), because CUE_L=3 is the test for picking a phase
# up, not for overriding a cue that is currently trusted. Rows accumulate in
# sizes.tsv, so a label already measured is not re-measured -- delete the file
# to start over.
#
# Everything is measured at LEVEL 3, where the release's per-event figures and
# the CHM13 headline were measured (docs/batch4.md R1-R3). Every archive is
# decoded and cmp-ed before its size is recorded. Timing is a separate section
# and alternates the labels inside each round: a ratio taken across separate
# invocations is not a ratio on a machine with this much noise.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

B=$WORK/ride
mkdir -p "$B"
LABELS=${LABELS:-"rel ride"}
for lb in $LABELS; do
  exe=$(build "$lb" $(defines_for "$lb"))
  eval "$(echo "$lb" | tr a-z A-Z)"='$exe'
done
SECTIONS=${*:-targets pairs human heldout time}
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
  for lb in $LABELS; do
    eval exe=\$$(echo "$lb" | tr a-z A-Z)
    st=$B/ref.$lb.l3.state
    "$exe" prime "$REF" "$st" 22 3 >/dev/null 2>&1 || { echo "FAIL prime $lb" >&2; exit 1; }
    for t in ctl sub_1 sub_2 sub_3 ind_1 ind_2 ind_3 hp_1 hp_2 hp_3; do
      rt "$lb" "$t" 3 "$TGT/$t.fa" "$st"
    done
    rm -f "$st"
  done
fi

if has pairs; then
  need "$REF" "sh scripts/get-data.sh"
  # M2b: the DIVERGED bacterial pair, where long exact anchors are scarce -- the
  # case rotation is registered against separately (docs/riding-prediction.md).
  echo "== M2b: O157:H7 and ecoli_ind against MG1655, level 3"
  for lb in $LABELS; do
    for pr in o157 ecoli_ind; do rt "$lb" "$pr" 3 "$ROOT/$pr.fa" "$REF"; done
  done
fi

if has human; then
  need "$HUM/chm13_chr21.fa" "sh scripts/get-data.sh --cue"
  echo "== M1b: CHM13 chr21 against GRCh38 chr21, level 3"
  for lb in $LABELS; do rt "$lb" chm13_chr21 3 "$HUM/chm13_chr21.fa" "$HUM/grch38_chr21.fa"; done
fi

if has heldout; then
  need "$HUM/chm13_chr22.fa" "sh scripts/get-data.sh --cue"
  echo "== D-M condition 4: CHM13 chr22, held out, level 3"
  for lb in $LABELS; do rt "$lb" chm13_chr22 3 "$HUM/chm13_chr22.fa" "$HUM/grch38_chr22.fa"; done
fi

if has targets || has pairs || has human || has heldout; then
  echo
  echo "== per event (target - ctl) x 8 / 2000, mean of three seeds, and the pairs"
  awk -F'\t' '{ S[$1 FS $2] = $4; if (!($1 in L)) { L[$1] = 1; ord[++nl] = $1 } }
    END {
      printf "%-8s %10s %10s %10s %10s\n", "build", "ctl", "sub", "indel", "hp slip"
      for (i = 1; i <= nl; i++) {
        lb = ord[i]
        if (S[lb FS "ctl"] == "") continue
        c = S[lb FS "ctl"]
        for (k = 1; k <= 3; k++) {
          nm = (k == 1) ? "sub" : (k == 2) ? "ind" : "hp"
          t = 0; for (sd = 1; sd <= 3; sd++) t += (S[lb FS nm "_" sd] - c) * 8 / 2000
          v[nm] = t / 3
        }
        printf "%-8s %10d %10.2f %10.2f %10.2f\n", lb, c, v["sub"], v["ind"], v["hp"]
      }
      print ""
      printf "%-14s %-8s %10s %9s\n", "pair", "build", "bytes", "vs rel"
      split("chm13_chr21 chm13_chr22 o157 ecoli_ind", P, " ")
      for (p = 1; p <= 4; p++) {
        cs = P[p]
        if (S["rel" FS cs] == "") continue
        for (i = 1; i <= nl; i++) {
          lb = ord[i]
          if (S[lb FS cs] == "") continue
          printf "%-14s %-8s %10d %+8.3f%%\n", cs, lb, S[lb FS cs],
                 100 * (S[lb FS cs] / S["rel" FS cs] - 1)
        }
      }
    }' "$B/sizes.tsv"
fi

if has time; then
  need "$HUM/chm13_chr21.fa" "sh scripts/get-data.sh --cue"
  echo
  echo "== M1d: encode of CHM13 chr21 at level 3, priming inside the time, 3 rounds"
  : > "$B/time.tsv"
  for r in 1 2 3; do
    for lb in $LABELS; do
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
  awk -F'\t' '{ if (m[$1] == "" || $3 < m[$1]) m[$1] = $3; if (!($1 in L)) { L[$1] = 1; ord[++nl] = $1 } }
    END { for (i = 1; i <= nl; i++) printf "  %-8s %7.2f s   %+.2f%% time vs rel\n",
                 ord[i], m[ord[i]], 100 * (m[ord[i]] / m["rel"] - 1) }' "$B/time.tsv"
fi

echo "ALL_DONE  ->  $B/sizes.tsv"
