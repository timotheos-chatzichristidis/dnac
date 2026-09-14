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

# Build one labelled experiment binary, FROM THE SOURCE THAT MEASURED IT. Every
# label below is a record of an experiment run before v0.9.0 made the cue a
# run-time feature (docs/batch4-prediction.md F6): `-DDNAC_CUE`, the nudge and
# the alternating deck no longer exist in dnac.c, and CUE_MINLEN's default moved.
# So these labels compile 4932ffe's dnac.c, the last source that measured
# anything on the branch, with exactly the flags in defines_for. `base` there is
# the unflagged build, byte-identical to v0.8.0. What links these records to the
# shipping code is scripts/cue/batch4.sh, which checks byte identity.
PIN=4932ffe
# The two labels that are NOT records: v0.9.0's own builds, from the working
# tree. `rel` is the release (the cue on, CUE_MINLEN 4, level 1 by default with
# a reference); `v08` is the same source with the cue off and v0.8.0's default
# level, byte-identical to the v0.8.0 tag (docs/batch4-prediction.md P2).
TREE_LABELS="rel v08 exp"          # exp: an experimental build, for its refusals
build() { # build <label> [defines...]
  lbl=$1; shift
  exe=$WORK/dnac_$lbl.exe
  case " $TREE_LABELS " in
    *" $lbl "*) src=$ROOT/dnac.c ;;
    *) src=$WORK/src_$PIN.c
       [ -s "$src" ] || git -C "$ROOT" show "$PIN:dnac.c" > "$src" || { echo "git show $PIN:dnac.c failed" >&2; exit 1; } ;;
  esac
  $CC -O3 -o "$exe" "$src" -lm -pthread "$@" || { echo "build failed: $lbl" >&2; exit 1; }
  echo "$exe"
}

defines_for() { # the flags each label in the docs was measured with
  case $1 in
    rel)        ;;                                   # working tree, see TREE_LABELS
    v08)        echo "-DCUE_DEFAULT=0 -DREF_LEVEL_DEFAULT=3" ;;
    exp)        echo "-DCUE_MINLEN=16" ;;
    base)       ;;
    cue)        echo "-DDNAC_CUE" ;;
    noroom)     echo "-DDNAC_CUE -DCUE_ROOM=0" ;;
    mf)         echo "-DDNAC_CUE -DCUE_MIXFREE=1" ;;
    mf_noroom)  echo "-DDNAC_CUE -DCUE_ROOM=0 -DCUE_MIXFREE=1" ;;
    cue2)       echo "-DDNAC_CUE -DCUE_BACK=1" ;;
    # Batch 3's neighbourhood sweep: one parameter moved off the centre
    # (CUE_L=3, CUE_D=12, CUE_SWITCH=12, CUE_MINLEN=16), which is `cue`.
    cue_L2)     echo "-DDNAC_CUE -DCUE_L=2" ;;
    cue_L4)     echo "-DDNAC_CUE -DCUE_L=4" ;;
    cue_D6)     echo "-DDNAC_CUE -DCUE_D=6" ;;
    cue_D20)    echo "-DDNAC_CUE -DCUE_D=20" ;;
    cue_S8)     echo "-DDNAC_CUE -DCUE_SWITCH=8" ;;
    cue_S16)    echo "-DDNAC_CUE -DCUE_SWITCH=16" ;;
    cue_M8)     echo "-DDNAC_CUE -DCUE_MINLEN=8" ;;
    cue_M24)    echo "-DDNAC_CUE -DCUE_MINLEN=24" ;;
    # post-hoc, disclosed in docs/batch3.md: CUE_MINLEN 8 beat 16 and 24 was
    # worse, so the winning direction is extended past the registered grid.
    cue_M4)     echo "-DDNAC_CUE -DCUE_MINLEN=4" ;;
    cue_M2)     echo "-DDNAC_CUE -DCUE_MINLEN=2" ;;
    cue_M4x4)   echo "-DDNAC_CUE -DCUE_MINLEN=4 -DL1_NMIX=4" ;;
    cue_M4stcm) echo "-DDNAC_CUE -DCUE_MINLEN=4 -DL1_STCM=1" ;;
    # Batch 3's add-back: level 1 + cue, plus ONE thing level 3 has.
    cue_x4)     echo "-DDNAC_CUE -DL1_NMIX=4" ;;
    cue_ir)     echo "-DDNAC_CUE -DL1_IR=1" ;;
    cue_stcm)   echo "-DDNAC_CUE -DL1_STCM=1" ;;
    cue_ord)    echo "-DDNAC_CUE -DL1_ORDERS=1" ;;
    base_x4)    echo "-DL1_NMIX=4" ;;
    nudge)      echo "-DDNAC_NUDGE -DNUDGE_L=5 -DNUDGE_D=12" ;;
    L*D*)       l=${1#L}; l=${l%%D*}; d=${1##*D}
                echo "-DDNAC_NUDGE -DNUDGE_L=$l -DNUDGE_D=$d" ;;
    *) echo "unknown label: $1" >&2; exit 1 ;;
  esac
}
