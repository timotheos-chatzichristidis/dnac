#!/bin/sh
# Batch 5: the four peak-memory figures the README quotes for chr21. Peak
# working set is sampled by the OS, so these carry a percentage tolerance in
# verify-claims.ps1 rather than an exact one; this script exists to produce the
# numbers to write into the doc, and the rows re-derive them afterwards.
#
#   sh scripts/cue/batch5-ram.sh        # ~12 minutes, run it alone (-j 8 is 4.8 GB)
set -eu
. "$(cd "$(dirname "$0")" && pwd)/common.sh"
B=$WORK/b5ram; mkdir -p "$B"
SEQ=${SEQ:-$ROOT/bench-external/seq}
REL=$(build rel $(defines_for rel))
peak() {  # peak <label> <level> [blocks]
  lb=$1; lv=$2; jn=${3:-}
  set -- c "$SEQ/chr21.seq" "$B/r.dnac" 22 "$lv"
  [ -n "$jn" ] && set -- "$@" -j "$jn"
  ${PYTHON:-python} - "$REL" "$@" <<'PY'
import subprocess, sys, time, ctypes, ctypes.wintypes as w
p = subprocess.Popen(sys.argv[1:], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
K = ctypes.WinDLL('kernel32'); P = ctypes.WinDLL('psapi')
class PMC(ctypes.Structure):
    _fields_ = [("cb", w.DWORD), ("PageFaultCount", w.DWORD),
                ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t)]
h = K.OpenProcess(0x0400 | 0x0010, False, p.pid)
peak = 0
while p.poll() is None:
    m = PMC(); m.cb = ctypes.sizeof(m)
    if P.GetProcessMemoryInfo(h, ctypes.byref(m), m.cb):
        peak = max(peak, m.PeakWorkingSetSize)
    time.sleep(0.05)
print(int(peak / 1048576))
PY
}
echo "== chr21 peak working set, release build"
echo "  -l 3        $(peak l3 3) MB"
echo "  -l 4        $(peak l4 4) MB"
echo "  -l 3 -j 1   $(peak j1 3 1) MB"
echo "  -l 3 -j 8   $(peak j8 3 8) MB"
echo "RAM_DONE"
