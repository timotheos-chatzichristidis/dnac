# Shared locations for the cue measurement scripts. Sourced, not run.
#
# These scripts were written in a scratch directory on one machine and carried
# its absolute paths. That made the figures traceable but not re-derivable, so
# every path now comes from the repository root, which is found from this file.
#
#   $ROOT     the checkout
#   $TGT      bench-external/cue/ecoli-targets   (sh scripts/cue/make-targets.sh)
#   $HUM      bench-external/cue/human           (sh scripts/get-data.sh --cue)
#   $HRCM     bench-external/cue/hrcm/hrcm.exe   (built from the patch, see README)
#   $WORK     bench-external/work/cue            (scratch; anything here is disposable)
#   $CC       compiler for the experiment builds (default gcc)
CUE_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$CUE_DIR/../.." && pwd)
# $0 is the calling script, so this is right when these are RUN. Sourced by hand
# from somewhere else it is not, and a wrong root would quietly measure nothing:
[ -s "$ROOT/dnac.c" ] || { echo "common.sh: '$ROOT' is not a dnac checkout (run these as scripts, from anywhere)" >&2; exit 1; }
TGT=${TGT:-$ROOT/bench-external/cue/ecoli-targets}
HUM=${HUM:-$ROOT/bench-external/cue/human}
HRCM=${HRCM:-$ROOT/bench-external/cue/hrcm/hrcm.exe}
WORK=${WORK:-$ROOT/bench-external/work/cue}
CC=${CC:-gcc}
mkdir -p "$WORK"

# The reference side of every controlled target, and of the real E. coli pairs.
REF=${REF:-$ROOT/ecoli.fa}
[ -s "$REF" ] || REF=$ROOT/data/ecoli.fa

need() { [ -s "$1" ] || { echo "missing: $1${2:+  ($2)}" >&2; exit 1; }; }

# Build one labelled experiment binary. `base` is the unflagged build, which is
# byte-identical to v0.8.0 -- that is the whole point of keeping the cue behind
# a flag, and every "against v0.8.0" number here is against this build.
build() { # build <label> [defines...]
  lbl=$1; shift
  exe=$WORK/dnac_$lbl.exe
  $CC -O3 -o "$exe" "$ROOT/dnac.c" -lm "$@" || { echo "build failed: $lbl" >&2; exit 1; }
  echo "$exe"
}

defines_for() { # the flags each label in the docs was measured with
  case $1 in
    base)       ;;
    cue)        echo "-DDNAC_CUE" ;;
    noroom)     echo "-DDNAC_CUE -DCUE_ROOM=0" ;;
    mf)         echo "-DDNAC_CUE -DCUE_MIXFREE=1" ;;
    mf_noroom)  echo "-DDNAC_CUE -DCUE_ROOM=0 -DCUE_MIXFREE=1" ;;
    cue2)       echo "-DDNAC_CUE -DCUE_BACK=1" ;;
    nudge)      echo "-DDNAC_NUDGE -DNUDGE_L=5 -DNUDGE_D=12" ;;
    L*D*)       l=${1#L}; l=${l%%D*}; d=${1##*D}
                echo "-DDNAC_NUDGE -DNUDGE_L=$l -DNUDGE_D=$d" ;;
    *) echo "unknown label: $1" >&2; exit 1 ;;
  esac
}
