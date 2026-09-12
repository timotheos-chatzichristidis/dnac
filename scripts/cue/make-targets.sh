#!/bin/sh
# Rebuild the ten controlled E. coli targets the cue was measured on.
#
# Every per-event figure in docs/nudge.md, docs/cue.md, docs/cue-room.md,
# docs/cue-back.md, docs/remaining.md and docs/speed.md is a cost measured
# against ONE of these files, so the figures are only reproducible if the files
# are. They are not committed (10 x 4.8 MB); this rebuilds them, byte for byte,
# from a reference genome and a seed.
#
#   sh scripts/cue/make-targets.sh [ref.fa] [outdir]
#
# defaults: ref = ./ecoli.fa (or data/ecoli.fa), out = bench-external/cue/ecoli-targets
#
# The ten files, all from E. coli K-12 MG1655 (NC_000913.3), 2,000 events each:
#   ctl          0 events -- the zero-event control every cost is measured against
#   sub_1..3     2,000 substitutions
#   ind_1..3     2,000 single-base indels at random positions
#   hp_1..3      2,000 single-base slips inside homopolymer runs of >= 6
#
# Determinism is the point: make_tumour.py draws from a seeded stream, so the
# same reference and seed give the same bytes on any machine. That is checked
# against targets.sha256 at the end -- a rebuild that drifts is a broken
# measurement, not a new one, and must be seen immediately.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)

ref=${1:-}
if [ -z "$ref" ]; then
  if   [ -s "$root/ecoli.fa" ];      then ref="$root/ecoli.fa"
  elif [ -s "$root/data/ecoli.fa" ]; then ref="$root/data/ecoli.fa"
  else echo "no ecoli.fa found -- run: sh scripts/get-data.sh" >&2; exit 1; fi
fi
out=${2:-$root/bench-external/cue/ecoli-targets}
mkdir -p "$out"

PY=${PYTHON:-python}
command -v "$PY" >/dev/null 2>&1 || { echo "no python on PATH (set PYTHON=)" >&2; exit 1; }

mk() { # mk <name> <n_events> <indel_fraction> <seed> <context>
  echo "  $1"
  "$PY" "$here/make_tumour.py" "$ref" "$out/$1.fa" "$out/$1.truth.tsv" "$2" "$3" "$4" "$5" >/dev/null
}

echo "rebuilding the E. coli targets from $(basename "$ref") into $out"
mk ctl 0 0 1 random
for s in 1 2 3; do
  mk "sub_$s" 2000 0 "$s" random
  mk "ind_$s" 2000 1 "$s" random
  mk "hp_$s"  2000 1 "$s" homopolymer
done

# The check that makes this a rebuild rather than a new dataset.
if [ -s "$here/targets.sha256" ]; then
  echo "checking against scripts/cue/targets.sha256"
  ( cd "$out" && sha256sum -c "$here/targets.sha256" ) || {
    echo "REBUILT TARGETS DIFFER from the ones the docs were measured on." >&2
    echo "Do not compare new numbers with the published ones until this is understood." >&2
    exit 1; }
  echo "all ten targets are byte-identical to the measured set"
else
  ( cd "$out" && sha256sum ctl.fa sub_?.fa ind_?.fa hp_?.fa > "$here/targets.sha256" )
  echo "wrote scripts/cue/targets.sha256 (first run: nothing to compare against)"
fi
