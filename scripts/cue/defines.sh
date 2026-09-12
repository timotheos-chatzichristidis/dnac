#!/bin/sh
# Print the compiler flags one experiment label is built with.
#
#   sh scripts/cue/defines.sh cue      ->  -DDNAC_CUE
#
# It exists so the two copies of that table -- this one, used by the shell
# scripts, and CueDefs in verify-claims.ps1, used by the claim rows -- can be
# compared against each other. Two tables that quietly disagree would mean the
# figures and the scripts measure different builds.
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"
defines_for "${1:?usage: defines.sh <label>}"
