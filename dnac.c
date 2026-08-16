/* dnac - a lossless DNA compressor
 *
 * Copyright (C) 2026 Timotheos Chatzichristidis
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. It is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License (LICENSE) for details.
 *
 * Idea in one breath:
 *   DNA is a 4-symbol alphabet (A,C,G,T). A naive byte-per-base file spends
 *   8 bits/base. The theoretical floor for *random* ACGT is 2 bits/base.
 *   But real DNA is NOT random: the next base is biased by the previous ones.
 *   We predict each base from the previous bases and feed those predictions to
 *   a range coder. The better we predict, the fewer bits we spend.
 *
 * Context mixing + match models (the heart of this version):
 *   We run an ENSEMBLE of order models (orders 1..k from a fixed list) PLUS
 *   three long-range predictors: two forward match models with different anchor
 *   lengths (a short/sensitive 13-mer and a longer/precise 16-mer) and one
 *   reverse-complement match model for inverted repeats. Each base is coded as 2
 *   binary decisions (a tree over {A,C,G,T}); for each bit, every predictor
 *   contributes, and a logistic mixer blends them in the logit domain with
 *   adaptively learned weights -- kept in a separate weight vector per match
 *   state, so "a long match is running" and "nothing matches" do not share one
 *   compromise. Two chained SSE/APM stages then recalibrate the result. Hot
 *   predictors get trusted, cold ones are ignored -- automatically, per bit.
 *   High orders use hashed tables so we can reach order ~22 without gigabytes.
 *
 * Lossless on ANY input:
 *   At every byte we first code a binary "is-this-a-base?" flag with its own
 *   model, contexted on the run-length of consecutive bases since the last
 *   non-base. FASTA wraps lines at a fixed width, so this run-context makes the
 *   periodic newlines almost free. Non-base bytes (headers, newlines, N,
 *   lowercase...) go through a separate order-0 byte model and never disturb the
 *   base history. Encoder and decoder run identical floating-point code in the
 *   same order, so the quantized probability fed to the coder is bit-identical.
 *
 * Build:  gcc -O2 -Wall -o dnac dnac.c -lm
 * Use:    dnac c input.fa  out.dnac  [k]     (compress, k = max order, default 22)
 *         dnac d out.dnac   roundtrip.fa     (decompress)
 *         dnac gen sample.fa 2000000 [seed]  (make a structured DNA sample)
 *
 * See README for the measured results and the "next improvements".
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

/* ----------------------- Range coder (Subbotin style) ----------------------- */
/* Carryless 32-bit range coder. Requires total frequency < BOT.               */

#define TOP (1u << 24)
#define BOT (1u << 16)

typedef struct { uint32_t low, range; FILE *out; } REnc;
typedef struct { uint32_t low, range, code; FILE *in; } RDec;

static void renc_init(REnc *e, FILE *out) { e->low = 0; e->range = 0xFFFFFFFFu; e->out = out; }

static void renc_renorm(REnc *e) {
    while ((e->low ^ (e->low + e->range)) < TOP ||
           (e->range < BOT && ((e->range = (0u - e->low) & (BOT - 1)), 1))) {
        fputc((int)(e->low >> 24), e->out);
        e->low <<= 8;
        e->range <<= 8;
    }
}

static void renc_encode(REnc *e, uint32_t cum, uint32_t freq, uint32_t tot) {
    e->range /= tot;
    e->low  += cum * e->range;
    e->range *= freq;
    renc_renorm(e);
}

static void renc_flush(REnc *e) {
    for (int i = 0; i < 4; i++) { fputc((int)(e->low >> 24), e->out); e->low <<= 8; }
}

static void rdec_init(RDec *d, FILE *in) {
    d->low = 0; d->range = 0xFFFFFFFFu; d->code = 0; d->in = in;
    for (int i = 0; i < 4; i++) d->code = (d->code << 8) | (uint32_t)(fgetc(d->in) & 0xFF);
}

static void rdec_renorm(RDec *d) {
    while ((d->low ^ (d->low + d->range)) < TOP ||
           (d->range < BOT && ((d->range = (0u - d->low) & (BOT - 1)), 1))) {
        d->code = (d->code << 8) | (uint32_t)(fgetc(d->in) & 0xFF);
        d->low <<= 8;
        d->range <<= 8;
    }
}

static uint32_t rdec_getfreq(RDec *d, uint32_t tot) {
    d->range /= tot;
    return (d->code - d->low) / d->range;
}

static void rdec_update(RDec *d, uint32_t cum, uint32_t freq) {
    d->low  += cum * d->range;
    d->range *= freq;
    rdec_renorm(d);
}

/* ---- binary coding on top of the range coder ----------------------------- */
/* A bit is coded with p1 = P(bit==1) given as an integer out of PSCALE.      */
/* Symbol 0 occupies [0, p0), symbol 1 occupies [p0, PSCALE), p0 = PSCALE-p1. */
#ifndef PBITS
#define PBITS  14
#endif
#define PSCALE (1u << PBITS)               /* must stay < BOT */

/* Bits are coded by SPLITTING the range with a multiply, not by dividing it by a
   total frequency. Dividing throws away up to tot/range of the interval on every
   symbol, which is why simply asking for finer probabilities made things worse:
   the resolution gained was smaller than the interval lost. With the multiply the
   two stop fighting, and p can be given to 16 bits -- which matters enormously
   when the model is nearly always right (a genome against its own reference),
   where the cost floor of a 12-bit p was ~0.00035 bit per bit, i.e. ~400 bytes
   per 4.6 Mbase genome, about a third of what such a file costs in total. */
static void renc_bit(REnc *e, int bit, uint32_t p1) {
    uint32_t bound = (e->range >> PBITS) * (PSCALE - p1);   /* the "bit==0" part */
    if (bit) { e->low += bound; e->range -= bound; }
    else     { e->range = bound; }
    renc_renorm(e);
}
static int rdec_bit(RDec *d, uint32_t p1) {
    uint32_t bound = (d->range >> PBITS) * (PSCALE - p1);
    int bit;
    if ((uint32_t)(d->code - d->low) < bound) { d->range = bound; bit = 0; }
    else { d->low += bound; d->range -= bound; bit = 1; }
    rdec_renorm(d);
    return bit;
}

/* ----------------------------- Models --------------------------------------- */

#define CAP 8192u   /* rescale a count model before its total reaches BOT       */
#define RUNCAP 1023 /* cap the base-run length used as context for the flag      */

/* flag model: binary {base, non-base}, contexted on run-length (0..RUNCAP)   */
static uint16_t flag_cnt[(RUNCAP + 1) * 2];
/* literal model: order-0 over 256 byte values, for escaped (non-ACGT) bytes  */
static uint16_t lit_cnt[256];

static int base_to_sym(int c) {
    switch (c) { case 'A': return 0; case 'C': return 1; case 'G': return 2; case 'T': return 3; }
    return -1; /* not a base */
}
static const char SYM_TO_BASE[4] = { 'A', 'C', 'G', 'T' };

/* ---- Context-mixing base model -------------------------------------------- */
/* Predictors feed a logistic mixer. Each base is coded as 2 bits via a tree:  */
/*   node 0: group {A,C}=0 vs {G,T}=1     (the high bit)                        */
/*   node 1: A=0 vs C=1 (the low bit, when high bit was 0)                      */
/*   node 2: G=0 vs T=1 (the low bit, when high bit was 1)                      */
/* For each predictor and node we store one adaptive probability P(bit==1)     */
/* scaled to [0,PSCALE]. The mixer blends their stretched values.              */

#define MAXIN     16     /* max mixer inputs = order models + 1 match model     */
#define NNODES    3
/* Hash tables are sized from the input length (which the decoder reads from the
   header, so both sides pick the same size and stay in lockstep): one slot per
   base is wasteful for a 1 KB file and far too few for a chromosome. */
#ifndef HASHBITS_MAX
#define HASHBITS_MAX 26
#endif
#define HASHBITS_MIN 18
#ifndef HASH_EXTRA
#define HASH_EXTRA 0    /* extra doublings of the order-model tables (memory) */
#endif
#ifndef MH_EXTRA
#define MH_EXTRA 0      /* extra doublings of the anchor tables */
#endif
static int      g_hashbits;
static uint32_t g_hashmask;

#ifndef MIX_LR
#define MIX_LR  0.0010   /* mixer learning rate (overridable: -DMIX_LR=...)    */
#endif
/* Adaptive-rate bit counter, packed in one uint16: 12-bit prob | 4-bit count.
   Early updates move far (rate 1/(n+2)), later ones settle to 1/(LIMIT+2).
   A fixed shift makes cold high-order contexts learn far too slowly. */
#ifndef CTR_DIV
#define CTR_DIV 3
#endif
#define CTR_LIMIT 15
#define CTR_INIT  ((uint16_t)(2048u << 4))
#define W_INIT  0.20     /* initial mixer weight per input                     */
#define DIRECT_MAXORDER 8 /* orders <= this use a direct table, else hashed    */

/* The mixer keeps a SEPARATE weight vector per (node, mixer-context): how much to
   trust the match models vs the order models depends strongly on which matches are
   running and how confident they are, and one global weight vector has to average
   those regimes together. Context = short-anchor confidence (4) x rc (2) x long (2). */
#define MIXCTX 64

/* SSE / APM: second-stage maps that recalibrate the mixer's probability by      */
/* context. Start as the identity map, then learn. APM_BINS points span stretch. */
/* Two chained stages with DIFFERENT contexts: stage 1 keyed on match state,      */
/* stage 2 on the last 6 bases. Each is blended 50/50 with its own input, because  */
/* the mixer is already well calibrated and a raw APM output mostly adds noise.    */
#define APM_BINS 33
#define APM_RATE 0.020
#define APM1_NCTX (NNODES * 4)
#define APM2_NCTX (NNODES * 4096)   /* node x last 6 bases                        */
#define APM_MAXCTX (APM1_NCTX > APM2_NCTX ? APM1_NCTX : APM2_NCTX)

static const int MASTER_ORDERS[] = { 1, 2, 3, 4, 6, 8, 11, 14, 18, 22 };

/* Substitution-tolerant context models (the GeCo idea we were missing).
   A normal order model conditions on the last k bases AS THEY ARE. Inside a
   diverged repeat, one SNP poisons the next k contexts: they have never been
   seen, so k models go cold at once. A tolerant model instead keeps a REPAIRED
   history -- when its own top guess turns out wrong, it pushes the guess it
   made rather than the base that actually occurred, so the context stays
   aligned with the earlier copy of the repeat. Give up (resync to the true
   history) after TOL_MAX failures, otherwise it would drift into fiction.
   Unlike the match models, which follow one anchored position, this one
   aggregates statistics over EVERY past occurrence of the repaired context. */
#ifndef IR_TOL
#define IR_TOL 1    /* also train the tolerant models on the other strand */
#endif
#ifndef IR_MODE
#define IR_MODE 2   /* 0=off, 1=hashed orders only, 2=every order model */
#endif
#ifndef NSTCM
#define NSTCM 2
#endif
#ifndef TOL_MAX
#define TOL_MAX 8               /* failures tolerated before resyncing            */
#endif
static const int TOL_ORDERS[] = { 16, 20, 12 };   /* first NSTCM of these are used */
static uint64_t  g_thist;                   /* the repaired history                */
static int       g_tfail;                   /* failures since the last resync      */
static int       g_tpred;                   /* this base's guess by the first STCM  */
static int       g_nstcm;

static int       g_nmodels;                 /* number of order models (incl. STCMs) */
static int       g_nin;                     /* total mixer inputs = g_nmodels + 1 */
static int       g_order[MAXIN];
static int       g_tol[MAXIN];              /* 1 = reads the repaired history      */
static int       g_ir[MAXIN];               /* 1 = also trained on the other strand */
static int       g_direct[MAXIN];
static uint64_t  g_ctxmask[MAXIN];          /* (1<<(2*order))-1, picks last `order` bases */
static size_t    g_size[MAXIN];
static uint16_t *g_tab[MAXIN];              /* order-model probability tables      */
#define NMIX 4                                  /* experts in the first mixing layer */
#ifndef MIX_LR2
#define MIX_LR2 0.0005                           /* second-layer learning rate        */
#endif
static double    g_w[NMIX][NNODES][MIXCTX][MAXIN]; /* expert weights per node/ctx/input */
static double    g_v[NNODES][MIXCTX][NMIX + 1];    /* second layer (+bias), per regime  */
typedef struct { double x[NMIX], p[NMIX]; } MixState;
static uint32_t pq_of_(double p);
static double    g_apm1[APM_MAXCTX][APM_BINS]; /* SSE stage 1 (match-state context) */
static double    g_apm2[APM_MAXCTX][APM_BINS]; /* SSE stage 2 (order-2 context)     */

/* ---- Match models --------------------------------------------------------- */
/* TWO forward match models with different anchor lengths. A short anchor (13)
   is SENSITIVE: it re-finds diverged repeats (human Alus are only ~85% identical,
   so long exact anchors rarely hit). A long anchor (24) is PRECISE: when it fires
   it is almost never a coincidence, so the mixer can trust it much harder. One
   model has to compromise between the two; two models let the mixer pick. */
#ifndef MMIN
#define MMIN      13            /* short/sensitive anchor (bases)                 */
#endif
#ifndef MMIN2
#define MMIN2     16            /* long/precise anchor                            */
#endif
#ifndef MHBITS_MAX
#define MHBITS_MAX 26           /* anchor tables are sized from the input length  */
#endif
#ifndef MWAYS
#define MWAYS     1             /* candidates kept per anchor bucket (2 measured neutral) */
#endif
#ifndef MVERIFY
#define MVERIFY   32            /* how far back to compare when picking one       */
#endif
#ifndef MWAY_EXTRA
#define MWAY_EXTRA 0            /* extra bucket-bits (memory) when MWAYS > 1       */
#endif
#define MLENCAP   63            /* cap on match length used as confidence bucket  */
#define MISS_MAX  8             /* abandon a match after this many consecutive misses */
#define MATCH_EMPTY 0xFFFFFFFFu

static uint8_t  *g_seq   = NULL;            /* base symbols (0..3) seen so far     */
static uint32_t  g_npos  = 0;               /* count of bases in g_seq             */

typedef struct {
    int       minlen;                       /* anchor length in bases              */
    int       hbits;
    uint32_t *hash;                         /* context -> last end position        */
    uint32_t  mp, mlen;                     /* follow position + confidence        */
    int       active, miss;
    /* adaptive probs, indexed by (node, just-missed flag, conf bucket, pred bit)  */
    uint16_t  pr[NNODES * 2 * (MLENCAP + 1) * 2];
} MatchModel;

#define NMATCH 2
static MatchModel g_mm[NMATCH];

/* reverse-complement match: same idea, but predicts complement(seq[rmp]) and walks
   BACKWARD through history (rmp--). Anchored by looking up the RC of the current
   context in the SAME forward hash table. Catches inverted repeats. */
static uint32_t  g_rmp     = 0;
static uint32_t  g_rlen    = 0;
static int       g_ractive = 0;
static int       g_rmiss   = 0;
static uint16_t  g_rc_pr[NNODES * 2 * (MLENCAP + 1) * 2];

static double stretchd(double p) { return log(p / (1.0 - p)); }
static double squashd(double x)  { return 1.0 / (1.0 + exp(-x)); }

/* packed counter helpers (12-bit probability + 4-bit observation count) */
static double ctr_p(uint16_t v) { return ((double)(v >> 4) + 0.5) / 4096.0; }
static void ctr_upd(uint16_t *sp, int bit) {
    int n = *sp & 15, pv = *sp >> 4;
    int target = bit ? 4095 : 0;
    pv += (target - pv) / (CTR_DIV * n + 2);
    if (n < CTR_LIMIT) n++;
    *sp = (uint16_t)((pv << 4) | n);
}

/* Slot for (order model i, packed context ctx, tree node).
   Hashed models store one BUCKET per context: [checksum][node0][node1][node2].
   The checksum turns a hash collision from "two contexts silently share and blur
   one counter" into "the loser is detected and reset", and keeping all three
   nodes of a base together costs one cache miss instead of two. */
#define BUCKETW 4
static uint16_t *mix_slot(int i, uint64_t ctx, int node) {
    if (g_direct[i]) return &g_tab[i][ctx * NNODES + (uint64_t)node];
    uint64_t key = ctx + 0x9E3779B97F4A7C15ull;
    key *= 0x9E3779B97F4A7C15ull; key ^= key >> 32;
    key *= 0xD6E8FEB86659FD93ull; key ^= key >> 29;
    uint16_t chk = (uint16_t)((key >> 48) | 1u);        /* 0 means "never used" */
    /* 2-way set: the pair sits in one cache line, so the second probe is free.
       On a miss evict the entry with the fewer observations behind it. */
    uint16_t *b0 = &g_tab[i][(size_t)(key & g_hashmask & ~(uint64_t)1) * BUCKETW];
    uint16_t *b1 = b0 + BUCKETW;
    uint16_t *b;
    if      (b0[0] == chk) b = b0;
    else if (b1[0] == chk) b = b1;
    else {
        int c0 = (b0[1] & 15) + (b0[2] & 15) + (b0[3] & 15);
        int c1 = (b1[1] & 15) + (b1[2] & 15) + (b1[3] & 15);
        b = (c1 < c0) ? b1 : b0;
        b[0] = chk; b[1] = b[2] = b[3] = CTR_INIT;
    }
    return &b[1 + node];
}

/* (Tried and rejected here: replacing these per-context probabilities with
   lpaq-style bit-history STATES + a shared StateMap. It costs 0.3-0.7% on DNA,
   because a 4-bit-per-side history caps confidence near p=0.94 while a good
   order-16 DNA context is nearly deterministic and wants p>0.99. That design
   wins on text, where nonstationarity matters more than sharpness.) */

static uint32_t mhash(uint64_t c, int hbits) {
    c *= 0x9E3779B97F4A7C15ull;
    return (uint32_t)(c >> (64 - hbits));
}

/* One match model's adaptive probability slot for this node.                  */
/* b1 is the (already known) high bit when predicting a low-bit node.          */
static uint16_t *match_slot_of(MatchModel *m, int node, int b1) {
    int bucket = 0, pbit = 0;
    int mflag = (m->miss > 0) ? 1 : 0;      /* are we predicting right after a mismatch? */
    if (m->active && m->mlen > 0 && m->mp < g_npos) {
        int psym = g_seq[m->mp];
        if (node == 0) {
            pbit = psym >> 1;
            bucket = (m->mlen < MLENCAP) ? (int)m->mlen : MLENCAP;
        } else if ((psym >> 1) == b1) {     /* match still on-track for this symbol */
            pbit = psym & 1;
            bucket = (m->mlen < MLENCAP) ? (int)m->mlen : MLENCAP;
        }
    }
    return &m->pr[(((node * 2 + mflag) * (MLENCAP + 1)) + bucket) * 2 + pbit];
}

/* Reverse-complement of the last `len` bases, packed like a forward context     */
/* (complement = 3 - base; reversing the order falls out of the shift loop).    */
static uint64_t rc_context(uint64_t hist, int len) {
    uint64_t c = hist, rc = 0;
    for (int j = 0; j < len; j++) { rc = (rc << 2) | (3 - (c & 3)); c >>= 2; }
    return rc;
}

/* The RC match model's adaptive probability slot for this node. Predicted base  */
/* is the complement of seq[g_rmp].                                              */
static uint16_t *rc_slot(int node, int b1) {
    int bucket = 0, pbit = 0;
    int mflag = (g_rmiss > 0) ? 1 : 0;
    if (g_ractive && g_rlen > 0 && g_rmp < g_npos) {
        int psym = 3 - g_seq[g_rmp];
        if (node == 0) {
            pbit = psym >> 1;
            bucket = (g_rlen < MLENCAP) ? (int)g_rlen : MLENCAP;
        } else if ((psym >> 1) == b1) {
            pbit = psym & 1;
            bucket = (g_rlen < MLENCAP) ? (int)g_rlen : MLENCAP;
        }
    }
    return &g_rc_pr[(((node * 2 + mflag) * (MLENCAP + 1)) + bucket) * 2 + pbit];
}

/* How many bases agree, walking backwards from two end positions. Used to pick
   between the candidates in an anchor bucket: a hash hit only proves the last
   `minlen` bases agree (and may be a collision), while the candidate whose
   context agrees FURTHER back is the one more likely to keep agreeing forward. */
static int back_agree(uint32_t a, uint32_t b, int cap) {
    int l = 0;
    while (l < cap && a >= (uint32_t)l && b >= (uint32_t)l &&
           g_seq[a - l] == g_seq[b - l]) l++;
    return l;
}

/* INVERTED-REPEAT TRAINING (the "mirroring" idea, applied to the context models
   rather than only to a match model).
   DNA is double-stranded: the stretch we just read also exists, physically, as
   its reverse complement. Read along that other strand, the last `order` bases
   we just saw form the CONTEXT, and the base that has just fallen out of the
   window is what FOLLOWS them (complemented). So after every base we can hand
   each order model a second, free training example taken from the other strand
   -- same tables, no extra prediction. A context first seen as an inverted
   repeat is then already warm when it later shows up the normal way round.
   This is the flag GeCo's model templates call "ir"; we had it only on the
   match model. Update-only, so encoder and decoder stay in lockstep. */
static void ir_train(uint64_t newhist, uint64_t tolhist) {
    for (int i = 0; i < g_nmodels; i++) {
        if (!g_ir[i]) continue;
        int o = g_order[i];
        if (g_npos < (uint32_t)o + 1) continue;
        uint64_t h = g_tol[i] ? tolhist : newhist;
        uint64_t rctx = rc_context(h, o);           /* the other strand's context */
        int sym = 3 - (int)((h >> (2 * o)) & 3);          /* ...and what follows it     */
        int b1 = sym >> 1, b0 = sym & 1;
        uint16_t *b = mix_slot(i, rctx, 0);               /* both nodes, one bucket     */
        ctr_upd(&b[0], b1);
        ctr_upd(&b[1 + b1], b0);
    }
}

/* After a base symbol s is known: append it, follow/break every match, and    */
/* refresh the hash anchors (newhist already includes s).                       */
static void match_after(int s, uint64_t newhist) {
    uint32_t np = g_npos;
    g_seq[np] = (uint8_t)s;
    g_npos = np + 1;

    uint32_t hidx[NMATCH];
    for (int mi = 0; mi < NMATCH; mi++) {
        MatchModel *m = &g_mm[mi];
        if (m->active && m->mp < np) {
            if (g_seq[m->mp] == (uint8_t)s) {       /* hit: grow confidence */
                if (m->mlen < MLENCAP) m->mlen++;
                m->miss = 0;
                m->mp++;
            } else {                                /* miss: tolerate, drop confidence */
                m->mlen >>= 1;
                m->miss++;
                m->mp++;
                if (m->miss > MISS_MAX) m->active = 0;
            }
            if (m->mp >= g_npos) m->active = 0;
        } else {
            m->active = 0;
        }

        uint64_t ctxm = newhist & (((uint64_t)1 << (2 * m->minlen)) - 1);
        hidx[mi] = mhash(ctxm, m->hbits) * MWAYS;
        /* (Re)anchor only when idle or confidence has collapsed. We deliberately do NOT
           re-anchor on every miss: on real (repetitive) genomes the post-SNP context
           often hash-hits, and re-anchoring there abandons good diverged matches and
           hurts compression -- measured, not assumed. */
        if (!m->active || m->mlen == 0) {
            uint32_t best = MATCH_EMPTY; int bestlen = -1;
            for (int w = 0; w < MWAYS; w++) {
                uint32_t cand = m->hash[hidx[mi] + w];
                if (cand == MATCH_EMPTY) continue;
                int l = back_agree(cand, np, MVERIFY);
                if (l > bestlen) { bestlen = l; best = cand; }
            }
            if (best != MATCH_EMPTY) { m->mp = best + 1; m->active = 1; m->mlen = 1; m->miss = 0; }
        }
    }

    /* reverse-complement follow: predict complement(seq[rmp]), walk backward */
    if (g_ractive && g_rmp < np) {
        int pred = 3 - g_seq[g_rmp];
        if (pred == s) { if (g_rlen < MLENCAP) g_rlen++; g_rmiss = 0; }
        else { g_rlen >>= 1; g_rmiss++; if (g_rmiss > MISS_MAX) g_ractive = 0; }
        if (g_rmp == 0) g_ractive = 0; else g_rmp--;
    } else {
        g_ractive = 0;
    }
    /* RC (re)anchor: find a forward occurrence of the RC of the current context
       (uses the short model's hash, i.e. the sensitive anchor length). */
    if (!g_ractive || g_rlen == 0) {
        /* The SHORT anchor, deliberately: preferring the longer/safer 16-mer here
           measured worse (1.7118 -> 1.7139 on chr21). Inverted repeats are as
           diverged as forward ones, so sensitivity beats precision again. */
        int rl = g_mm[0].minlen;
        uint32_t rprev = g_mm[0].hash[mhash(rc_context(newhist, rl), g_mm[0].hbits) * MWAYS];
        if (rprev != MATCH_EMPTY && rprev >= (uint32_t)rl) {
            uint32_t cand = rprev - rl;     /* base just left of the matched region */
            if (cand < g_npos) { g_rmp = cand; g_ractive = 1; g_rlen = 1; g_rmiss = 0; }
        }
    }

    /* store AFTER all anchors so nothing self-matches; the bucket keeps the most
       recent MWAYS occurrences of this context, newest first */
    for (int mi = 0; mi < NMATCH; mi++) {
        uint32_t *b = &g_mm[mi].hash[hidx[mi]];
        for (int w = MWAYS - 1; w > 0; w--) b[w] = b[w - 1];
        b[0] = np;
    }
}

/* table size for an input of n bytes: the next power of two above n, clamped */
static int size_bits(size_t n, int cap) {
    int b = HASHBITS_MIN;
    while (((size_t)1 << b) < n && b < cap) b++;
    if (b < cap) b++;                 /* one doubling of headroom for collisions */
    return b;
}

static int g_mhb;   /* anchor-table bucket bits, remembered for state files */

/* Build the ensemble + match tables. `sizing_n` decides the table sizes and
   `seq_alloc` how much history we can hold; in reference mode the sizes come
   from the REFERENCE alone, so a primed state can be built (and saved) before
   any target is known, and priming from a FASTA or from a state file give
   bit-identical models. hb/mhb override the computed sizes when a state file
   dictates them. Returns 0 on success. */
static int mix_setup(int maxorder, size_t sizing_n, size_t seq_alloc, int hb, int mhb) {
    /* g_hashbits counts BUCKETS of BUCKETW uint16, so the byte footprint of a
       hashed model is the same as it was with one uint16 per (context,node). */
    g_hashbits = (hb > 0) ? hb : size_bits(sizing_n, HASHBITS_MAX) - 2 + HASH_EXTRA;
    g_hashmask = (uint32_t)(((size_t)1 << g_hashbits) - 1);
    g_nmodels = 0;
    for (size_t m = 0; m < sizeof(MASTER_ORDERS) / sizeof(MASTER_ORDERS[0]); m++) {
        int o = MASTER_ORDERS[m];
        if (o > maxorder) continue;
        int i = g_nmodels;
        g_order[i]   = o;
        g_tol[i]     = 0;
        g_ir[i]      = (IR_MODE == 2) || (IR_MODE == 1 && o > DIRECT_MAXORDER);
        g_ctxmask[i] = (o >= 32) ? ~0ull : ((1ull << (2 * o)) - 1);
        if (o <= DIRECT_MAXORDER) {
            g_direct[i] = 1;
            g_size[i]   = (size_t)(1ull << (2 * o)) * NNODES;
        } else {
            g_direct[i] = 0;
            g_size[i]   = ((size_t)1 << g_hashbits) * BUCKETW;
        }
        g_tab[i] = (uint16_t *)malloc(g_size[i] * sizeof(uint16_t));
        if (!g_tab[i]) { fprintf(stderr, "out of memory for order-%d model\n", o); return -1; }
        if (g_direct[i]) { for (size_t j = 0; j < g_size[i]; j++) g_tab[i][j] = CTR_INIT; }
        else memset(g_tab[i], 0, g_size[i] * sizeof(uint16_t));  /* checksum 0 = unused */
        g_nmodels++;
    }
    /* substitution-tolerant models, same tables but fed the repaired history */
    g_nstcm = 0;
    g_thist = 0; g_tfail = 0; g_tpred = 0;
    for (int t = 0; t < NSTCM && t < (int)(sizeof(TOL_ORDERS)/sizeof(TOL_ORDERS[0])); t++) {
        int o = TOL_ORDERS[t];
        if (o > maxorder) continue;
        int i = g_nmodels;
        g_order[i]   = o;
        g_tol[i]     = 1;
        g_ir[i]      = IR_TOL;
        g_direct[i]  = 0;
        g_ctxmask[i] = (1ull << (2 * o)) - 1;
        g_size[i]    = ((size_t)1 << g_hashbits) * BUCKETW;
        g_tab[i] = (uint16_t *)malloc(g_size[i] * sizeof(uint16_t));
        if (!g_tab[i]) { fprintf(stderr, "out of memory for tolerant model\n"); return -1; }
        memset(g_tab[i], 0, g_size[i] * sizeof(uint16_t));
        g_nmodels++; g_nstcm++;
    }
    g_nin = g_nmodels + NMATCH + 1;  /* + forward matches + reverse-complement match */
    if (g_nin > MAXIN) { fprintf(stderr, "too many mixer inputs\n"); return -1; }
    for (int k = 0; k < NMIX; k++)
        for (int n = 0; n < NNODES; n++)
            for (int c = 0; c < MIXCTX; c++)
                for (int i = 0; i < g_nin; i++) g_w[k][n][c][i] = W_INIT;
    for (int n = 0; n < NNODES; n++)
        for (int c = 0; c < MIXCTX; c++) {
            for (int k = 0; k < NMIX; k++) g_v[n][c][k] = 1.0 / NMIX;
            g_v[n][c][NMIX] = 0.0;
        }

    /* SSE/APM: initialise every context's curve in both stages to the identity map */
    for (int c = 0; c < APM_MAXCTX; c++)
        for (int j = 0; j < APM_BINS; j++) {
            double id = squashd(-8.0 + 16.0 * j / (APM_BINS - 1));
            g_apm1[c][j] = id;
            g_apm2[c][j] = id;
        }

    /* match models (2 forward anchors + reverse-complement) */
    g_npos = 0;
    static const int MM_LEN[NMATCH] = { MMIN, MMIN2 };
    /* Anchor tables get two extra doublings of headroom: a collision here does not
       blur statistics, it hands the model a WRONG match to follow, so slack pays. */
    if (mhb <= 0) {
        mhb = size_bits(sizing_n, MHBITS_MAX) + 2 + MH_EXTRA;
        if (mhb > MHBITS_MAX) mhb = MHBITS_MAX;
    }
    g_mhb = mhb;
    int waybits = 0; while ((1 << (waybits + 1)) <= MWAYS) waybits++;
    for (int mi = 0; mi < NMATCH; mi++) {
        MatchModel *m = &g_mm[mi];
        m->minlen = MM_LEN[mi];
        /* hbits counts BUCKETS; total entries stay 2^mhb whatever MWAYS is */
        m->hbits  = mhb - mi - waybits + MWAY_EXTRA;
        if (m->hbits < 8) m->hbits = 8;
        m->mp = 0; m->mlen = 0; m->active = 0; m->miss = 0;
        for (size_t j = 0; j < sizeof(m->pr) / sizeof(m->pr[0]); j++) m->pr[j] = CTR_INIT;
        size_t hs = ((size_t)1 << m->hbits) * MWAYS;
        m->hash = (uint32_t *)malloc(hs * sizeof(uint32_t));
        if (!m->hash) { fprintf(stderr, "out of memory for match model\n"); return -1; }
        memset(m->hash, 0xFF, hs * sizeof(uint32_t));   /* all = MATCH_EMPTY */
    }
    g_rmp = 0; g_rlen = 0; g_ractive = 0; g_rmiss = 0;
    for (size_t j = 0; j < sizeof(g_rc_pr) / sizeof(g_rc_pr[0]); j++) g_rc_pr[j] = CTR_INIT;
    g_seq = (uint8_t *)malloc(seq_alloc ? seq_alloc : 1);
    if (!g_seq) { fprintf(stderr, "out of memory for match model\n"); return -1; }
    return 0;
}
static void mix_free(void) {
    for (int i = 0; i < g_nmodels; i++) { free(g_tab[i]); g_tab[i] = NULL; }
    free(g_seq);   g_seq = NULL;
    for (int mi = 0; mi < NMATCH; mi++) { free(g_mm[mi].hash); g_mm[mi].hash = NULL; }
}

/* Predict P(bit==1) for `node`. mslot is the match model's slot for this node. */
/* Fills st[] (stretched inputs), slot[] (pointers to update), *pout (mixed p). */
/* which weight vector to use: how confident the match models currently are */
static int mix_ctx(void) {
    MatchModel *m = &g_mm[0];
    int fb = 0;
    if (m->active && m->mlen > 0) fb = (m->mlen >= 24) ? 3 : ((m->mlen >= 6) ? 2 : 1);
    int lb = (g_mm[1].active && g_mm[1].mlen > 0) ? 1 : 0;   /* long anchor running? */
    return (fb * 2 + ((g_ractive && g_rlen > 0) ? 1 : 0)) * 2 + lb;
}

/* The tolerant model's own most likely base, from its three node counters.
   They live in one bucket, so this is a single lookup: mix_slot returns &b[1],
   and b[1],b[2],b[3] are nodes 0,1,2 of the same context. */
static int stcm_argmax(int i, uint64_t ctx) {
    uint16_t *s = mix_slot(i, ctx, 0);
    double p0 = ctr_p(s[0]);              /* P(base is G or T)     */
    double p1 = ctr_p(s[1]);              /* P(C | base is A or C) */
    double p2 = ctr_p(s[2]);              /* P(T | base is G or T) */
    double p[4];
    p[0] = (1.0 - p0) * (1.0 - p1);  p[1] = (1.0 - p0) * p1;
    p[2] = p0 * (1.0 - p2);          p[3] = p0 * p2;
    int best = 0;
    for (int j = 1; j < 4; j++) if (p[j] > p[best]) best = j;
    return best;
}

/* called before coding a base: what does the tolerant model expect? */
static void stcm_prepare(void) {
    if (g_nstcm > 0) {
        int i = g_nmodels - g_nstcm;                      /* the first STCM */
        g_tpred = stcm_argmax(i, g_thist & g_ctxmask[i]);
    }
}

/* called once the base is known: repair the history, or give up and resync */
static void stcm_after(int s, uint64_t truehist) {
    if (g_nstcm == 0) return;
    if (g_tpred == s) {
        g_thist = (g_thist << 2) | (uint64_t)s;
        if (g_tfail > 0) g_tfail--;
    } else if (++g_tfail > TOL_MAX) {
        g_thist = truehist;                               /* the repeat is over */
        g_tfail = 0;
    } else {
        g_thist = (g_thist << 2) | (uint64_t)g_tpred;     /* assume a substitution */
    }
}

/* the non-order inputs for this node: every forward match model, then the RC one */
static void extra_slots(int node, int b1, uint16_t **ex) {
    for (int mi = 0; mi < NMATCH; mi++) ex[mi] = match_slot_of(&g_mm[mi], node, b1);
    ex[NMATCH] = rc_slot(node, b1);
}

/* TWO-LAYER MIXING. One mixer has to pick a single context to specialise on.
   Instead we run NMIX mixers over the SAME inputs, each keyed on a different
   context (match state / recent bases / match confidence), each trained on its
   own error so each becomes an expert in its own regime -- then a small second
   layer learns how much to trust each expert, per node. This is what separates
   GeCo3 from GeCo2 and what PAQ has always done. */
static void mix_ctxs(uint64_t hist, int *mc) {
    mc[0] = mix_ctx();                                     /* which matches run   */
    mc[1] = (int)(hist & 63);                              /* last three bases     */
    MatchModel *m = &g_mm[0];
    int conf = (!m->active || m->mlen == 0) ? 0
             : (m->mlen >= 32 ? 3 : (m->mlen >= 12 ? 2 : 1));
    mc[2] = conf * 4 + (g_nstcm > 0 ? (g_tfail > 0 ? 2 : 0) : 0) + (g_mm[1].active ? 1 : 0);
    mc[3] = 0;                                             /* one global expert    */
}

static uint32_t mix_predict(int node, const int *mc, const uint64_t *ctxv, uint16_t **extra,
                            double *st, uint16_t **slot, MixState *ms, double *pout) {
    for (int i = 0; i < g_nmodels; i++) {
        uint16_t *sp = mix_slot(i, ctxv[i], node);
        slot[i] = sp;
        st[i] = stretchd(ctr_p(*sp));
    }
    for (int e = 0; e < NMATCH + 1; e++) {          /* forward matches, RC match */
        int i = g_nmodels + e;
        slot[i] = extra[e];
        st[i] = stretchd(ctr_p(*extra[e]));
    }
    double X = g_v[node][mc[0]][NMIX];              /* layer-2 bias              */
    for (int k = 0; k < NMIX; k++) {
        double x = 0.0;
        const double *w = g_w[k][node][mc[k]];
        for (int i = 0; i < g_nin; i++) x += w[i] * st[i];
        if (x < -12.0) x = -12.0;                   /* keep one expert from */
        if (x >  12.0) x =  12.0;                   /* dominating the layer above */
        ms->x[k] = x;
        ms->p[k] = squashd(x);
        X += g_v[node][mc[0]][k] * x;
    }
    double pp = squashd(X);
    *pout = pp;
    return pq_of_(pp);
}

/* After observing `bit`: every expert learns from ITS OWN error, the second
   layer from the final one, and each input's bit-predictor from the bit. */
static void mix_update(int node, const int *mc, const double *st, uint16_t *const *slot,
                       int bit, double pp, const MixState *ms) {
    double errf = (double)bit - pp;
    for (int k = 0; k < NMIX; k++) {
        double errk = (double)bit - ms->p[k];
        double *w = g_w[k][node][mc[k]];
        for (int i = 0; i < g_nin; i++) w[i] += MIX_LR * errk * st[i];
        g_v[node][mc[0]][k] += MIX_LR2 * errf * ms->x[k];
    }
    g_v[node][mc[0]][NMIX] += MIX_LR2 * errf;
    for (int i = 0; i < g_nin; i++) ctr_upd(slot[i], bit);
}

/* quantize a probability in (0,1) to the coder's [1, PSCALE-1] */
static uint32_t pq_of_(double p) { 
    uint32_t q = (uint32_t)(p * (double)PSCALE + 0.5);
    if (q < 1)          q = 1;
    if (q > PSCALE - 1) q = PSCALE - 1;
    return q;
}
static uint32_t pq_of(double p) {
    uint32_t q = (uint32_t)(p * (double)PSCALE + 0.5);
    if (q < 1)          q = 1;
    if (q > PSCALE - 1) q = PSCALE - 1;
    return q;
}

/* APM: map probability p through the context's calibration curve (interpolated). */
/* Returns the refined probability; reports the two bin index/weight for update.  */
static double apm_apply(double tab[][APM_BINS], int ctx, double p, int *jout, double *fout) {
    double s = stretchd(p);
    if (s < -8.0) s = -8.0;
    if (s >  8.0) s =  8.0;
    double pos = (s + 8.0) / 16.0 * (APM_BINS - 1);
    int j = (int)pos;
    if (j > APM_BINS - 2) j = APM_BINS - 2;
    double frac = pos - j;
    *jout = j; *fout = frac;
    return tab[ctx][j] * (1.0 - frac) + tab[ctx][j + 1] * frac;
}
static void apm_update(double tab[][APM_BINS], int ctx, int j, double frac, int bit) {
    double t = bit ? 1.0 : 0.0;
    tab[ctx][j]     += APM_RATE * (1.0 - frac) * (t - tab[ctx][j]);
    tab[ctx][j + 1] += APM_RATE * frac         * (t - tab[ctx][j + 1]);
}
/* stage-1 context: node x which match models are running                       */
/* stage-2 context: node x the last 6 bases (measured better than 2 or 4)       */
static int apm1_ctx(int node) {
    return node * 4 + (g_mm[0].active ? 1 : 0) + (g_ractive ? 2 : 0);
}
static int apm2_ctx(int node, uint64_t hist) { return node * 4096 + (int)(hist & 4095); }

/* run both SSE stages; returns the final probability, records update state */
typedef struct { int j1, j2; double f1, f2; } SSEState;
static double sse_apply(int node, uint64_t hist, double pmix, SSEState *ss) {
    double q1 = apm_apply(g_apm1, apm1_ctx(node), pmix, &ss->j1, &ss->f1);
    double p2 = 0.5 * (q1 + pmix);
    double q2 = apm_apply(g_apm2, apm2_ctx(node, hist), p2, &ss->j2, &ss->f2);
    return 0.5 * (q2 + p2);
}
static void sse_update(int node, uint64_t hist, const SSEState *ss, int bit) {
    apm_update(g_apm1, apm1_ctx(node), ss->j1, ss->f1, bit);
    apm_update(g_apm2, apm2_ctx(node, hist), ss->j2, ss->f2, bit);
}

/* Same model path as coding a base, but nothing is written: used to walk a
   REFERENCE sequence so every model (counters, mixer weights, SSE curves, match
   anchors) learns it before the target is coded. Encoder and decoder run this
   identically over the same reference file, so they stay in lockstep. */
static void train_base(const uint64_t *ctxv, uint64_t hist, int s) {
    double st[MAXIN], pp; uint16_t *slot[MAXIN], *ex[NMATCH + 1];
    int b1 = s >> 1, b0 = s & 1;
    int mc[NMIX]; MixState ms;
    SSEState ss;
    stcm_prepare();
    mix_ctxs(hist, mc);

    extra_slots(0, 0, ex);
    mix_predict(0, mc, ctxv, ex, st, slot, &ms, &pp);
    (void)sse_apply(0, hist, pp, &ss);
    mix_update(0, mc, st, slot, b1, pp, &ms);
    sse_update(0, hist, &ss, b1);

    int node = b1 ? 2 : 1;
    extra_slots(node, b1, ex);
    mix_predict(node, mc, ctxv, ex, st, slot, &ms, &pp);
    (void)sse_apply(node, hist, pp, &ss);
    mix_update(node, mc, st, slot, b0, pp, &ms);
    sse_update(node, hist, &ss, b0);
}

/* Feed a whole reference sequence through the models (no output produced). */
static void prime_with_reference(const uint8_t *ref, size_t n) {
    uint64_t hist = 0, ctxv[MAXIN];
    for (size_t p = 0; p < n; p++) {
        int s = ref[p];
        for (int i = 0; i < g_nmodels; i++)
            ctxv[i] = (g_tol[i] ? g_thist : hist) & g_ctxmask[i];
        train_base(ctxv, hist, s);
        hist = (hist << 2) | (uint64_t)s;
        match_after(s, hist);
            stcm_after(s, hist);
            ir_train(hist, g_thist);
    }
}

static void code_base_enc(REnc *e, const uint64_t *ctxv, uint64_t hist, int s) {
    double st[MAXIN], pp; uint16_t *slot[MAXIN], *ex[NMATCH + 1];
    int b1 = s >> 1, b0 = s & 1;
    int mc[NMIX]; MixState ms;
    SSEState ss;
    stcm_prepare();
    mix_ctxs(hist, mc);

    extra_slots(0, 0, ex);
    mix_predict(0, mc, ctxv, ex, st, slot, &ms, &pp);
    renc_bit(e, b1, pq_of(sse_apply(0, hist, pp, &ss)));
    mix_update(0, mc, st, slot, b1, pp, &ms);
    sse_update(0, hist, &ss, b1);

    int node = b1 ? 2 : 1;
    extra_slots(node, b1, ex);
    mix_predict(node, mc, ctxv, ex, st, slot, &ms, &pp);
    renc_bit(e, b0, pq_of(sse_apply(node, hist, pp, &ss)));
    mix_update(node, mc, st, slot, b0, pp, &ms);
    sse_update(node, hist, &ss, b0);
}
static int code_base_dec(RDec *d, const uint64_t *ctxv, uint64_t hist) {
    double st[MAXIN], pp; uint16_t *slot[MAXIN], *ex[NMATCH + 1];
    int mc[NMIX]; MixState ms;
    SSEState ss;
    stcm_prepare();
    mix_ctxs(hist, mc);

    extra_slots(0, 0, ex);
    mix_predict(0, mc, ctxv, ex, st, slot, &ms, &pp);
    int b1 = rdec_bit(d, pq_of(sse_apply(0, hist, pp, &ss)));
    mix_update(0, mc, st, slot, b1, pp, &ms);
    sse_update(0, hist, &ss, b1);

    int node = b1 ? 2 : 1;
    extra_slots(node, b1, ex);
    mix_predict(node, mc, ctxv, ex, st, slot, &ms, &pp);
    int b0 = rdec_bit(d, pq_of(sse_apply(node, hist, pp, &ss)));
    mix_update(node, mc, st, slot, b0, pp, &ms);
    sse_update(node, hist, &ss, b0);
    return (b1 << 1) | b0;
}

/* ----------------------------- Reference mode -------------------------------- */
/* Two genomes of a species differ by ~0.1%, so a target compressed against a
   reference should cost far less than one compressed alone. We do NOT diff the
   files: we let the reference TRAIN the same models (and fill the match anchors),
   which keeps every existing mechanism -- substitution tolerance, inverted
   repeats, order models -- working across the file boundary, and stays lossless
   even if the "reference" turns out to be unrelated. */

/* Read a FASTA/text file and keep only its bases, as symbols 0..3 (case-folded).
   Returns a malloc'd array, *n = count, or NULL on error/empty. */
static uint8_t *ref_load(const char *path, size_t *n) {
    FILE *f = fopen(path, "rb");
    if (!f) { perror("open reference"); return NULL; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 0) { fclose(f); fprintf(stderr, "empty reference\n"); return NULL; }
    uint8_t *raw = (uint8_t *)malloc((size_t)sz);
    if (!raw || fread(raw, 1, (size_t)sz, f) != (size_t)sz) {
        fprintf(stderr, "cannot read reference\n"); free(raw); fclose(f); return NULL;
    }
    fclose(f);
    size_t m = 0;
    int in_header = 0;
    for (long i = 0; i < sz; i++) {
        int c = raw[i];
        if (c == '>' || c == ';') in_header = 1;
        if (c == '\n') { in_header = 0; continue; }
        if (in_header) continue;
        if (c >= 'a' && c <= 'z') c -= 32;          /* soft-masked bases count too */
        int s = base_to_sym(c);
        if (s >= 0) raw[m++] = (uint8_t)s;
    }
    *n = m;
    if (m == 0) { free(raw); fprintf(stderr, "reference has no bases\n"); return NULL; }
    return raw;
}

/* 64-bit FNV-1a over the reference symbols: stored in the header so decompression
   with the wrong reference fails loudly instead of producing garbage. */
static uint64_t ref_fingerprint(const uint8_t *r, size_t n) {
    uint64_t h = 0xCBF29CE484222325ull;
    for (size_t i = 0; i < n; i++) { h ^= r[i]; h *= 0x100000001B3ull; }
    return h;
}

static void put64(FILE *f, uint64_t v) {
    for (int i = 0; i < 8; i++) fputc((int)((v >> (8 * i)) & 0xFF), f);
}
static uint64_t get64(FILE *f) {
    uint64_t v = 0;
    for (int i = 0; i < 8; i++) v |= ((uint64_t)(fgetc(f) & 0xFF)) << (8 * i);
    return v;
}

/* ---- primed state files ---------------------------------------------------- */
/* Priming costs a full modelling pass over the reference (~2.4 s per Mbase), paid
   by BOTH compressor and decompressor, every time. For the real use case -- many
   genomes stored against one reference -- that pass is identical every time, so
   we let it be done once and written out: `dnac prime ref.fa ref.state`. The
   state is just the models' memory (tables, mixer weights, SSE curves, anchors,
   and the reference's bases), so loading it is a disk read instead of a pass.
   Table sizes are derived from the reference alone, so a state file and the
   FASTA it came from produce bit-identical models and are interchangeable.
   Endianness/float layout are the host's -- a state file is a cache, not an
   interchange format; the compressed stream is the portable artefact. */

#define STATE_MAGIC "DNACST01"

static int wr(const void *p, size_t sz, size_t n, FILE *f) { return fwrite(p, sz, n, f) == n; }
static int rd(void *p, size_t sz, size_t n, FILE *f)       { return fread(p, sz, n, f)  == n; }

static int state_save(const char *path, int k, uint64_t refn, uint64_t reffp) {
    FILE *f = fopen(path, "wb");
    if (!f) { perror("open state"); return 1; }
    int ok = 1;
    ok &= wr(STATE_MAGIC, 1, 8, f);
    put64(f, (uint64_t)k);
    put64(f, (uint64_t)g_hashbits);
    put64(f, (uint64_t)g_mhb);
    put64(f, (uint64_t)g_nmodels);
    put64(f, refn);
    put64(f, reffp);
    ok &= wr(g_seq, 1, (size_t)refn, f);
    for (int i = 0; i < g_nmodels; i++) {
        put64(f, (uint64_t)g_size[i]);
        ok &= wr(g_tab[i], sizeof(uint16_t), g_size[i], f);
    }
    ok &= wr(g_w, sizeof(double), (size_t)NMIX * NNODES * MIXCTX * MAXIN, f);
    ok &= wr(g_v, sizeof(double), (size_t)NNODES * MIXCTX * (NMIX + 1), f);
    ok &= wr(g_apm1, sizeof(double), (size_t)APM_MAXCTX * APM_BINS, f);
    ok &= wr(g_apm2, sizeof(double), (size_t)APM_MAXCTX * APM_BINS, f);
    put64(f, g_thist); put64(f, (uint64_t)g_tfail); put64(f, (uint64_t)g_tpred);
    for (int mi = 0; mi < NMATCH; mi++) {
        MatchModel *m = &g_mm[mi];
        put64(f, (uint64_t)m->mp); put64(f, (uint64_t)m->mlen);
        put64(f, (uint64_t)m->active); put64(f, (uint64_t)m->miss);
        ok &= wr(m->hash, sizeof(uint32_t), ((size_t)1 << m->hbits) * MWAYS, f);
        ok &= wr(m->pr, sizeof(uint16_t), sizeof(m->pr) / sizeof(m->pr[0]), f);
    }
    put64(f, (uint64_t)g_rmp); put64(f, (uint64_t)g_rlen);
    put64(f, (uint64_t)g_ractive); put64(f, (uint64_t)g_rmiss);
    ok &= wr(g_rc_pr, sizeof(uint16_t), sizeof(g_rc_pr) / sizeof(g_rc_pr[0]), f);
    if (fclose(f) != 0) ok = 0;
    if (!ok) { fprintf(stderr, "could not write state file (disk full?)\n"); return 1; }
    return 0;
}

/* Is this file a primed state rather than a FASTA reference? */
static int is_state_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    char m[8] = {0};
    size_t got = fread(m, 1, 8, f);
    fclose(f);
    return got == 8 && memcmp(m, STATE_MAGIC, 8) == 0;
}

/* Load a primed state. `extra` = how many more bases the target may add.        */
static int state_load(const char *path, size_t extra, int *k_out,
                      uint64_t *refn_out, uint64_t *reffp_out) {
    FILE *f = fopen(path, "rb");
    if (!f) { perror("open state"); return 1; }
    char m[8];
    if (!rd(m, 1, 8, f) || memcmp(m, STATE_MAGIC, 8) != 0) {
        fprintf(stderr, "not a dnac state file: %s\n", path); fclose(f); return 1;
    }
    int k          = (int)get64(f);
    int hashbits   = (int)get64(f);
    int mhb        = (int)get64(f);
    int nmodels    = (int)get64(f);
    uint64_t refn  = get64(f);
    uint64_t reffp = get64(f);

    if (mix_setup(k, (size_t)refn, (size_t)refn + extra, hashbits, mhb)) { fclose(f); return 1; }
    if (g_nmodels != nmodels) {
        fprintf(stderr, "state file was built by a different dnac build\n"); fclose(f); return 1;
    }
    int ok = 1;
    ok &= rd(g_seq, 1, (size_t)refn, f);
    g_npos = (uint32_t)refn;
    for (int i = 0; i < g_nmodels; i++) {
        uint64_t sz = get64(f);
        if (sz != (uint64_t)g_size[i]) { fprintf(stderr, "state file layout mismatch\n"); fclose(f); return 1; }
        ok &= rd(g_tab[i], sizeof(uint16_t), g_size[i], f);
    }
    ok &= rd(g_w, sizeof(double), (size_t)NMIX * NNODES * MIXCTX * MAXIN, f);
    ok &= rd(g_v, sizeof(double), (size_t)NNODES * MIXCTX * (NMIX + 1), f);
    ok &= rd(g_apm1, sizeof(double), (size_t)APM_MAXCTX * APM_BINS, f);
    ok &= rd(g_apm2, sizeof(double), (size_t)APM_MAXCTX * APM_BINS, f);
    g_thist = get64(f); g_tfail = (int)get64(f); g_tpred = (int)get64(f);
    for (int mi = 0; mi < NMATCH; mi++) {
        MatchModel *m = &g_mm[mi];
        m->mp = (uint32_t)get64(f); m->mlen = (uint32_t)get64(f);
        m->active = (int)get64(f);  m->miss = (int)get64(f);
        ok &= rd(m->hash, sizeof(uint32_t), ((size_t)1 << m->hbits) * MWAYS, f);
        ok &= rd(m->pr, sizeof(uint16_t), sizeof(m->pr) / sizeof(m->pr[0]), f);
    }
    g_rmp = (uint32_t)get64(f); g_rlen = (uint32_t)get64(f);
    g_ractive = (int)get64(f);  g_rmiss = (int)get64(f);
    ok &= rd(g_rc_pr, sizeof(uint16_t), sizeof(g_rc_pr) / sizeof(g_rc_pr[0]), f);
    fclose(f);
    if (!ok) { fprintf(stderr, "state file is truncated or corrupt\n"); return 1; }
    *k_out = k; *refn_out = refn; *reffp_out = reffp;
    return 0;
}

/* `dnac prime <ref.fa> <state> [k]` */
static int do_prime(const char *refpath, const char *statepath, int k) {
    size_t refn = 0;
    uint8_t *ref = ref_load(refpath, &refn);
    if (!ref) return 1;
    if (mix_setup(k, refn, refn, -1, -1)) { free(ref); mix_free(); return 1; }
    uint64_t fp = ref_fingerprint(ref, refn);
    prime_with_reference(ref, refn);
    free(ref);
    int rc = state_save(statepath, k, (uint64_t)refn, fp);
    mix_free();
    return rc;
}

/* ------------------------------- Compress ----------------------------------- */

static int do_compress(const char *inpath, const char *outpath, int k, const char *refpath) {
    FILE *in = fopen(inpath, "rb");
    if (!in) { perror("open input"); return 1; }
    fseek(in, 0, SEEK_END);
    long n = ftell(in);
    fseek(in, 0, SEEK_SET);
    if (n < 0) { fclose(in); fprintf(stderr, "bad input size\n"); return 1; }
    uint8_t *buf = (uint8_t *)malloc((size_t)n ? (size_t)n : 1);
    if (n && fread(buf, 1, (size_t)n, in) != (size_t)n) { perror("read"); fclose(in); return 1; }
    fclose(in);

    memset(lit_cnt, 0, sizeof(lit_cnt));
    memset(flag_cnt, 0, sizeof(flag_cnt));

    /* Three ways in: no reference, a reference FASTA (prime now), or a state
       file (priming already done). The last two produce identical models. */
    uint8_t *ref = NULL; size_t refn = 0; uint64_t reffp = 0;
    int from_state = refpath && is_state_file(refpath);
    if (from_state) {
        uint64_t rn = 0;
        if (state_load(refpath, (size_t)n, &k, &rn, &reffp)) { free(buf); mix_free(); return 1; }
        refn = (size_t)rn;
    } else {
        if (refpath) {
            ref = ref_load(refpath, &refn);
            if (!ref) { free(buf); return 1; }
            reffp = ref_fingerprint(ref, refn);
        }
        if (mix_setup(k, refpath ? refn : (size_t)n, (size_t)n + refn, -1, -1)) {
            free(buf); free(ref); mix_free(); return 1;
        }
    }

    FILE *out = fopen(outpath, "wb");
    if (!out) { perror("open output"); free(buf); free(ref); mix_free(); return 1; }
    /* header: magic ('A' plain / 'R' reference), k, original length [, ref info] */
    fputc('D', out); fputc('N', out); fputc('C', out); fputc(refpath ? 'R' : 'A', out);
    fputc((int)k, out);
    put64(out, (uint64_t)n);
    if (refpath) { put64(out, (uint64_t)refn); put64(out, reffp); }

    if (ref) { prime_with_reference(ref, refn); free(ref); ref = NULL; }

    REnc e; renc_init(&e, out);
    uint64_t hist = 0;
    int run = 0;

    for (long p = 0; p < n; p++) {
        int b = buf[p];
        int s = base_to_sym(b);
        int rc = run < RUNCAP ? run : RUNCAP;
        uint16_t *fc = &flag_cnt[rc * 2];
        uint32_t f0 = (uint32_t)fc[0] + 1, f1 = (uint32_t)fc[1] + 1, ft = f0 + f1;

        if (s >= 0) {                          /* a base: flag=0, then mixed prediction */
            renc_encode(&e, 0, f0, ft);
            fc[0]++;
            uint64_t ctxv[MAXIN];
            for (int i = 0; i < g_nmodels; i++)
            ctxv[i] = (g_tol[i] ? g_thist : hist) & g_ctxmask[i];
            code_base_enc(&e, ctxv, hist, s);
            hist = (hist << 2) | (uint64_t)s;
            match_after(s, hist);
            stcm_after(s, hist);
            ir_train(hist, g_thist);
            run++;
        } else {                               /* not a base: flag=1, then literal byte */
            renc_encode(&e, f0, f1, ft);
            fc[1]++;
            uint32_t lf[256], ltot = 0;
            for (int i = 0; i < 256; i++) { lf[i] = (uint32_t)lit_cnt[i] + 1; ltot += lf[i]; }
            uint32_t lcum = 0; for (int i = 0; i < b; i++) lcum += lf[i];
            renc_encode(&e, lcum, lf[b], ltot);
            lit_cnt[b]++;
            if (ltot + 1 >= CAP) for (int i = 0; i < 256; i++) lit_cnt[i] >>= 1;
            run = 0;
        }
        if (ft + 1 >= CAP) { fc[0] >>= 1; fc[1] >>= 1; }
    }
    renc_flush(&e);
    fclose(out);
    free(buf); mix_free();
    return 0;
}

/* ------------------------------ Decompress ---------------------------------- */

static int do_decompress(const char *inpath, const char *outpath, const char *refpath) {
    FILE *in = fopen(inpath, "rb");
    if (!in) { perror("open input"); return 1; }
    int m0 = fgetc(in), m1 = fgetc(in), m2 = fgetc(in), m3 = fgetc(in);
    if (m0 != 'D' || m1 != 'N' || m2 != 'C' || (m3 != 'A' && m3 != 'R')) {
        fprintf(stderr, "not a dnac file\n"); fclose(in); return 1;
    }
    int need_ref = (m3 == 'R');
    if (need_ref && !refpath) {
        fprintf(stderr, "this file was compressed against a reference: use  dnac dr <in> <out> <ref.fa>\n");
        fclose(in); return 1;
    }
    if (!need_ref && refpath) {
        fprintf(stderr, "this file was compressed without a reference: use  dnac d <in> <out>\n");
        fclose(in); return 1;
    }
    int k = fgetc(in);
    uint64_t len = get64(in);
    uint64_t refn_hdr = 0, refhash_hdr = 0;
    if (need_ref) { refn_hdr = get64(in); refhash_hdr = get64(in); }

    memset(lit_cnt, 0, sizeof(lit_cnt));
    memset(flag_cnt, 0, sizeof(flag_cnt));

    uint8_t *ref = NULL; size_t refn = 0; uint64_t reffp = 0;
    if (need_ref && is_state_file(refpath)) {
        uint64_t rn = 0;
        int ks = k;
        if (state_load(refpath, (size_t)len, &ks, &rn, &reffp)) { fclose(in); mix_free(); return 1; }
        refn = (size_t)rn;
        if ((uint64_t)refn != refn_hdr || reffp != refhash_hdr) {
            fprintf(stderr, "wrong reference: this file was compressed against a different one\n");
            fclose(in); mix_free(); return 1;
        }
    } else {
        if (need_ref) {
            ref = ref_load(refpath, &refn);
            if (!ref) { fclose(in); return 1; }
            if ((uint64_t)refn != refn_hdr || ref_fingerprint(ref, refn) != refhash_hdr) {
                fprintf(stderr, "wrong reference: this file was compressed against a different one\n");
                free(ref); fclose(in); return 1;
            }
        }
        if (mix_setup(k, need_ref ? refn : (size_t)len, (size_t)len + refn, -1, -1)) {
            free(ref); fclose(in); mix_free(); return 1;
        }
    }

    FILE *out = fopen(outpath, "wb");
    if (!out) { perror("open output"); free(ref); fclose(in); mix_free(); return 1; }

    if (ref) { prime_with_reference(ref, refn); free(ref); ref = NULL; }

    RDec d; rdec_init(&d, in);
    uint64_t hist = 0;
    int run = 0;

    for (uint64_t p = 0; p < len; p++) {
        int rc = run < RUNCAP ? run : RUNCAP;
        uint16_t *fc = &flag_cnt[rc * 2];
        uint32_t f0 = (uint32_t)fc[0] + 1, f1 = (uint32_t)fc[1] + 1, ft = f0 + f1;
        uint32_t fdv = rdec_getfreq(&d, ft);
        int isbase = (fdv < f0);
        if (isbase) { rdec_update(&d, 0, f0); fc[0]++; }
        else        { rdec_update(&d, f0, f1); fc[1]++; }

        if (isbase) {
            uint64_t ctxv[MAXIN];
            for (int i = 0; i < g_nmodels; i++)
            ctxv[i] = (g_tol[i] ? g_thist : hist) & g_ctxmask[i];
            int s = code_base_dec(&d, ctxv, hist);
            fputc(SYM_TO_BASE[s], out);
            hist = (hist << 2) | (uint64_t)s;
            match_after(s, hist);
            stcm_after(s, hist);
            ir_train(hist, g_thist);
            run++;
        } else {
            uint32_t lf[256], ltot = 0;
            for (int i = 0; i < 256; i++) { lf[i] = (uint32_t)lit_cnt[i] + 1; ltot += lf[i]; }
            uint32_t ldv = rdec_getfreq(&d, ltot);
            uint32_t lcum = 0; int b = 0;
            while (b < 255 && lcum + lf[b] <= ldv) { lcum += lf[b]; b++; }
            rdec_update(&d, lcum, lf[b]);
            fputc(b, out);
            lit_cnt[b]++;
            if (ltot + 1 >= CAP) for (int i = 0; i < 256; i++) lit_cnt[i] >>= 1;
            run = 0;
        }
        if (ft + 1 >= CAP) { fc[0] >>= 1; fc[1] >>= 1; }
    }
    fclose(out); fclose(in);
    mix_free();
    return 0;
}

/* --------------------- Sample generator (structured DNA) -------------------- */
/* Produces DNA with real structure (a Markov chain + occasional repeats) and  */
/* FASTA-style 70-column lines + a header, so the demo mirrors real files.     */

static uint64_t rng_state = 0x2545F4914F6CDD1Dull;
static uint32_t xrng(void) {
    rng_state ^= rng_state << 13; rng_state ^= rng_state >> 7; rng_state ^= rng_state << 17;
    return (uint32_t)(rng_state >> 32);
}

static int do_gen(const char *outpath, long bases, unsigned seed) {
    rng_state = 0x2545F4914F6CDD1Dull ^ ((uint64_t)seed * 0x9E3779B97F4A7C15ull + 1);
    FILE *out = fopen(outpath, "wb");
    if (!out) { perror("open output"); return 1; }
    fprintf(out, ">synthetic_structured_dna len=%ld seed=%u\n", bases, seed);

    /* order-2 Markov transition weights (skewed -> compressible structure) */
    /* trans[a][b][next] : higher weight = more likely next base            */
    static const int W[4][4][4] = {
        {{50,10,10,30},{10,50,30,10},{30,10,50,10},{10,30,10,50}},
        {{40,20,30,10},{10,40,10,40},{20,30,40,10},{30,10,20,40}},
        {{10,40,20,30},{40,10,40,10},{10,20,50,20},{20,30,10,40}},
        {{30,10,40,20},{20,40,10,30},{40,10,30,20},{10,20,40,30}},
    };
    char *seq = (char *)malloc((size_t)bases + 1);
    int a = 0, b = 0;
    for (long i = 0; i < bases; i++) {
        /* occasionally splice in a repeat of an earlier stretch (real genomes repeat) */
        if (i > 5000 && (xrng() % 1000) < 6) {
            long src = (long)(xrng() % (uint32_t)(i - 2000));
            long L = 200 + (long)(xrng() % 800);
            for (long j = 0; j < L && i < bases; j++, i++) seq[i] = seq[src + j];
            if (i >= 2) { a = base_to_sym(seq[i-2]); b = base_to_sym(seq[i-1]); }
            i--; continue;
        }
        const int *w = W[a][b];
        int tot = w[0] + w[1] + w[2] + w[3];
        int r = (int)(xrng() % (uint32_t)tot), nx = 0, acc = 0;
        for (nx = 0; nx < 4; nx++) { acc += w[nx]; if (r < acc) break; }
        seq[i] = SYM_TO_BASE[nx];
        a = b; b = nx;
    }
    for (long i = 0; i < bases; i++) {
        fputc(seq[i], out);
        if ((i + 1) % 70 == 0) fputc('\n', out);
    }
    if (bases % 70 != 0) fputc('\n', out);
    free(seq); fclose(out);
    return 0;
}

/* ------------------- Simulated resequencing (for testing) ------------------- */
/* Two humans differ by ~1 base in 1000. To test reference-based compression
   without downloading two assemblies, `mut` derives a realistic "individual"
   from a genome: SNPs at the requested rate, plus short indels at 1/10 of it.
   The output is a fresh FASTA, so it is a genuinely different file, not a diff. */

static int do_mutate(const char *inpath, const char *outpath, double permille, unsigned seed) {
    size_t n = 0;
    uint8_t *sym = ref_load(inpath, &n);
    if (!sym) return 1;
    rng_state = 0x2545F4914F6CDD1Dull ^ ((uint64_t)seed * 0x9E3779B97F4A7C15ull + 1);

    FILE *out = fopen(outpath, "wb");
    if (!out) { perror("open output"); free(sym); return 1; }
    fprintf(out, ">simulated_individual from=%s snp_per_mille=%.3f seed=%u\n",
            inpath, permille, seed);

    uint32_t snp_thresh  = (uint32_t)(permille * 1e-3 * 4294967296.0);
    uint32_t idel_thresh = snp_thresh / 10;
    long col = 0;
    for (size_t i = 0; i < n; i++) {
        uint32_t r = xrng();
        if (r < idel_thresh) {                       /* short indel */
            int len = 1 + (int)(xrng() % 10);
            if (xrng() & 1) { i += (size_t)len; continue; }   /* deletion */
            for (int j = 0; j < len; j++) {                   /* insertion */
                fputc(SYM_TO_BASE[xrng() & 3], out);
                if (++col % 70 == 0) fputc('\n', out);
            }
        }
        int s = sym[i];
        if (r < snp_thresh) s = (s + 1 + (int)(xrng() % 3)) & 3;   /* substitution */
        fputc(SYM_TO_BASE[s], out);
        if (++col % 70 == 0) fputc('\n', out);
    }
    if (col % 70 != 0) fputc('\n', out);
    fclose(out); free(sym);
    return 0;
}

/* --------------------------------- main ------------------------------------- */

int main(int argc, char **argv) {
    if (argc >= 4 && strcmp(argv[1], "c") == 0) {
        int k = (argc >= 5) ? atoi(argv[4]) : 22;
        if (k < 1 || k > 28) { fprintf(stderr, "k (max order) must be 1..28\n"); return 1; }
        return do_compress(argv[2], argv[3], k, NULL);
    }
    if (argc >= 5 && strcmp(argv[1], "cr") == 0) {
        int k = (argc >= 6) ? atoi(argv[5]) : 22;
        if (k < 1 || k > 28) { fprintf(stderr, "k (max order) must be 1..28\n"); return 1; }
        return do_compress(argv[2], argv[3], k, argv[4]);
    }
    if (argc >= 4 && strcmp(argv[1], "d") == 0) {
        return do_decompress(argv[2], argv[3], NULL);
    }
    if (argc >= 5 && strcmp(argv[1], "dr") == 0) {
        return do_decompress(argv[2], argv[3], argv[4]);
    }
    if (argc >= 4 && strcmp(argv[1], "prime") == 0) {
        int k = (argc >= 5) ? atoi(argv[4]) : 22;
        if (k < 1 || k > 28) { fprintf(stderr, "k (max order) must be 1..28\n"); return 1; }
        return do_prime(argv[2], argv[3], k);
    }
    if (argc >= 4 && strcmp(argv[1], "gen") == 0) {
        long bases = atol(argv[3]);
        unsigned seed = (argc >= 5) ? (unsigned)strtoul(argv[4], NULL, 10) : 1u;
        return do_gen(argv[2], bases, seed);
    }
    if (argc >= 4 && strcmp(argv[1], "mut") == 0) {
        double permille = (argc >= 5) ? atof(argv[4]) : 1.0;
        unsigned seed = (argc >= 6) ? (unsigned)strtoul(argv[5], NULL, 10) : 1u;
        return do_mutate(argv[2], argv[3], permille, seed);
    }
    fprintf(stderr,
        "dnac - lossless DNA compressor (context mixing + match models)\n"
        "  dnac c  <in> <out> [k]        compress (k = max model order, default 22)\n"
        "  dnac d  <in> <out>            decompress\n"
        "  dnac cr <in> <out> <ref> [k]  compress against a reference genome\n"
        "  dnac dr <in> <out> <ref>      decompress (same reference required)\n"
        "     <ref> may be a FASTA file or a primed state built with:\n"
        "  dnac prime <ref.fa> <state> [k]   pay the priming pass once\n"
        "  dnac gen <out> <bases> [seed] generate a structured sample\n"
        "  dnac mut <in> <out> [per-mille] [seed]   simulate a resequenced genome\n");
    return 1;
}
