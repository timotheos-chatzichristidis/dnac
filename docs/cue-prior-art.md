# The cue: prior art in the PAQ family

**Checked 2026-09-10**, after `docs/real-human.md` and before any claim that the
cue is new. Source read: paq8px `master`, shallow clone (`src/model/MatchModel.cpp`,
`MatchInfo.cpp`, `SparseMatchModel.{hpp,cpp}`, `CHANGELOG`). The DNA
context-mixing family (GeCo's STCM, JARVIS3's repeat models) was checked in
`docs/nudge-prediction.md`: substitution tolerance, or stop and restart. No
realignment.

## What paq8px has that looks close

| mechanism in paq8px | what it does | the same as the cue? |
|---|---|---|
| **Recovery mode** (`MatchInfo::update`, v181, 2019) | after a 1-byte mismatch, keeps a backup of the match at the **same** phase and resumes it if the next byte agrees | **No.** This is substitution recovery, which dnac already does by tolerance. It cannot follow an insertion or deletion. |
| **Several match candidates** (`MatchModel`, up to N, from the hash at three lengths) | keeps several independent hash matches alive at once | **No.** Only the best candidate predicts. The others add one bit of context ("candidates disagree"). None is the running match's shifted phase, and none is heard through a table conditioned on another's state. |
| **`SparseMatchModel`**, field `deletions` ("ignore these many initial post-match bytes, to model deletions") | re-finds a match through a hash that skips bytes, and could skip bytes after the match | **Closest, and still no.** It is a fresh hash lookup, not a shift of the running match. And **`deletions` is 0 in all four shipped configurations**: the knob exists and is not used. |

## What was not found anywhere

The cue as a combination:

1. a second deck **loaded at a shifted phase of the running match** at the
   moment that match loses the beat;
2. **permanently a mixer input**, never switched in or out;
3. heard through probabilities **indexed by the master's state** (the osmosis),
   so the trust in it is learned over the file;
4. **mixed in** only after it has kept agreeing, after which the cue goes idle.

## Verdict

The pieces have neighbours: backup-and-recover, several candidates, a parameter
meant for deletions. **The mechanism that produced −5.97% on a real human pair
was not found in paq8px, GeCo3 or JARVIS3.** That is absence at this depth of
reading (three code bases and their papers), not proof of absence. The claim to
make is narrow and specific: *a phase-shifted cue match model, conditioned on the
master's state, for insertion/deletion recovery in context-mixing DNA
compression*. It is not "indel handling", which alignment-style compressors have
always done.
