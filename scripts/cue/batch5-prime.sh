#!/bin/sh
# Batch 5: the priming table in README's "Pay for the reference once".
#
#   sh scripts/cue/batch5-prime.sh        # ~15 minutes, run it alone
#
# Four wall-clock figures, and v0.9.0 moves all of them: `dnac prime` and
# `dnac cr` default to level 1 with a reference now, so the pass that used to
# cost 98 s on chr21 is a level-1 pass. Encode-only, because the point of the
# table is what a saved state saves, and the state is loaded once either way.
# Every archive is still round-tripped before its number is kept.
#
# Single runs: the table is illustrative and no row defends a wall-clock figure
# here (run-to-run noise on this machine reaches 24%). The STATE SIZES it also
# quotes are deterministic and do have rows.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

B=$WORK/b5p
mkdir -p "$B"
REL=$(build rel $(defines_for rel))

now() { ${PYTHON:-python} -c 'import time; print("%.3f" % time.time())'; }
el()  { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.1f", b-a}'; }

# one <name> <reference.fa> <target.fa>
one() {
  nm=$1; rf=$2; tg=$3
  [ -s "$rf" ] || { echo "  missing $rf -- sh scripts/get-data.sh" >&2; return 0; }
  st=$B/$nm.state

  t0=$(now); "$REL" prime "$rf" "$st" 22 >/dev/null 2>&1 || { echo "FAIL prime $nm" >&2; exit 1; }
  t1=$(now)
  mb=$(( $(wc -c < "$st") / 1000000 ))

  # a state LOAD, timed on its own: compress a tiny target so the run is the load
  head -c 200000 "$tg" > "$B/tiny.fa"
  t2=$(now); "$REL" cr "$B/tiny.fa" "$B/tiny.dnac" "$st" >/dev/null 2>&1 || { echo "FAIL load $nm" >&2; exit 1; }
  t3=$(now)
  rm -f "$B/tiny.fa" "$B/tiny.dnac"

  # the real target, against the FASTA (priming inside) and against the state
  t4=$(now); "$REL" cr "$tg" "$B/fa.dnac" "$rf" >/dev/null 2>&1 || { echo "FAIL cr-fasta $nm" >&2; exit 1; }
  t5=$(now); "$REL" cr "$tg" "$B/st.dnac" "$st" >/dev/null 2>&1 || { echo "FAIL cr-state $nm" >&2; exit 1; }
  t6=$(now)
  cmp -s "$B/fa.dnac" "$B/st.dnac" || { echo "FAIL: the state and its FASTA wrote different archives ($nm)" >&2; exit 1; }
  "$REL" dr "$B/st.dnac" "$B/back" "$st" >/dev/null 2>&1 || { echo "FAIL decode $nm" >&2; exit 1; }
  cmp -s "$tg" "$B/back" || { echo "FAIL lossless $nm" >&2; exit 1; }
  rm -f "$B/fa.dnac" "$B/st.dnac" "$B/back" "$st"

  awk -v n="$nm" -v p="$(el "$t0" "$t1")" -v l="$(el "$t2" "$t3")" \
      -v f="$(el "$t4" "$t5")" -v s="$(el "$t5" "$t6")" -v m="$mb" \
    'BEGIN{ printf "  %-10s prime %6.1f s   state %5d MB   load %5.1f s   target: FASTA %6.1f s -> state %6.1f s\n", n, p, m, l, f, s }'
}

echo "== priming, at the default level (1 with a reference, since v0.9.0)"
one ecoli "$REF" "$ROOT/ecoli_ind.fa"
[ -s "$ROOT/chr21.fa" ] && one chr21 "$ROOT/chr21.fa" "$ROOT/chr21_ind.fa"

echo "ALL_DONE"
